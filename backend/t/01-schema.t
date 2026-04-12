use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;

subtest 'instantiate and validate schema' => sub {
  my $sch = EduMaps::Schema->go;
  is (
    ref($sch), 
    'EduMaps::Schema', 
    'Schema conneceted to DB'
  );

  can_ok( $sch, qw/connect go/ );

};

done_testing;
