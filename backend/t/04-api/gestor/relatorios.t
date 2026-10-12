# t/04-api/gestor/relatorios.t
# Assistente de Relatório (#219) — rotas do gestor:
#   GET  /api/gestor/:cod_inep/relatorios/recorte-padrao
#   GET  /api/gestor/:cod_inep/relatorios/assistentes        (Fase 4)
#   GET  /api/gestor/:cod_inep/relatorios/temas?nivel=&assistente=
#   POST /api/gestor/:cod_inep/relatorios
#   GET  /api/gestor/:cod_inep/relatorios/jobs/:job_id
# O serviço R (Plumber) é simulado por um app Mojolicious embutido no UA do
# EduMaps::Analytics::Client (url base vazia -> requests relativos ao app).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojolicious;
use Mojo::JSON ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
# Fila dedicada: o worker real (fila analytics) não consome os jobs do teste.
$t->app->config->{relatorio_queue} = 'relatorio_test';
my $minion = $t->app->minion;
my $dbh    = $t->app->schema->storage->dbh;

# --- R simulado ------------------------------------------------------------
my %R = (temas_status => 200, chamadas_temas => 0,
         assistentes_status => 200, chamadas_assistentes => 0, ultimo_temas => undef);
my @TEMAS = (
  { id => 'ideb_territorio', titulo => 'IDEB do território', niveis => [qw(municipio uf regiao)] },
  { id => 'redes_territorio', titulo => 'Redes de ensino', niveis => [qw(municipio uf regiao)] },
  { id => 'gestores_territorio', titulo => 'Perfil dos gestores', niveis => [qw(uf regiao)] },
  { id => 'minha_escola', titulo => 'Minha escola', niveis => ['escola'] },
);

# Fase 4: assistentes declarados no R. `interno` não é do público gestor;
# `uf_so` tem publico escalar (Plumber com auto_unbox) e só o nível uf.
my @ASSISTENTES = (
  { id => 'relatorio', titulo => 'Relatório por tema', modo => 'tema',
    niveis => [qw(escola municipio uf regiao)], publico => ['gestor'],
    temas => [ map { $_->{id} } @TEMAS ], opcoes => {}, padroes => {} },
  { id => 'eda_municipio', titulo => 'EDA do município', modo => 'composto',
    niveis => ['municipio'], publico => ['gestor'],
    capitulos => [ { tema => 'ideb_territorio', titulo => 'IDEB do município' } ],
    opcoes => {}, padroes => {} },
  { id => 'uf_so', titulo => 'Só UF', modo => 'tema', niveis => 'uf', publico => 'gestor',
    temas => ['redes_territorio'], opcoes => {}, padroes => {} },
  { id => 'interno', titulo => 'Interno', modo => 'tema', niveis => [qw(uf)],
    publico => ['admin'], temas => ['ideb_territorio'], opcoes => {}, padroes => {} },
);

