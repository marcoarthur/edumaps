package EduMaps::Plugin::API::Chat;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

has chat_base_path => '/api/chat';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->chat_base_path);

  # Todas as rotas exigem gestor logado (#224): o Assistente consome a cota
  # do LLM pago e o escopo da pergunta vem da escola do gestor da sessão.
  my $auth = $api->under->to('pesquisa#_require_gestor');
  $auth->post('/ask')->to('chat#ask')->name('chat_ask');
  $auth->get('/progress')->to('chat#progress')->name('chat_progress');

  # Conversas
  $auth->post('/conversas')->to('chat#save_conversa')->name('chat_save_conversa');
  $auth->get('/conversas')->to('chat#list_conversas')->name('chat_list_conversas');
  $auth->get('/conversas/calendar')->to('chat#calendar_conversas')->name('chat_calendar_conversas');
  $auth->get('/conversas/search')->to('chat#search_conversas')->name('chat_search_conversas');
  $auth->get('/conversas/export')->to('chat#export_conversas')->name('chat_export_conversas');
  $auth->get('/conversas/:id')->to('chat#show_conversa')->name('chat_show_conversa');
  $auth->delete('/conversas/:id')->to('chat#delete_conversa')->name('chat_delete_conversa');
}

1;
