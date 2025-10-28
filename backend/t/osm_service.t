use Mojo::Base -strict, -signatures;
use Test2::V0;
use Test2::Tools::Compare qw(T F D DF E DNE FDNE U L);
use lib qw(./lib);
use MyApp::OSM::Service;
use Mojo::JSON qw(decode_json encode_json);
use DDP;

my $json_str =<<'EOS';
{
  "type": "Polygon",
  "coordinates": [
    [
      [
        [-45.0811, -23.4439],
        [-45.0611, -23.4439],
        [-45.0611, -23.4239],
        [-45.0811, -23.4239],
        [-45.0811, -23.4439]
      ]
    ]
  ]
}
EOS

my $osm = MyApp::OSM::Service->new( polygon => decode_json($json_str) );
my $poly_str = q(poly:"-23.4439 -45.0811 -23.4439 -45.0611 -23.4239 -45.0611 -23.4239 -45.0811 -23.4439 -45.0811");

subtest create_obj => sub {
  ok $osm->isa('MyApp::OSM::Service'), 'ok type';
};

subtest templates => sub {
  $osm->_precision(4);
  my $q = $osm->_build_query_tmpl('templates/osm/query/infrastructure.opq.ep');
  ok $q, 'got a query';
  like $q, qr/nrw\[.*\]/, 'expected nrw presence in query';
  like $q, qr/\Q$poly_str\E/, 'expected polygon in query';
};

subtest run_query => sub {
  $osm->_precision(4);
  $osm->on(
    query => sub ($evt, $query) { 
      like $query, qr/\Q$poly_str\E/, 'expected poly string conversion';
    }
  );
  $osm->on(
    feature => sub ($evt, $feat) {
      is (
        $feat,
        hash {
          field geometry    => L();
          field properties  => L();
          field type        => L();
        },
        'required top‑level members are present'
      );
    }
  );

  # make it offline
  $osm->_testing(1);
  my $geojson = $osm->run_query;
  is (
    $geojson,
    hash {
      field type      => L();
      field features  => L();
    },
    'correct geojson hash'
  );
};

done_testing;
