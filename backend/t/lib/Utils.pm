package Utils;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Exporter 'import';

our @EXPORT_OK = qw(filter_resultsets c random_schools_ids random_schools_with_grades random_city_id);
our $sch = EduMaps::Schema->go;

sub filter_resultsets($filter_cb) {
  c($sch->sources)->map( sub { $sch->resultset($_ ) } )->grep( $filter_cb );
}

sub random_schools_ids ($size = 10){
  $sch->resultset('CensoEscolas')
  ->columns(['co_entidade'])->random_sample($size)->get_all;
}

sub random_schools_with_grades ($size = 10){
  $sch->resultset('IdebNotasEscolas')->columns(['id_escola'])
  ->random_sample($size)->get_all;
}

sub random_city_id ($size = 10) {
  $sch->resultset('MunicipiosSp')->random_sample($size)
  ->columns(['codigo_ibge', 'nome_municipio'])
  ->get_all;
}

1;
