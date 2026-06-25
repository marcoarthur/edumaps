package EduMaps::Controller::City;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use EduMaps::Model::City;
use List::Util qw(any all);
use DateTime;
use JSON::PP qw();

has json_handle => sub {
  state $json = JSON::PP->new->canonical->utf8(1);
};

sub details($self) {
  my $details = $self->app->model('City')->details($self->param('codigo_ibge'));
  return $self->reply->not_found unless keys %$details;

  $self->render(data => $self->_sorted_json($details), format => 'json');
}

sub schools($self) {
  my $cod = $self->param('codigo_ibge');
  my $schools = $self->app->model('City')->find_schools($cod);

  $self->render(text => $schools, format => 'json');
}

sub osm_features($self) {
  my $cod = $self->param('codigo_ibge');
  $self->render(
    data => $self->app->model('City')->osm_features($cod),
    format => 'json',
  );
}

sub payroll($self) {
  my $v = $self->validation;
  $v->optional($_)->num for qw/year month/;
  $v->required('codigo_ibge');

  my %opts = (
    month => $v->param('month') || 6, year => $v->param('year') || 2025
  );

  if ( $opts{month} < 1 or $opts{month} > 12 or $opts{year} < 0 ) {
    return $self->render(text => "Bad request", status => 400);
  }
  
  my @params = (
    $v->param('codigo_ibge'),
    DateTime->new(year => $opts{'year'}, month => $opts{'month'}, locale => 'pt'),
  );

  return $self->render(
    text => $self->app->model('City')->payroll(@params),
    format => 'json',
  );
}

sub overall_payroll($self) {
  my $model = $self->_instantiate_model(model => 'City', route_params => [qw(codigo_ibge)]);

  $self->render(
    data => $model->overall_payroll,
    format => 'json'
  );
}

sub payroll_details($self) {

  my @params = (
    $self->param('codigo_ibge'),
    DateTime->new(
      year    => $self->param('year')  || 2025,
      month   => $self->param('month') || 06,
      locale  => 'pt'
    ),
  );

  $self->render(
    text => $self->model('City')->payroll_details(@params),
    format => 'json',
  );

}

sub search_by_name($self) {
  my $model = $self->_instantiate_model(model => 'City', route_params => [qw(name)]);
  my $opts = {name => $self->param('name')};

  if (length($opts->{name}) < 4 ) {
    return $self->render(text => 'Bad request', status => 400);
  }

  $self->render(
    text => $model->search_by_name($opts),
    format => 'json',
  );
}

sub detail_by_name($self) {
  my $model = $self->_instantiate_model(model => 'City');
  my $opts = {name => $self->param('name')};

  $self->render(
    text => $model->city_details($opts),
    format => 'json',
  );
}

sub _instantiate_model($self, %args) {
  my ($model, $params) = ($self->model($args{model}), $self->req->params->to_hash);
  $params->{$_} = $self->param($_) for $args{route_params}->@*;
  $model->ctx->params({ %$params });
  return $model;
}

sub _sorted_json($self, $data) {
  $self->json_handle->encode($data);
}

sub analytic_details($self) {
  my $model = $self->_instantiate_model(
    model => 'City', route_params => [qw(codigo_ibge)]
  );

  my $results = $model->analytic_details;
  if ( $results ) {
    $self->render(json => $results);
  } else {
    $self->render(text => 'Not found', status => 404);
  }
}

1;

__END__

=head1 NAME

EduMaps::Controller::City - API de dados municipais

=head1 DESCRIPTION

Controlador para endpoints da API de cidades, fornecendo informações
geoespaciais, educacionais e demográficas de municípios brasileiros.

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
