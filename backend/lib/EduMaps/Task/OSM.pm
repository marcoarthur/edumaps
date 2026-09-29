package EduMaps::Task::OSM;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::Task::OSM::Query;
use Syntax::Keyword::Try;
require EduMaps::Model::OSM;

sub register ($self, $app, $config){
  $app->minion->add_task(query_osm => \&_query_osm);
  $app->minion->add_task(query_osm_school => \&_query_osm_school);
  $app->helper(get_osm => \&_enqueue_osm_task);
  $app->helper(get_osm_school => \&_enqueue_osm_school_task);
}

sub _query_osm($job, $city_id) {
  my $query = EduMaps::Task::OSM::Query->new(
    municipio     => $city_id,
    log           => $job->app->log,
    config        => $job->app->config,
    save_db       => 1,
    _minion_job   => $job,
  );

  my $geojson;
  try {
    $geojson = $query->from_osm;
  } catch($err) {
    $job->app->log->err("Error querying OSM for $city_id");
    return $job->fail($err);
  }

  return $job->finish($geojson);
}

sub _query_osm_school($job, $args) {
  my $model = EduMaps::Model::OSM->new(
    ( $job->app->config->{osm_cache_ttl_days}
      ? (cache_ttl_days => $job->app->config->{osm_cache_ttl_days})
      : () ),
  );

  my $res;
  try {
    $res = $model->osm_for_school( %{ $args // {} } );
  } catch($err) {
    $job->app->log->err("Error querying OSM buffer for school");
    return $job->fail($err);
  }

  return $job->finish({
    digest  => $res->{digest},
    related => $res->{related},
    raio    => $res->{raio},
    geojson => $res->{geojson},
  });
}

sub _enqueue_osm_task($app, $cod_ibge) {
  return $app->minion->enqueue(query_osm => [$cod_ibge] => { attempts => 3 });
}

sub _enqueue_osm_school_task($app, $args = {}) {
  return $app->minion->enqueue(query_osm_school => [$args] => { attempts => 3 });
}

1;
