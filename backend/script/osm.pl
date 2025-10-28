use lib qw(./lib);
use MyApp::Schema;
use Mojo::File;
use Mojo::JSON qw(decode_json);
use DDP;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
my $sch = MyApp::Schema->go;

sub mun {
  my $m = $sch->resultset('MunicipiosSp');
  my $cols = [
    qw(nm_mun fid),
    {props => 'osm_landuses.properties'},
    {geojson => {ST_AsGeoJSON => 'geom'} },
  ];
  my @params = ( 
    { fid => 406 }, 
    { 
      columns => $cols,
      join => 'osm_landuses',
    } 
  );
  $m->search_rs(@params)->print_table
}

my $land = $sch->resultset('OsmLanduse')
->search_rs( { municipio_id => '592' })
->feat_collection->get_column('feature')->first;

$land = decode_json($land);
p $land;
#Mojo::File->new('uba.geojson')->spew($land);
