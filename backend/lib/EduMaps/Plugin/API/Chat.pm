package EduMaps::Plugin::API::Chat;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has chat_base_path => '/api/chat';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->chat_base_path);

  $api->post('/ask')->to('chat#ask')->name('chat_ask');
  $api->get('/progress')->to('chat#progress')->name('chat_progress');
}

1;
