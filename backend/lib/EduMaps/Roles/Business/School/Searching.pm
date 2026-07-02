package EduMaps::Roles::Business::School::Searching;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

requires qw(schema default_limit);

sub search($self, $params = {}) {
  my $v = $self->validation;
  $v->input($params);
  $v->optional($_, 'trim')->like(qr/.{3,100}/) for qw/escola municipio/;
  $v->optional('limit', 'trim')->num(1,500);

  croak "Erro dos parametros" if $v->has_error;
  # wrap db operator and metachar
  my $clean = {};
  for (qw/escola municipio/) {
    if (my $value = $v->param($_)) {
      $clean->{$_} = { -ilike => "%$value%" };
    }
  }
  
  croak "Sem parâmetros válidos" if scalar(keys $params->%*) == 0;

  my $rs = $self->schema->resultset('Escolas');
  my $results = $rs->search_rs($clean)
  ->limit($v->param('limit') || $self->default_limit)
  ->columns($self->default_columns)
  ->as_hash->get_all;

  return $results;
}

1;
