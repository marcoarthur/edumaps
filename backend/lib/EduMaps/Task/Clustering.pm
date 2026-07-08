package EduMaps::Task::Clustering;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use EduMaps::Analysis::R::Pipe;
use Time::Piece;

use constant {
  STAGING_SCHEMA    => 'staging',
  DB_SERVICE        => 'edumaps_local',
  DEFAULT_ALGORITHM => 'kmeans',
  DEFAULT_CLUSTERS  => 5,
  DEFAULT_EPS       => 0.5,
  DEFAULT_MIN_PTS   => 5,
};

# Mapa unico e explicito: algoritmo -> nome da funcao R correspondente.
# Esta e a UNICA fonte de verdade sobre quais algoritmos existem;
# a lista de valores aceitos pelo validador e derivada daqui (ver abaixo),
# para nunca mais divergir como aconteceu antes (algorithm validado mas
# nao usado para escolher a funcao/script real).
use constant ALGORITHM_R_FUNCTION => {
  kmeans   => 'compute_and_save_kmeans_with_meta',
  dbscan   => 'compute_and_save_dbscan_with_meta',
  gmm      => 'compute_and_save_gmm_with_meta',
  spectral => 'compute_and_save_spectral_with_meta',
};

# Validacao adicional de parametros especifica de cada algoritmo.
# Cada entrada recebe o objeto $v (Mojolicious::Validation) ja com
# ->input() chamado, e adiciona as regras extras necessarias.
my %ALGORITHM_VALIDATORS = (
  kmeans   => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  gmm      => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  spectral => sub ($v) { $v->optional('clusters', 'trim')->num(2, 10) },
  dbscan   => sub ($v) {
    $v->optional('eps', 'trim')->is_between(0.0001,100);
    $v->optional('min_pts', 'trim')->num(1, 1000);
  },
);

# Defaults aplicados apos a validacao passar, quando o parametro
# correspondente nao foi informado.
my %ALGORITHM_DEFAULTS = (
  kmeans   => { clusters => DEFAULT_CLUSTERS },
  gmm      => { clusters => DEFAULT_CLUSTERS },
  spectral => { clusters => DEFAULT_CLUSTERS },
  dbscan   => { eps => DEFAULT_EPS, min_pts => DEFAULT_MIN_PTS },
);

# Monta o trecho de argumentos nomeados especifico de cada algoritmo,
# usado para completar a chamada da funcao R.
my %ALGORITHM_R_ARGS = (
  kmeans   => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  gmm      => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  spectral => sub ($a) { sprintf('k = %d', $a->{clusters}) },
  dbscan   => sub ($a) {
    # sprintf com %.10g normaliza notacao cientifica/locale e evita
    # que um eps tipo 1e-05 quebre a interpolacao no script R
    sprintf('eps = %.10g, min_pts = %d', $a->{eps}, $a->{min_pts});
  },
);

sub register ($self, $app, $config) {
  # registra task
  $app->minion->add_task(clusterization => \&_apply_clustering);

  # adiciona o helper
  $app->helper(
    apply_clustering => sub ($c, $args) { $app->minion->enqueue( clusterization => [$args] ) }
  );
}

sub _apply_clustering($job, $args) {
  my $v = $job->app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  # O algoritmo precisa ser resolvido ANTES da validacao completa,
  # pois algumas regras (clusters vs eps/min_pts) sao condicionais a ele.
  my $algorithm = $args->{algorithm} // DEFAULT_ALGORITHM;

  $v->input($args);
  $v->required('id_column', 'trim')->like(qr/^\w+$/);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+$/);
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('db_service', 'trim')->like(qr/^\w+$/);
  $v->optional('algorithm', 'trim')->in(sort keys %{ +ALGORITHM_R_FUNCTION() });

  return $job->fail("Invalid algorithm '$algorithm'")
    unless exists ALGORITHM_R_FUNCTION->{$algorithm};

  ($ALGORITHM_VALIDATORS{$algorithm} // sub {})->($v);

  return $job->fail("Invalid arguments!") if $v->has_error;

  # Defaults gerais
  $args->{algorithm}    = $algorithm;
  $args->{schema}     //= STAGING_SCHEMA;
  $args->{db_service} //= DB_SERVICE;
  # source_file segue o algoritmo por padrao (kmeans.R, dbscan.R, ...),
  # mas pode ser sobrescrito explicitamente (ex: para apontar a uma
  # variante/versao alternativa do script durante testes)
  $args->{source_file} //= $algorithm;

  # Defaults especificos do algoritmo (clusters | eps+min_pts | ...)
  for my $key (keys %{ $ALGORITHM_DEFAULTS{$algorithm} // {} }) {
    $args->{$key} //= $ALGORITHM_DEFAULTS{$algorithm}{$key};
  }

  my $r_function  = ALGORITHM_R_FUNCTION->{$algorithm};
  my $extra_args  = $ALGORITHM_R_ARGS{$algorithm}->($args);

  my $r_out;
  try {
    $r_out = $rpipe->run(
      {
        paths => $args->{paths} || $job->app->renderer->paths,
        source_file => $args->{source_file} . '.R',
        script => <<~"EOS",
          ${r_function}(
            con        = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
            schema     = "$args->{schema}",
            table_name = "$args->{table_name}",
            id_column  = "$args->{id_column}",
            $extra_args
          )
        EOS
      }
    );
  } catch($err) {
    return $job->fail("Error running R ($algorithm): $err");
  }

  my $end = localtime;
  $job->finish(
    {
      meta => {
        name => 'clusterization',
        job_id => $job->id,
        algorithm => $algorithm,
        took => $end - $start,
      },
      cluster_info => {
        inject_args => {
          schema_name => $args->{schema},
          id_column => $args->{id_column},
          cluster_column => 'cluster_id',
          table_name => $args->{table_name},
        },
        r_meta => $r_out,
      }
    }
  );
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Task::Clustering - Plugin do Mojolicious para processamento assíncrono de clusterização via R

=head1 SYNOPSIS

    # No startup da aplicação EduMaps
    $self->plugin('EduMaps::Task::Clustering');

    # Em algum controller ou ação para enfileirar a tarefa
    my $job_id = $c->apply_clustering({
        id_column  => 'co_entidade',
        table_name => 'test_cluster',
        algorithm  => 'dbscan',      # opcional: kmeans, dbscan, gmm, spectral. Padrão kmeans
        schema     => 'staging',     # opcional, padrão: 'staging'
        clusters   => 5,             # opcional (kmeans/gmm/spectral), padrão: 5
        eps        => 0.5,           # opcional (dbscan), padrão: 0.5
        min_pts    => 5,             # opcional (dbscan), padrão: 5
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::Clustering> atua como uma ponte assíncrona entre o
gerenciador de tarefas L<Minion> e o motor estatístico R. Ele registra a
tarefa C<clusterization> para processamento em background de algoritmos de
agrupamento (K-means, DBSCAN, GMM, Spectral) sobre tabelas de dados
educacionais. O algoritmo efetivamente executado é resolvido dinamicamente
a partir do parâmetro C<algorithm>, tanto para localizar o script R
(C<{algorithm}.R>) quanto para escolher a função R chamada
(ver C<ALGORITHM_R_FUNCTION>).

=head1 HELPERS

=head2 apply_clustering

    my $job_id = $c->apply_clustering(\%args);

Enfileira um novo processo de clusterização e retorna o identificador único do Job no Minion.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>

=cut
