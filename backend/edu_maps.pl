#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use lib qw(./lib);
use EduMaps::Schema;
use Mojo::JSON qw(encode_json);
use Mojo::Collection qw(c);
use Scalar::Util qw( looks_like_number );
use MyApp::OSM::Query;

push @{app->static->paths}, qw(./public ../frontend/map_app/dist);

plugin Config => {file => './edu_maps.conf'};
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
  state $sch = EduMaps::Schema->connect($conf->{db_params}->@*,$conf->{db_opts}); 
};
helper municipios => sub ($c) {
  state $m = $c->dbic->resultset('MunicipiosSp');
};
helper escolas => sub ($c) {
  state $e = $c->dbic->resultset('Escolas');
};
helper find_municipio => sub ($c, $name) {
  my $params = \[ qq{unaccent(nome_municipio) ILIKE unaccent('%$name%')}];
  return $c->municipios->search_rs($params)
  ->to_geojson->get_column('feature')->first;
};
helper find_escolas => sub ($c, $id) {
  return $c->escolas->find_by_city_id($id)->get_column('feature')->first;
};
helper find_query_for => sub ($c, $fid) {
  $c->dbic->resultset('OsmQuery')->search_rs( { city_fid => $fid } )->first;
};
helper job_progress_poll => sub ($c, $job_id, $poll_intv = 2) {
  my $job = $c->minion->job($job_id);
  return $c->reply->not_found unless $job;
  my $monitor;

  $c->write_sse;
  $c->on(finish => sub($c) { Mojo::IOLoop->remove($monitor) if $monitor });
  return $c->finish if $job->info->{state} eq 'finished';

  $monitor = Mojo::IOLoop->recurring(
    $poll_intv => sub {
      my $note = $job->info->{notes};
      my $unknown = {
        total     => 'Unknown',
        processed => 'None',
        phase     => 'osm',
      };
      $note = keys %$note ? $note : { progress => $unknown };
      $note->{progress}{state} = $job->info->{state};
      $c->log->debug(
        sprintf (
          "Job (%d) at state (%s): processed (%d) from total (%d)",
          $job->info->{id},
          $note->{progress}{state},
          $note->{progress}{processed},
          $note->{progress}{total},
        )
      );
      $c->write_sse( {type => 'progress', text => encode_json($note)} );
      $c->finish if $job->info->{state} ne 'active';
    }
  );
};

helper format_float_nums => sub($c, $hash) {
  while( my ($key, $val) = each %$hash ) {
    next unless looks_like_number($val);
    next if $val == int($val);
    $hash->{$key} = sprintf "%.2f", $val;
  }
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

  my $radius    = 3000;
  my $details   = $c->municipios->details($fid)->first;
  my $cobertura = $c->dbic->resultset('AnaliseCoberturaEscolar')
  ->search_rs( 
    { codigo_ibge => $details->{codigo_ibge} }, 
    { bind => [$radius] }
  )->sumario_municipio->as_hash->first;

  my $mun_details = { %$details, $cobertura ? (%$cobertura) : () };
  $c->format_float_nums($mun_details);
  $c->render( json => $mun_details );
};

get '/api/schools' => sub ($c) {
  my $id = $c->param('city');
  return unless $id;
  $c->render( text => $c->find_escolas($id) );
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
  $c->job_progress_poll($job_id);
};

get '/api/query-osm/result/:job_id' => sub ($c) {
  my $job_id = $c->param('job_id');
  my $job = $c->minion->job($job_id);
  return $c->reply->not_found unless $job;
  $c->render(json => $job->info->{result});
};

app->start;
