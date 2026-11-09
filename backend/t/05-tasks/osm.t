use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use CI;
use Mojo::JSON qw(decode_json);

# query_osm consulta a API Overpass do OpenStreetMap.
CI->skip_network ('query_osm consulta a Overpass');

my $t = Test::Mojo->new('EduMaps');
my $minion = $t->app->minion;
my $cod = 3555406;
my $not_exist = 110001; #código de município inexistente (antigo falta 1 digito)
my $tag = '[task] osm:';

# Jobs criados pelo teste: removidos no fim (os que não estiverem rodando).
my @JOBS;
my $FILA = "teste_$$";
END {
  for my $id (@JOBS) {
    my $job = $minion->job($id) or next;
    $job->remove unless $job->info->{state} eq 'active';
  }
}

sub _delete_previous {
  my $rs = $t->app->schema->resultset('OsmQuery')->search_rs( { city_fid => $cod } );
  $rs->search_related('osm_landuses')->delete;
  $rs->delete;
}

# Sem rede: a falha da consulta chega ao job (antes o log->err, inexistente,
# derrubava o próprio tratamento de erro e a mensagem original se perdia).
subtest qq{$tag falha da Overpass vira falha do job} => sub {
  no warnings qw(redefine once);
  local *EduMaps::Task::OSM::Query::from_osm = sub { die "overpass fora do ar\n" };
  local $t->app->config->{minion_filas}{query_osm} = $FILA;
  my $id = $t->app->get_osm($cod);
  push @JOBS, $id;
  $minion->perform_jobs({ queues => [$FILA] });
  my $info = $minion->job($id)->info;
  # attempts => 3: a falha agenda nova tentativa (volta a inactive).
  is $info->{retries}, 1, 'falha agendou nova tentativa';
  like $info->{result}, qr/overpass fora do ar/, 'erro original preservado';
  $minion->job($id)->remove;   # sem a nova tentativa, que usaria a Overpass
};

subtest qq{executando task query_osm com codigo_municipio = $cod} => sub {
  _delete_previous;
  # Fila própria: só o perform_jobs deste teste executa o job (o minion local
  # consome a `default`).
  local $t->app->config->{minion_filas}{query_osm} = $FILA;
  my $id = $t->app->get_osm($cod);
  push @JOBS, $id;
  my $job = $minion->job($id);

  $minion->perform_jobs({ queues => [$FILA] });

  # Verifica se o job foi concluído com sucesso
  ok $job->info->{state} eq 'finished', 'job finalizado com sucesso';

  # Obtém o resultado (GeoJSON)
  my $json = $job->info->{result};

  if ($json) {
    # Verifica estrutura básica do GeoJSON
    is $json->{type}, 'FeatureCollection', 'tipo é FeatureCollection';
    ok exists $json->{features}, 'possui campo features';
    ok ref($json->{features}) eq 'ARRAY', 'features é um array';
  }

  # Verifica se a task foi registrada com o nome correto
  is $job->task, 'query_osm', 'task executada é query_osm';
};


subtest qq/
$tag <executando task via app>
  - enfileira a task e acompanha o progresso por SSE
/ => sub {
  # Fila própria: o job fica parado (o SSE emite o progresso inicial) e pode
  # ser removido no fim; na `default` o minion local o executaria.
  local $t->app->config->{minion_filas}{query_osm} = $FILA;
  my $tx = $t->post_ok("/api/task/osm?codigo_ibge=$cod")
  ->status_is(202)
  ->header_like( Location => qr/progress\?job_id=\d+/ )
  ->json_has('/job_id')
  ->json_has('/task')
  ->tx
  ;

  my $json = $tx->res->json;
  push @JOBS, $json->{job_id};
  my $location = $tx->res->headers->location;
  # O EventSource manda o Accept; sem ele a rota devolve o snapshot em JSON.
  $t->get_sse_ok($location => {Accept => 'text/event-stream'})
  ->status_is(200)
  ->sse_ok
  ->sse_type_is('progress')
  ->sse_text_like(qr/percent/)
  ;

  ok ($minion->backend->remove_job($json->{job_id}), "job $json->{job_id} removido");
};

done_testing;
