package EduMaps::Task::OSM;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::OSM::Query;
use Syntax::Keyword::Try;

# DBIx::Class::Schema
sub register ($self, $app, $config){
  $app->minion->add_task(query_osm => \&_query_siope);
}

sub _query_siope($job, $city_id) {
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

1;
