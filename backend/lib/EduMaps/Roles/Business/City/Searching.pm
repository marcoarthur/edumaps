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

  # A sigla desempata homônimos no autocompletar ("Vitória · ES"); o nome do
  # estado fica de reserva para linha sem sigla.
  my $cols  = ['codigo_ibge', 'nome', {uf => \'COALESCE(sigla_estado, nome_estado)'}];
  my $limit = $params->{limit} // 50;
  delete $params->{limit};

  my $expr = q{contrib.unaccent(nome_municipio) ILIKE contrib.unaccent(?)};
  my $search = \[$expr, $self->_wrap_percent($params->{nome_municipio})];

  # Nome igual ao digitado primeiro, depois o que começa com o texto (#431):
  # "Vitória" sugere Vitória (ES) antes de Porto Vitória e Santa Vitória.
  my $termo = $params->{nome_municipio} =~ s/[%']//gr;
  my $ordem = \[
    q{CASE WHEN lower(contrib.unaccent(nome_municipio)) = lower(contrib.unaccent(?)) THEN 0
           WHEN contrib.unaccent(nome_municipio) ILIKE contrib.unaccent(?) THEN 1
           ELSE 2 END},
    $termo, "$termo%"
  ];

  my $results = $rs->search_rs($search)->limit($limit)->columns($cols)
  ->order_by([$ordem, 'nome_municipio'])->as_hash->get_all;

  return $results->to_array;
}

1;
