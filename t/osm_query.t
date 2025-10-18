use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use MyApp::OSM::Query;
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use DDP;

our $ONLINE = $ENV{OSM_ONLINE} // 0;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}

my $conf = do './map_app.conf';
my $q = MyApp::OSM::Query->new(
  municipio => 113,
  config => $conf,
);
my ($db_data, $osm_data);

subtest data_base => sub {
  is ref $q, 'MyApp::OSM::Query', 'correct object';
  $db_data   = $q->from_db;
  is (
    $db_data,
    hash {
      field features    => L();
      field type        => L();
    },
    'right geojson structure'
  );
  is $db_data->{features}->@*, 
  30,
  sprintf ("right number of features for municipio %s", $q->municipio);
};

subtest online => sub {
  skip_all "Set OSM_ONLINE env var for testing OSM" unless $ONLINE;
  my $osm_q = MyApp::OSM::Query->new(
    municipio => 113,
    config => $conf
  );

  $osm_data = $osm_q->from_osm;
  is (
    $osm_data,
    hash {
      field features    => L();
      field type        => L();
    },
    'right geojson structure'
  );
  is $db_data->{features}->@*, $osm_data->{features}->@*, 'same features';
};

done_testing;
