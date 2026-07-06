package EduMaps::Schema;
use Mojo::Base 'DBIx::Class::Schema', -strict, -signatures;
use Role::Tiny::With;
use utf8;

with qw/EduMaps::Roles::DB::InjectRelation/;

sub go {
  my $class = shift;

  my $conf_file = $ENV{EDUMAPS_CONF} || './edu_maps.conf';
  die "$conf_file not found configuration file" unless -f $conf_file;
  my $params = do $conf_file;
  my @db_params = (
    $params->{db_params}->@*,
    $params->{db_opts},
  );
  return $class->connect(@db_params);
}

__PACKAGE__->load_namespaces(
  result_namespace => [qw(Result Result::View)],
  resultset_namespace => [qw(ResultSet)],
);

1;
