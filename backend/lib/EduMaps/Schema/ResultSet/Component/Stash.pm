package EduMaps::Schema::ResultSet::Component::Stash;

use Mojo::Base "DBIx::Class::ResultSet", -strict, -signatures;
use EduMaps::Util::Context;
use Mojo::Collection qw(c);
use Class::Method::Modifiers;

has __ctx => sub { EduMaps::Util::Context->new };

around search_rs => sub ($orig, $self, @args) {
  my $rs = $orig->($self, @args);
  $rs->__ctx($self->__ctx);
  return $rs;
};

sub stash ($self, %args) {

  if (my $as = $args{as}) {
    $self->__ctx->add($as => $self);
    return $self;
  }

  if (my $get = $args{get}) {
    $get = ref $get ? $get : [$get];
    return c($self->__ctx->get(sort @$get));
  }

  die "stash(): expected 'as' or 'get'";
}

1;
