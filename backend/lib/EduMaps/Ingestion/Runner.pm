package EduMaps::Ingestion::Runner;
use Mojo::Base -base, -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Log;
use Scalar::Util ();
use EduMaps::Ingestion::NaoCarregada;

# ================================================================
# ORQUESTRADOR DE JOBS DE INGESTÃO
# ================================================================

has jobs => sub { {} };
has log => sub { Mojo::Log->new };
has config => sub { {} };
has dry_run => 0;

# Notificador de eventos (#183, fase 1D): avisa o Telegram sobre o resultado
# de cada job (ingest_done / ingest_failed / ingest_stall), sujeito à config
# da AppConfig (enabled + allowed_actions) — nada é enviado sem decisão
# explícita do admin. Lazy e injetável: nos testes passa-se um mock.
has notifier => sub ($self) {
  require EduMaps::Bots::Notifier;
  return EduMaps::Bots::Notifier->new(
    schema => $self->app->schema,
    log    => $self->log,
  );
};

# --- Stall detection (#166) --------------------------------------------------
# O IBGE ficou parado dentro da extração e nunca devolveu o controlo: nenhum
# check "depois do job" correria. O watchdog corre EM PARALELO (SIGALRM) e
# morre com [STALL] quando o progresso real fica parado stall_timeout segundos.
has stall_timeout        => 600;   # segundos sem progresso até abortar
has stall_check_interval => 60;    # segundos entre verificações
has _stall_last_at       => sub { time };
has _stall_last_sig      => sub { '' };

# Contexto mínimo passado a cada job (ver EduMaps::Ingestion::App). Lazy:
# construir o Runner não abre ligação nenhuma à base de dados. Nos testes é
# substituído por um mock — `Runner->new(app => $mock)`.
has app => sub ($self) {
  require EduMaps::Ingestion::App;
  return EduMaps::Ingestion::App->new;
};

