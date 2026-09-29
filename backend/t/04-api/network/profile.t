# t/04-api/network/profile.t
# Testes da rota do perfil da rede (issue #109):
#   GET /api/network/:codigo_ibge/profile
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

{
  package StubAnalytics;
  sub new { bless {}, shift }
  sub run_network_profile {
    die $StubAnalytics::error if defined $StubAnalytics::error;
    return $StubAnalytics::result;
  }
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
$t->app->helper(analytics => sub { StubAnalytics->new });

my $IBGE = '2307304';

subtest 'GET /api/network/:ibge/profile devolve o payload' => sub {
  $StubAnalytics::error = undef;
  $StubAnalytics::result = {
    analysis => 'network_profile',
    data     => [],
    metrics  => { n_escolas => 225, n_clusters => 1 },
    metadata => { codigo_ibge => $IBGE, no_municipio => 'Juazeiro do Norte' },
    tables   => { clusters => [], indicadores => [] },
  };

  my $json = $t->get_ok("/api/network/$IBGE/profile")->status_is(200)
    ->tx->res->json;

  is $json->{analysis}, 'network_profile', 'analysis correto';
  is $json->{metadata}{codigo_ibge}, $IBGE, 'metadata propagada';
  ok exists $json->{tables}, 'tables presente';
};

subtest '400 do serviço vira 400' => sub {
  $StubAnalytics::error = 'Analytics: network_profile retornou 400: Município sem escolas no censo: 9999999';

  my $tx = $t->get_ok("/api/network/$IBGE/profile")->status_is(400)->tx;
  like $tx->res->json->{error}, qr/sem escolas/, 'mensagem propagada';
};

subtest 'indisponibilidade do serviço vira 503' => sub {
  $StubAnalytics::error = 'Analytics: falha de conexão (http://analytic:8000/network_profile): Connection refused';

  my $tx = $t->get_ok("/api/network/$IBGE/profile")->status_is(503)->tx;
  like $tx->res->json->{error}, qr/indisponível/i, 'mensagem genérica';
};

subtest 'codigo_ibge malformado não casa a rota' => sub {
  $StubAnalytics::error = undef;
  $StubAnalytics::result = { analysis => 'network_profile' };

  $t->get_ok('/api/network/abc/profile')->status_is(404);
};

done_testing();
