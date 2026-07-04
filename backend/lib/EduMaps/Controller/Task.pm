package EduMaps::Controller::Task;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use DateTime;

has _current_year => sub { DateTime->now->year };
has _default_poll_time => 1;

sub request_siope($self) {
  my $v = $self->validation;
  $v->required('codigo_ibge', 'trim')->like(qr/^\d{6}\z/); #codigo ibge antigo 6 digitos
  $v->optional('ano', 'trim')->in(2015 .. $self->_current_year);

  return $self->bad_req if $self->any_error;

  my $job_id = $self->get_siope(
    $v->param('codigo_ibge'),
    $v->param('ano') || $self->_current_year
  );

  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");

  $self->render(
    status => 202,
    json => {task => 'query_siope', job_id => $job_id},
  );
}

sub job_progress($self) {
  my $v = $self->validation;
  $v->required('job_id', 'trim')->num;

  return $self->bad_req if $self->any_error;

  $self->render_later;
  $self->monitor_job(
    {
      job_id => $v->param('job_id'),
      poll_time => $self->_default_poll_time,
    }
  );
}

1;
