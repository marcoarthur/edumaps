package EduMaps::Task::OSM;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use EduMaps::Task::OSM::Query;
use EduMaps::Services::OSM::Query;
use Minion::Task::Generator qw/task/;
use Syntax::Keyword::Try;
require EduMaps::Model::OSM;

sub register ($self, $app, $config){
  $app->minion->add_task(query_osm => \&_query_osm);
  $app->minion->add_task(
    query_osm_school => task {
      sub   => \&_query_osm_school,
      roles => { '+Progress' => { log => $app->log } },
    }
  );
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
  my $app  = $job->app;
  $args  //= {};

  my $co       = $args->{co_entidade};
  my $raio     = $args->{raio} // 1000;
  my $profiles = $args->{profiles} // ['equipamentos_publicos'];

  return $job->fail('co_entidade é obrigatório') unless defined $co;

  return $job->fail('raio deve ser um inteiro entre 100 e 10000 metros')
    unless $raio =~ /^\d+$/ && $raio >= 100 && $raio <= 10_000;

  return $job->fail('profiles deve ser uma lista')
    unless ref $profiles eq 'ARRAY' && @$profiles;

  for my $p (@$profiles) {
    return $job->fail("catálogo OSM inválido: $p")
      unless EduMaps::Services::OSM::Query->valid_profile($p);
  }

  my $model = EduMaps::Model::OSM->new(
    ( $app->config->{osm_cache_ttl_days}
      ? (cache_ttl_days => $app->config->{osm_cache_ttl_days}) : () ),
    ( $app->config->{osm_service_class}
      ? (service_class => $app->config->{osm_service_class}) : () ),
  );

  # Encaminha o progresso do Model/Service para as "notes" do job
  # (é o que o monitor_job transmite por SSE ao usuário).
  $model->on(progress => sub ($evt, $p) {
    $job->progress($p->{percent} // 0, $p->{message} // '');
  });

  $job->progress(2, 'Iniciando consulta OSM');

  my $res;
  try {
    $res = $model->osm_for_school(
      co_entidade => $co,
      raio        => 0 + $raio,
      profiles    => $profiles,
      (defined $args->{nu_ano_censo} ? (nu_ano_censo => 0 + $args->{nu_ano_censo}) : ()),
      (defined $args->{refresh} ? (refresh => $args->{refresh} ? 1 : 0) : ()),
    );
  } catch($err) {
    $app->log->error("Error querying OSM POIs for school $co: $err");
    return $job->fail({ error => "$err" });
  }

  $job->progress(100, 'Concluído');

  return $job->finish({
    co_entidade  => 0 + $co,
    nu_ano_censo => $res->{nu_ano_censo},
    raio         => $res->{raio},
    profiles     => $res->{profiles},
    digest       => $res->{digest},
    related      => $res->{related},
    updated_at   => $res->{updated_at},
  });
}

sub _enqueue_osm_task($app, $cod_ibge) {
  return $app->minion->enqueue(query_osm => [$cod_ibge] => { attempts => 3 });
}

sub _enqueue_osm_school_task($app, $args = {}) {
  return $app->minion->enqueue(
    query_osm_school => [$args] => {
      attempts => 3,
      queue    => $app->config->{osm_queue} // 'default',
      notes    => { co_entidade => $args->{co_entidade} },
    }
  );
}

1;
