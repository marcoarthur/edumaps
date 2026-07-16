package EduMaps::Task::OSM;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::OSM::Query;
use Syntax::Keyword::Try;

sub register ($self, $app, $config){
  $app->minion->add_task(query_osm => \&_query_osm);
  $app->helper(get_osm => \&_enqueue_osm_task);
}

sub _query_osm($job, $city_id) {
  my $query = EduMaps::OSM::Query->new(
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

sub _enqueue_osm_task($app, $cod_ibge) {
  return $app->minion->enqueue(query_osm => [$cod_ibge] => { attempts => 3 });
}

1;
