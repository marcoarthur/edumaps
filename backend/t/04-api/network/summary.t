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
    ok(exists $rede->{total_matriculas}, 'Campo total_matriculas presente');
    ok(exists $rede->{total_docentes}, 'Campo total_docentes presente');
    ok(exists $rede->{ideb_fund_ii}, 'Campo ideb_fund_ii presente');
    ok(exists $rede->{ano_ideb}, 'Campo ano_ideb presente');
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

done_testing;