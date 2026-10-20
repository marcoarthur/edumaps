# t/04-api/school/isocrona.t
# Testes da rota da isócrona (issue #296, PR2):
#   GET /api/school/:cod_inep/isocrona?tempo=15|45
#
# A rota lê as células H3 vigentes de clean.isocrona_escolar (extração
# #278/#295). Integração com fixture própria (INEPs fora do censo real):
# a conversão célula -> polígono é do frontend (h3-js), aqui só o shape.
#
# Regras verificadas aqui:
#   - snapshot vigente por escola (max(dt_snapshot));
#   - faixas 15 (pé, r9) e 45 (carro, r7) com totais;
#   - ausência vira JSON null, nunca 0 (#154);
#   - tempo inválido -> 400; escola sem extração -> 404.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;

# clean.isocrona_escolar tem FK (codigo_ibge) -> clean.malha_municipio:
# a fixture usa um município real. Sem malha (CI recém-deployada), nada
# a testar aqui.
my ($ibge) = $dbh->selectrow_array(
  q{SELECT codigo_ibge FROM clean.malha_municipio ORDER BY codigo_ibge LIMIT 1}
);
plan skip_all => 'malha_municipio vazia — fixture precisa de um codigo_ibge válido'
  unless defined $ibge;

my @FIXTURE = (99999994, 99999993, 99999992);
sub _limpar {
  $dbh->do(
    'DELETE FROM clean.isocrona_escolar WHERE co_entidade IN (?,?,?)',
    undef, @FIXTURE
  );
}
_limpar();
END { eval { _limpar() } }

sub _inserir ($co, $tempo, $r, $grid, $pop, $snapshot = '2026-10-18') {
  $dbh->do(
    q{
      INSERT INTO clean.isocrona_escolar
        (codigo_ibge, co_entidade, tempo_minutos, grid_id, resolucao_h3,
         populacao_grade, tileset_origin, tileset_build_date, engine,
         engine_version, dt_snapshot)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)
    },
    undef,
    $ibge, $co, $tempo, $grid, $r, $pop,
    'geofabrik_sudeste_2026-10', '2026-10-19', 'valhalla', '3.5.1', $snapshot
  );
}

subtest 'devolve as faixas com células, totais e proveniência' => sub {
  _inserir(99999994, 15, 9, '8948123450fffff', 200);
  _inserir(99999994, 15, 9, '8948123451fffff', 100);
  _inserir(99999994, 15, 9, '8948123452fffff', undef);   # sem dado (#154)
  _inserir(99999994, 45, 7, '8748123450fffff', 3000);
  _inserir(99999994, 45, 7, '8748123451fffff', undef);

  my $res  = $t->get_ok('/api/school/99999994/isocrona')->status_is(200)->tx->res;
  my $json = $res->json;

  is $json->{co_entidade}, 99999994, 'co_entidade';
  is $json->{dt_snapshot}, '2026-10-18', 'dt_snapshot vigente';
  is $json->{engine}{nome}, 'valhalla', 'engine';
  is $json->{engine}{versao}, '3.5.1', 'versão do engine';
  is $json->{engine}{tileset_build_date}, '2026-10-19', 'build dos tiles';

  is scalar @{$json->{tempos}}, 2, 'duas faixas';

  my ($f15, $f45) = @{$json->{tempos}};
  is $f15->{tempo_minutos}, 15, 'faixa 15';
  is $f15->{resolucao_h3}, 9, 'resolução r9 (pé)';
  is $f15->{n_celulas}, 3, 'células do 15';
  is $f15->{populacao_total}, 300, 'total ignora células NULL (#154)';
  is $f15->{celulas}[0]{grid_id}, '8948123450fffff', 'ordenada por pop desc';
  is $f15->{celulas}[0]{populacao}, 200, 'população da célula';
  like $res->text, qr/"populacao":null/, 'célula sem população é JSON null';

  is $f45->{tempo_minutos}, 45, 'faixa 45';
  is $f45->{resolucao_h3}, 7, 'resolução r7 (carro)';
  is $f45->{populacao_total}, 3000, 'total do 45';
};

subtest 'snapshot vigente por escola (max(dt_snapshot))' => sub {
  _limpar();
  # extração antiga (3 células) e nova (1 célula) — a view/API usa a nova
  _inserir(99999994, 15, 9, '8948123450fffff', 200, '2026-10-18');
  _inserir(99999994, 15, 9, '8948123451fffff', 100, '2026-10-18');
  _inserir(99999994, 15, 9, '8948123452fffff', 50,  '2026-10-18');
  _inserir(99999994, 15, 9, '8948123450fffff', 999, '2026-10-20');

  my $json = $t->get_ok('/api/school/99999994/isocrona')->status_is(200)->tx->res->json;
  is $json->{dt_snapshot}, '2026-10-20', 'snapshot novo vence';
  is $json->{tempos}[0]{n_celulas}, 1, 'só as células do snapshot novo';
  is $json->{tempos}[0]{populacao_total}, 999, 'população do snapshot novo';
};

subtest 'filtro por faixa: ?tempo=45' => sub {
  # o subtest 2 limpou — repõe a faixa 45 no snapshot vigente (2026-10-20)
  _inserir(99999994, 45, 7, '8748123450fffff', 3000, '2026-10-20');

  my $json = $t->get_ok('/api/school/99999994/isocrona?tempo=45')
    ->status_is(200)->tx->res->json;
  is scalar @{$json->{tempos}}, 1, 'uma faixa';
  is $json->{tempos}[0]{tempo_minutos}, 45, 'a faixa 45';

  $t->get_ok('/api/school/99999994/isocrona?tempo=15')
    ->status_is(200)->json_is('/tempos/0/tempo_minutos', 15);
};

subtest 'tempo inválido -> 400' => sub {
  $t->get_ok('/api/school/99999994/isocrona?tempo=30')->status_is(400);
  $t->get_ok('/api/school/99999994/isocrona?tempo=x')->status_is(400);
};

subtest 'faixa só com células NULL -> total null, nunca 0 (#154)' => sub {
  _limpar();
  _inserir(99999993, 15, 9, '8948999990fffff', undef);
  _inserir(99999993, 15, 9, '8948999991fffff', undef);

  my $res = $t->get_ok('/api/school/99999993/isocrona')->status_is(200)->tx->res;
  like $res->text, qr/"populacao_total":null/, 'total null (não 0)';
  is $res->json->{tempos}[0]{n_celulas}, 2, 'células contadas mesmo sem pop';
};

subtest 'escola sem extração -> 404' => sub {
  $t->get_ok('/api/school/99999992/isocrona')->status_is(404);
};

done_testing;
