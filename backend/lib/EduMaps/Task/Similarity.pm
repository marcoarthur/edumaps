package EduMaps::Task::Similarity;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use EduMaps::Analysis::R::Pipe;
use Time::Piece;

use constant {
  STAGING_SCHEMA   => 'staging',
  ANALYTICS_SCHEMA => 'analytics',
  DB_SERVICE       => 'edumaps_local',
  DEFAULT_METRIC   => 'gower',
};

# Mapa unico: metrica -> nome da funcao R correspondente. Mesma logica do
# ALGORITHM_R_FUNCTION em Task::Clustering: fonte unica de verdade, para
# nao repetir o bug historico de 'metric' ser validado mas nao usado para
# escolher o script/funcao real.
use constant METRIC_R_FUNCTION => {
  gower            => 'compute_and_save_gower_similarity',
  euclidean_zscore => 'compute_and_save_euclidean_zscore_similarity',
  mahalanobis      => 'compute_and_save_mahalanobis_similarity',
  aitchison        => 'compute_and_save_aitchison_similarity',
  dtw              => 'compute_and_save_dtw_similarity',
};

# Validacao extra especifica de cada metrica. A maioria nao precisa de
# nada alem do id_column/table_name genericos (as features numericas sao
# auto-detectadas pelo script R, como ja acontece em kmeans.R/dbscan.R).
# aitchison e dtw sao excecoes: dependem de colunas que so fazem sentido
# semanticamente escolhidas por quem chama (colunas composicionais,
# coluna de tempo/valor de uma serie), entao sao obrigatorias.
my %METRIC_VALIDATORS = (
  gower            => sub ($v) {},
  euclidean_zscore => sub ($v) {},
  mahalanobis      => sub ($v) {},
  aitchison        => sub ($v) {},
  dtw              => sub ($v) {
    $v->required('time_column', 'trim')->like(qr/^\w+$/);
    $v->required('value_column', 'trim')->like(qr/^\w+$/);
    $v->optional('entity_column', 'trim')->like(qr/^\w+$/);
  },
);

# Checagens que nao cabem bem no Mojolicious::Validation (ex: arrayref),
# aplicadas manualmente apos a validacao geral passar - mesmo padrao usado
# para os ranges de eps/min_pts em Task::Clustering.
my %METRIC_MANUAL_CHECKS = (
  aitchison => sub ($args) {
    return "'composition_columns' e obrigatorio para aitchison e precisa ter pelo menos 2 colunas"
      unless ref $args->{composition_columns} eq 'ARRAY'
          && @{ $args->{composition_columns} } >= 2;
    return undef;
  },
);

# Monta o trecho de argumentos nomeados especifico de cada metrica, usado
# para completar a chamada da funcao R.
my %METRIC_R_ARGS = (
  gower            => sub ($a) { '' },
  euclidean_zscore => sub ($a) { '' },
  mahalanobis      => sub ($a) { '' },
  aitchison        => sub ($a) {
    my $cols = join(', ', map { qq{"$_"} } @{ $a->{composition_columns} });
    "composition_columns = c($cols)";
  },
  dtw => sub ($a) {
    my $entity_col = $a->{entity_column} // $a->{id_column};
    sprintf(
      'time_column = "%s", value_column = "%s", entity_column = "%s"',
      $a->{time_column}, $a->{value_column}, $entity_col
    );
  },
);

sub register ($self, $app, $config) {
  $app->minion->add_task(
    similarity => task {
        sub => \&_apply_similarity,
        roles => {'+Progress' => {log => $app->log}},
      }
  );
  $app->helper(
    apply_similarity => sub ($c, $args) { $app->minion->enqueue( similarity => [$args] ) }
  );
}

