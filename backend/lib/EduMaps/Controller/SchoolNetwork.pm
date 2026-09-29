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

# Perfil da rede do município (issue #109, roadmap do #105): ponte síncrona
# para POST /network_profile. Mesmo tratamento de erro do perfil da escola.
sub network_profile($self) {
  my $params = {
    codigo_ibge    => $self->param('codigo_ibge'),
    tp_dependencia => $self->param('tp_dependencia'),
  };

  my $result = eval { $self->analytics->run_network_profile($params) };

  if (my $err = $@) {
    my $is_client_error = $err =~ /retornou 400/;
    my $status = $is_client_error ? 400 : 503;

    (my $msg = "$err") =~ s/^\QAnalytics:\E\s*//;
    $msg =~ s/^\Qnetwork_profile\E\s+retornou\s+\d+:\s*//;
    $msg =~ s/\s+at\s+\S+\s+line\s+\d+.*$//s;
    $msg =~ s/\s+$//;

    $self->app->log->error(
      "network_profile[$params->{codigo_ibge}]: $err"
    );

    return $self->render(
      json => {
        error => $is_client_error
          ? $msg
          : 'Perfil da rede temporariamente indisponível',
      },
      status => $status,
    );
  }

  $self->render(json => $result);
}

1;

=head1 NAME

EduMaps::Controller::SchoolNetwork - API da rede de escolas por município

=head1 DESCRIPTION

Controlador para endpoints da API da rede de escolas (SchoolNetwork), fornecendo
o resumo por tipo de administração, escolas, desempenho em exames e GeoJSON de
markers, por município.

=cut