# t/04-api/gestor/planos_indicadores.t
# #370 (épico #368): metas ligadas a indicadores oficiais da escola, medições
# (oficiais gravadas da fonte; manuais do gestor) e cálculo de progresso.
#
#   * progresso_meta: aumentar / reduzir / manter, limites 0..1, estados;
#   * catálogo com o último valor da escola; sem dado != 0 (#154);
#   * meta oficial: base sugerida, histórico gravado por ano, recarga da fonte
#     acrescenta e NÃO reescreve o ano já gravado; plano encerrado congela;
#   * meta manual: medições, exclusão; oficial não aceita medição à mão.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use EduMaps::Model::Gestor;
use utf8;
use open ':std', ':encoding(UTF-8)';

# ---------------------------------------------------------------- função pura
my $M = 'EduMaps::Model::Gestor';
my @casos = (
  [ 'aumentar a meio caminho', [ aumentar => 5, 6, 5.5 ], 0.5,  'medida' ],
  [ 'aumentar além do alvo',   [ aumentar => 5, 6, 7 ],   1,    'medida' ],
  [ 'aumentar abaixo da base', [ aumentar => 5, 6, 4 ],   0,    'medida' ],
  [ 'reduzir um quarto',       [ reduzir => 20, 12, 18 ], 0.25, 'medida' ],
  [ 'manter acima do alvo',    [ manter => undef, 100, 120 ], 1, 'medida' ],
  [ 'manter abaixo do alvo',   [ manter => undef, 100, 90 ],  0, 'medida' ],
  [ 'sem valor atual',         [ aumentar => 5, 6, undef ], undef, 'sem_medicao' ],
  [ 'sem base',                [ aumentar => undef, 6, 5 ], undef, 'rascunho' ],
  [ 'sem alvo',                [ reduzir => 5, undef, 5 ],  undef, 'rascunho' ],
  [ 'alvo do lado errado',     [ aumentar => 6, 5, 5.5 ],   undef, 'incoerente' ],
);
for my $c (@casos) {
  my ($nome, $args, $p, $estado) = @$c;
  is [ $M->progresso_meta(@$args) ], [ $p, $estado ], "progresso: $nome";
}

# ---------------------------------------------------------------- API
my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.planos_metas_medicoes')");
skip_all('clean.planos_metas_medicoes ausente (migration nao aplicada)') unless $has;

my $INEP  = '77777771';
my $EMAIL = sprintf 'planos.ind.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my $limpar = sub {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
END { return unless $has; $limpar->(); $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL) }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, in_quadra_esportes)
          VALUES (2025, ?, ?, NULL)', {}, $INEP, "Escola Indicadores $INEP");
my $ideb = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas (id_escola, ano, etapa, ideb_observado)
                           VALUES (?, ?, 'fundamental_i', ?)});
$ideb->execute($INEP, 2021, 5.0);
$ideb->execute($INEP, 2023, 5.4);
$dbh->do('INSERT INTO clean.censo_matriculas (nu_ano_censo, co_entidade, qt_mat_bas) VALUES (2025, ?, 320)', {}, $INEP);

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Indicadores', email => $EMAIL, senha => $SENHA })->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
my $auth = { Authorization => "Bearer $token" };
my $base = "/api/gestor/$INEP/planos";

subtest 'catálogo: último valor da escola; sem dado é null' => sub {
  my $ind = $t->get_ok("$base/indicadores", $auth)->status_is(200)->tx->res->json->{indicadores};
  my %c = map { $_->{codigo} => $_ } @$ind;
  is $c{ideb_ai}{ultimo}, { ano => 2023, valor => 5.4 }, 'IDEB AI: o ano mais recente';
  is $c{ideb_ai}{fonte}, 'INEP — IDEB', 'com a fonte';
  is $c{matriculas_total}{ultimo}{valor}, 320, 'matrículas';
  is $c{infra_quadra}{ultimo}, undef, 'infraestrutura NULL na fonte: sem dado (#154), não 0';
  is $c{ideb_em}{ultimo}, undef, 'etapa sem IDEB: sem dado';
  is $c{ivet}{sentido_sugerido}, 'reduzir', 'IVET sugere reduzir';
};

