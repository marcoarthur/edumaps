use Mojo::Base -strict, -signatures;
use Test2::V0;
use lib qw(./lib);
use EduMaps::Task::OSM::Query;
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use Digest::SHA qw(sha1_hex);
use Test::Mojo;
use DDP;

our $ONLINE = $ENV{OSM_ONLINE} // 0;

# Mojolicious::Plugin::Config
my $conf = Test::Mojo->new('EduMaps')->app->config;
my $q = EduMaps::Task::OSM::Query->new(
  municipio => 3555406,
  config => $conf,
);
my ($db_data, $osm_data);

subtest data_base => sub {
  is ref $q, 'EduMaps::Task::OSM::Query', 'correct object';
  $db_data   = $q->from_db;
  is (
    $db_data,
    hash {
      field features    => L();
      field type        => L();
    },
    'right geojson structure'
  );
  # O banco pode já ter os dados do município (t/05-tasks/osm.t com rede os
  # grava): o retorno tem de bater com as feições salvas para a consulta.
  my $salvas = $q->_sch->resultset('OsmQuery')
    ->search_rs({ digest => sha1_hex($q->_service->query) })
    ->search_related('osm_landuses', {})->count;
  is scalar $db_data->{features}->@*, $salvas,
    sprintf("features do banco para o municipio %s (%d salvas)", $q->municipio, $salvas);
};

subtest online => sub {
  skip_all "Set OSM_ONLINE env var for testing OSM" unless $ONLINE;
  my $osm_q = MyApp::OSM::Query->new(
    municipio => 3555406,
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
