package EduMaps::Plugin::API::Canais;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Face pública da autoinscrição por QR (issue #208 — Fase 0). Sem sessão: o
# token na URL é a capability. A gestão autenticada vive em
# /api/gestor/:cod_inep/canais/listas (Plugin::API::Gestor).
#
# Registrada em /api/canais, isolada dos plugins de API pré-existentes. A rota
# anônima é análoga à de pesquisas públicas
# (/api/gestor/pesquisas/publica/:token).

has canais_path => '/api/canais';

sub register ($self, $app, @args) {
  my $api = $app->routes->under($self->canais_path);
  my $with_token = { token => qr/[0-9a-fA-F-]{36}/ };

  $api->get('/inscricao/:token' => $with_token)
    ->to('canais#inscricao_form')->name('canais_inscricao_form');
  $api->post('/inscricao/:token' => $with_token)
    ->to('canais#inscricao_create')->name('canais_inscricao_create');
}

1;
