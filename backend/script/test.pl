use lib qw(./lib);
use MyApp::Schema;
use DDP;
binmode STDOUT, ":encoding(UTF-8)";

BEGIN {
  $ENV{DBIC_TRACE_PROFILE} = 'console';
  $ENV{DBIC_TRACE} = 1;
}
my $sch = MyApp::Schema->go;
my $e = $sch->resultset('Escola');
print $e->search_rs(
  { codigo_inep => '35011198' }, 
  {
    join => 'municipio',
    columns => [qw(municipio endereco escola)]
  }
)->with_geojson->to_yaml;
# zotero://note/u/3PCTKTKC/?line=2
# my $m = $sch->resultset('MunicipiosSp');
# my $rs = $m->search_rs(
#   { nm_mun => { -like => 'Ubatuba' } },
#   { 
#     join => 'escolas',
#     columns => [ qw( fid nm_mun escolas.escola )],
#   }
# )->print_table;
