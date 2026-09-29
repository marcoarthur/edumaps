use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Services::OSM::Query;

subtest 'around: QL com raio/ponto e filtros do perfil' => sub {
  my $q = EduMaps::Services::OSM::Query->new(
    target  => { type => 'around', lat => -23.55, lon => -46.63, raio => 500 },
    profile => 'transporte',
  );

  my $ql = $q->to_ql;
  like $ql, qr/\[out:json\]\[timeout:60\]/,                        'cabeçalho';
  like $ql, qr/nwr\["highway"="bus_stop"\]\(around:500,-23.55,-46.63\)/, 'cláusula de transporte';
  ok length $q->digest, 'digest gerado';
};

subtest 'poly: cláusula por filtro com o anel do polígono' => sub {
  my $geom = {
    type => 'Polygon',
    coordinates => [[ [-46.7, -23.6], [-46.6, -23.6], [-46.6, -23.5],
                       [-46.7, -23.5], [-46.7, -23.6] ]],
  };
  my $q = EduMaps::Services::OSM::Query->new(
    target  => { type => 'poly', geometry => $geom },
    profile => 'saude',
  );

  my $ql = $q->to_ql;
  like $ql, qr/nwr\["amenity"="hospital"\]\(poly:"-23.600000 -46.700000/, 'cláusula poly';
  unlike $ql, qr/around:/, 'sem cláusula around';
};

subtest 'raio fora de [100, 10000] morre' => sub {
  ok dies {
    EduMaps::Services::OSM::Query->new(
      target => { type => 'around', lat => 0, lon => 0, raio => 50 }, profile => 'saude');
  }, 'raio < 100';

  ok dies {
    EduMaps::Services::OSM::Query->new(
      target => { type => 'around', lat => 0, lon => 0, raio => 20_000 }, profile => 'saude');
  }, 'raio > 10000';
};

subtest 'default equipamentos_publicos agrega vários perfis' => sub {
  my $q = EduMaps::Services::OSM::Query->new(
    target => { type => 'around', lat => 0, lon => 0, raio => 300 });

  my %keys = map { $_->{key} => 1 } @{ $q->expanded_filters };
  ok $keys{amenity} && $keys{leisure} && $keys{railway} && $keys{office},
    'cobre amenity/leisure/railway/office';
};

subtest 'digest estável e sensível ao raio' => sub {
  my %base = (
    target  => { type => 'around', lat => -23, lon => -46, raio => 300 },
    profile => 'saude',
  );

  my $a = EduMaps::Services::OSM::Query->new(%base)->digest;
  my $b = EduMaps::Services::OSM::Query->new(%base)->digest;
  is $a, $b, 'mesma query => mesmo digest';

  my $c = EduMaps::Services::OSM::Query->new(
    target => { type => 'around', lat => -23, lon => -46, raio => 600 },
    profile => 'saude',
  )->digest;
  isnt $a, $c, 'raio diferente => digest diferente';
};

subtest 'classify mapeia tags para (key, value, category)' => sub {
  my $q = EduMaps::Services::OSM::Query->new(
    target => { type => 'around', lat => 0, lon => 0, raio => 300 },
    profile => 'transporte',
  );

  is [ $q->classify({ highway => 'bus_stop', name => 'X' }) ],
    ['highway', 'bus_stop', 'highway=bus_stop'], 'bus_stop';
  is [ $q->classify({ name => 'X' }) ], [ undef, undef, undef ], 'sem match';
};

done_testing;
