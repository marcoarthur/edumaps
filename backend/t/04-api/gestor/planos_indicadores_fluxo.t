# t/04-api/gestor/planos_indicadores_fluxo.t
# #376: taxas de rendimento e distorção idade-série do INEP como indicadores
# oficiais das metas dos planos.
#
#   * catálogo: 12 códigos novos (grupo fluxo), unidade %, sentido sugerido;
#   * último valor da escola por etapa; etapa sem dado é null (#154);
#   * meta "reduzir o abandono" ligada ao indicador: base sugerida, histórico
#     gravado por ano, progresso calculado com o valor oficial.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
skip_all('clean.inep_rendimento_escola ausente (migration nao aplicada)')
  unless $dbh->selectrow_array("SELECT to_regclass('clean.inep_rendimento_escola')");

my $INEP  = '77777780';
my $EMAIL = sprintf 'planos.fluxo.%d@edumaps.test', $$;
my $SENHA = 'senha123';
my $limpar = sub {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $INEP);
  $dbh->do("DELETE FROM clean.$_ WHERE cod_inep = ?", {}, $INEP) for qw(inep_rendimento_escola inep_distorcao_escola);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
END { return unless $dbh; $limpar->(); $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL) }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
  {}, $INEP, "Escola Fluxo $INEP");
my $rend = $dbh->prepare(q{INSERT INTO clean.inep_rendimento_escola (cod_inep, ano, etapa, aprovacao, reprovacao, abandono)
                           VALUES (?, ?, ?, ?, ?, ?)});
$rend->execute($INEP, 2024, 'af', 88.0, 6.0, 6.0);
$rend->execute($INEP, 2025, 'af', 91.5, 5.0, 3.5);
$rend->execute($INEP, 2025, 'ai', 99.0, 1.0, undef);    # abandono sem dado na fonte
$dbh->do(q{INSERT INTO clean.inep_distorcao_escola (cod_inep, ano, etapa, distorcao) VALUES (?, 2025, 'af', 22.9)},
  {}, $INEP);

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Fluxo', email => $EMAIL, senha => $SENHA })->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
my $auth = { Authorization => "Bearer $token" };
my $base = "/api/gestor/$INEP/planos";

subtest 'catálogo: os 12 códigos de fluxo, com o último valor da escola' => sub {
  my $ind = $t->get_ok("$base/indicadores", $auth)->status_is(200)->tx->res->json->{indicadores};
  my %c = map { $_->{codigo} => $_ } @$ind;
  my @fluxo = grep { /^(aprovacao|reprovacao|abandono|distorcao)_(ai|af|em)$/ } keys %c;
  is scalar @fluxo, 12, '12 códigos';
  is [ @{ $c{abandono_af} }{qw(unidade fonte sentido_sugerido)} ], [ '%', 'INEP — Taxas de Rendimento', 'reduzir' ],
    'abandono: %, fonte, reduzir';
  is $c{aprovacao_af}{sentido_sugerido}, 'aumentar', 'aprovação: aumentar';
  is $c{abandono_af}{ultimo}, { ano => 2025, valor => 3.5 }, 'o ano mais recente';
  is $c{distorcao_af}{ultimo}, { ano => 2025, valor => 22.9 }, 'distorção';
  is $c{abandono_ai}{ultimo}, undef, 'abandono sem dado na fonte: null, nunca 0 (#154)';
  is $c{aprovacao_em}{ultimo}, undef, 'etapa que a escola não tem: null';
};

subtest 'meta "reduzir o abandono" com o indicador oficial' => sub {
  my $plano = $t->post_ok($base, $auth, json => { tipo => 'acao', titulo => 'Plano fluxo' })
    ->status_is(201)->tx->res->json->{id};
  my $obj = $t->post_ok("$base/$plano/objetivos", $auth, json => { titulo => 'Permanência' })
    ->status_is(201)->tx->res->json->{id};
  my $m = $t->post_ok("$base/$plano/metas", $auth, json => {
    objetivo_id => $obj, descricao => 'Reduzir o abandono nos anos finais', indicador_codigo => 'abandono_af',
    sentido => 'reduzir', alvo => 2,
  })->status_is(201)->tx->res->json;
  is $m->{linha_base}, 3.5, 'base sugerida = último valor';
  is $m->{unidade}, '%', 'unidade';
  is [ map { [ $_->{ano_ref}, $_->{valor} ] } @{ $m->{medicoes} } ], [ [ 2024, 6 ], [ 2025, 3.5 ] ],
    'histórico oficial por ano';
  is [ $m->{progresso}, $m->{estado} ], [ 0, 'medida' ], 'na base: 0%';
};

done_testing;
