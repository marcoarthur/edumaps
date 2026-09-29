use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Services::OSM;
use EduMaps::Services::OSM::Query;

# Teste ONLINE (opt-in): faz UMA chamada mínima ao Overpass para não
# sobrecarregar o serviço/bloquear IP durante o desenvolvimento.
my $ONLINE = $ENV{OSM_ONLINE} // 0;
skip_all 'Set OSM_ONLINE=1 para testar contra o Overpass' unless $ONLINE;

my $q = EduMaps::Services::OSM::Query->new(
  target  => { type => 'around', lat => -23.5615, lon => -46.6560, raio => 300 },
  profile => 'transporte',
  timeout => 30,
);

my $svc = EduMaps::Services::OSM->new(query => $q);
my $gj  = $svc->run;

is $gj->{type}, 'FeatureCollection', 'geojson FeatureCollection';
ok ref($gj->{features}) eq 'ARRAY', 'features é array';
ok $svc->elapsed > 0, 'tempo da requisição medido';

done_testing;
