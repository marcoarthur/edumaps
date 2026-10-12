# t/05-tasks/relatorio_gerar.t
# Task Minion `relatorio_gerar` (Assistente de Relatório, #219): chama o R
# (POST /report) via Analytics::Client com a config LLM do painel; finish com
# o ReportResult + cache_hit; 400 do R -> fail com a mensagem do R; demais
# erros -> fail com mensagem genérica; a api_key nunca entra na chave do
# cache. O R é simulado por um app Mojolicious embutido no UA do client.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojolicious;
use Mojo::JSON ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $app    = $t->app;
my $minion = $app->minion;
my $dbh    = $app->schema->storage->dbh;
my $QUEUE  = 'relatorio_task_test';

# --- R simulado --------------------------------------------------------------
my %R = (status => 200, error => undef, chamadas => 0, ultimo => undef);
my $mock = Mojolicious->new;
$mock->log->level('fatal');
$mock->routes->post('/report' => sub ($c) {
  $R{chamadas}++;
  $R{ultimo} = $c->req->json;
  return $c->render(json => { error => $R{error} }, status => $R{status})
    if $R{status} != 200;
  $c->render(json => {
    titulo   => 'IDEB do território — Campinas (SP)',
    gerado_em => '2026-10-12T12:00:00Z',
    recorte  => { nivel => 'municipio', codigo => '3509502', nome => 'Campinas', uf => 'SP' },
    tema     => { id => 'ideb_territorio', titulo => 'IDEB do território' },
    secoes   => [
      { id => 'resumo', tipo => 'texto', titulo => 'Resumo', markdown => 'Texto.' },
      { id => 'kpis', tipo => 'indicadores', titulo => 'KPIs',
        itens => [ { rotulo => 'IDEB 2023', valor => 6.1, formato => 'decimal1' } ] },
    ],
    fontes   => [ { ferramenta => 'ideb_agregado', n => 645 } ],
    avisos   => [],
    rastreio => { provedor => 'mock', llm => 'ok' },
  });
});

my $client = $app->analytics;
my %orig = (url => $client->url, source_version => $client->source_version,
            cache_enabled => $client->cache_enabled);
my $SV = "edumapsr-test-relatorio-gerar-$$";
$client->ua->server->app($mock);
$client->url('');
$client->source_version($SV);
$client->cache_enabled(1);

# Config LLM do painel com api_key (sem depender da master key).
my %CFG = (provider => 'mock', model => 'm1', api_key => 'segredo-123');
{
  no warnings qw(redefine once);
  *EduMaps::Model::AppConfig::chat_llm_config = sub ($self) { return { %CFG } };
}

my $limpa = sub {
  $minion->backend->pg->db->query('DELETE FROM minion_jobs WHERE queue = ?', $QUEUE);
  $dbh->do('DELETE FROM analytics.analysis_cache WHERE source_version = ?', {}, $SV);
};
$limpa->();
END {
  $limpa->();
  $client->url($orig{url});
  $client->source_version($orig{source_version});
  $client->cache_enabled($orig{cache_enabled});
}

my %ARGS = (
  gestor_id => 1,
  cod_inep  => '35038751',
  geotag    => { nivel => 'municipio', codigo => '3509502' },
  tema      => 'ideb_territorio',
  opcoes    => { etapa => 'fundamental_i' },
);

sub roda (%over) {
  my $id = $minion->enqueue(relatorio_gerar => [{ %ARGS, %over }] => { queue => $QUEUE });
  # em primeiro plano (sem fork): o R simulado registra o corpo recebido.
  $minion->perform_jobs_in_foreground({ queues => [$QUEUE] });
  return $minion->job($id)->info;
}

subtest 'task registrada; helper enfileira na fila analytics por padrão' => sub {
  ok $minion->tasks->{relatorio_gerar}, 'relatorio_gerar registrada';
  my $id = $app->build_controller->gerar_relatorio({ %ARGS });
  is $minion->job($id)->info->{queue}, 'analytics', 'fila analytics';
  $minion->backend->remove_job($id);
};

