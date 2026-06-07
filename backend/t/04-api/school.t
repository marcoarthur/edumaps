use lib qw(./t/lib);
use Imports;
use Test::Mojo;

my $t = Test::Mojo->new(Mojo::File->new('./edu_maps.pl'));
$t->app->log->level('fatal');
my $school_id_valid    = 35047824;
my $school_id_invalid  = 12123123;

subtest 'ID inválido' => sub {
  $t->get_ok("/api/school/scores?id=$school_id_invalid")
  ->status_is(200)
  ->json_has('/error')
  ->json_like('/error' => qr/não encontrad[ao]/i)
  ->json_hasnt('/co_entidade');
};

subtest 'ID válido' => sub {
  $t->get_ok("/api/school/scores?id=$school_id_valid")
  ->status_is(200)
  ->json_is('/co_entidade' => $school_id_valid)
  ->json_has('/score_capacidade_atendimento');

  my @score_fields = qw(
    score_capacidade_atendimento
    score_capacidade_gestora
    score_capacitacao_docente
    score_diversidade_discente
    score_infraestrutura
    score_sustentabilidade
  );
  for my $field (@score_fields) {
    $t->json_like("/$field" => qr/^(?:[0-9]|[1-9][0-9]?|100)(?:\.[0-9]{1,2})?$/)
    ->or( sub { diag("Campo $field parece inválido: $_") } );
  }
};

subtest 'Parâmetros ausentes ou inválidos' => sub {
  $t->get_ok("/api/school/scores")->status_is(400);
  $t->get_ok("/api/school/scores?id=abc")->status_is(400);
  $t->get_ok("/api/school/scores?id=")   ->status_is(400);
};

done_testing;