my ($plano, $obj, $meta_of, $meta_man, $meta_quadra);
subtest 'meta oficial: base sugerida e histórico gravado' => sub {
  $plano = $t->post_ok($base, $auth, json => { tipo => 'acao', titulo => 'Plano indicadores' })
    ->status_is(201)->tx->res->json->{id};
  $obj = $t->post_ok("$base/$plano/objetivos", $auth, json => { titulo => 'Aprendizagem' })
    ->status_is(201)->tx->res->json->{id};

  $t->post_ok("$base/$plano/metas", $auth, json => { objetivo_id => $obj, descricao => 'X', indicador_codigo => 'nao_existe' })
    ->status_is(400)->json_like('/error' => qr/não está no catálogo/);
  $t->post_ok("$base/$plano/metas", $auth, json => { objetivo_id => $obj, descricao => 'X',
    indicador_codigo => 'ideb_ai', linha_base => 6, alvo => 5 })
    ->status_is(400, 'aumentar com alvo abaixo da base')->json_like('/error' => qr/alvo tem de ser maior/);

  my $m = $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'Subir o IDEB dos anos iniciais', indicador_codigo => 'ideb_ai', alvo => 6,
  })->status_is(201)->tx->res->json;
  $meta_of = $m->{id};
  is $m->{linha_base}, 5.4, 'linha de base sugerida pelo último valor';
  is $m->{unidade}, 'pontos (0 a 10)', 'unidade do catálogo';
  is [ map { [ $_->{ano_ref}, $_->{valor}, $_->{origem} ] } @{ $m->{medicoes} } ],
     [ [ 2021, 5, 'oficial' ], [ 2023, 5.4, 'oficial' ] ], 'histórico oficial gravado por ano';
  is $m->{atual}{valor}, 5.4, 'atual = medição mais recente';
  is [ $m->{progresso}, $m->{estado} ], [ 0, 'medida' ], 'na base: 0%';
  is $m->{indicador}{fonte}, 'INEP — IDEB', 'meta traz a fonte';

  $t->post_ok("$base/$plano/metas/$meta_of/medicoes", $auth, json => { data_ref => '2026-06-30', valor => 5.8 })
    ->status_is(400, 'meta oficial não recebe valor à mão');
};

subtest 'recarga da fonte: acrescenta e não reescreve' => sub {
  $ideb->execute($INEP, 2025, 6.0);
  $dbh->do(q{UPDATE clean.ideb_notas_escolas SET ideb_observado = 9.9
              WHERE id_escola = ? AND ano = 2023 AND etapa = 'fundamental_i'}, {}, $INEP);
  my $j = $t->get_ok("$base/$plano", $auth)->status_is(200)->tx->res->json;
  my ($m) = @{ $j->{objetivos}[0]{metas} };
  is [ map { $_->{ano_ref} } @{ $m->{medicoes} } ], [ 2021, 2023, 2025 ], '2025 entrou';
  is $m->{medicoes}[1]{valor}, 5.4, '2023 gravado continua 5,4 (a fonte mudou para 9,9)';
  is [ $m->{progresso}, $m->{estado} ], [ 1, 'medida' ], 'alvo atingido: 100%';
};

subtest 'meta manual: medições; sem dado; agregados' => sub {
  $meta_man = $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'Reduzir faltas (%)', sentido => 'reduzir', linha_base => 20, alvo => 12,
  })->status_is(201)->json_is('/estado' => 'sem_medicao')->tx->res->json->{id};

  $t->post_ok("$base/$plano/metas/$meta_man/medicoes", $auth, json => { data_ref => '2026-04-30', valor => '18' })
    ->status_is(201)->json_is('/progresso' => 0.25)->json_is('/atual/origem' => 'manual');
  my $m = $t->post_ok("$base/$plano/metas/$meta_man/medicoes", $auth,
    json => { data_ref => '2026-05-31', valor => '16,0', nota => 'busca ativa' })
    ->status_is(201)->json_is('/progresso' => 0.5)->tx->res->json;
  is scalar @{ $m->{medicoes} }, 2, 'duas medições';
  $t->post_ok("$base/$plano/metas/$meta_man/medicoes", $auth, json => { data_ref => '2026-13-01', valor => 1 })
    ->status_is(400)->json_is('/campos/data_ref' => 'data inexistente');

  my $ultima = $m->{medicoes}[-1]{id};
  $t->delete_ok("$base/$plano/metas/$meta_man/medicoes/$ultima", $auth)->status_is(200);

  $meta_quadra = $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'Ter quadra', indicador_codigo => 'infra_quadra', sentido => 'manter', alvo => 1,
  })->status_is(201)->json_is('/estado' => 'sem_dado', 'fonte sem valor para a escola')->tx->res->json->{id};

  my $j = $t->get_ok("$base/$plano", $auth)->tx->res->json;
  is $j->{objetivos}[0]{progresso}, { valor => 0.625, n_medidas => 2, n_metas => 3 },
    'objetivo: média das medidas (1 e 0,25), com N de M';
  is $j->{resumo}{progresso}{n_metas}, 3, 'resumo do plano com o agregado';

  my ($of) = grep { $_->{id} == $meta_of } @{ $j->{objetivos}[0]{metas} };
  my $med_oficial = $of->{medicoes}[0]{id};
  $t->delete_ok("$base/$plano/metas/$meta_of/medicoes/$med_oficial", $auth)
    ->status_is(409, 'medição oficial não se exclui');
};

