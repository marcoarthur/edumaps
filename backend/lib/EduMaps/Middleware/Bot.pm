package EduMaps::Middleware::Bot;
use Mojo::Base -base, -signatures;
use utf8;
use Mojo::IOLoop;
use Syntax::Keyword::Try;

use EduMaps::Bots::Notifier;

# ============================================================================
# CATEGORIA "SYSTEM MIDDLEWARES" DE ENVIO DO BOT (issue #188)
# ============================================================================
#
# Qualquer middleware registrado no EventBus pode enviar mensagem ao bot
# emitindo um evento com o label agregador `system.bot.<severidade>`, por
# exemplo:
#
#   $app->event_bus->emit('system.bot.info', { text => 'Login realizado: x' });
#
# Este middleware filtra esses eventos na cadeia do EventBus e informa o
# EduMaps::Bots::Notifier com a ação equivalente (`system.bot.info` ->
# `system_bot_info`), que decide envio via enabled + allowed_actions.
#
# FRONTEIRA ASSÍNCRONA: com loop de eventos rodando (web worker, Minion) o
# envio é fire-and-forget via `notify_p` (Mojo::Promise, post_p não-bloqueante)
# — quem emite NÃO espera o RTT do Telegram. Sem loop (CLI), cai no `notify`
# síncrono, correto naquele contexto. `Mojo::Promise->wait` é no-op com loop
# rodando (Mojo 5.44), por isso a decisão vive aqui e não em quem emite.
#
# Nunca estoura a cadeia: severidade desconhecida, texto vazio ou falha do
# Notifier são logados e o evento segue para o próximo middleware ($next).
# ============================================================================

has 'app';
has notifier => sub ($self) {
  EduMaps::Bots::Notifier->new(schema => $self->app->schema);
};

# severidade do label -> ação do Policy::Actions (adicionar severidade nova =
# 1 linha aqui + 1 ação na Policy::Actions)
my %SEVERITY_ACTION = (
  info  => 'system_bot_info',
  warn  => 'system_bot_warn',
  error => 'system_bot_error',
  trace => 'system_bot_trace',
);

# Retorna a closure no formato aceito pelo EventBus: sub ($event, $next)
sub to_middleware ($self) {
  return sub ($event, $next) {
    if (my ($severity) = ($event->{type} // '') =~ /^system\.bot\.([a-z]+)$/) {
      $self->_forward($severity, $event->{payload} // {});
    }

    # Passa a execução para o próximo middleware / handlers da cadeia
    return $next->($event);
  };
}

sub _forward ($self, $severity, $payload) {
  my $action = $SEVERITY_ACTION{$severity};
  unless ($action) {
    $self->_log->debug("Middleware::Bot: severidade '$severity' fora do mapa — ignorada");
    return;
  }

  my $text = $payload->{text} // '';
  unless (length $text) {
    $self->_log->debug("Middleware::Bot: $action sem texto (payload vazio) — ignorada");
    return;
  }

  try {
    if (Mojo::IOLoop->singleton->is_running) {
      # Fire-and-forget: não bloqueia quem emite (ex.: resposta do login).
      $self->notifier->notify_p($action, $text)->then(
        sub ($ok)  { $self->_log->info("Middleware::Bot: $action " . ($ok ? 'entregue' : 'não enviada (política/config/API)')); undef },
        sub ($err) { $self->_log->error("Middleware::Bot: $action falhou: $err"); undef },
      );
    }
    else {
      # Sem loop (CLI): envio síncrono é o comportamento correto.
      $self->notifier->notify($action, $text);
    }
  }
  catch ($err) {
    $self->_log->error("Middleware::Bot: falha ao notificar $action: $err");
  }
}

sub _log ($self) {
  return $self->app->log if $self->app && $self->app->can('log');
  require Mojo::Log;
  state $fallback = Mojo::Log->new;
  return $fallback;
}

1;

__END__

=head1 NAME

EduMaps::Middleware::Bot - categoria "system middlewares" de envio do bot via EventBus

=head1 SYNOPSIS

  # Em qualquer middleware do EventBus (registrado via $app->add_mw):
  $app->event_bus->emit('system.bot.info',  { text => 'Login realizado: a@b.c' });
  $app->event_bus->emit('system.bot.error', { text => 'Falha crítica no módulo X' });

=head1 DESCRIPTION

Filtra eventos com label `system.bot.<severidade>` na cadeia do EventBus e
informa o Notifier com a ação equivalente (severidade -> ação do
Policy::Actions). Com loop de eventos rodando o envio é assíncrono
(Mojo::Promise, fire-and-forget); sem loop, síncrono. Nunca interrompe a
cadeia do EventBus.

=cut