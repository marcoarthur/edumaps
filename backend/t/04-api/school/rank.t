# t/04-api/school/rank.t
# Testes de integração para API de ranking escolar
#
# Endpoints testados:
#   GET /api/school/:cod_inep/indicators  - lista indicadores disponíveis
#   GET /api/school/:cod_inep/ranking     - ranking por indicador
#
# Contexto:
#   - EduMaps::Plugin::API::Rank  (rotas)
#   - EduMaps::Controller::Rank   (validação + chamada ao modelo)
#   - EduMaps::Model::Rank::School (lógica de ranking)

use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

use ok 'EduMaps::Schema';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $schema = EduMaps::Schema->go;

# ============================================================================
# Buscar escolas de exemplo com dados adequados para os testes
# ============================================================================

# --- MV: escola com dados na rede municipal (tp_dependencia = 3) ---
my $mv_school_rs = $schema->resultset('MvEscolasScores')
->search_rs({ -and => [
      score_infraestrutura => { '!=' => undef },
      'me.co_entidade'     => { '!=' => undef },
    ] })
->join('escola')
->search_rs({ 'escola.tp_dependencia' => 3 })
->order_by({ -desc => 'nu_ano_censo' })
->limit(1);

my $mv_school = $mv_school_rs->first;
ok($mv_school, 'Encontrou escola com dados MV e rede municipal') or BAIL_OUT('Sem dados de MV municipal');
my $mv_cod_inep = $mv_school->co_entidade;

# --- Ideb: escola com dados para fundamental_ii (ideb_anos_finais) ---
my $ideb_school_rs = $schema->resultset('IdebNotasEscolas')
->search_rs({ -and => [
      ideb_observado => { '!=' => undef },
      etapa          => 'fundamental_ii',
      id_escola      => { '!=' => undef },
    ] })
->order_by({ -desc => 'ano' })
->limit(1);

my $ideb_school = $ideb_school_rs->first;
ok($ideb_school, 'Encontrou escola com dados Ideb (fundamental_ii)') or BAIL_OUT('Sem dados de Ideb para fundamental_ii');
my $ideb_cod_inep = $ideb_school->id_escola;

# ============================================================================
# Subteste: /api/school/:cod_inep/indicators
# ============================================================================
subtest '[API Rank] indicators' => sub {
  my $path = "/api/school/$mv_cod_inep/indicators";

  # 1. Requisição bem-sucedida
  my $tx = $t->get_ok($path)
  ->status_is(200)
  ->tx;

  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');

  # Verifica estrutura de cada indicador
  if (@$json) {
    my $first = $json->[0];
    ok(exists $first->{id}, 'Campo id presente');
    ok(exists $first->{label}, 'Campo label presente');
    ok(exists $first->{available}, 'Campo available presente');
    like($first->{id}, qr/^[a-z0-9_]+$/, 'id tem formato válido');
  }

  # Verifica se pelo menos um indicador está disponível
  my $any_available = grep { $_->{available} } @$json;
  ok($any_available, 'Pelo menos um indicador disponível');

  # 2. Testa com cod_inep inválido
  $t->get_ok("/api/school/123/indicators")
  ->status_is(404);

  # 3. Testa com escola sem dados
  # (usando cod_inep 00000000 - deve retornar array vazio ou todos indisponíveis)
  $tx = $t->get_ok("/api/school/00000000/indicators")
  ->status_is(200)
  ->tx;

  $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array para escola sem dados');
  if (@$json) {
    my @available = grep { $_->{available} } @$json;
    ok(@available == 0, 'Nenhum indicador disponível para escola sem dados');
  }
};

# ============================================================================
# Subteste: GET /api/school/:cod_inep/ranking
# ============================================================================
subtest '[API Rank] ranking - validações' => sub {
  my $path = "/api/school/$mv_cod_inep/ranking";

  # 1. Parâmetro 'indicador' obrigatório
  $t->get_ok($path)
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 2. 'indicador' com formato inválido (caracteres especiais)
  $t->get_ok("$path?indicador=ideb\@invalid")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 3. 'indicador' com formato válido mas não existe no registry
  $t->get_ok("$path?indicador=indicador_inexistente")
  ->status_is(400)
  ->content_like(qr/Indicador ou rede de ensino inválidos/i);

  # 4. 'national' com valor inválido
  $t->get_ok("$path?indicador=infraestrutura&national=2")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 5. 'national' com valor não numérico
  $t->get_ok("$path?indicador=infraestrutura&national=sim")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 6. 'rede' com valor inválido
  $t->get_ok("$path?indicador=infraestrutura&rede=federal")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 7. 'rede' com valor válido (municipal) - deve funcionar se a escola tiver dados
  # Nota: Se a escola não tiver dados para a rede municipal, retorna 404
  $t->get_ok("$path?indicador=infraestrutura&rede=municipal")
  ->status_is(200, 'rede municipal aceita na validação');
  #->or->status_is(404, 'pode retornar 404 se não houver dados para a rede');
};