subtest 'trocar o indicador refaz o histórico; plano encerrado congela' => sub {
  my $m = $t->put_ok("$base/$plano/metas/$meta_of", $auth, json => { indicador_codigo => 'matriculas_total', linha_base => 300, alvo => 350 })
    ->status_is(200)->tx->res->json;
  is [ map { $_->{ano_ref} } @{ $m->{medicoes} } ], [ 2025 ], 'só o histórico do indicador novo';
  is $m->{progresso}, 0.4, '(320 − 300) / (350 − 300)';

  $t->put_ok("$base/$plano", $auth, json => { situacao => 'encerrado' })->status_is(200);
  $dbh->do('INSERT INTO clean.censo_matriculas (nu_ano_censo, co_entidade, qt_mat_bas) VALUES (2026, ?, 360)', {}, $INEP);
  my $j = $t->get_ok("$base/$plano", $auth)->tx->res->json;
  my ($of) = grep { $_->{id} == $meta_of } @{ $j->{objetivos}[0]{metas} };
  is [ map { $_->{ano_ref} } @{ $of->{medicoes} } ], [ 2025 ], 'encerrado: 2026 não entra';

  $t->put_ok("$base/$plano", $auth, json => { situacao => 'vigente' })->status_is(200)
    ->json_is('/situacao' => 'vigente');
  ($of) = grep { $_->{id} == $meta_of } map { @{ $_->{metas} } } @{ $t->tx->res->json->{objetivos} };
  is [ map { $_->{ano_ref} } @{ $of->{medicoes} } ], [ 2025, 2026 ], 'reaberto: a fonte volta a entrar';
};

subtest 'base ajustada pela escola fica visível (P2-PG-05)' => sub {
  # o valor oficial atual do IDEB da escola (subtestes anteriores acrescentam anos)
  my ($ideb) = grep { $_->{codigo} eq 'ideb_ai' }
    @{ $t->get_ok("$base/indicadores", $auth)->status_is(200)->tx->res->json->{indicadores} };
  my $oficial = $ideb->{ultimo}{valor};
  ok defined $oficial, "IDEB oficial da escola: $oficial";

  # sugerida pela fonte: sem marca
  my $m = $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'IDEB (base sugerida)', indicador_codigo => 'ideb_ai', alvo => 9.5 })
    ->status_is(201)->json_is('/linha_base' => $oficial)->json_is('/linha_base_oficial' => $oficial)
    ->json_is('/base_ajustada' => Mojo::JSON::false)->tx->res->json->{id};

  # a escola baixa a base: marca, e o valor oficial continua guardado
  $t->put_ok("$base/$plano/metas/$m", $auth, json => { linha_base => $oficial - 1 })->status_is(200)
    ->json_is('/linha_base_oficial' => $oficial)->json_is('/base_ajustada' => Mojo::JSON::true);
  # volta ao valor oficial: sem marca
  $t->put_ok("$base/$plano/metas/$m", $auth, json => { linha_base => $oficial })->status_is(200)
    ->json_is('/base_ajustada' => Mojo::JSON::false);

  # informada na criação, diferente da fonte: já nasce marcada
  $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'IDEB (base informada)', indicador_codigo => 'ideb_ai',
    linha_base => $oficial - 0.5, alvo => 9.5 })
    ->status_is(201)->json_is('/linha_base_oficial' => $oficial)->json_is('/base_ajustada' => Mojo::JSON::true);

  # meta manual: não há valor oficial nem marca
  $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'Frequência', linha_base => 80, alvo => 90 })
    ->status_is(201)->json_is('/linha_base_oficial' => undef)->json_is('/base_ajustada' => Mojo::JSON::false);

  # o relatório traz a marca e o valor oficial
  my $r = $t->get_ok("$base/$plano/relatorio", $auth)->status_is(200)->tx->res->json;
  my %metas = map { $_->{descricao} => $_ } map { @{ $_->{metas} } } @{ $r->{plano}{objetivos} };
  is $metas{'IDEB (base informada)'}{base_ajustada}, Mojo::JSON::true, 'relatório: base ajustada';
  is $metas{'IDEB (base informada)'}{linha_base_oficial}, $oficial, 'relatório: valor oficial';
  is $metas{'IDEB (base sugerida)'}{base_ajustada}, Mojo::JSON::false, 'relatório: base oficial sem marca';
};

done_testing;
