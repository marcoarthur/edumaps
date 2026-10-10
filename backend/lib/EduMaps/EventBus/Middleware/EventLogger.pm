package EduMaps::EventBus::Middleware::EventLogger;

use Mojo::Base -base, -signatures;
use Mojo::JSON qw(encode_json);
use Syntax::Keyword::Try;
use Digest::SHA qw(hmac_sha256_hex);

# ============================================================================
# EVENT LOGGER BUFFERIZADO (telemetria — etapa 1)
# ============================================================================
#
# Middleware do EventBus que grava os eventos no `event_store`. Ao contrário
# da versão anterior (um INSERT assíncrono por evento), agora os eventos são
# acumulados em memória (buffer por worker) e persistidos em LOTE:
#
#   - flush por tempo (flush_interval_s, default 30s);
#   - flush por volume (max_buffer, default 500 eventos);
#   - flush manual via comando do EventBus: `event_bus->request('event_logger.flush')`.
#
# O flush escreve as interações num único INSERT multi-row e, na mesma
# transação, faz o UPSERT agregado da dimensão de sessão (`session_tracking`:
# seen_count++, last_seen_at, ip/user_agent/gestor_id do primeiro evento).
#
# Dado pessoal: o IP do visitante NUNCA vai para `event_store` — fica só na
# dimensão `session_tracking` (retenção curta); a análise usa `ip_anon`
# (HMAC(ip + salt diário)). Chaves sensíveis são removidas do payload JSONB
# gravado (ver `strip_payload_keys`).
# ============================================================================

has 'app';
has ignore_events => sub { { 'system.ping' => 1 } }; # Eventos de ruído para ignorar
has flush_interval_s => 30;
has max_buffer => 500;
has buffer => sub { [] };
has _flushing => 0;
has _timer    => undef;
has _commands_done => 0;

# Chaves removidas do payload JSONB persistido (dado pessoal fica apenas na
# dimensão de sessão). `user_agent` permanece — integridade histórica do
# event_store (payload era gravado como vinha).
has strip_payload_keys => sub { [qw(ip)] };

sub to_middleware ($self) {
  # Comando de flush disponível desde o startup (testes/shutdown), não só
  # após o primeiro evento bufferizado.
  $self->_ensure_commands;

  return sub ($event, $next) {
    $self->_buffer_event($event);

    # Continua a execução do EventBus sem esperar a gravação
    return $next->($event);
  };
}

sub _buffer_event ($self, $event) {
  my $type = $event->{type};
  return if $self->ignore_events->{$type};
  return unless $self->app;

  my $payload   = $event->{payload} // {};
  my $stripped  = {%$payload};
  delete @$stripped{ @{ $self->strip_payload_keys } };

  push @{ $self->buffer }, {
    event_id       => $event->{id},
    event_type     => $type,
    codigo_ibge    => $payload->{codigo_ibge} // $payload->{ibge_code},
    is_speculative => $payload->{is_speculative} ? 1 : 0,
    source         => $event->{source} // 'unknown',
    payload        => encode_json($stripped),
    # Dimensão de sessão: colunas em event_store…
    session_id     => $payload->{session_id},
    gestor_id      => $payload->{gestor_id},
    # …e campos só para agregar session_tracking no flush (nunca colunas).
    ip             => $payload->{ip},
    user_agent     => $payload->{user_agent},
  };

  $self->_ensure_timer;
  $self->flush if @{ $self->buffer } >= $self->max_buffer;
}

sub flush ($self) {
  my $rows = $self->buffer;
  return 0 unless @$rows;
  return 0 if $self->_flushing;

  $self->_flushing(1);
  $self->buffer([]);
  my $count = scalar @$rows;

  try {
    my $db = $self->app->pg->db;

    # 1) Interações: 1 INSERT multi-row (uma transação/round-trip).
    my $values = join(', ', map { '(?, ?, ?, ?, ?, ?::jsonb, ?::text, ?::bigint)' } @$rows);
    my @flat;
    for my $r (@$rows) {
      push @flat,
        $r->{event_id}, $r->{event_type}, $r->{codigo_ibge}, $r->{is_speculative},
        $r->{source}, $r->{payload}, $r->{session_id}, $r->{gestor_id};
    }
    $db->query(
      'INSERT INTO event_store (event_id, event_type, codigo_ibge, is_speculative, source, payload, session_id, gestor_id) VALUES '
        . $values,
      @flat,
    );

    # 2) Dimensão de sessão: upsert agregado.
    $self->_flush_sessions($rows);
  }
  catch ($err) {
    $self->app->log->error("Erro ao gravar lote de $count eventos no EventStore: $err");
  }

  $self->_flushing(0);
  return $count;
}

