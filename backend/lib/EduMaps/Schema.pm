use utf8;
package EduMaps::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-19 10:29:22
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:C+IR82cpQI//tHornfLMuA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub go {
  my $class = shift;

  my $params = do './edu_maps.conf';
  my @db_params = (
    $params->{db_params}->@*,
    $params->{db_opts},
  );
  return $class->connect(@db_params);
}

1;
