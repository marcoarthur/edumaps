# t/04-api/school/evolution.t
# Testes da rota da série histórica da escola (issue #110):
#   GET /api/school/:cod_inep/evolution
#
# A rota é uma ponte síncrona para o serviço analítico
# (Plumber/edumapsr, POST /school_evolution). Aqui o helper `analytics` é
# substituído por um stub, para testar roteamento + controller sem o
# serviço analítico de pé.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

{
  package StubAnalytics;
  sub new { bless {}, shift }
  sub run_school_evolution {
    die $StubAnalytics::error if defined $StubAnalytics::error;
    return $StubAnalytics::result;
  }
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
$t->app->helper(analytics => sub { StubAnalytics->new });

my $INEP = '23165669';

subtest 'GET /api/school/:inep/evolution devolve a série' => sub {
  $StubAnalytics::error = undef;
  $StubAnalytics::result = {
    analysis => 'school_evolution',
    data     => [
      { indicador => 'ideb_observado', label => 'IDEB observado', ano => 2023,
        etapa => 'fundamental_ii', valor => 4.7 },
    ],
    metrics  => { n_series => 1, ano_max => 2023 },
    metadata => { co_entidade => $INEP, no_entidade => 'EMEF Exemplo' },
    tables   => { resumo => [] },
  };

  my $json = $t->get_ok("/api/school/$INEP/evolution")->status_is(200)
    ->tx->res->json;

  is $json->{analysis}, 'school_evolution', 'analysis correto';
  ok ref($json->{data}) eq 'ARRAY', 'data é array';
  is $json->{metadata}{co_entidade}, $INEP, 'metadata propagada';
};

subtest 'erro de cliente do serviço (400) vira 400' => sub {
  $StubAnalytics::error = 'Analytics: school_evolution retornou 400: Escola não encontrada: 99999999';

  my $tx = $t->get_ok("/api/school/$INEP/evolution")->status_is(400)->tx;
  like $tx->res->json->{error}, qr/não encontrada/, 'mensagem do serviço propagada';
};

subtest 'indisponibilidade do serviço vira 503' => sub {
  $StubAnalytics::error = 'Analytics: falha de conexão (http://analytic:8000/school_evolution): Connection refused';

  my $tx = $t->get_ok("/api/school/$INEP/evolution")->status_is(503)->tx;
  like $tx->res->json->{error}, qr/indisponível/i, 'mensagem genérica';
};

subtest 'cod_inep malformado não casa a rota' => sub {
  $StubAnalytics::error = undef;
  $StubAnalytics::result = { analysis => 'school_evolution' };

  $t->get_ok('/api/school/abc/evolution')->status_is(404);
};

done_testing();
