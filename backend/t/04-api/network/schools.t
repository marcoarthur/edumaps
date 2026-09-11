# t/04-api/network/schools.t
# Testes de integração para API da rede de escolas (schools)
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $path = "/api/network/3550308/schools";

subtest '[API Network] schools - validações' => sub {
  # rede inválida
  $t->get_ok("$path?rede=nao_existe")->status_is(400);

  # limit inválido
  $t->get_ok("$path?limit=abc")->status_is(400);

  # município sem dados
  $t->get_ok("/api/network/9999999/schools")->status_is(404);
};

subtest '[API Network] schools - contrato' => sub {
  my $tx = $t->get_ok("$path?rede=municipal&limit=5")->status_is(200)->tx;
  my $json = $tx->res->json;

  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Possui escolas');
  ok($json->@* <= 5, 'Respeita o limite');

  for my $school ($json->@*) {
    ok(exists $school->{co_entidade}, 'Campo co_entidade presente');
    ok(exists $school->{no_entidade}, 'Campo no_entidade presente');
    is($school->{tp_dependencia}, 3, 'Rede municipal (tp_dependencia=3)');
    ok(exists $school->{matricula_qt_mat_bas}, 'Campo matricula presente');
  }
};

done_testing;