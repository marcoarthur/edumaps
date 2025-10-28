use lib qw(./lib);
use MyApp::Schema;
use DDP;
binmode(STDOUT, ':utf8');

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
# my $random = {
#   lon => -45.186014643019405,
#   lat => -22.810618105217017,
# };
my $sch       = MyApp::Schema->go;
my $l23  = { lon => -45.06790, lat => -23.44979 };
my $cols      = {columns => [qw(escola dependencia_administrativa etapas_modalidades)]};
my $e         = $sch->resultset('Escola');

$e->search_rs( undef, $cols ) # only columns
->nearest_from($l23, 10)      # the 10-schools near $l23
->print_table;                # print results 