my $mock = Mojolicious->new;
$mock->log->level('fatal');
$mock->routes->get('/report/assistentes' => sub ($c) {
  $R{chamadas_assistentes}++;
  return $c->render(json => { error => 'boom interno' }, status => $R{assistentes_status})
    if $R{assistentes_status} != 200;
  $c->render(json => { assistentes => \@ASSISTENTES });
});
$mock->routes->get('/report/temas' => sub ($c) {
  $R{chamadas_temas}++;
  $R{ultimo_temas} = $c->req->query_params->to_hash;
  return $c->render(json => { error => 'boom interno' }, status => $R{temas_status})
    if $R{temas_status} != 200;
  my $nivel = $c->param('nivel');
  my $assistente = $c->param('assistente') // 'relatorio';
  my ($def) = grep { $_->{id} eq $assistente } @ASSISTENTES;
  return $c->render(json => { error => 'assistente desconhecido' }, status => 400) unless $def;
  my %do_assistente = map { $_ => 1 } @{ $def->{temas} // [] };
  my @t = grep { $do_assistente{ $_->{id} } }
          grep { !$nivel || grep { $_ eq $nivel } @{ $_->{niveis} } } @TEMAS;
  $c->render(json => { temas => \@t });
});
$mock->routes->post('/report' => sub ($c) {
  my $body = $c->req->json;
  $c->render(json => {
    titulo  => 'Relatório de teste',
    recorte => { %{ $body->{geotag} }, nome => 'X' },
    tema    => { id => $body->{tema}, titulo => 'T' },
    secoes  => [ { id => 'resumo', tipo => 'texto', titulo => 'Resumo', markdown => 'ok' } ],
    fontes  => [], avisos => [], rastreio => { provedor => 'mock', llm => 'ok' },
  });
});

my $client = $t->app->analytics;
my %orig = (url => $client->url, source_version => $client->source_version,
            cache_enabled => $client->cache_enabled);
my $SV = "edumapsr-test-relatorios-$$";
$client->ua->server->app($mock);
$client->url('');
$client->source_version($SV);

# --- fixtures ----------------------------------------------------------------
my $INEP  = '77770081';
my $OUTRO = '66660081';
my $SENHA = 'senha123';
my $EMAIL  = sprintf 'rel.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'rel.b.%d@edumaps.test', $$;

my $cleanup = sub {
  $minion->backend->pg->db->query(
    q{DELETE FROM minion_jobs WHERE task = 'relatorio_gerar' AND queue = 'relatorio_test'});
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $_) for $EMAIL, $OEMAIL;
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $_) for $INEP, $OUTRO;
  $dbh->do('DELETE FROM analytics.analysis_cache WHERE source_version = ?', {}, $SV);
};
$cleanup->();
END {
  $cleanup->();
  $client->url($orig{url});
  $client->source_version($orig{source_version});
  $client->cache_enabled($orig{cache_enabled});
}

$dbh->do(q{INSERT INTO clean.censo_escolas
             (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio,
              sg_uf, no_uf, co_regiao, no_regiao)
           VALUES (2024, ?, 'Escola Antiga', 3, 3509502, 'Campinas', 'SP', 'São Paulo', 3, 'Sudeste'),
                  (2025, ?, 'Escola Relatório', 3, 3509502, 'Campinas', 'SP', 'São Paulo', 3, 'Sudeste')},
         {}, $INEP, $INEP);
$dbh->do(q{INSERT INTO clean.censo_escolas
             (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, sg_uf, co_regiao)
           VALUES (2025, ?, 'Outra Escola', 2, 2927408, 'BA', 2)}, {}, $OUTRO);

my ($token, $out_token);
$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Relatório', email => $EMAIL, senha => $SENHA,
})->status_is(200);
$token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $OUTRO, nome => 'Gestor Outro', email => $OEMAIL, senha => $SENHA,
})->status_is(200);
$out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
ok $token && $out_token, 'tokens de sessão';

my $auth  = { Authorization => "Bearer $token" };
my $oauth = { Authorization => "Bearer $out_token" };
my $base  = "/api/gestor/$INEP/relatorios";

