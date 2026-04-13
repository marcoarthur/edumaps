package EduMaps::Util::Context;

use Mojo::Base -base, -signatures;

has stash => sub { +{} };

sub add ($self, $name, $rs) {
  $self->stash->{$name} = $rs;
}

sub get ($self, @names) {
  return @{$self->stash}{@names};
}

1;
