package EduMaps::Bots::Notifier;
use Mojo::Base -base, -signatures;
use utf8;

# ============================================================================
# NOTIFICADOR DE EVENTOS DO SISTEMA VIA BOT TELEGRAM (issue #183, fase 1D)
# ============================================================================
#
# Ponto único pelo qual eventos reais do EduMaps (ingestão, stalls, alertas)
# chegam ao bot. Lê a config efetiva da AppConfig (`bot_telegram_config`:
# token decifrado em memória) e NUNCA envia nada sem decisão explícita do
# admin — `enabled=0` por omissão e a ação precisa estar em `allowed_actions`.
#
# Contrato com o chamador:
#   * `notify('ingest_done', 'Job X concluído em 10s')`
#   * retorna 1 se enviou, 0 se não (desativado / ação não permitida / falha)
#   * ação desconhecida (fora da whitelist da Policy) é erro de programação
#     e morre com croak — o chamador decide se captura (o Runner captura e
#     loga, a ingestão não cai).
#   * falha de RUNTIME (API do Telegram recusou, config incompleta) NUNCA
#     morre: loga e devolve 0. Notificação é best-effort por design.
# ============================================================================

use Carp qw(croak);
use Mojo::Log;
use Mojo::Promise;

use EduMaps::Bots::Policy::Actions;
use EduMaps::Bots::Telegram;

has schema     => sub { die "Notifier: schema obrigatório" };
has log        => sub { Mojo::Log->new };
has app_config => undef;          # injeção p/ testes (responde bot_telegram_config)
has bot_class  => 'EduMaps::Bots::Telegram';   # injeção p/ testes (mock de envio)

# Envia $text para o chat configurado se a $action estiver habilitada e
# permitida. Devolve 1 (enviou) ou 0 (não enviou; por quê fica no log).
# Síncrono (bloqueante) — usado pela ingestão (CLI/Minion) e endpoints que
# precisam do resultado imediato.
sub notify ($self, $action, $text = '') {
  my $cfg = $self->_policy($action) or return 0;

  my $bot = $self->_bot_from($cfg);
  my $res = eval { $bot->send_text($text, { action => $action }) };
  if ($@) {
    $self->log->error("Notifier: falha ao enviar $action: $@");
    return 0;
  }
  unless ($res && $res->{ok}) {
    my $motivo = $res ? ($res->{error} // "HTTP $res->{status}") : 'sem resposta';
    $self->log->error("Notifier: API recusou $action: $motivo");
    return 0;
  }

  $self->log->info("Notifier: $action enviada (HTTP $res->{status})");
  return 1;
}

# Mesma política de notify(), mas assíncrona (Mojo::Promise): envia via
# send_text_p (post_p não-bloqueante) e resolve 1 ou 0 quando o Telegram
# responder. Nunca rejeita — falhas viram 0 com log. Usada pela fronteira
# assíncrona do Middleware::Bot (web/Minion: quem emite não espera o RTT).
sub notify_p ($self, $action, $text = '') {
  my $cfg = $self->_policy($action);
  return Mojo::Promise->resolve(0) unless $cfg;

  my $bot = $self->_bot_from($cfg);
  return $bot->send_text_p($text, { action => $action })->then(
    sub ($res) {
      unless ($res && $res->{ok}) {
        my $motivo = $res ? ($res->{error} // "HTTP $res->{status}") : 'sem resposta';
        $self->log->error("Notifier: API recusou $action: $motivo");
        return 0;
      }
      $self->log->info("Notifier: $action enviada (HTTP $res->{status})");
      return 1;
    },
    sub ($err) {
      $self->log->error("Notifier: falha ao enviar $action: $err");
      return 0;
    },
  );
}

# Valida a ação e devolve a config efetiva se o envio está habilitado e
# permitido; caso contrário loga o motivo e devolve undef. Nunca croak para
# falha de runtime — apenas para ação fora da whitelist (erro de programação).
sub _policy ($self, $action) {
  croak "Notifier: ação desconhecida '$action' (whitelist da Policy)"
    unless EduMaps::Bots::Policy::Actions->is_valid($action);

  my $cfg = $self->_config;
  unless ($cfg->{enabled}) {
    $self->log->debug("Notifier: bot desativado — $action ignorada");
    return;
  }

  my $allowed = $cfg->{allowed_actions} || [];
  unless (grep { $_ eq $action } @$allowed) {
    $self->log->info("Notifier: ação '$action' não permitida nas allowed_actions — ignorada");
    return;
  }

  for my $campo (qw/token chat_id/) {
    unless (defined $cfg->{$campo} && length $cfg->{$campo}) {
      $self->log->warn("Notifier: config incompleta ao notificar $action (falta $campo)");
      return;
    }
  }

  return $cfg;
}

sub _bot_from ($self, $cfg) {
  return $self->bot_class->new(
    enabled => 1,
    config  => {
      telegram_token   => $cfg->{token},
      telegram_chat_id => $cfg->{chat_id},
    },
  );
}

# Config efetiva: AppConfig real por omissão, ou objeto injetado nos testes.
sub _config ($self) {
  return $self->app_config->bot_telegram_config if $self->app_config;
  require EduMaps::Model::AppConfig;
  return EduMaps::Model::AppConfig->new(schema => $self->schema)->bot_telegram_config;
}

1;