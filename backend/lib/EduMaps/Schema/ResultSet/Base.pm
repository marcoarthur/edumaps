package EduMaps::Schema::ResultSet::Base;

use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use Role::Tiny::With;
our @APP_ROLES = map { "EduMaps::Roles::DB::$_" } 
  qw(PrettyPrint Formats SearchHelpers Scaling Stats Geo Joins Derived SQLUtils Plot Aggregates);
with @APP_ROLES;

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});
__PACKAGE__->load_components(qw{+EduMaps::Schema::ResultSet::Component::Stash});

1;
