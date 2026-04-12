package EduMaps::Model::Role::Contextable;
use Mojo::Base -role, -signatures;
use EduMaps::Model::Exception;
use EduMaps::Util::ContextFluent;
use List::Util qw(first all);
use DDP;

has ctx => sub { EduMaps::Util::ContextFluent->new };

sub set_params_map($self, %args) {
  for my $key (keys $args{map}->%*) {
    my $mapping = $args{map}{$key};
    my $size = @$mapping;

    # case 1: simple map : bd_param => [@app_params]
    if ( ! ref $mapping->[0] ) {
      $self->_assign_from($args{params}, $key, $args{map}{$key}->@*);
    } 
    # case 2: map + transformation bd_param => [ [@app_params], $call_back ]
    elsif( $size == 2  &&
      ref $mapping->[0] eq 'ARRAY' &&
      ref $mapping->[1] eq 'CODE' ) 
    {
      my $source_keys = $mapping->[0];
      my $callback = $mapping->[1];

      my @values = $self->_fetch_values($args{params}, $source_keys->@*);

      if ( @values == @$source_keys && all { defined } @values ) {
        my $transformed = $callback->(@values);
        $args{params}{$key} = $transformed if defined $transformed;
      }
    }
  }
}

sub _fetch_values($self, $hash, @source_keys) {
  my @values;
  for my $source_key (@source_keys) {
    my $found_key = first {
      defined $hash->{$source_key} || defined $self->ctx->params->{$_}
    } (ref $source_key ? @$source_key : ($source_key));

    if (ref $source_key eq 'ARRAY') {
      my $val;
      for my $sk (@$source_key) {
        $val = $hash->{$sk} // $self->ctx->params->{$sk};
        last if defined $val;
      }
      push @values, $val;
    } else {
      my $val = $hash->{$found_key} // $self->ctx->params->{$found_key};
      push @values, $val;
    }
  }
  return @values;
}

sub _assign_from ($self, $hash, $key, @source_keys) {
  my $found_key = first { 
    defined $hash->{$_} ||
    defined $self->ctx->params->{$_}
  } @source_keys;

  if ( defined $found_key ) {
    my $val = $hash->{$found_key} // $self->ctx->params->{$found_key};
    $hash->{$key} = $val;
  }
}

1;
