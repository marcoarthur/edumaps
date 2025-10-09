use v5.38;
use Test2::V0;
use lib qw(./lib);
use MyApp::OSM::Query;
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use DDP;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}

my @ids = (406, 409, 592);
foreach my $id (@ids) {
  my $osm = MyApp::OSM::Query->new( municipio => $id );

  is ref $osm, 'MyApp::OSM::Query', 'correct object';

  $osm->run_query;
  $osm->to_geojson;
}

done_testing;
