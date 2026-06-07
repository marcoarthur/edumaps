package Utils;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Exporter 'import';

our @EXPORT_OK = qw(filter_resultsets c);
our $sch = EduMaps::Schema->go;

sub filter_resultsets($filter_cb) {
  c($sch->sources)->map( sub { $sch->resultset($_ ) } )->grep( $filter_cb );
}

1;
