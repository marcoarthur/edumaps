package EduMaps::Plugin::API::Chat;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has chat_base_path => '/api/chat';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->chat_base_path);

  # Ask + progress (existentes)
  $api->post('/ask')->to('chat#ask')->name('chat_ask');
  $api->get('/progress')->to('chat#progress')->name('chat_progress');

  # Conversas (novo) — exigem gestor logado
  my $auth = $api->under->to('pesquisa#_require_gestor');
  $auth->post('/conversas')->to('chat#save_conversa')->name('chat_save_conversa');
  $auth->get('/conversas')->to('chat#list_conversas')->name('chat_list_conversas');
  $auth->get('/conversas/calendar')->to('chat#calendar_conversas')->name('chat_calendar_conversas');
  $auth->get('/conversas/search')->to('chat#search_conversas')->name('chat_search_conversas');
  $auth->get('/conversas/export')->to('chat#export_conversas')->name('chat_export_conversas');
  $auth->get('/conversas/:id')->to('chat#show_conversa')->name('chat_show_conversa');
  $auth->delete('/conversas/:id')->to('chat#delete_conversa')->name('chat_delete_conversa');
}

1;
