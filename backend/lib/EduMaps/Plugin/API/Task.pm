package EduMaps::Plugin::API::Task;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has task_base_path => '/api/task';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->task_base_path);

  $api->post('/siope')->to('task#request_siope')->name('request_siope');
  $api->get('/progress')->to('task#job_progress')->name('job_progress');
}

1;