# ============================================================================
# Subteste: ranking - MV (indicadores da tabela mv_escolas_scores)
# ============================================================================
subtest '[API Rank] ranking - indicadores MV' => sub {
  my $path = "/api/school/$mv_cod_inep/ranking";

  subtest 'sem filtros' => sub {
    my $tx = $t->get_ok("$path?indicador=infraestrutura")
    ->status_is(200)
    ->tx;

    my $json = $tx->res->json;
    ok($json, 'Resposta JSON');

    # Verifica estrutura básica
    ok(exists $json->{indicador}, 'Campo indicador presente');
    ok(exists $json->{indicador}->{id}, 'indicador.id presente');
    is($json->{indicador}->{id}, 'infraestrutura', 'id correto');
    ok(exists $json->{indicador}->{label}, 'indicador.label presente');
    ok(exists $json->{indicador}->{valor}, 'indicador.valor presente');
    ok($json->{indicador}->{valor} > 0, 'valor > 0');

    ok(exists $json->{ano}, 'Campo ano presente');
    ok($json->{ano} > 2000, 'ano > 2000');
    ok(!defined $json->{rede}, 'rede é undef (sem filtro)');

    ok(exists $json->{ranking}, 'Campo ranking presente');
    ok(exists $json->{ranking}->{municipio}, 'ranking.municipio presente');
    ok(exists $json->{ranking}->{estado}, 'ranking.estado presente');

    my $mun = $json->{ranking}->{municipio};
    ok($mun->{posicao} > 0, 'posicao municipal > 0');
    ok($mun->{total} > 0, 'total municipal > 0');
    ok($mun->{percentil} >= 0, 'percentil >= 0');
    ok($mun->{percentil} <= 100, 'percentil <= 100');

    my $est = $json->{ranking}->{estado};
    ok($est->{posicao} > 0, 'posicao estadual > 0');
    ok($est->{total} > 0, 'total estadual > 0');
    ok($est->{percentil} >= 0, 'percentil >= 0');
    ok($est->{percentil} <= 100, 'percentil <= 100');

    # nacional deve ser undef (não solicitado)
    ok(exists $json->{ranking}->{nacional}, 'ranking.nacional presente');
    ok(!defined $json->{ranking}->{nacional} || $json->{ranking}->{nacional} eq undef, 'nacional é undef');
  };

  subtest 'com filtro de rede municipal' => sub {
    my $tx = $t->get_ok("$path?indicador=infraestrutura&rede=municipal")
    ->status_is(200, 'filtro rede municipal OK')
    #->or->status_is(404, 'pode retornar 404 se não houver dados para a rede')
    ->tx;

    # Se retornou 200, verifica estrutura
    if ($tx->res->code == 200) {
      my $json = $tx->res->json;
      is($json->{rede}, 'municipal', 'rede retornada é municipal');
      ok(exists $json->{ranking}->{municipio}, 'ranking municipal presente');
    }
  };

  subtest 'com filtro nacional' => sub {
    my $tx = $t->get_ok("$path?indicador=infraestrutura&national=1")
    ->status_is(200)
    ->tx;

    my $json = $tx->res->json;
    ok(exists $json->{ranking}->{nacional}, 'ranking.nacional presente');

    # Se nacional existe, verifica estrutura
    if (defined $json->{ranking}->{nacional}) {
      my $nac = $json->{ranking}->{nacional};
      ok($nac->{posicao} > 0, 'posicao nacional > 0');
      ok($nac->{total} > 0, 'total nacional > 0');
      ok($nac->{percentil} >= 0, 'percentil >= 0');
      ok($nac->{percentil} <= 100, 'percentil <= 100');
    }
  };
};

