package EduMaps::Controller::SchoolNetwork;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;

has default_limit => 100;

sub summary($self) {
  my $result = $self->instantiate_model(model => 'SchoolNetwork')
  ->summary({ codigo_ibge => $self->param('codigo_ibge') });

  return $self->render(
    json => { error => "Dados não encontrados para o município: ${\$self->param('codigo_ibge')}" },
    status => 404,
  ) unless $result->@*;

  $self->render(json => $result);
}

sub schools($self) {
  my $v = $self->validation;
  $v->optional('rede', 'trim')->in(qw(federal estadual municipal privada));
  $v->optional('limit', 'trim')->num(1, 500);
  return $self->bad_req if $self->any_error;

  my $params = {
    codigo_ibge => $self->param('codigo_ibge'),
    rede => $self->param('rede'),
    limit => $self->param('limit') // $self->default_limit,
  };

  my $result = $self->instantiate_model(model => 'SchoolNetwork')->schools($params);

  return $self->render(
    json => { error => "Dados não encontrados para o município: $params->{codigo_ibge}" },
    status => 404,
  ) unless $result->@*;

  $self->render(json => $result);
}

sub performance($self) {
  my $v = $self->validation;
  $v->optional('rede', 'trim')->in(qw(federal estadual municipal privada));
  $v->optional('etapa', 'trim')->in(qw(fundamental_i fundamental_ii ensino_medio));
  $v->optional('desde', 'trim')->num(2000, 2030);
  $v->optional('ate', 'trim')->num(2000, 2030);
  return $self->bad_req if $self->any_error;

  my $params = {
    codigo_ibge => $self->param('codigo_ibge'),
    rede => $self->param('rede'),
    etapa => $self->param('etapa'),
    desde => $self->param('desde'),
    ate => $self->param('ate'),
  };

  my $result = $self->instantiate_model(model => 'SchoolNetwork')->performance($params);

  return $self->render(
    json => { error => "Dados não encontrados para o município: $params->{codigo_ibge}" },
    status => 404,
  ) unless $result->@*;

  $self->render(json => $result);
}

sub markers($self) {
  my $v = $self->validation;
  $v->optional('rede', 'trim')->in(qw(federal estadual municipal privada));
  return $self->bad_req if $self->any_error;

  my $params = {
    codigo_ibge => $self->param('codigo_ibge'),
    rede => $self->param('rede'),
  };

  my $result = $self->instantiate_model(model => 'SchoolNetwork')->markers($params);
  return $self->render(json => { type => 'FeatureCollection', features => [] })
  if $result =~ /"features":\[\]/;

  $self->render(text => $result, format => 'json');
}

1;

=head1 NAME

EduMaps::Controller::SchoolNetwork - API da rede de escolas por município

=head1 DESCRIPTION

Controlador para endpoints da API da rede de escolas (SchoolNetwork), fornecendo
o resumo por tipo de administração, escolas, desempenho em exames e GeoJSON de
markers, por município.

=cut