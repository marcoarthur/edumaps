package EduMaps::Plugin::API::Canais;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

use Mojo::UserAgent;

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

  # Confirmação de posse do telefone (#212): a `ref` (32 hex) é a capability.
  # Formato validado no controller (404 genérico, sem ir ao banco).
  $api->get('/confirmacao/:ref')
    ->to('canais#confirmacao_show')->name('canais_confirmacao_show');

  # Onda 2 (#212): código pelo WhatsApp (template de autenticação) e
  # recebimento do bot público do Telegram por webhook.
  $api->post('/confirmacao/:ref/whatsapp')
    ->to('canais#confirmacao_whatsapp')->name('canais_confirmacao_whatsapp');
  $api->post('/confirmacao/:ref/whatsapp/verificar')
    ->to('canais#confirmacao_whatsapp_verificar')
    ->name('canais_confirmacao_whatsapp_verificar');
  $api->post('/telegram/webhook')
    ->to('canais#telegram_webhook')->name('canais_telegram_webhook');

  # UA HTTP dos canais públicos (Telegram Bot API / WhatsApp Cloud API). Um
  # objeto novo por chamada (seguro entre forks). inactivity_timeout acima
  # dos 25s do long polling do getUpdates. Testes sobrescrevem o helper com
  # um UA falso (sem rede).
  $app->helper(canais_ua => sub ($c) {
    Mojo::UserAgent->new(
      connect_timeout    => 10,
      inactivity_timeout => 40,
      request_timeout    => 45,
    );
  });
}

1;
