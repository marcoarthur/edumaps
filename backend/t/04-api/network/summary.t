# t/04-api/network/summary.t
# Testes de integração para API da rede de escolas (summary)
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Schema';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $path = "/api/network/3550308";

subtest '[API Network] summary - validações' => sub {
  # código inválido (formato)
  $t->get_ok('/api/network/123/summary')->status_is(404);

  # código não numérico
  $t->get_ok('/api/network/abc/summary')->status_is(404);

  # código com mais dígitos
  $t->get_ok('/api/network/12345678/summary')->status_is(404);

  # município sem dados
  $t->get_ok('/api/network/9999999/summary')->status_is(404);
};

subtest '[API Network] summary - contrato' => sub {
  my $tx = $t->get_ok($path . '/summary')->status_is(200)->tx;
  my $json = $tx->res->json;

  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Possui pelo menos uma rede');

  for my $rede ($json->@*) {
    ok(exists $rede->{rede}, 'Campo rede presente');
    ok(exists $rede->{codigo_rede}, 'Campo codigo_rede presente');
    ok(exists $rede->{total_escolas}, 'Campo total_escolas presente');
    ok(exists $rede->{total_etapas}, 'Campo total_etapas presente');
    ok(exists $rede->{media_etapas}, 'Campo media_etapas presente');
    ok(exists $rede->{total_matriculas}, 'Campo total_matriculas presente');
    ok(exists $rede->{total_docentes}, 'Campo total_docentes presente');
    ok(exists $rede->{ideb_fund_ii}, 'Campo ideb_fund_ii presente');
    ok(exists $rede->{ano_ideb}, 'Campo ano_ideb presente');
  }
};

subtest '[API Network] summary - creche e pré-escola separadas (#516)' => sub {
  my $json = $t->get_ok($path . '/summary')->status_is(200)->tx->res->json;
  for my $rede ($json->@*) {
    ok(exists $rede->{matriculas_creche} && exists $rede->{matriculas_pre}, "$rede->{rede}: creche e pré-escola");
    is(($rede->{matriculas_creche} // 0) + ($rede->{matriculas_pre} // 0), $rede->{matriculas_infantil} // 0,
      "$rede->{rede}: creche + pré-escola = infantil");
  }
};

subtest '[API Network] summary - privadas conveniadas com a prefeitura (#518)' => sub {
  my $json = $t->get_ok($path . '/summary')->status_is(200)->tx->res->json;
  for my $rede ($json->@*) {
    my @c = qw(escolas_conveniadas matriculas_creche_conveniada matriculas_pre_conveniada);
    ok((!grep { !exists $rede->{$_} } @c), "$rede->{rede}: as três colunas");
    if ($rede->{rede} ne 'privada') {
      is([ map { $rede->{$_} // 0 } @c ], [0, 0, 0], "$rede->{rede}: sem conveniadas");
    }
    ok(($rede->{escolas_conveniadas} // 0) <= ($rede->{total_escolas} // 0)
      && ($rede->{matriculas_creche_conveniada} // 0) <= ($rede->{matriculas_creche} // 0)
      && ($rede->{matriculas_pre_conveniada} // 0) <= ($rede->{matriculas_pre} // 0),
      "$rede->{rede}: conveniadas dentro do total");
  }
};

subtest '[API Network] summary - inclui rede federal' => sub {
  my $tx = $t->get_ok($path . '/summary')->tx;
  my $json = $tx->res->json;

  my %redes = map { $_->{rede} => 1 } $json->@*;
  ok($redes{federal}, 'Possui rede federal');
  ok($redes{municipal}, 'Possui rede municipal');
  ok($redes{estadual}, 'Possui rede estadual');
  ok($redes{privada}, 'Possui rede privada');
};

# #479 (RP-01): a comparação conta só as escolas em funcionamento, como o
# perfil, o ranking e a base de análise.
subtest '[API Network] summary - só escolas em funcionamento (#479)' => sub {
  my $dbh = $t->app->schema->storage->dbh;
  my $json = $t->get_ok($path . '/summary')->status_is(200)->tx->res->json;
  my $total = 0; $total += $_->{total_escolas} for $json->@*;
  my ($ativas) = $dbh->selectrow_array(q{SELECT count(DISTINCT co_entidade) FROM clean.censo_escolas
    WHERE co_municipio = 3550308 AND tp_situacao_funcionamento = 1 AND tp_dependencia IS NOT NULL});
  is $total, $ativas, "total de escolas do município = em funcionamento ($ativas)";
  my ($fora) = $dbh->selectrow_array(q{SELECT count(*) FROM clean.censo_escolas
    WHERE co_municipio = 3550308 AND tp_situacao_funcionamento <> 1});
  note "escolas fora de funcionamento no município: $fora";
};

# #479: uma escola paralisada num município só dela não cria rede na MV.
# Município fictício (1199999) e INEP só deste arquivo.
subtest '[API Network] escola paralisada fora da MV (#479)' => sub {
  my $dbh = $t->app->schema->storage->dbh;
  my $INEP = '60479001';
  my $limpa = sub {
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', undef, $INEP);
    $dbh->do('REFRESH MATERIALIZED VIEW analytics.mv_rede_escolas');
  };
  $limpa->();
  $dbh->do(q{INSERT INTO clean.censo_escolas
               (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, tp_situacao_funcionamento,
                co_municipio, no_municipio, sg_uf, no_uf, co_regiao, no_regiao)
             VALUES (2025, ?, 'Escola Paralisada', 3, 2, 1199999, 'Teste', 'RO', 'Rondônia', 1, 'Norte')}, {}, $INEP);
  $dbh->do('REFRESH MATERIALIZED VIEW analytics.mv_rede_escolas');
  my ($n) = $dbh->selectrow_array(q{SELECT count(*) FROM analytics.mv_rede_escolas WHERE co_municipio = '1199999'});
  is $n, 0, 'município só com escola paralisada não tem rede na comparação';
  $t->get_ok('/api/network/1199999/summary')->status_is(404);
  $limpa->();
};

done_testing;