use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Services::OSM;
use EduMaps::Services::OSM::Query;

my $q = EduMaps::Services::OSM::Query->new(
  target  => { type => 'around', lat => -23.5, lon => -46.6, raio => 800 },
  profile => 'equipamentos_publicos',
);

subtest 'parse offline da fixture mista (node/way/relation)' => sub {
  my $svc = EduMaps::Services::OSM->new(
    query   => $q,
    offline => 1,
    fixture => 't/fixtures/osm/mixed.json',
  );

  my (@features, @queries);
  $svc->on(feature => sub { push @features, $_[1] });
  $svc->on(query   => sub { push @queries, $_[1] });

  my $gj = $svc->run;

  is $gj->{type}, 'FeatureCollection', 'é FeatureCollection';
  my %by = map { $_->{geometry}{type} => 1 } @features;
  ok $by{Point},       'Point (biblioteca)';
  ok $by{Polygon},     'Polygon (escola)';
  ok $by{LineString},  'LineString (via)';
  ok $by{MultiPolygon},'MultiPolygon (praça)';

  my @points = grep { $_->{geometry}{type} eq 'Point' } @features;
  is scalar(@points), 1, 'só o nó COM tags vira Point (skel é ignorado)';
  is $points[0]{properties}{osm_type}, 'node', 'osm_type preenchido';

  ok scalar(@queries), 'evento query emitido';
};

subtest 'parse usa o raw do Overpass já decodificado' => sub {
  my $svc = EduMaps::Services::OSM->new(query => $q);
  my $gj = $svc->parse({
    elements => [
      { type => 'node', id => 10, lat => -23, lon => -46,
        tags => { amenity => 'hospital' } },
    ],
  });

  is scalar(@{ $gj->{features} }), 1, 'uma feature';
  is $gj->{features}[0]{geometry}{type}, 'Point', 'Point';
  is $gj->{features}[0]{properties}{amenity}, 'hospital', 'tag preservada';
};

done_testing;
