use lib qw(./lib);
use MyApp::Schema;
use DDP;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
my $sch = MyApp::Schema->go;
my $m = $sch->resultset('MunicipiosSp');
my $name = 'sao jose dos campos';
my $params = \[ qq{unaccent(nm_mun) ILIKE unaccent('%$name%')}];
$m->search_rs($params)->feat_collection->print_table
