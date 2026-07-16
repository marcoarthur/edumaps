package EduMaps::Model::Base;

use Mojo::Base "Mojo::EventEmitter", -signatures;
use Carp qw/croak/;
use Mojo::Log;
use Role::Tiny::With;
use Scalar::Util qw( looks_like_number );
use JSON::XS;
use Mojolicious::Validator;
with map { 'EduMaps::Model::Role::' . $_ } qw/Contextable/;

has schema => sub { 
  state $sch = EduMaps::Schema->go || croak 'requires a DBIx::Class::Schema';
};
has rs     => sub { croak 'requires a ResultSet' };
has log    => sub { Mojo::Log->new };
has json   => sub { JSON::XS->new->canonical->utf8 };
has [qw/validator v/] => sub { Mojolicious::Validator->new };

sub dbic($self) { return $self->schema->resultset($self->rs); }
sub validation($self) { return $self->validator->validation; }

sub resolve_bindings ($self, $sql, $params){
  # Encontrar todos os placeholders nomeados na query
  my @placeholders;
  my $sql_with_placeholders = $sql;

  # Substituir :param por ? e registrar a ordem
  $sql_with_placeholders =~ s/:([a-zA-Z_][a-zA-Z0-9_]*)/push @placeholders, $1; '?'/ge;

  # Criar array de valores na ordem correta
  my @bind_values;
  foreach my $placeholder (@placeholders) {
    if (exists $params->{$placeholder}) {
      push @bind_values, $params->{$placeholder};
    }
    elsif (exists $params->{":$placeholder"}) {
      push @bind_values, $params->{":$placeholder"};
    }
    else {
      croak "Parâmetro não encontrado: :$placeholder";
    }
  }

  return {
    sql => $sql_with_placeholders,
    bind_values => \@bind_values,
    placeholders => \@placeholders,
  };
}

sub _format_float_nums($self, $hash) {
  while( my ($key, $val) = each %$hash ) {
    my $ref = ref $val;
    $self->_format_float_nums($val) if $ref && $ref eq 'HASH';
    next unless looks_like_number($val);
    next if $val == int($val);
    $hash->{$key} = sprintf "%.2f", $val;
  }
}

1;