subtest '401 sem sessão / 403 em escola alheia' => sub {
  $t->get_ok("$base/recorte-padrao")->status_is(401);
  $t->get_ok("$base/temas")->status_is(401);
  $t->post_ok($base, json => {})->status_is(401);
  $t->get_ok("$base/jobs/1")->status_is(401);

  $t->get_ok("$base/recorte-padrao", $oauth)->status_is(403);
  $t->get_ok("$base/temas", $oauth)->status_is(403);
  $t->post_ok($base, $oauth, json => { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio' })
    ->status_is(403);
  $t->get_ok("$base/jobs/1", $oauth)->status_is(403);
};

subtest 'recorte-padrão da escola do gestor (edição mais recente)' => sub {
  $t->get_ok("$base/recorte-padrao", $auth)->status_is(200)
    ->json_is('/escola/cod_inep', $INEP)
    ->json_is('/escola/nome', 'Escola Relatório')
    ->json_is('/municipio/codigo', '3509502')
    ->json_is('/municipio/nome', 'Campinas')
    ->json_is('/uf/codigo', 'SP')
    ->json_is('/uf/nome', 'São Paulo')
    ->json_is('/regiao/codigo', 'SE')
    ->json_is('/regiao/nome', 'Sudeste');

  # Sem no_uf/no_regiao no Censo: nomes vêm das tabelas de referência.
  $t->get_ok("/api/gestor/$OUTRO/relatorios/recorte-padrao", $oauth)->status_is(200)
    ->json_is('/municipio/codigo', '2927408')
    ->json_is('/uf/codigo', 'BA')
    ->json_is('/uf/nome', 'Bahia')
    ->json_is('/regiao/codigo', 'NE')
    ->json_is('/regiao/nome', 'Nordeste');
};

subtest 'temas: proxy do R (com filtro de nível e cache)' => sub {
  $client->cache_enabled(1);
  $t->get_ok("$base/temas?nivel=uf", $auth)->status_is(200)
    ->json_is('/temas/0/id', 'ideb_territorio');
  my $ids = [ map { $_->{id} } @{ $t->tx->res->json->{temas} } ];
  is $ids, [qw(ideb_territorio redes_territorio gestores_territorio)], 'temas do nível uf';
  ok !exists $t->tx->res->json->{cache_hit}, 'cache_hit não vaza na resposta';

  my $antes = $R{chamadas_temas};
  $t->get_ok("$base/temas?nivel=uf", $auth)->status_is(200);
  is $R{chamadas_temas}, $antes, 'segunda chamada servida do cache';

  $t->get_ok("$base/temas", $auth)->status_is(200);
  is scalar @{ $t->tx->res->json->{temas} }, 4, 'sem nivel: catálogo inteiro';

  $t->get_ok("$base/temas?nivel=bairro", $auth)->status_is(400);

  is $R{ultimo_temas}{assistente}, 'relatorio', 'sem ?assistente: o padrão vai ao R';
};

subtest 'assistentes: proxy do R filtrado por público gestor (cache)' => sub {
  $client->cache_enabled(1);
  $t->get_ok("$base/assistentes")->status_is(401);
  $t->get_ok("$base/assistentes", $oauth)->status_is(403);

  $t->get_ok("$base/assistentes", $auth)->status_is(200)
    ->json_is('/assistentes/0/id', 'relatorio')
    ->json_is('/assistentes/1/id', 'eda_municipio')
    ->json_is('/assistentes/1/modo', 'composto')
    ->json_is('/assistentes/1/capitulos/0/tema', 'ideb_territorio');
  my $ids = [ map { $_->{id} } @{ $t->tx->res->json->{assistentes} } ];
  is $ids, [qw(relatorio eda_municipio uf_so)], 'sem o assistente de outro público';
  ok !exists $t->tx->res->json->{cache_hit}, 'cache_hit não vaza na resposta';

  my $antes = $R{chamadas_assistentes};
  $t->get_ok("$base/assistentes", $auth)->status_is(200);
  is $R{chamadas_assistentes}, $antes, 'segunda chamada servida do cache';
};

subtest 'assistentes: R fora do ar -> 502 genérico' => sub {
  $client->cache_enabled(0);
  local $R{assistentes_status} = 500;
  $t->get_ok("$base/assistentes", $auth)->status_is(502)
    ->json_like('/error', qr/indisponível/);
  unlike $t->tx->res->body, qr/boom interno/, 'não vaza o erro do R';

  # o POST também depende da lista
  $t->post_ok($base, $auth, json => { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio' })
    ->status_is(502);
  $client->cache_enabled(1);
};

subtest 'temas: ?assistente repassado ao R e validado' => sub {
  $client->cache_enabled(0);
  $t->get_ok("$base/temas?nivel=uf&assistente=uf_so", $auth)->status_is(200);
  is [ map { $_->{id} } @{ $t->tx->res->json->{temas} } ], ['redes_territorio'], 'temas do assistente no nível';
  is $R{ultimo_temas}, { nivel => 'uf', assistente => 'uf_so' }, 'query repassada ao R';

  $t->get_ok("$base/temas?nivel=uf&assistente=relatorio", $auth)->status_is(200);
  is scalar @{ $t->tx->res->json->{temas} }, 3, 'assistente padrão explícito';

  $t->get_ok("$base/temas?assistente=EDA-municipio", $auth)->status_is(400)->json_like('/error', qr/assistente/);
  $t->get_ok("$base/temas?assistente=nao_existe", $auth)->status_is(400);
  $t->get_ok("$base/temas?assistente=interno", $auth)->status_is(400, 'assistente de outro público');
  $client->cache_enabled(1);
};

subtest 'cache: chave de temas inclui o assistente' => sub {
  $client->cache_enabled(1);
  $t->get_ok("$base/temas?nivel=uf&assistente=uf_so", $auth)->status_is(200);
  $t->get_ok("$base/temas?nivel=uf", $auth)->status_is(200);
  is scalar @{ $t->tx->res->json->{temas} }, 3, 'cache do padrão não colide com o de uf_so';
};

subtest 'temas: R fora do ar -> 502 com mensagem genérica' => sub {
  $client->cache_enabled(0);
  local $R{temas_status} = 500;
  $t->get_ok("$base/temas?nivel=uf", $auth)->status_is(502)
    ->json_like('/error', qr/indisponível/);
  unlike $t->tx->res->body, qr/boom interno/, 'não vaza o erro do R';

  $t->post_ok($base, $auth, json => { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio' })
    ->status_is(502);
  $client->cache_enabled(1);
};

subtest 'POST: validação do geotag, tema e opcoes (400)' => sub {
  my @casos = (
    [ {}, 'sem geotag' ],
    [ { geotag => 'SP', tema => 'ideb_territorio' }, 'geotag não-objeto' ],
    [ { geotag => { nivel => 'bairro', codigo => '1' }, tema => 'ideb_territorio' }, 'nível inválido' ],
    [ { geotag => { nivel => 'municipio', codigo => '350950' }, tema => 'ideb_territorio' }, 'município 6 dígitos' ],
    [ { geotag => { nivel => 'uf', codigo => 'sp' }, tema => 'ideb_territorio' }, 'UF minúscula' ],
    [ { geotag => { nivel => 'uf', codigo => 'XX' }, tema => 'ideb_territorio' }, 'UF inexistente' ],
    [ { geotag => { nivel => 'regiao', codigo => 'Sul' }, tema => 'ideb_territorio' }, 'região por nome' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' } }, 'sem tema' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'nao_existe' }, 'tema fora do catálogo' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'minha_escola' }, 'tema de outro nível' ],
    [ { geotag => { nivel => 'regiao', codigo => 'SE' }, tema => 'ideb_territorio', opcoes => [1] }, 'opcoes não-objeto' ],
    # Fase 4 — assistente
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio', assistente => 'nao_existe' }, 'assistente desconhecido' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio', assistente => 'interno' }, 'assistente de outro público' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio', assistente => 'Bad-Id' }, 'assistente com formato inválido' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio', assistente => ['relatorio'] }, 'assistente não-escalar' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, assistente => 'eda_municipio' }, 'nível fora dos niveis do assistente' ],
    [ { geotag => { nivel => 'municipio', codigo => '3509502' }, tema => 'redes_territorio', assistente => 'uf_so' }, 'nível fora (niveis escalar)' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, assistente => 'uf_so' }, 'modo tema exige tema' ],
    [ { geotag => { nivel => 'uf', codigo => 'SP' }, tema => 'ideb_territorio', assistente => 'uf_so' }, 'tema fora do catálogo do assistente' ],
  );
  for my $c (@casos) {
    $t->post_ok($base, $auth, json => $c->[0])->status_is(400, $c->[1])->json_has('/error');
  }
};

subtest 'POST: escola de outro gestor -> 400' => sub {
  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'escola', codigo => $OUTRO }, tema => 'minha_escola',
  })->status_is(400)->json_like('/error', qr/sua própria escola/);
};

