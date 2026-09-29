# t/04-api/gestor/osm_pois.t
# Testes do disparo/status dos POIs OSM no entorno da escola (Painel do Gestor):
#   POST /api/gestor/:cod_inep/osm/pois  (enfileira/idempotente)
#   GET  /api/gestor/:cod_inep/osm/pois  (status/leitura)
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON ();
use utf8;
use open ':std', ':encoding(UTF-8)';

# Serviço OSM offline para o teste da task (não toca a rede).
{
  package Test::OSM::Offline;
  use Mojo::Base 'EduMaps::Services::OSM', -signatures;
  our $FIXTURE;
  sub new($class, %args) {
    $class->SUPER::new(%args, offline => 1, fixture => $FIXTURE);
  }
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
# Fila dedicada: evita que o worker do compose (fila 'default') consuma os
# jobs do teste e cause corrida com o perform_jobs in-process.
$t->app->config->{osm_queue} = 'osm_test';
my $minion = $t->app->minion;

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.school_osm_query')"
);

my $INEP  = '77770061';   # escola (censo) do teste
my $OUTRO = '66660051';   # outra escola (gestor diferente)
my $SENHA = 'senha123';
my $EMAIL = sprintf 'osm.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'osm.b.%d@edumaps.test', $$;

my ($token, $out_token);

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRO) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
            VALUES (2025, ?, ?, 3, ?)', {}, $INEP, 'Escola OSM POIs', 2307304);
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
            VALUES (2025, ?, ?, 3, ?)', {}, $OUTRO, 'Outra Escola OSM', 2307304);
}

my $clear_jobs = sub {
  return unless $has_tables;
  my $it = $minion->jobs({ tasks => ['query_osm_school'], states => ['inactive', 'active'] });
  my @ids;
  while (my $j = $it->next) {
    push @ids, $j->{id} if (($j->{notes}{co_entidade} // '') eq $INEP);
  }
  $minion->backend->remove_job($_) for @ids;
};

my $cleanup = sub {
  return unless $has_tables;
  $clear_jobs->();
  my $dbh = $t->app->schema->storage->dbh;

  for my $email ($EMAIL, $OEMAIL) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $email);
  }
  for my $inep ($INEP, $OUTRO) {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
    $dbh->do('DELETE FROM clean.school_osm_feature WHERE co_entidade = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.school_osm_query   WHERE co_entidade = ?', {}, $inep);
  }
};

END { $cleanup->() }

my $auth  = sub { { Authorization => "Bearer $token" } };
my $oauth = sub { { Authorization => "Bearer $out_token" } };

subtest 'setup: escola no censo + gestor logado' => sub {
  plan skip_all => 'clean.school_osm_query ausente (migration nao aplicada)'
    unless $has_tables;

  $clear_jobs->();  # limpa jobs pendentes de execuções anteriores

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor OSM', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRO, nome => 'Gestor Outro', email => $OEMAIL, senha => $SENHA,
  })->status_is(200);
  $out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};

  ok $token && $out_token, 'tokens de sessão';
};

subtest 'POST: exige sessão e é restrito à própria escola' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/osm/pois", json => { raio => 500 })->status_is(401);
  $t->post_ok("/api/gestor/$INEP/osm/pois", $oauth->(), json => { raio => 500 })->status_is(403);
};

subtest 'POST: enfileira query_osm_school com raio/catálogos' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  my $tx = $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => {
    raio     => 500,
    profiles => ['transporte', 'saude'],
  })->status_is(202)
    ->header_like(Location => qr/progress\?job_id=\d+/)
    ->json_has('/job_id')->tx;

  my $json   = $tx->res->json;
  my $job_id = $json->{job_id};

  is $json->{task}, 'query_osm_school', 'task correta';
  ok !$json->{reused}, 'não reusou (job novo)';

  my $job = $minion->job($job_id);
  is $job->task, 'query_osm_school', 'task no Minion';
  is $job->info->{args}[0]{raio}, 500, 'raio propagado';
  is $job->info->{args}[0]{profiles}[1], 'saude', 'catálogo propagado';

  ok $minion->backend->remove_job($job_id), 'job removido';
};

subtest 'POST: idempotente — reusa o job pendente da escola' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  my $job_id = $t->app->get_osm_school({ co_entidade => $INEP, raio => 300, profiles => ['transporte'] });

  my $tx = $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => {
    raio => 800, profiles => ['educacao'],
  })->status_is(202)->json_has('/job_id')->tx;

  my $json = $tx->res->json;
  is $json->{job_id}, $job_id, 'devolveu o job existente';
  ok $json->{reused}, 'marcado como reusado';

  ok $minion->backend->remove_job($job_id), 'job removido';
};

