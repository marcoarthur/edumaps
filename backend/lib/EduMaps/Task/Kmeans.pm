package EduMaps::Task::Kmeans;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use EduMaps::Analysis::R::Pipe;
use Time::Piece;

use constant { 
  STAGING_SCHEMA  => 'staging',
  DB_SERVICE      => 'edumaps_local',
  KMEANS_SCRIPT   => 'kmeans.R',
  CLUSTERS_SIZE   => 5,
};

sub register ($self, $app, $config) {
  # registra task
  $app->minion->add_task(
    clusterization => task {
        sub => \&_apply_kmeans,
        roles => {'+Progress' => {log => $app->log}},
      }
  );

  # adiciona o helper
  $app->helper(
    apply_kmeans => sub ($c, $args) { $app->minion->enqueue( clusterization => [$args] ) }
  );
}

sub _apply_kmeans($job, $args) {
  # verifica os argumentos
  my $v = $job->app->validator->validation;
  my $start = localtime;
  my $rpipe = EduMaps::Analysis::R::Pipe->new;

  $v->input($args);
  $v->required('id_column', 'trim')->like(qr/^\w+$/);
  $v->required('table_name', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('source_file', 'trim')->like(qr/^\w+\.R$/);
  $v->optional('schema', 'trim')->like(qr/^[a-zA-Z]\w+$/);
  $v->optional('clusters', 'trim')->num(2,10);
  $v->optional('db_service', 'trim')->like(qr/^\w+$/);

  return job->fail("Invalid arguments!") if $v->has_error;

  $args->{source_file}  //= KMEANS_SCRIPT;
  $args->{schema}       //= STAGING_SCHEMA;
  $args->{clusters}     //= CLUSTERS_SIZE;
  $args->{db_service}   //= DB_SERVICE;

  # motor R para cálculo de clusters
  try {
    $rpipe->run(
      {
        paths => $job->app->renderer->paths,
        source_file => $args->{source_file},
        script => <<~"EOS",
          compute_and_save_kmeans_with_meta(
            con        = dbConnect(RPostgres::Postgres(), service = "$args->{db_service}"),
            schema     = "$args->{schema}",
            table_name = "$args->{table_name}",
            k          = $args->{clusters},
            id_column  = "$args->{id_column}"
          )
        EOS
      }
    );
  } catch($err) {
    return $job->fail("Error running R: $err");
  }

  my $end = localtime;

  $job->finish(
    {
      meta => {
        name => 'clusterization',
        job_id => $job->id,
        took => $end - $start,
      },
      cluster_info => {
        inject_args => {
          schema_name => $args->{schema},
          id_column => $args->{id_column},
          cluster_column => 'cluster_id',
          table_name => $args->{table_name},
        },
      }
    }
  );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

EduMaps::Task::Kmeans - Plugin do Mojolicious para processamento assíncrono de clusterização K-means via R

=head1 SYNOPSIS

    # No startup da aplicação EduMaps
    $self->plugin('EduMaps::Task::Kmeans');

    # Em algum controller ou ação para enfileirar a tarefa
    my $job_id = $c->apply_kmeans({
        id_column  => 'co_entidade',
        table_name => 'test_cluster',
        schema     => 'staging',     # opcional, padrão: 'staging'
        clusters   => 5,             # opcional, padrão: 5
    });

=head1 DESCRIPTION

O módulo L<EduMaps::Task::Kmeans> atua como uma ponte assíncrona entre o gerenciador de tarefas L<Minion> e o motor estatístico R. Ele registra a tarefa C<clusterization> para processamento em background de algoritmos de agrupamento (K-means) sobre tabelas de dados educacionais.

=head1 HELPERS

=head2 apply_kmeans

    my $job_id = $c->apply_kmeans(\%args);

Enfileira um novo processo de clusterização e retorna o identificador único do Job no Minion.

=head1 SEE ALSO

L<Minion>, L<EduMaps::Analysis::R::Pipe>

=cut
