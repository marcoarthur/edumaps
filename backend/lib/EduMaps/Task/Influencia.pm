package EduMaps::Task::Influencia;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use utf8;

# Refresh da camada de influência (metodologia influencia-v1,
# docs/analises/influencia.md). A geometria — buffer em METROS — vive em
# clean.escola_influencia e a lógica é PostGIS (clean.refresh_escola_influencia).
# Este job só a dispara:
#
#   refresh_influencia => []                  # raios default [500,1000,2000]
#   refresh_influencia => [{raios => [500]}]  # raios explícitos
#
# Idempotente (UPSERT): pode rodar quantas vezes quiser. Base das arealizações
# do zonal statistics (#255) e dos blocos territoriais B–F do #137.

sub register ($self, $app, $config) {
  $app->minion->add_task(refresh_influencia => \&_refresh);
  $app->helper(
    refresh_influencia => sub ($c, $args = {}) {
      $app->minion->enqueue(refresh_influencia => [$args] => { attempts => 3 });
    }
  );
}

sub _refresh ($job, $args = undef) {
  my $raios = ref $args eq 'HASH' ? $args->{raios} : undef;
  my $linhas;

  try {
    my $dbh = $job->app->schema->storage->dbh;
    if (ref $raios eq 'ARRAY' && @$raios) {
      my $lit = '{' . join(',', map { 0 + $_ } @$raios) . '}';
      $linhas = $dbh->selectrow_array(
        'SELECT clean.refresh_escola_influencia(?::integer[])', {}, $lit
      );
    } else {
      $linhas = $dbh->selectrow_array('SELECT clean.refresh_escola_influencia()');
    }
  } catch ($err) {
    $job->app->log->error("refresh_influencia falhou: $err");
    return $job->fail({ error => "$err" });
  }

  return $job->finish({ linhas => 0 + ($linhas // 0) });
}

1;
