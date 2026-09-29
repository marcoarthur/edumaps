# t/04-api/school/profile.t
# Testes da rota do Perfil da Escola (issue #105):
#   GET /api/school/:cod_inep/profile
#
# A rota é uma ponte síncrona para o serviço analítico
# (Plumber/edumapsr, POST /school_profile). Aqui o helper `analytics` é
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
  sub run_school_profile {
    die $StubAnalytics::error if defined $StubAnalytics::error;
    return $StubAnalytics::result;
  }
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
$t->app->helper(analytics => sub { StubAnalytics->new });

my $INEP = '23165669';

subtest 'GET /api/school/:inep/profile devolve o payload do serviço' => sub {
  $StubAnalytics::result = {
    analysis => 'school_profile',
    data     => [],
    metrics  => { cluster_size => 5, n_peers => 2, n_flags => 1 },
    metadata => {
      co_entidade    => $INEP,
      no_entidade    => 'EMEF Exemplo',
      cluster_source => 'fallback_kmeans',
    },
    tables   => {
      indicadores_comparados => [],
      cluster_resumo         => [],
      peers                  => [],
      flags                  => [],
    },
  };

  my $json = $t->get_ok("/api/school/$INEP/profile")->status_is(200)
    ->tx->res->json;

  is $json->{analysis}, 'school_profile', 'analysis correto';
  is $json->{metadata}{cluster_source}, 'fallback_kmeans', 'cluster_source presente';
  is $json->{metrics}{cluster_size}, 5, 'metrics propagadas';
  ok exists $json->{tables}, 'tables presente';
};

subtest 'erro de cliente do serviço (400) vira 400' => sub {
  $StubAnalytics::error = 'Analytics: school_profile retornou 400: Escola não encontrada: 99999999';

  my $tx = $t->get_ok("/api/school/$INEP/profile")->status_is(400)->tx;
  my $json = $tx->res->json;
  like $json->{error}, qr/não encontrada/, 'mensagem do serviço propagada';
};

subtest 'mensagem 400 não vaza caminho/linha do Perl' => sub {
  $StubAnalytics::error =
    'Analytics: school_profile retornou 400: Escola não encontrada: 99999999 at /opt/edumaps/backend/lib/EduMaps/Controller/School.pm line 56.';

  my $tx = $t->get_ok("/api/school/$INEP/profile")->status_is(400)->tx;
  my $json = $tx->res->json;
  like $json->{error}, qr/não encontrada/, 'mantém a mensagem do serviço';
  unlike $json->{error}, qr{/opt/edumaps}, 'não vaza caminho do servidor';
  unlike $json->{error}, qr/\bline\b/, 'não vaza número de linha';
};

subtest 'indisponibilidade do serviço vira 503' => sub {
  $StubAnalytics::error = 'Analytics: falha de conexão (http://analytic:8000/school_profile): Connection refused';

  my $tx = $t->get_ok("/api/school/$INEP/profile")->status_is(503)->tx;
  my $json = $tx->res->json;
  like $json->{error}, qr/indisponível/i, 'mensagem genérica de indisponibilidade';
};

subtest 'cod_inep malformado não casa a rota' => sub {
  $StubAnalytics::error = undef;
  $StubAnalytics::result = { analysis => 'school_profile' };

  $t->get_ok('/api/school/abc/profile')->status_is(404);
};

done_testing();
