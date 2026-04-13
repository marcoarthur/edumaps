package EduMaps::Util::ContextFluent;

use Mojo::Base -base, -signatures;
use DDP;
our $AUTOLOAD;

sub new ($class, @args) {
  my $self = $class->SUPER::new;
  if (ref $args[0] eq 'HASH') {
    $self->$_($args[0]{$_}) for keys %{$args[0]};
  }
  return $self;
}

sub AUTOLOAD ($self, @args) {
  my ($meth) = ($AUTOLOAD =~ /.*::(\w+)$/);
  warn "Retrieving unknow $meth, Not a setting $meth" unless @args;
  if ( ref $args[0] ) {
    $self->attr( $meth => sub { $args[0] } )
  } else {
    $self->attr($meth => $args[0]);
  }
  # void calling just to appears in internals of DDP::p(): why is this ??? We don't know
  $self->$meth;
  $self;
}

1;
