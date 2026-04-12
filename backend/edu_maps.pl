#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use lib qw(./lib);
use EduMaps::Schema qw();
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Collection qw(c);
use Syntax::Keyword::Try;
use Scalar::Util qw( looks_like_number );
use DateTime;
use EduMaps::OSM::Query;
use EduMaps::Siope::Scrap::SpreadSheet::Gastos;
use utf8;
use Mojo::Loader qw(find_modules load_class);
use JSON::PP qw();
use DDP;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';
#------------------------------------------------------------------------------
# Load all models dynamically
#------------------------------------------------------------------------------
my @model_classes = find_modules('EduMaps::Model');

foreach my $class (@model_classes) {
  my $error = load_class($class);
  if (ref $error) {
    warn "Error loading $class: $error\n";
  } else {
    warn "✓ Loaded: $class\n";
  }
}

push @{app->static->paths}, qw(./public ../frontend/map_app/dist);

plugin Config => {file => './edu_maps.conf'};
my $conf = app->config;

##############################################
# MINION JOBS
##############################################
plugin Minion => {Pg => $conf->{db_url}};
app->minion->add_task(
  query_osm => sub ($job, $municipio_id) {
    my $query = EduMaps::OSM::Query->new(
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

app->minion->add_task(
  query_siope => sub($job, $city_id, $year) {
    my $driver = EduMaps::Siope::Scrap::SpreadSheet::Gastos->new(
      cod_mun => $city_id,
      captcha => $ENV{CAPTCHA_SIOPE} || '',
      ano     => $year,
    );

    my $chunk_size  = 5000;
    my $rs          = $job->app->dbic->resultset('RemuneracaoMunicipal');
    my $rows        = c($driver->get_and_process->@*);
    my $total       = $rows->size;
    my $processed   = 0;
    my $col_order   = $rs->siope_column_order;

    try {
      $rows->each(
        sub { push @$_, $city_id, 'Municipal'; }
      );

      while(@$rows) {
        my @chunk    = splice(@$rows, 0, $chunk_size);
        my $progress = { phase => 'DB saving', total => $total, processed => ($processed += scalar @chunk) };
        $rs->populate([$col_order, @chunk]);
        $job->note(progress => $progress);
      }
    } catch($err) {
      warn "Error during populate $city_id payroll for year $year";
      return $job->finish( encode_json( { error => "Error during $city_id payroll saving" } ) );
    }

    $job->finish(encode_json($job->app->payroll_of_city($city_id)));
  }
);

plugin 'Minion::Admin';

#############################################
# HELPERS
#############################################
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
  my ($monitor, $note);

  $c->write_sse;
  $c->on(finish => sub($c) { Mojo::IOLoop->remove($monitor) if $monitor });
  return $c->finish if $job->info->{state} eq 'finished';

  $monitor = Mojo::IOLoop->recurring(
    $poll_intv => sub {
      $note = $job->info->{notes};
      $note->{progress}{state} = $job->info->{state};
      $note->{result} = decode_json($job->info->{result}) if $job->info->{result};
      $c->log->debug(
        sprintf (
          "Job (%d) at state (%s): processed (%s) from total (%s)",
          $job->info->{id},
          $note->{progress}{state} //= 'Initial',
          $note->{progress}{processed} //= 'None',
          $note->{progress}{total} //= 'Unknown',
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

helper payroll_of_city => sub($c, $city_id) {
    my $city_name = $c->dbic->resultset('MunicipiosSp')->search_rs(
      { codigo_ibge_antigo => $city_id },
    )->get_column('nome_municipio');

    my @payroll = $c->dbic->resultset('Escolas')
    ->payroll_by_city($city_name->as_query)->as_hash->all;

    return [ @payroll ];
};

helper model => sub($c, $model) {
  my $class = "EduMaps::Model::$model";
  return $class->new( schema => $c->dbic );
};

helper sorted_json => sub($c, $data) {
  state $json = JSON::PP->new->canonical->utf8(1);
  return $json->encode($data);
};

helper instantiate_model => sub($c, %args) {
  my ($model, $params) = ($c->model($args{model}), $c->req->params->to_hash);
  $params->{$_} = $c->param($_) for $args{route_params}->@*;
  $model->ctx->params({ %$params });
  return $model;
};

############################################################
# ROUTES + API
############################################################
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

  my %categorias = $c->escolas->count_by_size($details->{nome_municipio})
  ->as_hash->get_all->map(sub {$_->{porte_escola} => $_->{total_por_porte} })->@*;

  chop($fid);
  my %workers = $c->dbic->resultset('RemuneracaoMunicipal')
  ->search_rs( { cod_municipio => $fid })
  ->columns([qw/nome_profissional cpf tipo segmento_ensino/])
  ->distinct
  ->as_subselect_rs
  ->count_of([qw(tipo segmento_ensino)], 'total')
  ->as_hash
  ->get_all->map(
      sub { join("/", $_->{tipo}, $_->{segmento_ensino}) => $_->{total} }
    )->@*;

  my $mun_details = { 
    %$details, 
    %categorias, 
    %workers,
    $cobertura ? (%$cobertura) : () 
  };
  $c->format_float_nums($mun_details);
  $c->render( json => $mun_details, encoding => 'UTF-8' );
};

get '/api/schools' => sub ($c) {
  my $id = $c->param('city');
  return unless $id;
  $c->render( text => $c->find_escolas($id) );
};

get '/api/query-osm' => sub ($c) {
  my $fid = $c->param('fid');
  my $query = EduMaps::OSM::Query->new(
    municipio     => $fid,
    log           => app->log,
    config        => $conf,
  );
  my $json = $query->from_db;
  return $c->render( json => $json ) if $json->{features}->@* > 0;

  # enqueue a query for OSM
  my $job_id = $c->minion->enqueue('query_osm', [$fid]);
  $c->render(json => {job_id => $job_id, status => 'enqueued', task => 'query_osm'});
};

get '/api/query-osm/progress/:job_id' => sub ($c) {
  my $job_id = $c->param('job_id');
  $c->job_progress_poll($job_id);
};

get '/api/job/progress/:job_id' => sub ($c) {
  my $id = $c->param('job_id');
  $c->job_progress_poll($id);
};

get '/api/query-osm/result/:job_id' => sub ($c) {
  my $job_id = $c->param('job_id');
  my $job = $c->minion->job($job_id);
  return $c->reply->not_found unless $job;
  $c->render(json => $job->info->{result});
};

get '/api/query/siope' => sub ($c) {
  my $dt = DateTime->now(locale => 'pt');
  my ($cid, $year, $month) = (
    $c->param('city'), $c->param('year') || $dt->year,
    $c->param('month') || $dt->month
  );
  return $c->reply->not_found unless $cid;

  my $payroll = $c->payroll_of_city($cid);

  if ( @$payroll ) {
    $c->render(json => $payroll);
  } else {
    $c->render(status => 204, text => 'No content');
  }
};

post '/api/jobs/siope' => sub ($c) {
  my $dt           = DateTime->now;
  my $json         = $c->req->json;
  my ($cid, $year) = ($json->{city}, $json->{year} || $dt->year);
  my $job_id       = $c->minion->enqueue('query_siope', [$cid, $year]);

  # shows the 202 accepted header, include location
  $c->res->headers->header('Location' => "/api/job/progress/$job_id");
  $c->render(
    status => 202,
    json => {job => 'query_siope', job_id => $job_id}
  );
};

################################################################################
#                                   NEW API 
################################################################################
# API FOR CITY
################################################################################
get 'api/city/:codigo_ibge/details' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  my $details = $c->model('City')->details($c->param('codigo_ibge'));
  return $c->reply->not_found unless keys %$details;

  $c->render(data => $c->sorted_json($details), format => 'json');
} => 'city_details';

get 'api/city/:codigo_ibge/schools' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  $c->render(
    text => $c->find_escolas($c->param('codigo_ibge')),
    format => 'json'
  );
} => 'city_schools';

get 'api/city/:codigo_ibge/osm_features' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  $c->render(
    data => $c->model('City')->osm_features($c->param('codigo_ibge')),
    format => 'json',
  );
} => 'city_osm_features';

get 'api/city/:codigo_ibge/payroll' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  my @params = ( 
    $c->param('codigo_ibge'),
    DateTime->new( 
      year    => $c->param('year')  || 2025,
      month   => $c->param('month') || 06,
      locale  => 'pt'
    ),
  );

  $c->render(
    text => $c->model('City')->payroll(@params),
    format => 'json',
  );
} => 'city_payroll';

get 'api/city/:codigo_ibge/payroll/overall' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  my $model = $c->instantiate_model(model => 'City', route_params => [qw(codigo_ibge)]);

  $c->render(
    data => $model->overall_payroll,
    format => 'json'
  );
} => 'city_overall_payroll';

get 'api/city/:codigo_ibge/payroll_details' => [codigo_ibge => qr/\d{7}/] => sub ($c) {
  my @params = (
    $c->param('codigo_ibge'),
    DateTime->new(
      year    => $c->param('year')  || 2025,
      month   => $c->param('month') || 06,
      locale  => 'pt'
    ),
  );

  $c->render(
    text => $c->model('City')->payroll_details(@params),
    format => 'json',
  );
} => 'city_payroll_details';

get 'api/city/search/:name' => sub($c) {
  my $model = $c->instantiate_model(model => 'City');

  $c->render(
    data => $model->search_by_name({name => $c->param('name')}),
    format => 'json'
  );
} => 'city_search_by_name';

get 'api/city/detail/:name' => sub($c) {
  my $model = $c->instantiate_model(model => 'City');

  $c->render(
    data => $model->city_details({name => $c->param('name')}),
    format => 'json'
  );
} => 'city_search_by_name';

################################################################################
# API FOR SCHOOL
################################################################################
get 'api/school/:cod_inep/info' => [ cod_inep => qr/\d+/ ] => sub ($c) {
  $c->render(
    data => $c->model('School')->info($c->param('cod_inep')),
    format => 'json',
  );
} => 'school_info';

get 'api/school/:cod_inep/payroll' => [ cod_inep => qr/\d+/ ] => sub ($c) { my $dt = DateTime->new(
    year  => $c->param('year') || 2025,
    month => $c->param('month') || 06,
    locale => 'pt'
  );

  $c->render(
    text => $c->model('School')->payroll($c->param('cod_inep'), $dt),
    format => 'json'
  );
} => 'school_payroll';

get 'api/school/:cod_inep/grades' => [ cod_inep => qr/\d+/ ] => sub ($c) {
  my $model = $c->instantiate_model(
    model => 'School',
    route_params => [qw(cod_inep)],
  );

  $c->render(
    data => $model->grades,
    format => 'json',
  );
} => 'school_grades';

get 'api/school/:cod_inep/full_grades' => [ cod_inep => qr/\d+/ ] => sub ($c) {
  my $model = $c->instantiate_model(model => 'School');
  $c->render(text => $model->full_inep_grades({cod_inep => $c->param('cod_inep')}), format => 'json');
} => 'school_full_grades';

get 'api/school/:cod_inep/professionals' => [ cod_inep => qr/\d+/ ] => sub ($c) {
  my $model = $c->instantiate_model(
    model => 'School',
    route_params => [qw(cod_inep)],
  );

  $c->render(
    data => $model->workers,
    format => 'json',
  );
} => 'school_professionals';

get 'api/school/search' => sub ($c) {
  my $model = $c->instantiate_model(model => 'School');

  $c->render( data => $model->search_all_from, format => 'json');
};

get 'api/school/search/:term' => sub ($c) {
  my $model = $c->instantiate_model(
    model => 'School',
    route_params => [qw(term)],
  );

  $c->render(
    data => $model->search, format => 'json',
  );
} => 'school_search';

get 'api/school/nearby/:lat/:lon' => [lat => qr/[^\/]+/, lon => qr/[^\/]+/] => sub ($c) {
  my $model = $c->instantiate_model(model => 'School');
  # max distance 5000 meters
  my $params = { lat => $c->param('lat'), lon => $c->param('lon'), opts => { max => 5000 } };

  $c->render(
    data => $model->search_nearby($params), format => 'json'
  );
} => 'school_nearby';

get 'api/school/cluster' => sub ($c) {
  my $model = $c->instantiate_model(model => 'School');

  $c->render(
    data => $model->cluster_schools, format => 'json'
  );
} => 'school_city_cluster';

app->start;