subtest 'finish com ReportResult + cache_hit; segundo job vem do cache' => sub {
  my $info = roda();
  is $info->{state}, 'finished', 'finished';
  my $r = $info->{result};
  is $r->{titulo}, 'IDEB do território — Campinas (SP)', 'titulo';
  is $r->{secoes}[1]{itens}[0]{valor}, 6.1, 'seções preservadas';
  is $r->{fontes}[0]{n}, 645, 'fontes';
  ok !$r->{cache_hit}, 'cache_hit falso na primeira';
  is $info->{notes}{progress}{percent}, 100, 'progresso 100%';

  # Corpo enviado ao R conforme o contrato.
  is $R{ultimo}{geotag},   $ARGS{geotag}, 'geotag';
  is $R{ultimo}{tema},     'ideb_territorio', 'tema';
  is $R{ultimo}{assistente}, 'relatorio', 'job sem assistente (antigo): padrão relatorio';
  is $R{ultimo}{opcoes},   $ARGS{opcoes}, 'opcoes';
  is $R{ultimo}{contexto}, { cod_inep => '35038751' }, 'contexto.cod_inep';
  is $R{ultimo}{config}{api_key}, 'segredo-123', 'config (com api_key) vai no body';

  my $antes = $R{chamadas};
  my $info2 = roda(gestor_id => 2, cod_inep => '11111111');
  is $info2->{state}, 'finished', 'finished (cache)';
  ok $info2->{result}{cache_hit}, 'cache_hit verdadeiro';
  is $R{chamadas}, $antes, 'R não foi chamado de novo (contexto fora da chave)';
};

subtest 'cache_params: sem api_key; config_version muda com a config' => sub {
  my $p = $client->report_cache_params({ %ARGS, config => { %CFG } });
  is [ sort keys %$p ], [qw(assistente config_version geotag opcoes tema)], 'só as chaves do contrato';
  is $p->{assistente}, 'relatorio', 'assistente ausente = relatorio';
  is $client->report_cache_params({ %ARGS, assistente => 'relatorio', config => { %CFG } }), $p,
    'assistente padrão explícito = mesma chave (jobs antigos continuam no cache)';
  my $pe = $client->report_cache_params({ %ARGS, assistente => 'eda_municipio', config => { %CFG } });
  is $pe->{assistente}, 'eda_municipio', 'assistente na chave';
  unlike Mojo::JSON::encode_json($p), qr/segredo/, 'api_key fora da chave';

  my $p2 = $client->report_cache_params({ %ARGS, config => { %CFG, api_key => 'outra' } });
  isnt $p2->{config_version}, $p->{config_version}, 'trocar a chave invalida o cache';

  my $rows = $dbh->selectall_arrayref(
    'SELECT params::text FROM analytics.analysis_cache WHERE source_version = ?', {}, $SV);
  ok scalar @$rows, 'entrada gravada no analysis_cache';
  unlike $_->[0], qr/segredo/, 'params persistidos sem api_key' for @$rows;
};

subtest 'assistente dos args vai ao R e separa o cache' => sub {
  my $antes = $R{chamadas};
  my $info = roda(assistente => 'eda_municipio', tema => undef);
  is $info->{state}, 'finished', 'finished';
  is $R{ultimo}{assistente}, 'eda_municipio', 'assistente no body';
  is $R{chamadas}, $antes + 1, 'outro assistente não reaproveita o cache do relatorio';

  my $info2 = roda(assistente => 'eda_municipio', tema => undef, gestor_id => 3);
  ok $info2->{result}{cache_hit}, 'mesmo assistente e recorte: cache';
  is $R{chamadas}, $antes + 1, 'R não chamado de novo';
};

subtest '400 do R -> fail com a mensagem do R' => sub {
  local $R{status} = 400;
  local $R{error}  = 'Tema "x" não existe para o nível municipio';
  my $info = roda(tema => 'x');
  is $info->{state}, 'failed', 'failed';
  is $info->{result}{error}, 'Tema "x" não existe para o nível municipio', 'mensagem do R';
};

subtest '500 do R / falha de conexão -> fail genérico' => sub {
  {
    local $R{status} = 500;
    local $R{error}  = 'Erro interno: senha do banco xyz';
    my $info = roda(tema => 'redes_territorio');
    is $info->{state}, 'failed', 'failed';
    like $info->{result}{error}, qr/Não foi possível gerar o relatório/, 'mensagem genérica';
    unlike $info->{result}{error}, qr/senha|Analytics|500/, 'sem vazar detalhes';
  }

  # Conexão recusada (porta fechada).
  $client->url('http://127.0.0.1:1');
  my $info = roda(tema => 'docentes_territorio');
  $client->url('');
  is $info->{state}, 'failed', 'failed';
  like $info->{result}{error}, qr/Não foi possível gerar o relatório/, 'mensagem genérica';
  unlike $info->{result}{error}, qr/127\.0\.0\.1|conex/, 'sem vazar detalhes';
};

done_testing();
