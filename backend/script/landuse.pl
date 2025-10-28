use Mojo::Base -strict, -signatures;
use lib qw(./lib);
use MyApp::Schema;
use DDP;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
my $sch = MyApp::Schema->go;
my $city = $sch->resultset('MunicipiosSp')->search_rs( {nm_mun => {-ilike => 'paraibuna'} } )->get_column('fid');
my $land = $sch->resultset('OsmLanduse')->search_rs({ municipio_id => { '=' => $city->as_query }})
->feat_collection->first;

say $land->get_column('feature');
