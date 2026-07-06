package EduMaps::Controller::School;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;

has default_distance => 10;
has default_limit => 10;

sub _not_found_msg($self, $params) {
  my $params_str;
  if ( keys $params_str->%* ) {
    my $params_str = join(
      "\n",
      map { sprintf(qq/%s => %s/, $_, $params->{$_}) } keys $params->%* 
    );
    return "Escola não encontrada com os parametros:\n" . $params_str;
  } else {
    return "Não encontrado";
  }
}

sub info($self){
  my $v = $self->validation;
  my $model = $self->instantiate_model(model => 'School');
  my $params = {codigo_inep => $self->param('cod_inep')};
  my $result = $model->info($params);
  unless($result) {
    return $self->render(
      json => { error => $self->_not_found_msg($params) }, status => 404
    );
  }

  $self->render(json => $result);
};

sub payroll($self){
  ...
};

sub grades($self){
  ...
};

sub full_grades($self){
  ...
}

sub professionals($self){
  ...
}

sub search_all($self){
  ...
}

sub search($self) {
  my $v = $self->validation;

  $v->optional($_, 'trim')->like(qr/.{3,100}/) for qw/escola municipio/;
  $v->optional('limit', 'trim')->num(1,500);

  return $self->bad_req if $self->any_error;

  my $params = {};
  for (qw/escola municipio/) {
    $params->{$_} = $v->param($_) if $v->param($_);
  }

  my $model  = $self->instantiate_model(model => 'School');
  $params->{limit} = $v->param('limit') || $model->default_limit;

  my $result = $model->search($params);
  unless($result || $result->size == 0) {
    return $self->render(
      json => { error => $self->_not_found_msg($params) }, status => 404
    );
  }

  $self->render(json => $result->to_array);
}

sub search_nearby($self){
  my $v = $self->validation;
  $v->optional('dist')->num;
  $v->required('lon', 'trim')->is_longitude;
  $v->required('lat', 'trim')->is_latitude;

  my $params = {
    latitude => $self->param('lat'),
    longitude => $self->param('lon'),
    distance => $self->param('dist') || $self->default_distance
  };

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'School');
  my $result = $model->search_nearby($params);
  unless($result || $result->size == 0) {
    return $self->render(
      json => { error => $self->_not_found_msg($params) }, status => 404
    );
  }

  $self->render(json => $result->to_array);
}

sub cluster_schools($self, $params = {}) {
  my $v = $self->validation;
  $v->required('codigo_ibge', 'trim')->is_ibge_code;
  return $self->bad_req if $self->any_error;

  $params->{codigo_ibge} = $v->param('codigo_ibge');

  my $model = $self->instantiate_model(model => 'School');
  my $result = $model->simple_cluster_school($params);
  unless($result) {
    return $self->render(
      json => { error => $self->_not_found_msg($params) }, status => 404
    );
  }

  $self->render(json => $result->to_array);
}

sub cover($self){
  ...
}

sub scores($self){
  ...
}

1;

=head1 NAME

EduMaps::Controller::School - API de dados das escolas

=head1 DESCRIPTION

Controlador para endpoints da API das escolas brasileiras, fornecendo informações
geoespaciais, educacionais, incluindo docencias e matrículas fornecidas pelo Censo
Escolar para todo o Brasil.

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