sub _flush_sessions ($self, $rows) {
  my %by_sid;
  for my $r (@$rows) {
    next unless defined $r->{session_id} && length $r->{session_id};
    my $s = $by_sid{ $r->{session_id} } //= {
      count      => 0,
      ip         => undef,
      user_agent => undef,
      gestor_id  => undef,
    };
    $s->{count}++;
    $s->{ip}         //= $r->{ip};
    $s->{user_agent} //= $r->{user_agent};
    $s->{gestor_id}  //= $r->{gestor_id} if defined $r->{gestor_id};
  }

  return unless %by_sid;

  my @values;
  my @flat;
  for my $sid (keys %by_sid) {
    my $s = $by_sid{$sid};
    push @values, '(?, ?::inet, ?, ?, ?, ?, NOW(), NOW(), ?)';
    push @flat,
      $sid, $s->{ip}, $self->_ip_anon($s->{ip}), $s->{user_agent},
      ($s->{gestor_id} ? 1 : 0), $s->{gestor_id}, $s->{count};
  }

  $self->app->pg->db->query(
    'INSERT INTO session_tracking
       (session_id, ip, ip_anon, user_agent, is_logged, gestor_id, first_seen_at, last_seen_at, seen_count)
     VALUES ' . join(', ', @values) . '
     ON CONFLICT (session_id) DO UPDATE SET
       last_seen_at = NOW(),
       seen_count   = session_tracking.seen_count + EXCLUDED.seen_count,
       user_agent   = COALESCE(EXCLUDED.user_agent, session_tracking.user_agent),
       is_logged    = session_tracking.is_logged OR EXCLUDED.is_logged,
       gestor_id    = COALESCE(EXCLUDED.gestor_id, session_tracking.gestor_id)',
    @flat,
  );
}

sub _ip_anon ($self, $ip) {
  return undef unless defined $ip && length $ip;   # escalar: nunca lista vazia (contexto de lista!)
  my $conf = $self->app->config // {};
  my $salt = $conf->{privacy}{anon_salt} // 'edumaps-dev-salt';
  my @g    = gmtime;
  my $day  = sprintf('%04d-%02d-%02d', $g[5] + 1900, $g[4] + 1, $g[3]);
  return hmac_sha256_hex($ip, "${salt}::$day");
}

sub _ensure_timer ($self) {
  return if $self->_timer;
  $self->_timer(Mojo::IOLoop->recurring($self->flush_interval_s => sub {
      $self->flush if @{ $self->buffer };
    }));
}

sub _ensure_commands ($self) {
  return if $self->_commands_done;
  $self->_commands_done(1);
  $self->app->event_bus->handle('event_logger.flush', sub ($payload) { return $self->flush });
}

1;

__END__

=head1 NAME

EduMaps::EventBus::Middleware::EventLogger - persiste eventos do EventBus em lote

=head1 SYNOPSIS

  # EduMaps.pm (startup)
  $self->add_mw('EventLogger', $conf->{event_logger} // {});

  # flush manual (testes, shutdown)
  $app->event_bus->request('event_logger.flush');

=head1 CONFIG

=over

=item * flush_interval_s — intervalo do flush agendado (default 30)

=item * max_buffer — nº de eventos que dispara flush por volume (default 500)

=item * ignore_events — hashref de tipos a descartar (default: system.ping)

=back

=head1 LGPD

O IP cru é usado apenas para agregar C<session_tracking.ip> (retenção curta,
config C<privacy.ip_retention_days>); análise usa C<ip_anon>. O IP é removido
do payload JSONB persistido em C<event_store>.

=cut