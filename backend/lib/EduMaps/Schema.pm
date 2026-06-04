package EduMaps::Schema;
use Mojo::Base 'DBIx::Class::Schema', -strict, -signatures;
use utf8;

sub go {
  my $class = shift;

  my $params = do './edu_maps.conf';
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
