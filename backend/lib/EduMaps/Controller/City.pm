package EduMaps::Controller::City;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use DateTime;

has default_date => sub { DateTime->new( month => 6, year => 2025 ) };
has min_search_len => 4;
has default_limit => 10;

sub details($self) {
  my $model = $self->instantiate_model(model => 'City');
  my $details = $model->details($self->param('codigo_ibge'));
  return $self->reply->not_found unless keys %$details;

  $self->render(json => $details);
}

sub schools($self) {
  my $cod = $self->param('codigo_ibge');
  my $model = $self->instantiate_model(model => 'City');
  my $schools = $self->instantiate_model(model => 'City')->find_schools($cod);

  return $self->reply->not_found unless $schools;
  $self->render(text => $schools, format => 'json');
}

sub osm_features($self) {
  my $cod = $self->param('codigo_ibge');
  my $model = $self->instantiate_model(model => 'City'); 

  $self->render(
    text => $model->osm_features($cod),
    format => 'json',
  );
}

sub payroll($self) {
  my $v = $self->validation;
  $v->optional('month')->like(qr/^\d+$/);
  $v->optional('year')->like(qr/^\d+$/);

  return $self->bad_req if $self->any_error;

  my $date = eval {
    DateTime->new( 
      year    => $v->param('year') // $self->default_date->year,
      month   => $v->param('month') // $self->default_date->month,
      locale  => 'pt',
    );
  };
  return $self->bad_req if $@;

  my $model = $self->instantiate_model(model => 'City');
  my $result = $model->payroll($v->param('codigo_ibge'), $date);
  $self->render(text => $result, format => 'json');
}

sub overall_payroll($self) {
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(codigo_ibge)]);

  $self->render(
    text => $model->overall_payroll,
    format => 'json'
  );
}

sub payroll_details($self) {

  my $model = $self->instantiate_model(model => 'City');
  my $v = $self->validation;
  $v->optional('month')->like(qr/^\d+$/);
  $v->optional('year')->like(qr/^\d+$/);

  return $self->bad_req if $self->any_error;

  my $date = eval {
    DateTime->new( 
      year    => $v->param('year') // $self->default_date->year,
      month   => $v->param('month') // $self->default_date->month,
      locale  => 'pt',
    );
  };
  return $self->bad_req if $@;

  $self->render(
    text => $model->payroll_details($self->param('codigo_ibge'), $date),
    format => 'json',
  );

}

sub search_by_name($self) {
  my $model = $self->instantiate_model(model => 'City', route_params => [qw(name)]);
  my $opts = {name => $self->param('name')};

  if (length($opts->{name}) < $self->min_search_len ) {
    return $self->bad_req('name have to be greater than ' . $self->min_search_len);
  }

  $self->render(
    text => $model->search_by_name($opts),
    format => 'json',
  );
}

sub detail_by_name($self) {
  my $model = $self->instantiate_model(model => 'City');
  my $opts = {name => $self->param('name')};

  if (length($opts->{name}) < $self->min_search_len ) {
    return $self->bad_req('name have to be greater than ' . $self->min_search_len);
  }

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

sub search_analytic($self) {
  my $v = $self->validation;
  $v->required('term','not_empty')->like(qr/^[\w\s]+$/);
  $v->optional('limit')->num;

  return $self->bad_req if $self->any_error;

  my $model = $self->instantiate_model(model => 'City');
  my $result = $model->search_analytic(
    {
      term => $self->param('term'),
      limit => $self->param('limit') || $self->default_limit
    }
  );

  $self->render(text => $result, format => 'json');
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
