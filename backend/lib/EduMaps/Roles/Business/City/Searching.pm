package EduMaps::Roles::Business::City::Searching;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

requires qw(schema);

sub suggests($self, $params = {}) {
  my $v = $self->validation;
  my $rs = $self->schema->resultset('MunicipiosSp');
  $v->input($params);

  $v->required($_, 'trim')->like(qr/.{3,100}/) for qw/nome_municipio/;
  $v->optional('limit', 'trim')->num(1,50);

  croak "Erro dos parametros" if $v->has_error;

  my $cols  = ['codigo_ibge', 'nome', {uf => 'nome_estado'}];
  my $limit = $params->{limit} // 50;
  delete $params->{limit};

  $params->{nome_municipio} = {-ilike => "%$params->{nome_municipio}%"};

  my $results = $rs->search_rs($params)->limit($limit)->columns($cols)
  ->order_by(['nome_municipio'])->as_hash->get_all;

  return $results->to_array;
}

1;
