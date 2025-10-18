#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use lib qw(./lib);
use MyApp::Schema;
use Mojo::JSON qw(encode_json);
use MyApp::OSM::Query;

push @{app->static->paths}, qw(./public frontend/map_app/dist);

plugin Config => {file => './map_app.conf'};
my $conf = app->config;

plugin Minion => {Pg => $conf->{db_url}};
app->minion->add_task(
  query_osm => sub ($job, $municipio_id) {
    my $query = MyApp::OSM::Query->new(
      municipio     => $municipio_id,
      log           => $job->app->log,
      config        => $conf,
      save_db       => 1,
      _minion_job   => $job,
    );

    my $geojson = $query->from_osm;

    $job->finish($geojson);
  }
);

plugin 'Minion::Admin';

helper dbic => sub ($c) { 
  state $sch = MyApp::Schema->connect($conf->{db_params}->@*,$conf->{db_opts}); 
};
helper municipios => sub ($c) {
  state $m = $c->dbic->resultset('MunicipiosSp');
};
helper escolas => sub ($c) {
  state $e = $c->dbic->resultset('Escola');
};
helper find_municipio => sub ($c, $name) {
  my $params = \[ qq{unaccent(nm_mun) ILIKE unaccent('%$name%')}];
  return $c->municipios->search_rs($params)
  ->feat_collection->get_column('feature')->first;
};
helper find_escolas => sub ($c, $name) {
  return $c->escolas->find_by_city_name($name)->get_column('feature')->first;
};

helper find_query_for => sub ($c, $fid) {
  $c->dbic->resultset('OsmQuery')->search_rs( { city_fid => $fid } )->first;
};

get '/' => 'map_svelte';

get '/api/geojson' => sub ($c) {
  my $city_name = $c->param('city');
  return unless $city_name;
  $c->render( text => $c->find_municipio($city_name) );
};

get '/api/details' => sub ($c) {
  my $fid = $c->param('fid');
  return unless $fid;
  $c->render( json => $c->municipios->details($fid)->first );
};

get '/api/schools' => sub ($c) {
  my $city_name = $c->param('city');
  return unless $city_name;
  $c->render( text => $c->find_escolas($city_name) );
};

get '/api/query-osm' => sub ($c) {
  my $fid = $c->param('fid');
  my $query = MyApp::OSM::Query->new(
    municipio     => $fid,
    log           => app->log,
    config        => $conf,
  );
  my $json = $query->from_db;
  return $c->render( json => $json ) if $json->{features}->@* > 0;

  # enqueue a query for OSM
  my $job_id = $c->minion->enqueue('query_osm', [$fid]);
  $c->render(json => {job_id => $job_id, status => 'enqueued'});
};

get '/api/query-osm/progress/:job_id' => sub ($c) {
  my $job_id = $c->param('job_id');
  my $job = $c->minion->job($job_id);
  my $cb;
  return $c->reply->not_found unless $job;
  $c->write_sse;
  $c->on( finish => sub ($c) { Mojo::IOLoop->remove($cb) if $cb} );
  return $c->finish if $job->info->{state} eq 'finished';

  $cb = Mojo::IOLoop->recurring(
    2 => sub {
      my $info = $job->info;
      my $note = $info->{notes};
      my $debug;

      if (keys %$note) {
        $debug = sprintf "Job (%d) State (%s) processed (%d) total (%d)", $info->{id}, $info->{state}, $note->{progress}{processed}, $note->{progress}{total};
      } else {
        $debug = sprintf "Job (%d) getting data from OSM", $info->{id};
        $note = { progress => { processed => 'None', total => 'Unknown', phase => 'osm', } };
      }
      $note->{progress}{state} = $info->{state};
      $c->log->debug($debug);
      $c->write_sse({type => 'progress', text => encode_json($note)});
      $c->finish if $info->{state} ne 'active';
    }
  );
};

get '/api/query-osm/result/:job_id' => sub ($c) {
  my $job_id = $c->param('job_id');
  my $job = $c->minion->job($job_id);
  return $c->reply->not_found unless $job;
  $c->render(json => $job->info->{result});
};

app->start;