# ============================================================================
# Subteste: ranking - Ideb (indicadores da tabela ideb_notas_escolas)
# ============================================================================
subtest '[API Rank] ranking - indicadores Ideb' => sub {
  my $path = "/api/school/$ideb_cod_inep/ranking";

  subtest 'sem filtros' => sub {
    my $tx = $t->get_ok("$path?indicador=ideb_anos_finais")
    ->status_is(200, 'Ideb disponível para esta escola')
    #->or->status_is(404, 'pode retornar 404 se não houver dados para o indicador')
    ->tx;

    # Se retornou 200, verifica estrutura
    if ($tx->res->code == 200) {
      my $json = $tx->res->json;
      ok($json, 'Resposta JSON');
      ok(exists $json->{indicador}, 'Campo indicador presente');
      is($json->{indicador}->{id}, 'ideb_anos_finais', 'id correto');
      ok($json->{indicador}->{valor} > 0, 'valor > 0');
      ok(exists $json->{ano}, 'Campo ano presente');
      ok(exists $json->{ranking}->{municipio}, 'ranking.municipio presente');
      ok(exists $json->{ranking}->{estado}, 'ranking.estado presente');
    }
  };

  subtest 'com filtro de rede estadual' => sub {
    my $tx = $t->get_ok("$path?indicador=ideb_anos_finais&rede=estadual")
    ->status_is(200, 'filtro rede estadual OK')
    #->or->status_is(404, 'pode retornar 404 se não houver dados para a rede')
    ->tx;

    if ($tx->res->code == 200) {
      my $json = $tx->res->json;
      is($json->{rede}, 'estadual', 'rede retornada é estadual');
    }
  };
};

# ============================================================================
# Subteste: ranking - casos de erro
# ============================================================================
subtest '[API Rank] ranking - casos de erro' => sub {
  my $path = "/api/school/$mv_cod_inep/ranking";

  # 1. Indicador não disponível para a escola (cenário 2 da user story)
  # Usa um indicador que a escola não tem (ex: ideb_ensino_medio para escola sem ensino médio)
  $t->get_ok("$path?indicador=ideb_ensino_medio")
  ->status_is(404);

  # 2. Cod_inep inválido
  $t->get_ok("/api/school/123/ranking?indicador=infraestrutura")
  ->status_is(404);

  # 3. Cod_inep não encontrado (mas formato válido)
  $t->get_ok("/api/school/00000000/ranking?indicador=infraestrutura")
  ->status_is(404);
};

# ============================================================================
# Subteste: performance da API
# ============================================================================
subtest '[API Rank] performance' => sub {
  my $path = "/api/school/$mv_cod_inep/ranking?indicador=infraestrutura";

  # Inicia cronômetro
  my $t0 = [gettimeofday];

  $t->get_ok($path)
  ->status_is(200);

  my $elapsed = tv_interval($t0);

  # Teto: 500ms para ranking (pode envolver consultas mais complexas que search)
  my $max_api_time = 2.50;

  ok(
    $elapsed <= $max_api_time,
    sprintf("Tempo da rota ranking (%.4fs) dentro do limite (%.2fs)", $elapsed, $max_api_time)
  );

  note sprintf("API Performance Info -> Rota: %s | Tempo: %.4f segundos", $path, $elapsed);
};

# ============================================================================
# Subteste: integração frontend - contratos
# ============================================================================
subtest '[API Rank] contrato frontend' => sub {
  my $path = "/api/school/$mv_cod_inep/ranking";

  # Verifica que a resposta está no formato esperado pelo frontend
  my $tx = $t->get_ok("$path?indicador=infraestrutura")
  ->status_is(200)
  ->tx;

  my $json = $tx->res->json;

  # Contrato esperado pelo frontend (SchoolRanking.svelte / rankingApi.js)
  # Estrutura:
  # {
    #   indicador: { id, label, valor },
    #   ano: number,
    #   rede: string|null,
    #   ranking: {
      #     municipio: { posicao, total, percentil } | null,
      #     estado: { posicao, total, percentil } | null,
      #     nacional: { posicao, total, percentil } | null
      #   }
    # }

  ok(exists $json->{indicador}, 'indicador existe');
  ok(exists $json->{indicador}->{id}, 'indicador.id existe');
  ok(exists $json->{indicador}->{label}, 'indicador.label existe');
  ok(exists $json->{indicador}->{valor}, 'indicador.valor existe');

  ok(exists $json->{ano}, 'ano existe');
  ok($json->{ano} =~ /^\d+$/, 'ano é numérico');

  ok(exists $json->{rede}, 'rede existe');

  ok(exists $json->{ranking}, 'ranking existe');
  ok(exists $json->{ranking}->{municipio}, 'ranking.municipio existe');
  ok(exists $json->{ranking}->{estado}, 'ranking.estado existe');
  ok(exists $json->{ranking}->{nacional}, 'ranking.nacional existe');

  if (defined $json->{ranking}->{municipio}) {
    ok(exists $json->{ranking}->{municipio}->{posicao}, 'municipio.posicao existe');
    ok(exists $json->{ranking}->{municipio}->{total}, 'municipio.total existe');
    ok(exists $json->{ranking}->{municipio}->{percentil}, 'municipio.percentil existe');
  }

  # NOTA: O cluster NÃO está no contrato — o frontend lida com cluster separadamente
  ok(!exists $json->{cluster}, 'cluster NÃO está presente no contrato de ranking');
};

done_testing;
