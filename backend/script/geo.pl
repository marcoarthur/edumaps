use lib qw(./lib);
use MyApp::Schema;
use DDP;

my $sch = MyApp::Schema->go;
my $m = $sch->resultset('MunicipiosSp');
my $rs = $m->search_rs(
  { nm_mun => { -like => 'Ubatuba' } },
)
->with_geojson
->as_subselect_rs;

$rs->search_rs(
  undef,
  { columns => [ qw(nm_mun geojson)] }
)->print_table;