my $job_id;
subtest 'POST: 202 + job_id; job com args do gestor' => sub {
  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'municipio', codigo => 3509502 },
    tema   => 'ideb_territorio',
    opcoes => { etapa => 'fundamental_i' },
  })->status_is(202)->json_has('/job_id')
    ->header_like(Location => qr{/relatorios/jobs/\d+$});
  $job_id = $t->tx->res->json->{job_id};

  my $info = $minion->job($job_id)->info;
  is $info->{task},  'relatorio_gerar', 'task';
  is $info->{queue}, 'relatorio_test',  'fila configurada (default analytics)';
  my $args = $info->{args}[0];
  is $args->{cod_inep}, $INEP, 'cod_inep';
  ok $args->{gestor_id}, 'gestor_id';
  is $args->{geotag}, { nivel => 'municipio', codigo => '3509502' }, 'geotag normalizado (string)';
  is $args->{opcoes}, { etapa => 'fundamental_i' }, 'opcoes';
  is $args->{assistente}, 'relatorio', 'assistente padrão nos args';
  is $args->{tema}, 'ideb_territorio', 'tema nos args';

  # escola do próprio gestor é aceita
  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'escola', codigo => $INEP }, tema => 'minha_escola',
  })->status_is(202);
};

subtest 'POST: assistente composto (sem tema / tema ignorado) e tema de outro assistente' => sub {
  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'municipio', codigo => '3509502' }, assistente => 'eda_municipio',
    opcoes => { etapa => 'fundamental_ii' },
  })->status_is(202)->json_has('/job_id');
  my $args = $minion->job($t->tx->res->json->{job_id})->info->{args}[0];
  is $args->{assistente}, 'eda_municipio', 'assistente nos args';
  ok !exists $args->{tema}, 'composto: sem tema nos args';
  is $args->{opcoes}, { etapa => 'fundamental_ii' }, 'opcoes';

  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'municipio', codigo => '3509502' }, assistente => 'eda_municipio',
    tema => 'qualquer_coisa',
  })->status_is(202);
  ok !exists $minion->job($t->tx->res->json->{job_id})->info->{args}[0]{tema}, 'tema ignorado no composto';

  $t->post_ok($base, $auth, json => {
    geotag => { nivel => 'uf', codigo => 'SP' }, assistente => 'uf_so', tema => 'redes_territorio',
  })->status_is(202);
  $args = $minion->job($t->tx->res->json->{job_id})->info->{args}[0];
  is [ @$args{qw(assistente tema)} ], [qw(uf_so redes_territorio)], 'modo tema com assistente não padrão';
};

