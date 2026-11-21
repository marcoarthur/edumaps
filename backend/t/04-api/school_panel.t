# t/04-api/school_panel.t
# #510: painel público da escola (/api/school/:inep/panel/info).
#  - RA-01: etapas e infraestrutura com as chaves da tela e o estado de cada
#    item (1 tem, 0 não tem, null sem dado); esgoto e energia contam a fossa
#    e o gerador como "outra solução", não como falta.
#  - RA-02: matrículas = total da educação básica do Censo (qt_mat_bas), sem
#    somar de novo a infantil, a EJA e o médio; com o ano do Censo.
# Escola fictícia (INEP de prefixo 60, município 6051000).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $INEP  = '60510001';
my $INEP2 = '60510002';
my ($ANO) = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas');
$ANO //= 2025;

my $limpa = sub {
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade IN (?, ?)', {}, $INEP, $INEP2);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?)', {}, $INEP, $INEP2);
};
$limpa->();
END { $limpa->() }

my $ins = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf,
   tp_situacao_funcionamento,
   in_comum_creche, in_comum_pre, in_comum_fund_ai, in_comum_fund_af, in_comum_medio_medio,
   in_eja, in_profissionalizante,
   in_agua_potavel, in_lixo_servico_coleta, in_internet, in_biblioteca,
   in_laboratorio_ciencias, in_laboratorio_informatica, in_quadra_esportes,
   in_acessibilidade_rampas, in_alimentacao,
   in_energia_rede_publica, in_energia_inexistente,
   in_esgoto_rede_publica, in_esgoto_inexistente)
  VALUES (?, ?, ?, 3, 6051000, 'Município do Teste', 'XU', 1,
          ?, ?, ?, 0, 0, 0, 0,
          1, 1, 1, 0, 0, 0, ?, ?, 1,
          ?, ?, ?, ?)});
# Escola 1: pré-escola e anos iniciais, quadra e rampas; esgoto por fossa
# (sem rede pública, mas não inexistente) e sem energia.
$ins->execute($ANO, $INEP, 'Escola Painel Um', 0, 1, 1, 1, 1, 0, 1, 0, 0);
# Escola 2: creche; energia e esgoto da rede pública; sem quadra e sem rampas.
$ins->execute($ANO, $INEP2, 'Escola Painel Dois', 1, 0, 0, 0, 0, 1, 0, 1, 0);

$dbh->do(q{INSERT INTO clean.censo_matriculas
  (nu_ano_censo, co_entidade, qt_mat_bas, qt_mat_inf, qt_mat_fund, qt_mat_eja, qt_mat_med)
  VALUES (?, ?, 285, 72, 213, 0, 0)}, {}, $ANO, $INEP);

subtest 'etapas e infraestrutura com as chaves da tela (RA-01)' => sub {
  my $e = $t->get_ok("/api/school/$INEP/panel/info")->status_is(200)->tx->res->json->{escola};
  is $e->{etapas}{pre_escola}, 1, 'pré-escola oferecida (antes: pre_infantil, apagada na tela)';
  is $e->{etapas}{fundamental_i}, 1, 'anos iniciais';
  is $e->{etapas}{creche}, 0, 'creche não oferecida';
  ok !exists $e->{etapas}{pre_infantil}, 'sem a chave antiga';

  my $i = $e->{infraestrutura};
  is $i->{quadra_esportes}, 1, 'quadra (antes: quadra_esporte)';
  is $i->{acessibilidade}, 1, 'rampas de acessibilidade (antes: nunca vinha)';
  is $i->{esgoto}, 1, 'esgoto por fossa conta como tem';
  is $i->{detalhe}{esgoto}, 'outra_solucao', 'detalhe: outra solução';
  is $i->{energia}, 0, 'sem energia';
  ok !exists $i->{detalhe}{energia}, 'sem detalhe para o que não tem';
  is $i->{biblioteca}, 0, 'sem biblioteca';

  my $e2 = $t->get_ok("/api/school/$INEP2/panel/info")->status_is(200)->tx->res->json->{escola};
  is $e2->{etapas}{creche}, 1, 'creche';
  is $e2->{infraestrutura}{energia}, 1, 'energia da rede pública';
  is $e2->{infraestrutura}{detalhe}{energia}, 'rede_publica', 'detalhe: rede pública';
  is $e2->{infraestrutura}{quadra_esportes}, 0, 'sem quadra';
  is $e2->{infraestrutura}{acessibilidade}, 0, 'sem rampas';
};

subtest 'matrículas: total da educação básica, com o ano (RA-02)' => sub {
  my $e = $t->get_ok("/api/school/$INEP/panel/info")->status_is(200)->tx->res->json->{escola};
  is $e->{matriculas}, 285, 'qt_mat_bas, sem somar a infantil de novo (antes: 357)';
  is $e->{ano_censo}, $ANO, 'ano do Censo';

  my $e2 = $t->get_ok("/api/school/$INEP2/panel/info")->status_is(200)->tx->res->json->{escola};
  is $e2->{matriculas}, undef, 'sem linha de matrículas: sem número (não 0)';
};

done_testing;