# Lista de jobs derivada do directório, e não de uma lista escrita à mão.
#
# Existia um `qw(...)` com 11 nomes em dois sítios (`load_jobs` e
# `CLI::list_jobs`), e não continha `IBGE` — logo `--list`, `--schedule` e
# "roda todos" omitiam um loader completo e mergeado. Derivar do directório
# faz com que um job novo seja descoberto sem ninguém ter de lembrar-se de o
# acrescentar em dois sítios.
#
# `Base.pm` é a classe abstracta pai (`run()` morre com "deve ser
# implementado") e por isso fica de fora.
sub job_names ($class) {
  my $dir = path(__FILE__)->dirname->child('Job');
  opendir my $dh, $dir or die "Não abriu $dir: $!\n";
  my @names =
    sort
    map  { s/\.pm\z//r }
    grep { $_ ne 'Base.pm' && /\.pm\z/ }
    readdir $dh;
  closedir $dh;
  die "Nenhum job de ingestão em $dir\n" unless @names;
  return @names;
}

sub register_job ($self, $job_class, $config = undef) {
  eval "require $job_class";
  die "Erro ao carregar $job_class: $@" if $@;

  my $cfg = defined $config ? $config : $self->config;
  my $job = $job_class->new(
    log => $self->log,
    config => $cfg,
    dry_run => $self->dry_run,
    app => $self->app,
  );

  $self->jobs->{ $job->job_name } = $job;
  $self->log->info("Job registrado: $job_class ($job->{job_name})");
}


# Assinatura do progresso real: ficheiros de trabalho (tamanho/mtime/linhas)
# mais contadores leves da BD. Se algo disto muda, houve progresso.
# Directório de trabalho dos loaders. O contexto mínimo (App.pm) não expõe
# `home`, por isso cai para o cwd — o ingestion_runner corre sempre de backend/.
sub _stall_dir ($self) {
  return path('data', 'ingestao');
}

sub _progress_sig ($self) {
  my @parts;
  my $dir = $self->_stall_dir;
  if ($dir && -d $dir) {
    for my $f (sort $dir->list->each) {
      next unless -f $f;
      my @st = stat($f);
      next unless @st;
      my $lines = 0;
      if ($st[7] < 10_000_000) {
        if (open my $fh, '<', $f) { $lines = () = <$fh>; close $fh }
      }
      else { $lines = $st[7] }
      push @parts, join(':', $f->basename, $st[7], int($st[9] // time), $lines);
    }
  }
  if ($self->app && eval { $self->app->can('schema') && $self->app->schema }) {
    my $schema = $self->app->schema;
    for my $pair ([ImportMetadata => 'im'], [DadosIbge => 'dibge'], [IbgeAgregados => 'iag']) {
      my ($rs, $tag) = @$pair;
      my $c = eval { $schema->resultset($rs)->count };
      push @parts, "$tag:$c" if defined $c;
    }
  }
  return join('|', @parts);
}

# Devolve 0 (houve progresso), 1 (sem progresso mas dentro do prazo) ou morre
# com [STALL] quando o prazo estourou — falha alto, como manda a #156.
sub _check_stall ($self) {
  my $now  = time;
  my $sig  = $self->_progress_sig;
  my $idle = $now - $self->_stall_last_at;
  if ($sig ne $self->_stall_last_sig) {
    $self->_stall_last_sig($sig);
    $self->_stall_last_at($now);
    return 1;
  }
  return 0 if $idle < $self->stall_timeout;
  my $dir = $self->_stall_dir;
  die sprintf(
    "[STALL] Sem progresso há %ds (timeout %ds). dir=%s sig=%s\n",
    $idle, $self->stall_timeout, $dir, substr($sig, 0, 300)
  );
}

# Watchdog periódico activo DURANTE a execução do job. Sem ele o check só
# ocorreria após o job devolver o controlo — que é precisamente o que um job
# bloqueado nunca faz.
sub _install_stall_watch ($self) {
  return 0 if $self->stall_timeout <= 0;
  my $interval = $self->stall_check_interval || 60;
  $interval = $self->stall_timeout if $interval > $self->stall_timeout;
  $self->_stall_last_at(time);
  $self->_stall_last_sig($self->_progress_sig);
  $SIG{ALRM} = sub {
    my $err = '';
    eval { $self->_check_stall; 1 } or $err = $@;
    if ($err) { die $err }        # propaga dentro do job (loop do Mojo/IO)
    alarm $interval;
  };
  alarm $interval;
  return 1;
}

sub _remove_stall_watch ($self) {
  alarm 0;
  delete $SIG{ALRM};
  return;
}

sub load_jobs ($self, $job_names = []) {
  my @to_load = @$job_names ? @$job_names : $self->job_names;

  for my $name (@to_load) {
    my $class = "EduMaps::Ingestion::Job::$name";
    $self->register_job($class);
  }
}

sub run_job ($self, $job_name, $args = {}) {
  my $job = $self->jobs->{$job_name}
    or die "Job '$job_name' não registrado";
  $args //= {};

  $self->log->info("Executando job: $job_name");
  my $start = time;

  # #231: o estado da tentativa vai para clean.import_metadata, nas tabelas
  # que o job declara, sem tocar na proveniência da última carga boa.
  # Best-effort: um problema ao registrar o estado nunca mascara o resultado
  # do job (vai para o log).
  my @tabelas = $job->can('tabelas') ? $job->tabelas($args) : ();
  $self->_estado($job, registrar_tentativa => @tabelas);

  # Um job pode declarar um prazo maior (#238): o ogr2ogr da malha de setores
  # escreve direto no banco e passa >10 min sem tocar data/ingestao, o que o
  # watchdog lia como travamento. Vale o maior dos dois prazos, só neste job.
  my $prazo_runner = $self->stall_timeout;
  my $prazo_job = $job->can('stall_timeout') ? $job->stall_timeout : undef;
  $self->stall_timeout($prazo_job)
    if defined $prazo_job && $prazo_runner > 0 && $prazo_job > $prazo_runner;
  $self->_install_stall_watch;

  my $ok = eval {
    $job->run($args);
    1;
  };
  $self->stall_timeout($prazo_runner);
  $ok or do {
    my $error = $@ || 'Erro desconhecido';
    $self->_remove_stall_watch;
    my $duration = time - $start;

    # Bloqueio conhecido (e-SIC, API retirada, fora do objetivo): não é bug,
    # mas também não é sucesso — estado 'nao_carregada' + motivo.
    if (Scalar::Util::blessed($error) && $error->isa('EduMaps::Ingestion::NaoCarregada')) {
      $self->log->warn("Job $job_name NÃO CARREGADA: " . $error->motivo);
      $self->_estado($job, registrar_nao_carregada => $error->motivo, @tabelas);
      $self->_notify('ingest_failed', "Job $job_name não carregada: " . $error->motivo);
      return { success => 0, nao_carregada => 1, error => "$error", duration => $duration };
    }

    $self->log->error("Job $job_name falhou: $error");
    $self->_estado($job, registrar_falha => "$error", @tabelas);
    my $action = $error =~ /\[STALL\]/ ? 'ingest_stall' : 'ingest_failed';
    $self->_notify($action, "Job $job_name falhou: $error");
    return { success => 0, error => "$error", duration => $duration };
  };
  $self->_remove_stall_watch;
  $self->_estado($job, fechar_tentativa => @tabelas);

  my $duration = time - $start;
  $self->log->info("Job $job_name concluído em ${duration}s");
  $self->_notify('ingest_done', "Job $job_name concluído em ${duration}s");
  return { success => 1, duration => $duration };
}

sub _estado ($self, $job, $metodo, @args) {
  return 0 unless $job->can($metodo);
  my $n = eval { $job->$metodo(@args) };
  $self->log->error("Registro de estado ($metodo) falhou: $@") if $@;
  return $n // 0;
}

# Notificação best-effort: nunca deita abaixo a ingestão. Um bot quebrado ou
# sem config não pode fazer o job falhar — erros vão para o log.
sub _notify ($self, $action, $text) {
  my $sent = eval { $self->notifier->notify($action, $text) };
  if ($@) {
    $self->log->error("Notificação $action falhou: $@");
  }
  elsif (!$sent) {
    $self->log->debug("Notificação $action não enviada (não habilitada/permitida)");
  }
  return $sent ? 1 : 0;
}

# #158: as views analíticas são materializadas (analytics.mv_*). Ao fim de
# uma execução REAL com ao menos um job bem-sucedido, refresca-as — senão o
# produto leria a fotografia anterior à carga. Best-effort, mas alto: a falha
# vai para o log como erro e é notificada; não desfaz as cargas já gravadas.
# Sem a função (banco antes da change analytics_views_materializadas), não faz
# nada.
sub refrescar_views ($self, $results) {
  return 0 if $self->dry_run;
  return 0 unless grep { $_->{success} } @{ $results // [] };
  return 0 unless $self->app && eval { $self->app->can('schema') && $self->app->schema };
  my $dbh = $self->app->schema->storage->dbh;
  my ($existe) = eval {
    $dbh->selectrow_array(q{SELECT to_regprocedure('analytics.refresh_views_ingestao()') IS NOT NULL})
  };
  return 0 unless $existe;
  my $inicio = time;
  my $ok = eval { $dbh->do('SELECT analytics.refresh_views_ingestao()'); 1 };
  if (!$ok) {
    my $err = $@ || 'erro desconhecido';
    $self->log->error("Refresh das views analíticas falhou: $err");
    $self->_notify('ingest_failed', "Refresh das views analíticas falhou: $err");
    return 0;
  }
  $self->log->info(sprintf('Views analíticas materializadas refrescadas em %ds', time - $inicio));
  return 1;
}

sub run_all ($self, $job_names = [], $args = {}) {
  $self->load_jobs($job_names);
  
  my @jobs = @$job_names ? @$job_names : keys %{$self->jobs};
  my @results;
  
  for my $name (@jobs) {
    my $result = $self->run_job($name, $args);
    push @results, { job => $name, %$result };
  }
  
  return \@results;
}

sub run_scheduled ($self, $schedule = 'daily', $args = {}) {
  $self->load_jobs;
  
  my @scheduled = grep { $_->schedule eq $schedule } values %{$self->jobs};
  
  $self->log->info("Executando $schedule jobs: " . join(', ', map { $_->job_name } @scheduled));
  
  my @results;
  for my $job (@scheduled) {
    my $result = $self->run_job($job->job_name, $args);
    push @results, { job => $job->job_name, %$result };
  }
  
  return \@results;
}

1;