subtest 'GET job: estado inactive -> finished com ReportResult + cache_hit' => sub {
  $t->get_ok("$base/jobs/$job_id", $auth)->status_is(200)->json_is('/state', 'inactive');

  $minion->perform_jobs({ queues => ['relatorio_test'] });

  $t->get_ok("$base/jobs/$job_id", $auth)->status_is(200)
    ->json_is('/state', 'finished')
    ->json_is('/result/titulo', 'Relatório de teste')
    ->json_is('/result/recorte/codigo', '3509502')
    ->json_is('/result/secoes/0/tipo', 'texto')
    ->json_is('/result/cache_hit', Mojo::JSON::false)
    ->json_is('/progress/percent', 100);
};

subtest 'GET job: de outro gestor / outra task / inexistente -> 404' => sub {
  # job de outro gestor (mesma escola na rota não bate com a sessão alheia)
  $t->get_ok("/api/gestor/$OUTRO/relatorios/jobs/$job_id", $oauth)->status_is(404);

  my $outra = $minion->enqueue(chat_ask => [{ pergunta => 'x', contexto => {} }] => { queue => 'relatorio_test' });
  $t->get_ok("$base/jobs/$outra", $auth)->status_is(404);
  $minion->backend->remove_job($outra);

  # relatorio_gerar de outro gestor_id com o mesmo cod_inep
  my $alheio = $minion->enqueue(relatorio_gerar => [{
    gestor_id => -1, cod_inep => $INEP, geotag => { nivel => 'uf', codigo => 'SP' },
    tema => 'ideb_territorio', opcoes => {},
  }] => { queue => 'relatorio_test' });
  $t->get_ok("$base/jobs/$alheio", $auth)->status_is(404);
  $minion->backend->remove_job($alheio);

  $t->get_ok("$base/jobs/999999999", $auth)->status_is(404);
};

done_testing();
