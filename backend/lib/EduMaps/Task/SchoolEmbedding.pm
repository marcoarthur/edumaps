package EduMaps::Task::SchoolEmbedding;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use Minion::Task::Generator qw/task/;
use Time::Piece;

# Ordem das dimensões do embedding — FONTE ÚNICA DE VERDADE.
# Precisa ser IDÊNTICA à usada em:
#   - data_pipeline/deploy/school_embedding.sql (backfill)
#   - EduMaps::Schema::ResultSet::SchoolEmbedding::similar_to (distância)
use constant REFRESH_SQL => <<~'SQL';
  INSERT INTO analytics.school_embedding (co_entidade, embedding)
  SELECT
    co_entidade,
    ARRAY[
      COALESCE(score_capacidade_atendimento, 0),
      COALESCE(score_infraestrutura, 0),
      COALESCE(score_capacitacao_docente, 0),
      COALESCE(score_diversidade_discente, 0),
      COALESCE(score_capacidade_gestora, 0),
      COALESCE(score_sustentabilidade, 0)
    ]::vector
  FROM clean.mv_escolas_scores
  ON CONFLICT (co_entidade)
  DO UPDATE SET embedding = EXCLUDED.embedding
SQL

sub register ($self, $app, $config) {
  $app->minion->add_task(
    refresh_school_embeddings => task {
      sub   => \&_refresh_school_embeddings,
      roles => {'+Progress' => {log => $app->log}},
    }
  );

  $app->helper(
    refresh_school_embeddings => sub ($c, $args = {}) {
      $app->minion->enqueue(refresh_school_embeddings => []);
    }
  );
}

sub _refresh_school_embeddings($job) {
  my $start = localtime;
  my $refreshed;

  try {
    my $dbh = $job->app->schema->storage->dbh;
    $refreshed = $dbh->do(REFRESH_SQL);
  } catch ($err) {
    $job->app->log->error("Error refreshing school embeddings: $err");
    return $job->fail({ error => "$err" });
  }

  my $end = localtime;
  return $job->finish({
    meta => {
      name      => 'refresh_school_embeddings',
      job_id    => $job->id,
      took      => $end - $start,
      refreshed => $refreshed,
    },
  });
}

1;
