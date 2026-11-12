# t/04-api/rede/painel.t
# #396 (visão da rede, #375): painel da rede e relatório da escola pela rede.
#
#   * por escola: plano vigente mais recente (ou nenhum), andamento "N de M"
#     (sem metas medidas = null, nunca 0), atrasadas, vencem em 7 dias,
#     evidências, quantos vigentes; totais da rede;
#   * escola só com rascunho e sem plano aparecem como "sem plano vigente";
#   * escola de outra rede não aparece; relatório dela é 403;
#   * relatório pela rede é só leitura: não grava medição oficial;
#   * 300 escolas com plano: o painel responde em menos de 2 s.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Time::HiRes qw(time);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.rede_vinculos')");
skip_all('clean.rede_vinculos ausente (migration nao aplicada)') unless $has;

my $P    = sprintf '%04d', $$ % 10000;
my $M    = 9990011;            # município fictício da rede
my $MG   = 9990012;            # município do teste de carga
my %E    = (P1 => 77778901, P2 => 77778902, P3 => 77778903, P4 => 77778904, X => 77778905);
my $REDE = "painel.rede.$P\@edumaps.test";
my $CARGA_INI = 77700000;      # 300 escolas fictícias para o teste de carga

sub limpa {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ANY(?) OR cod_inep BETWEEN ? AND ?',
    {}, [ values %E ], $CARGA_INI, $CARGA_INI + 299);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?) OR co_entidade BETWEEN ? AND ?',
    {}, [ values %E ], $CARGA_INI, $CARGA_INI + 299);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $REDE);
}
limpa();
END { limpa() if $has }

my $censo = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento)
  VALUES (2025, ?, ?, ?, ?, 'Vila Painel', 'ZZ', 1)});
$censo->execute($E{P1}, 'P1 com plano', 3, $M);
$censo->execute($E{P2}, 'P2 só rascunho', 3, $M);
$censo->execute($E{P3}, 'P3 sem plano', 3, $M);
$censo->execute($E{P4}, 'P4 dois vigentes', 3, $M);
$censo->execute($E{X},  'X estadual', 2, $M);

# planos direto no banco (o painel lê o que a escola gravou)
my $plano = sub ($inep, $titulo, $situacao, $atualizado) {
  my ($id) = $dbh->selectrow_array(q{INSERT INTO clean.planos_gestao (cod_inep, tipo, titulo, situacao, updated_at)
    VALUES (?, 'acao', ?, ?, ?::timestamptz) RETURNING id}, {}, $inep, $titulo, $situacao, $atualizado);
  my ($obj) = $dbh->selectrow_array(q{INSERT INTO clean.planos_objetivos (plano_id, titulo, ordem)
    VALUES (?, 'Objetivo', 1) RETURNING id}, {}, $id);
  return ($id, $obj);
};
my ($p1, $o1) = $plano->($E{P1}, 'Plano P1', 'vigente', '2026-11-10 10:00');
# meta medida a meio caminho (base 20 -> alvo 10, atual 15 = 50%) e meta sem medição
my ($m1) = $dbh->selectrow_array(q{INSERT INTO clean.planos_metas (objetivo_id, descricao, sentido, linha_base, alvo)
  VALUES (?, 'Reduzir faltas', 'reduzir', 20, 10) RETURNING id}, {}, $o1);
$dbh->do(q{INSERT INTO clean.planos_metas_medicoes (meta_id, data_ref, valor, origem) VALUES (?, '2026-06-01', 18, 'manual'),
  (?, '2026-09-01', 15, 'manual')}, {}, $m1, $m1);
$dbh->do(q{INSERT INTO clean.planos_metas (objetivo_id, descricao, sentido, linha_base, alvo) VALUES (?, 'Sem medição', 'aumentar', 1, 2)}, {}, $o1);
my $acao = $dbh->prepare(q{INSERT INTO clean.planos_acoes (objetivo_id, descricao, prazo, situacao, concluida_em)
  VALUES (?, ?, ?::date, ?, CASE WHEN ? = 'concluida' THEN NOW() END) RETURNING id});
