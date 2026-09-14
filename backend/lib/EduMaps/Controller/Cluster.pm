package EduMaps::Controller::Cluster;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;

sub schools($self) {
  my $v = $self->validation;
  $v->optional('codigo_regiao', 'trim')->num(1, 5);
  $v->optional('codigo_uf',     'trim')->like(qr/^\d{2}$/);
  $v->optional('codigo_ibge',   'trim')->like(qr/^\d{7}$/);
  return $self->bad_req if $self->any_error;

  my $params = {
    codigo_regiao => $self->param('codigo_regiao'),
    codigo_uf     => $self->param('codigo_uf'),
    codigo_ibge   => $self->param('codigo_ibge'),
  };

  my $result = $self->instantiate_model(model => 'Cluster')->clustered_schools($params);

  return $self->render(
    json => { error => "Nenhuma escola com cluster gerado para o recorte informado." },
    status => 404,
  ) unless $result;

  $self->render(text => $result, format => 'json');
}

sub regions($self) {
  my $result = $self->instantiate_model(model => 'Cluster')->regions;
  return $self->render(json => { error => 'Sem regiões disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub ufs($self) {
  my $v = $self->validation;
  $v->optional('codigo_regiao', 'trim')->num(1, 5);
  return $self->bad_req if $self->any_error;

  my $result = $self->instantiate_model(model => 'Cluster')->ufs({
    codigo_regiao => $self->param('codigo_regiao'),
  });
  return $self->render(json => { error => 'Sem UFs disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

sub municipalities($self) {
  my $v = $self->validation;
  $v->optional('codigo_uf', 'trim')->like(qr/^\d{2}$/);
  return $self->bad_req if $self->any_error;

  my $result = $self->instantiate_model(model => 'Cluster')->municipalities({
    codigo_uf => $self->param('codigo_uf'),
  });
  return $self->render(json => { error => 'Sem municípios disponíveis' }, status => 404) unless $result->@*;
  $self->render(json => $result);
}

1;