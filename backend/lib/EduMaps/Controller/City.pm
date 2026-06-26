package EduMaps::Controller::City;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use EduMaps::Model::City;
use List::Util qw(any all);
use DateTime;

sub details($self) {
  my $details = $self->app->model('City')->details($self->param('codigo_ibge'));
  return $self->reply->not_found unless keys %$details;

  $self->render(data => $self->sorted_json($details), format => 'json');
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
  my %opts = (
    month => $self->param('month') || 6, year => $self->param('year') || 2025
  );

  if ( $opts{month} < 1 or $opts{month} > 12 or $opts{year} < 0 or any { m/[^0-9]/ } values %opts ) {
    return $self->render(text => "Bad request", status => 400);
  }
  
  my @params = (
    $self->param('codigo_ibge'),
    DateTime->new(year => $opts{'year'}, month => $opts{'month'}, locale => 'pt'),
  );

  return $self->render(
    text => $self->app->model('City')->payroll(@params),
    format => 'json',
  );
}

sub overall_payroll($self) {
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(codigo_ibge)]);

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
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(name)]);
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
  my $model = $self->instantiate_model(model => 'City');
  my $opts = {name => $self->param('name')};

  $self->render(
    text => $model->city_details($opts),
    format => 'json',
  );
}

sub analytic_details($self) {
  my $model = $self->instantiate_model(
    model => 'City', route_params => [qw(codigo_ibge)]
  );

  my $results = $model->analytic_details;
  if ( $results ) {
    $self->render(json => $results);
  } else {
    $self->render(text => 'Not found', status => 404);
  }
}

sub search_for_complete($self) {
  my $model = $self->instantiate_model(model => 'City');

  $self->render(
    data => $model->search_for_complete, format => 'json'
  );
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
