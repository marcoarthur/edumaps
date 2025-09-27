use utf8;
package MyApp::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-09-26 08:23:08
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ac61dVf0XAlX1wQ5d8SfxQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
sub go {
  my $class = shift;
  my $db_opts = 
  {
    RaiseError          => 1,
    PrintError          => 0,
    AutoCommit          => 1,

    # PostgreSQL-specific optimizations
    pg_server_prepare   => 1,          # ✅ Significant performance boost
    pg_enable_utf8      => 1,          # ✅ Essential for Unicode
    pg_bytea            => 'escape',   # Binary data handling

    # Debugging and development
    ShowErrorStatement  => 1,          # See failing SQL in errors
    TraceLevel          => 0,          # Set to 1-4 for debugging

    # Connection management
    pg_connect_timeout  => 10,
    pg_keepalive        => 1,          # Enable TCP keepalive

    # Application identification
    pg_appname          => 'map_app',  # Shows in pg_stat_activity
  };

  my @db_params = (
    'dbi:Pg:dbname=gisdb;host=ubatexu.lan',
    'devel',
    'senhaboa123',
    $db_opts,
  );
  return $class->connect(@db_params);
}

1;
