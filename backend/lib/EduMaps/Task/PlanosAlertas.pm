package EduMaps::Task::PlanosAlertas;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use DateTime;
use EduMaps::Channel::Email;
use EduMaps::Util::MinionFila qw(minion_fila);

# ============================================================================
# ALERTAS DE PRAZO DOS PLANOS DE GESTÃO (#373, épico #368)
# ============================================================================
#
# Task Minion `planos_alertas` (mesmo padrão autorreagendável da
# `canais_retencao`):
#
#   - DIÁRIA, às 07:00 de America/Sao_Paulo: cada job manda os resumos do dia
#     e enfileira o próximo para as 07:00 seguintes;
#   - um resumo por GESTOR (conta da escola dona do plano), com os planos
#     vigentes de alertas ligados: ações atrasadas e as que vencem em 7 dias;
#   - idempotência (clean.planos_alertas_envio): no máximo um por gestor por
#     dia, e nada sai se o conteúdo é o mesmo do último enviado (sem novidade);
#   - e-mail desligado ou sem URL pública: o job não envia, mas segue a cadeia
#     (a config pode ser ligada depois sem reiniciar o worker);
#   - lock Minion `planos_alertas` — uma execução por vez;
#   - início: boot do worker Minion (evento `wait`), e helper
#     `planos_alertas_start`. `{manual => 1}` roda uma vez sem reagendar.
#
# O e-mail vai para o endereço da CONTA do gestor; contatos da escola e a
# comunidade não entram. O corpo traz o link do plano, onde o gestor desliga
# os alertas daquele plano.

our $TASK       = 'planos_alertas';
our $HORA       = 7;
our $LOCK_TTL   = 1_800;
our $DELAY_LOCK = 600;
our $TZ         = 'America/Sao_Paulo';

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);
  $app->helper(planos_alertas_start => sub ($c) { iniciar($c->app) });

  $app->minion->on(worker => sub ($minion, $worker) {
    $worker->once(wait => sub {
      my $ok = eval { iniciar($app); 1 };
      $app->log->warn("planos_alertas no boot do worker falhou: $@") unless $ok;
    });
  });
}

# Segundos até as próximas 07:00 em America/Sao_Paulo (a partir de $agora,
# DateTime; padrão: agora).
sub segundos_ate_proxima ($agora = undef) {
  $agora //= DateTime->now(time_zone => $TZ);
  $agora = $agora->clone->set_time_zone($TZ);
  my $alvo = $agora->clone->set(hour => $HORA, minute => 0, second => 0, nanosecond => 0);
  $alvo->add(days => 1) if $alvo <= $agora;
  return $alvo->epoch - $agora->epoch;
}

sub _agendado ($app) {
  my $jobs = $app->minion->jobs({ tasks => [$TASK], queues => [minion_fila($app, $TASK)],
                                  states => [qw(inactive active)] });
  while (my $j = $jobs->next) {
    return 1 unless ref $j->{args} eq 'ARRAY' && ref $j->{args}[0] eq 'HASH' && $j->{args}[0]{manual};
  }
  return 0;
}

sub iniciar ($app) {
  return { ok => 1, ja_ativo => 1 } if _agendado($app);
  my $id = $app->minion->enqueue($TASK => [{}] => {
    attempts => 1, queue => minion_fila($app, $TASK), delay => segundos_ate_proxima() });
  return { ok => 1, job_id => $id };
}

