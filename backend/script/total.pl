use lib qw(./lib);
use MyApp::Schema;
use DDP;

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
my $sch = MyApp::Schema->go;
my $m = $sch->resultset('MunicipiosSp');
my $type = { 'escolas.categoria_administrativa' => { -like => 'P%blica' } }; 
$m->search_rs(
  undef,
  {
    columns => ['nm_mun', { total_escolas => {count => 'escolas'}}],
    join => 'escolas',
    group_by => 'fid',
    rows => 3,
  }
)->print_table;
