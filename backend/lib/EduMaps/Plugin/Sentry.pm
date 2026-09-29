package EduMaps::Plugin::Sentry;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Class::Method::Modifiers qw(around);
use EduMaps::Services::Sentry;
use Scalar::Util qw(blessed);

# ABSTRACT: Integra o EduMaps ao Sentry (5xx dos controllers + jobs Minion falhos)

# Registra o serviço `EduMaps::Services::Sentry` como helper `sentry` e, se
# houver DSN configurado, liga dois ganchos de captura:
#
#   1. after_dispatch  — todo response >= 500 (exceções de controller viram
#      `$c->stash->{exception}` nos renderers de erro do Mojolicious; 5xx
#      explícitos viram mensagem genérica).
#   2. Minion::Job::fail — ponto único por onde passam TODOS os fails de job
#      (explícitos via `$job->fail(...)` ou óbitos convertidos em fail por
#      `Minion::Job::start`/`_reap`). Não existe evento de estado de job no
#      Minion 12, então o wrap no método `fail` é o choke point estável.
#
# Privacidade: argumentos de job são sanitizados (`_sanitize_args`); corpo de
# request NUNCA é enviado — só method/path/status.

my $WRAPPED = 0;    # evita re-wrap se o plugin registrar 2x no mesmo processo

sub register ($self, $app, $config) {
  $config ||= {};
  my $conf = $app->config->{sentry} || {};

  my $sentry = $config->{service}
    || EduMaps::Services::Sentry->new(
      dsn         => $config->{dsn}         // $conf->{dsn}         // $ENV{EDUMAPS_SENTRY_DSN}   // '',
      release     => $config->{release}     // $conf->{release}     // $ENV{EDUMAPS_SENTRY_RELEASE} // 'dev',
      environment => $config->{environment} // $conf->{environment} // ($app->mode || 'development'),
      server_name => $config->{server_name} || '',
      log         => $app->log,
    );

  # Helper sempre disponível (no-op sem DSN), p/ tasks/controllers usarem à vontade.
  $app->helper(sentry => sub { $sentry });

  # Sem DSN: sistema é no-op — nenhum hook, nenhum HTTP.
  return unless $sentry->is_active;

  # 1) 5xx / erros de controller
  $app->hook(after_dispatch => sub ($c) { $self->capture_dispatch($sentry, $c) });

  # 2) Jobs Minion falhos (wrap global na classe Minion::Job)
  unless ($WRAPPED++) {
    around 'Minion::Job::fail' => sub {
      my ($orig, $job) = (shift, shift);
      my $err = @_ ? $_[0] : 'Unknown error';
      my $ok  = eval {
        $self->capture_job_failure($sentry, $job, $err);
        1;
      };
      $app->log->warn("Sentry: falha ao capturar job: $@") unless $ok;
      # Sempre repassa: o fail/retry do Minion não pode ser alterado pelo Sentry.
      return $orig->($job, @_);
    };
  }
}

# Captura responses >= 500 (exceções renderizadas ou 5xx explícitos).
sub capture_dispatch ($self, $sentry, $c) {
  my $code = $c->res->code || 0;
  return unless $code >= 500;
  my %ctx = (
    status => $code,
    method => $c->req->method,
    path   => $c->req->url->path->to_string,
  );
  my $e = $c->stash->{exception};
  my $ok = eval {
    if (blessed $e) { $sentry->capture_exception($e, %ctx) }
    else            { $sentry->capture_message("HTTP $code em $ctx{path}", %ctx) }
    1;
  };
  $c->app->log->warn("Sentry: falha em capture_dispatch: $@") unless $ok;
  return;
}

# Captura falha de job com contexto reduzido (task/id/queue + args sanitizados).
sub capture_job_failure ($self, $sentry, $job, $err) {
  my $info = eval { $job->info } || {};
  my %ctx = (
    task   => $info->{task}   || '?',
    queue  => $info->{queue}  || 'default',
    job_id => $job->id,
    level  => 'error',
    extra  => {},
  );
  my $safe = eval { $sentry->_sanitize_args($info->{args}) } || [];
  $ctx{extra}{args} = $safe if @$safe;
  return $sentry->capture_exception($err, %ctx);
}

1;

__END__

=head1 NAME

EduMaps::Plugin::Sentry - Hooks de observabilidade (Sentry) do EduMaps

=head1 SYNOPSIS

  # no startup (após Minion):
  $self->plugin('EduMaps::Plugin::Sentry');

  # config (edu_maps.conf):
  sentry => { dsn => 'https://<key>@o<org>.ingest.sentry.io/<project>', release => '<sha>' },

=head1 DESCRIPTION

Sem `dsn` o plugin só expõe o helper `sentry` (no-op). Com `dsn`, liga os
ganchos de 5xx e de jobs Minion falhos. `service` no config permite injetar
um serviço próprio em testes.

=cut