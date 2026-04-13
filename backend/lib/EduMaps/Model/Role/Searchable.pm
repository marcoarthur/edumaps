package EduMaps::Model::Role::Searchable;

use Mojo::Base -role, -signatures;
use EduMaps::Model::Exception;

sub find_by($self, %args) {
  return $self->dbic->find( { %args } )->limit(1)->first
    or
  EduMaps::Model::Exception::raise(
    'Model::NotFound', 
    sprintf('Not found a %s using %s as args',
      caller,
      \%args,
    )
  );
}

1;
