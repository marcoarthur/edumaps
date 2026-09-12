package EventBus;

use Mojo::Base -base, -signatures, -async_await;
use Mojo::Promise;
use Mojo::IOLoop;
use Time::HiRes qw(time);

# Definição de atributos no estilo Mojo::Base
has handlers    => sub { {} };
has on_any      => sub { [] };
has middlewares => sub { [] };
has commands    => sub { {} };
has destroyed   => 0;
has seq_id      => 0;

sub _check_destroyed ($self) {
  die "EventBus já foi destruído\n" if $self->destroyed;
}

# --- PUB / SUB ---

sub on ($self, $type, $handler) {
  $self->_check_destroyed;

  push @{ $self->handlers->{$type} }, $handler;

  return sub {
    return if $self->destroyed;
    @{ $self->handlers->{$type} } = grep { $_ ne $handler } @{ $self->handlers->{$type} // [] };
  };
}

sub once ($self, $type, $handler) {
  $self->_check_destroyed;

  my $unsubscribe;
  $unsubscribe = $self->on($type, sub ($payload, $event) {
      $unsubscribe->(); # Desinscreve na primeira execução
      $handler->($payload, $event);
    });

  return $unsubscribe;
}

sub onAny ($self, $handler) {
  $self->_check_destroyed;

  push @{ $self->on_any }, $handler;

  return sub {
    return if $self->destroyed;
    @{ $self->on_any } = grep { $_ ne $handler } @{ $self->on_any };
  };
}

sub use ($self, $middleware) {
  $self->_check_destroyed;

  push @{ $self->middlewares }, $middleware;

  return sub {
    return if $self->destroyed;
    @{ $self->middlewares } = grep { $_ ne $middleware } @{ $self->middlewares };
  };
}

sub emit ($self, $type, $payload = {}, %opts) {
  $self->_check_destroyed;

  $self->seq_id($self->seq_id + 1);
  my $event = {
    type      => $type,
    payload   => $payload,
    id        => "evt_" . $self->seq_id,
    timestamp => time(),
    source    => $opts{source} // (caller)[1],
  };

  my @mws = @{ $self->middlewares };

  my $run_chain;
  $run_chain = sub ($current_evt) {
    if (@mws) {
      my $mw = shift @mws;
      $mw->($current_evt, $run_chain);
    } else {
      $self->_dispatch_to_handlers($current_evt);
    }
  };

  $run_chain->($event);
}

sub _dispatch_to_handlers ($self, $event) {
  my $type     = $event->{type};
  my $payload  = $event->{payload};
  my @handlers = @{ $self->handlers->{$type} // [] };
  my @on_any   = @{ $self->on_any };

  if (!@handlers && !@on_any) {
    warn "WARN: emit(\"$type\") disparado sem nenhum handler registrado.\n";
    return;
  }

  for my $handler (@handlers) {
    eval { $handler->($payload, $event); };
    warn "Erro no handler para '$type': $@\n" if $@;
  }

  for my $handler (@on_any) {
    eval { $handler->($payload, $event); };
    warn "Erro no handler onAny: $@\n" if $@;
  }
}

# --- ASSÍNCRONO & EVENT LOOP (waitFor) ---

sub waitFor ($self, $type, %opts) {
  $self->_check_destroyed;

  my $timeout_ms = $opts{timeoutMs} // 5000;
  my $seconds    = $timeout_ms / 1000;

  my $promise = Mojo::Promise->new;

  # 1. Escuta o evento via once()
  my $unsub = $self->once($type, sub ($payload, $event) {
      $promise->resolve($payload);
    });

  # 2. Garante o cancelamento do listener quando a promise resolver ou der timeout
  $promise->finally(sub {
      $unsub->();
    });

  # 3. Aplica o timeout nativo da Promise (rejeita se expirar o tempo)
  return $promise->timeout($seconds => "Event '$type' expirou após ${timeout_ms}ms");
}

# --- COMANDOS (Request / Response) ---

sub handle ($self, $command, $handler) {
  $self->_check_destroyed;

  if (exists $self->commands->{$command}) {
    die "Já existe um handler registrado para o comando '$command'\n";
  }

  $self->commands->{$command} = $handler;

  return sub {
    delete $self->commands->{$command} unless $self->destroyed;
  };
}

async sub request ($self, $command, $payload = {}) {
  $self->_check_destroyed;

  unless (exists $self->commands->{$command}) {
    die "Nenhum handler registrado para o comando \"$command\"\n";
  }

  my $handler = $self->commands->{$command};
  my $res     = $handler->($payload);

  # Suporta handlers que retornam Promises/são async
  if (ref $res && $res->isa('Mojo::Promise')) {
    return await $res;
  }

  return $res;
}

# --- CICLO DE VIDA ---

sub destroy ($self) {
  return if $self->destroyed;

  $self->handlers({});
  $self->on_any([]);
  $self->middlewares([]);
  $self->commands({});
  $self->destroyed(1);
}

1;
