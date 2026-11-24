# t/04-api/school/finance_ausencia.t
# #422: o painel financeiro diz POR QUE não há folha (ausência não é erro nem
# zero, #154) e onde há folha carregada (cobertura por município).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('clean.remuneracao_municipal')");

my $INEP_MUNICIPAL = '60001701';   # municipal, município sem carga
my $INEP_ESTADUAL  = '60001702';   # estadual: o SIOPE não cobre
my $INEP_COM_FOLHA = '60001703';   # municipal, com folha própria
my $INEP_EST_COM   = '60001704';   # estadual no município COM folha municipal
my $INEP_MUN_SEM   = '60001705';   # municipal sem folha própria no município com folha
my $CO_MUN_SEM     = 6000181;      # município fictício sem folha (outro prefixo de 6 dígitos)
my $CO_MUN_COM     = 6000172;      # município fictício com folha
my $MUN_COM        = '600017';     # cod_municipio (6 dígitos) da folha

my $limpa = sub {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN_COM);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?, ?, ?, ?)', {},
    $INEP_MUNICIPAL, $INEP_ESTADUAL, $INEP_COM_FOLHA, $INEP_EST_COM, $INEP_MUN_SEM);
};

if ($has_tables) {
  $limpa->();
  my $ins = $dbh->prepare('INSERT INTO clean.censo_escolas
      (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio) VALUES (2025, ?, ?, ?, ?)');
  $ins->execute($INEP_MUNICIPAL, 'Escola Municipal Sem Folha', 3, $CO_MUN_SEM);
  $ins->execute($INEP_ESTADUAL,  'Escola Estadual',            2, $CO_MUN_SEM);
  $ins->execute($INEP_COM_FOLHA, 'Escola Com Folha',           3, $CO_MUN_COM);
  $ins->execute($INEP_EST_COM,   'Estadual Vizinha',           2, $CO_MUN_COM);
  $ins->execute($INEP_MUN_SEM,   'Municipal Sem Folha Própria', 3, $CO_MUN_COM);
  $dbh->do('INSERT INTO clean.remuneracao_municipal
              (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total)
            VALUES (2025, ?, ?, ?, ?, ?, ?, ?, ?, 1000)',
    {}, 'Janeiro', 'Servidor Teste', 'xxx.600.017-xx', $INEP_COM_FOLHA, $MUN_COM, 'Municipal',
    'Docente', 'Profissionais do magistério');
}

END { $limpa->() if $has_tables }

subtest 'motivo da ausência' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente' unless $has_tables;

  my $r = $t->get_ok("/api/school/$INEP_MUNICIPAL/finance")->status_is(200)->tx->res->json;
  is $r->{ausencia}, 'municipio_sem_carga', 'municipal sem carga no município';
  is scalar @{ $r->{series} }, 0, 'série vazia';
  is $r->{por_fonte}, undef, 'sem folha: sem divisão por fonte (#553)';

  $r = $t->get_ok("/api/school/$INEP_ESTADUAL/finance")->status_is(200)->tx->res->json;
  is $r->{ausencia}, 'nao_municipal', 'estadual: o SIOPE só cobre a rede municipal';

  $r = $t->get_ok("/api/school/60001799/finance")->status_is(200)->tx->res->json;
  is $r->{ausencia}, 'escola_inexistente', 'escola que não existe';

  $r = $t->get_ok("/api/school/$INEP_COM_FOLHA/finance")->status_is(200)->tx->res->json;
  is $r->{ausencia}, undef, 'com folha: sem motivo de ausência';
  ok scalar @{ $r->{series} } > 0, 'série presente';
};

subtest 'agregado da secretaria não vaza para outra rede nem soma o município (#422)' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente' unless $has_tables;

  # antes: a estadual recebia a folha municipal inteira como "Secretaria"
  my $r = $t->get_ok("/api/school/$INEP_EST_COM/finance")->status_is(200)->tx->res->json;
  is scalar @{ $r->{series} }, 0, 'estadual não recebe a folha municipal';
  is $r->{ausencia}, 'nao_municipal', 'motivo: fora da rede municipal';
  is $r->{origem}, 'escola', 'sem origem secretaria';

  # municipal sem folha própria e sem agregado 99999999: não soma a folha
  # das outras escolas do município
  $r = $t->get_ok("/api/school/$INEP_MUN_SEM/finance")->status_is(200)->tx->res->json;
  is scalar @{ $r->{series} }, 0, 'não soma a folha das outras escolas';
  is $r->{ausencia}, 'escola_sem_folha', 'motivo: o município tem folha, a escola não';
  is $r->{total_profissionais}, 0, 'nenhum profissional';
};

subtest 'cobertura por município' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente' unless $has_tables;

  my $r = $t->get_ok("/api/school/$INEP_MUNICIPAL/finance")->status_is(200)->tx->res->json;
  my $cob = $r->{cobertura};
  ok $cob->{municipios} >= 1, 'conta os municípios com folha';
  is $cob->{municipios}, scalar @{ $cob->{lista} }, 'contagem = tamanho da lista';
  my ($item) = grep { "$_->{cod_municipio}" eq $MUN_COM } @{ $cob->{lista} };
  ok $item, 'município de teste na cobertura' or return;
  is $item->{escolas}, 1, 'uma escola com folha própria';
  is $item->{ano_inicial}, 2025, 'ano inicial';
  is $item->{ano_final}, 2025, 'ano final';
};

done_testing;