my $hoje = $dbh->selectrow_array(q{SELECT (NOW() AT TIME ZONE 'America/Sao_Paulo')::date});
my ($atrasada) = do { $acao->execute($o1, 'Atrasada', '2020-01-01', 'em_andamento', 'em_andamento'); $acao->fetchrow_array };
$acao->execute($o1, 'Vence logo', $dbh->selectrow_array(q{SELECT ?::date + 3}, {}, $hoje), 'nao_iniciada', 'nao_iniciada');
$acao->execute($o1, 'Feita', '2020-01-01', 'concluida', 'concluida');
$dbh->do(q{INSERT INTO clean.planos_evidencias (acao_id, tipo, texto) VALUES (?, 'nota', 'Registro')}, {}, $atrasada);

$plano->($E{P2}, 'Rascunho P2', 'rascunho', '2026-11-11 10:00');
my ($p4a) = $plano->($E{P4}, 'Vigente antigo', 'vigente', '2026-01-01 10:00');
my ($p4b) = $plano->($E{P4}, 'Vigente novo',   'vigente', '2026-11-01 10:00');
$plano->($E{X}, 'Plano estadual', 'vigente', '2026-11-01 10:00');

# conta de rede (municipal, município M) pelo model
my $pm = $t->app->model('Pesquisa');
my $c = $pm->rede_conta_criar(undef, { nome => 'Rede Painel', email => $REDE, cargo => 'Supervisora' });
$pm->rede_convite_aceitar($c->{convite}{token}, 'senha123');
my $conta = $c->{conta}{id};
$pm->rede_vinculo_conceder(undef, $conta, 3, $M);
my $tok = $t->post_ok('/api/gestor/login', json => { email => $REDE, senha => 'senha123' })->status_is(200)->tx->res->json->{token};
my $H = { Authorization => "Bearer $tok" };

my $painel = $t->get_ok('/api/rede/painel', $H)->status_is(200)->tx->res->json;
my %linha = map { $_->{cod_inep} => $_ } @{ $painel->{escolas} };

subtest 'escolas e totais' => sub {
  is [ sort keys %linha ], [ sort @E{qw(P1 P2 P3 P4)} ], 'só a rede municipal (X estadual fora)';
  is $painel->{totais}, { escolas => 4, com_plano_vigente => 2, sem_plano_vigente => 2, acoes_atrasadas => 1 }, 'totais';
};

subtest 'escola com plano vigente' => sub {
  my $p = $linha{ $E{P1} }{plano};
  is $p->{id}, $p1, 'plano vigente';
  is $p->{progresso}, { valor => 0.5, n_medidas => 1, n_metas => 2 }, 'andamento 50%, 1 de 2 medidas';
  is [ @{$p}{qw(n_acoes n_concluidas n_atrasadas n_vencem_7d n_evidencias n_vigentes)} ], [ 3, 1, 1, 1, 1, 1 ], 'ações e evidências';
};

subtest 'sem plano vigente' => sub {
  is $linha{ $E{P2} }{plano}, undef, 'só rascunho: sem plano vigente';
  is $linha{ $E{P2} }{n_planos}, 1, '… mas tem 1 plano (rascunho)';
  is $linha{ $E{P3} }{plano}, undef, 'sem plano';
  is $linha{ $E{P3} }{n_planos}, 0, 'nenhum plano';
};

subtest 'dois vigentes: o mais recente, com a contagem' => sub {
  is $linha{ $E{P4} }{plano}{id}, $p4b, 'o mais recente';
  is $linha{ $E{P4} }{plano}{n_vigentes}, 2, 'dois vigentes';
  is $linha{ $E{P4} }{plano}{progresso}, { valor => undef, n_medidas => 0, n_metas => 0 }, 'sem metas: null, nunca 0';
};