subtest 'POST: valida raio e catálogos' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => { raio => 50 })
    ->status_is(400)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => { raio => 20000 })
    ->status_is(400)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => { raio => 'abc' })
    ->status_is(400);

  my $tx = $t->post_ok("/api/gestor/$INEP/osm/pois", $auth->(), json => {
    raio => 500, profiles => ['nao-existe'],
  })->status_is(400)->json_has('/error')->tx;
};

subtest 'GET status: seleção atual + resumo por categoria' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do(q{
    INSERT INTO clean.osm_feature (osm_type, osm_id, tags_key, tags_value, category)
    VALUES ('node', 900001, 'amenity', 'library', 'amenity=library'),
           ('node', 900002, 'leisure', 'park',    'leisure=park')
  });
  $dbh->do(q{
    INSERT INTO clean.school_osm_feature (co_entidade, nu_ano_censo, osm_type, osm_id, raio)
    VALUES (?, 2025, 'node', 900001, 500),
           (?, 2025, 'node', 900002, 500)
  }, {}, $INEP, $INEP);
  $dbh->do(q{
    INSERT INTO clean.school_osm_query (co_entidade, nu_ano_censo, raio, profiles, updated_at)
    VALUES (?, 2025, 500, '["transporte","saude"]'::jsonb, now())
    ON CONFLICT (co_entidade, nu_ano_censo) DO UPDATE
      SET raio = EXCLUDED.raio, profiles = EXCLUDED.profiles, updated_at = now()
  }, {}, $INEP);

  my $json = $t->get_ok("/api/gestor/$INEP/osm/pois", $auth->())
    ->status_is(200)->tx->res->json;

  is $json->{raio}, 500, 'raio da seleção';
  is $json->{total}, 2, 'total de POIs';
  is scalar(@{ $json->{resumo} }), 2, 'duas categorias';
  is $json->{resumo}[0]{category}, 'amenity=library', 'categoria do resumo';
  is $json->{resumo}[0]{count}, 1, 'contagem';
  ok $json->{updated_at}, 'carimbo de atualização';

  $dbh->do(q{
    DELETE FROM clean.school_osm_feature WHERE co_entidade = ? AND osm_id IN (900001, 900002)
  }, {}, $INEP);
  $dbh->do("DELETE FROM clean.osm_feature WHERE osm_id IN (900001, 900002)");
};

subtest 'task: progresso, finish e fail (Model offline)' => sub {
  plan skip_all => 'sem tabelas' unless $has_tables;

  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do(q{
    UPDATE clean.censo_escolas
       SET latitude = -23.5, longitude = -46.6,
           geometry = ST_SetSRID(ST_MakePoint(-46.6, -23.5), 4674)
     WHERE co_entidade = ? AND nu_ano_censo = 2025
  }, {}, $INEP);

  $t->app->config->{osm_service_class} = 'Test::OSM::Offline';

  # sucesso: fixture com um POI exatamente no ponto da escola
  $Test::OSM::Offline::FIXTURE = {
    elements => [
      { type => 'node', id => 910001, lat => -23.5, lon => -46.6,
        tags => { amenity => 'library', name => 'Biblioteca Offline' } },
    ],
  };

  my $job_id = $t->app->get_osm_school({
    co_entidade => $INEP, raio => 500, profiles => ['educacao'], refresh => 1,
  });
  $minion->perform_jobs({ queues => ['osm_test'] });

  my $info = $minion->job($job_id)->info;
  is $info->{state}, 'finished', 'job finalizado';
  ok( ($info->{notes}{progress}{percent} // 0) >= 90, 'progresso reportado' );
  ok( ($info->{result}{related} // 0) >= 1, 'POI relacionado ao buffer' );
  ok $info->{result}{updated_at}, 'carimbo de atualização no resultado';
  $minion->backend->remove_job($job_id);

  # falha: fixture inexistente -> job failed com erro (attempts=1 para não
  # entrar em retry/backoff; refresh para ignorar cache de runs anteriores)
  $Test::OSM::Offline::FIXTURE = 't/fixtures/osm/nao-existe.json';
  my $fail_id = $minion->enqueue(
    query_osm_school => [ {
      co_entidade => $INEP, raio => 400, profiles => ['educacao'], refresh => 1,
    } ] => { attempts => 1, queue => 'osm_test', notes => { co_entidade => $INEP } }
  );
  $minion->perform_jobs({ queues => ['osm_test'] });

  my $finfo = $minion->job($fail_id)->info;
  is $finfo->{state}, 'failed', 'job falhou';
  ok $finfo->{result}{error}, 'erro registrado no job';
  $minion->backend->remove_job($fail_id);

  $dbh->do('DELETE FROM clean.school_osm_feature WHERE co_entidade = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.osm_feature WHERE osm_id = 910001');
};

done_testing;