sub _run ($job, $estado = {}) {
  my $app    = $job->app;
  my $minion = $job->minion;
  $estado = {} unless ref $estado eq 'HASH';
  my $manual = $estado->{manual} ? 1 : 0;

  if (my $ant = $estado->{anterior}) {
    eval { my $j = $minion->job($ant); $j->remove if $j && $j->info->{state} eq 'finished'; };
  }

  my $guard = $minion->guard($TASK, $LOCK_TTL);
  unless ($guard) {
    return $job->finish({ parado => 'lock' }) if $manual;
    my $next = _reagendar($job, $DELAY_LOCK);
    return $job->finish({ adiado => 'lock', proximo => $next });
  }

  my $r = eval { enviar_resumos($app) } // { erro => ($@ || 'falha desconhecida') };
  undef $guard;
  $app->log->error("planos_alertas: $r->{erro}") if $r->{erro};
  $app->log->info(sprintf 'planos_alertas: %d enviados, %d sem novidade, %d falhas',
    map { $r->{$_} // 0 } qw(enviados sem_novidade falhas)) unless $r->{erro};

  return $job->finish($r) if $manual;
  my $next = _reagendar($job, segundos_ate_proxima());
  return $job->finish({ %$r, proximo => $next });
}

sub _reagendar ($job, $delay) {
  return $job->minion->enqueue($TASK => [{ anterior => $job->id }] => {
    attempts => 1, queue => $job->info->{queue}, delay => $delay });
}

# Monta e envia os resumos do dia. Exposto para teste (sem worker).
# %o: hoje ('AAAA-MM-DD'), janela (dias).
sub enviar_resumos ($app, %o) {
  my $model = $app->model('Gestor');
  my $cfg   = $app->model('Canal')->email_config;
  my $base  = $cfg->{public_base_url} // '';
  $base =~ s{/+$}{};
  return { enviados => 0, desligado => 1 }
    unless $cfg->{enabled} && $cfg->{smtp_host} && $cfg->{from} && $base =~ m{^https?://};

  my $hoje = $o{hoje} // DateTime->now(time_zone => $TZ)->ymd;
  my $mail = EduMaps::Channel::Email->new(
    config         => $cfg,
    enabled        => 1,
    schema         => $model->schema,
    log            => $app->log,
    smtp_transport => $app->build_controller->canais_smtp,
  );

  my %n = (enviados => 0, sem_novidade => 0, ja_enviado_hoje => 0, falhas => 0);
  for my $g (@{ $model->planos_alertas_resumos(hoje => $hoje, janela => $o{janela}) }) {
    if (my $motivo = $model->planos_alerta_pular($g->{gestor_id}, $hoje, $g->{assinatura})) {
      $n{$motivo}++;
      next;
    }
    my $res = eval {
      $mail->send_message({
        to       => $g->{email},
        operacao => 'alerta',
        assunto  => assunto($g),
        corpo    => corpo($g, $base, $hoje),
      });
    } // { ok => 0, error => ($@ || 'falha desconhecida') };
    $model->planos_alerta_registrar($g, $hoje, $res->{ok}, $res->{ok} ? undef : "$res->{error}");
    $res->{ok} ? $n{enviados}++ : $n{falhas}++;
  }
  return \%n;
}

sub assunto ($g) {
  my ($atr, $ven) = (0, 0);
  for my $p (@{ $g->{planos} }) { $atr += @{ $p->{atrasadas} }; $ven += @{ $p->{vencendo} } }
  my @partes;
  push @partes, $atr == 1 ? '1 ação atrasada' : "$atr ações atrasadas" if $atr;
  push @partes, $ven == 1 ? '1 ação vence em 7 dias' : "$ven ações vencem em 7 dias" if $ven;
  return 'Planos da escola: ' . join(' e ', @partes);
}

sub _data_br ($iso) { $iso =~ /^(\d{4})-(\d{2})-(\d{2})/ ? "$3/$2/$1" : $iso }

sub _linha ($a) {
  my $l = sprintf '  • %s — prazo %s', $a->{descricao}, _data_br($a->{prazo});
  $l .= " (responsável: $a->{responsavel})" if defined $a->{responsavel} && length $a->{responsavel};
  return $l;
}

sub corpo ($g, $base, $hoje) {
  my @l = ("Olá, $g->{nome}.", '', 'Resumo dos prazos dos planos da sua escola em ' . _data_br($hoje) . ':');
  for my $p (@{ $g->{planos} }) {
    push @l, '', "Plano: $p->{titulo}";
    if (@{ $p->{atrasadas} }) {
      push @l, 'Atrasadas:', map { _linha($_) } @{ $p->{atrasadas} };
    }
    if (@{ $p->{vencendo} }) {
      push @l, 'Vencem nos próximos 7 dias:', map { _linha($_) } @{ $p->{vencendo} };
    }
    push @l, "Abrir o plano: $base/gestor/planos/$p->{id}";
  }
  push @l, '',
    'Você só recebe este resumo quando há novidade, no máximo uma vez por dia.',
    'Para não receber mais os alertas de um plano, abra o plano e desligue',
    '"Receber alertas de prazo".',
    '',
    '— EduMaps';
  return join "\n", @l;
}

1;