subtest 'planos e relatório da escola pela rede' => sub {
  $t->get_ok("/api/rede/escolas/$E{P4}/planos", $H)->status_is(200)->json_is('/planos/0/titulo' => 'Vigente novo');
  $t->get_ok("/api/rede/escolas/$E{P1}/planos/$p1/relatorio", $H)->status_is(200)
    ->json_is('/plano/titulo' => 'Plano P1')->json_is('/emitido_por_cargo' => 'Supervisora')
    ->json_is('/plano/resumo/progresso/n_medidas' => 1);
  $t->get_ok("/api/rede/escolas/$E{P1}/planos/$p4a/relatorio", $H)->status_is(404, 'plano de outra escola');
  $t->get_ok("/api/rede/escolas/$E{X}/planos", $H)->status_is(403);
  my ($px) = $dbh->selectrow_array('SELECT id FROM clean.planos_gestao WHERE cod_inep = ?', {}, $E{X});
  $t->get_ok("/api/rede/escolas/$E{X}/planos/$px/relatorio", $H)->status_is(403);
};

subtest 'relatório pela rede não grava nada' => sub {
  # meta oficial com valor da fonte ainda não gravado: a escola sincronizaria
  $dbh->do(q{INSERT INTO clean.censo_matriculas (nu_ano_censo, co_entidade, qt_mat_bas) VALUES (2025, ?, 99)}, {}, $E{P1});
  my ($mo) = $dbh->selectrow_array(q{INSERT INTO clean.planos_metas (objetivo_id, descricao, sentido, indicador_codigo, linha_base, alvo)
    VALUES (?, 'Matrículas', 'aumentar', 'matriculas_total', 90, 120) RETURNING id}, {}, $o1);
  $t->get_ok("/api/rede/escolas/$E{P1}/planos/$p1/relatorio", $H)->status_is(200);
  is $dbh->selectrow_array('SELECT count(*) FROM clean.planos_metas_medicoes WHERE meta_id = ?', {}, $mo), 0,
    'nenhuma medição oficial gravada pela leitura da rede';
  my ($upd_antes) = $dbh->selectrow_array('SELECT updated_at FROM clean.planos_gestao WHERE id = ?', {}, $p1);
  $t->get_ok('/api/rede/painel', $H)->status_is(200);
  is $dbh->selectrow_array('SELECT updated_at FROM clean.planos_gestao WHERE id = ?', {}, $p1), $upd_antes, 'plano intocado';
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade = ?', {}, $E{P1});
};

subtest '300 escolas: painel em menos de 2 s' => sub {
  $dbh->do(q{INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento)
    SELECT 2025, ? + g, 'Carga ' || g, 3, ?, 'Vila Carga', 'ZZ', 1 FROM generate_series(0, 299) g}, {}, $CARGA_INI, $MG);
  $dbh->do(q{WITH p AS (
      INSERT INTO clean.planos_gestao (cod_inep, tipo, titulo, situacao)
      SELECT ? + g, 'acao', 'Plano ' || g, 'vigente' FROM generate_series(0, 299) g RETURNING id
    ), o AS (
      INSERT INTO clean.planos_objetivos (plano_id, titulo, ordem) SELECT id, 'Obj', 1 FROM p RETURNING id
    ), m AS (
      INSERT INTO clean.planos_metas (objetivo_id, descricao, sentido, linha_base, alvo)
      SELECT o.id, 'Meta ' || k, 'aumentar', 10, 20 FROM o, generate_series(1, 3) k RETURNING id
    ), md AS (
      INSERT INTO clean.planos_metas_medicoes (meta_id, data_ref, valor, origem)
      SELECT id, '2026-06-01', 15, 'manual' FROM m
    )
    INSERT INTO clean.planos_acoes (objetivo_id, descricao, prazo, situacao)
    SELECT o.id, 'Ação ' || k, '2026-12-01', 'em_andamento' FROM o, generate_series(1, 4) k}, {}, $CARGA_INI);
  $pm->rede_vinculo_conceder(undef, $conta, 3, $MG);
  my $t0 = time;
  my $r = $t->get_ok('/api/rede/painel', $H)->status_is(200)->tx->res->json;
  my $dt = time - $t0;
  is $r->{totais}{escolas}, 304, '304 escolas (4 + 300)';
  ok $dt < 2, sprintf('painel em %.2f s (< 2 s)', $dt);
  diag sprintf('painel com 304 escolas: %.2f s', $dt);
};

done_testing;