sub _apply_similarity($job, $args) {
  my $v = $job->app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  # A metrica precisa ser resolvida ANTES da validacao completa, pois as
  # regras de dtw/aitchison sao condicionais a ela.
  my $metric = $args->{metric} // DEFAULT_METRIC;

  $v->input($args);
  $v->required('id_column', 'trim')->like(qr/^\w+$/);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+$/);
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('db_service', 'trim')->like(qr/^\w+$/);
  $v->optional('metric', 'trim')->in(sort keys %{ +METRIC_R_FUNCTION() });

  return $job->fail("Invalid metric '$metric'")
    unless exists METRIC_R_FUNCTION->{$metric};

  ($METRIC_VALIDATORS{$metric} // sub {})->($v);

  return $job->fail("Invalid arguments!") if $v->has_error;

  if (my $check = $METRIC_MANUAL_CHECKS{$metric}) {
    if (my $error = $check->($args)) {
      return $job->fail("Invalid arguments! ($error)");
    }
  }

  # Defaults gerais
  $args->{metric}      = $metric;
  $args->{schema}     //= STAGING_SCHEMA;
  $args->{db_service} //= DB_SERVICE;
  $args->{source_file} //= $metric;

  my $r_function = METRIC_R_FUNCTION->{$metric};
  my $extra_args = $METRIC_R_ARGS{$metric}->($args);
  # separador de virgula so quando ha argumentos extras
  my $extra_args_sep = length($extra_args) ? ",\n            $extra_args" : '';

  my $r_out;
  try {
    $r_out = $rpipe->run(
      {
        paths => $args->{paths} || $job->app->renderer->paths,
        source_file => $args->{source_file} . '.R',
        script => <<~"EOS",
          ${r_function}(
            con           = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
            schema        = "$args->{schema}",
            table_name    = "$args->{table_name}",
            id_column     = "$args->{id_column}",
            output_schema = "@{[ ANALYTICS_SCHEMA ]}"${extra_args_sep}
          )
        EOS
      }
    );
  } catch($err) {
    return $job->fail("Error running R ($metric): $err");
  }

  my $end = localtime;
  $job->finish(
    {
      meta => {
        name    => 'similarity',
        job_id  => $job->id,
        metric  => $metric,
        took    => $end - $start,
      },
      similarity_info => {
        query_args => {
          schema_name  => ANALYTICS_SCHEMA,
          output_table => 'similarity_pairs',
          target_table => $args->{schema} . '.' . $args->{table_name},
          metric       => $metric,
          # run_id vem de r_meta.run_id - usado para filtrar a execucao
          # mais recente ao consultar analytics.similarity_pairs (ver
          # comentario sobre historico em similarity_utils.R)
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

EduMaps::Task::Similarity - Plugin do Mojolicious para calculo assíncrono de similaridade par-a-par via R

=head1 SYNOPSIS

    # No startup da aplicação EduMaps
    $self->plugin('EduMaps::Task::Similarity');

    # Similaridade generica (Gower - lida com mistura de tipos automaticamente)
    my $job_id = $c->apply_similarity({
        id_column  => 'cod_municipio',
        table_name => 'municipio_perfil',
        schema     => 'staging',
        metric     => 'gower',            # opcional, padrão: 'gower'
    });

    # Similaridade composicional (ex: proporcao de gasto por categoria)
    my $job_id = $c->apply_similarity({
        id_column  => 'cod_municipio',
        table_name => 'municipio_gastos',
        metric     => 'aitchison',
        composition_columns => [qw/pct_educacao pct_saude pct_infra/],
    });

    # Similaridade de trajetoria temporal (formato longo: uma linha por
    # entidade+periodo)
    my $job_id = $c->apply_similarity({
        id_column     => 'cod_municipio',
        table_name    => 'municipio_ideb_historico',
        metric        => 'dtw',
        time_column   => 'ano',
        value_column  => 'nota_ideb',
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::Similarity> calcula similaridade par-a-par entre
entidades (municípios, escolas, etc.) com base em um perfil de variáveis,
seguindo o mesmo padrão de dispatch por parâmetro (aqui C<metric>, em vez de
C<algorithm>) usado por L<EduMaps::Task::Clustering>. Diferente do
clustering, o resultado tem cardinalidade O(n²) (todos os pares), por isso é
sempre persistido em C<analytics.similarity_pairs> em vez de devolvido por
completo no payload do job - o job devolve apenas um resumo (ver
C<similarity_utils.R>).

=head1 METRICAS

=over 4

=item * B<gower> - distância de Gower, lida nativamente com mistura de
variáveis numéricas/categóricas. Boa escolha default quando não se sabe
exatamente o tipo de cada coluna.

=item * B<euclidean_zscore> - Z-score + distância euclidiana (equivalente ao
que o script SQL original de similaridade de municípios fazia à mão).

=item * B<mahalanobis> - como euclidean_zscore, mas corrige a distância pela
covariância entre as variáveis (evita "contar duas vezes" variáveis
correlacionadas).

=item * B<aitchison> - para dados composicionais (proporções que somam a um
total fixo, ex: % de gasto por categoria, % de uso do solo). Requer
C<composition_columns>.

=item * B<dtw> - Dynamic Time Warping, compara trajetórias/séries temporais
inteiras em vez de um valor pontual. Requer dados em formato longo
(C<time_column>, C<value_column>).

=back

=head1 HELPERS

=head2 apply_similarity

    my $job_id = $c->apply_similarity(\%args);

Enfileira um novo cálculo de similaridade e retorna o identificador único do
Job no Minion.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>, L<EduMaps::Task::Clustering>

=cut
