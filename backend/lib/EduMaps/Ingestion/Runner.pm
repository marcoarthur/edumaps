package EduMaps::Ingestion::Runner;
use Mojo::Base -base, -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Log;

# ================================================================
# ORQUESTRADOR DE JOBS DE INGESTÃO
# ================================================================

has jobs => sub { {} };
has log => sub { Mojo::Log->new };
has config => sub { {} };
has dry_run => 0;

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
  
  $self->log->info("Executando job: $job_name");
  my $start = time;
  $self->_install_stall_watch;

  eval {
    $job->run($args);
    1;
  } or do {
    my $error = $@ || 'Erro desconhecido';
    $self->_remove_stall_watch;
    $self->log->error("Job $job_name falhou: $error");
    return { success => 0, error => $error, duration => time - $start };
  };
  $self->_remove_stall_watch;
  
  my $duration = time - $start;
  $self->log->info("Job $job_name concluído em ${duration}s");
  return { success => 1, duration => $duration };
}

sub run_all ($self, $job_names = []) {
  $self->load_jobs($job_names);
  
  my @jobs = @$job_names ? @$job_names : keys %{$self->jobs};
  my @results;
  
  for my $name (@jobs) {
    my $result = $self->run_job($name);
    push @results, { job => $name, %$result };
  }
  
  return \@results;
}

sub run_scheduled ($self, $schedule = 'daily') {
  $self->load_jobs;
  
  my @scheduled = grep { $_->schedule eq $schedule } values %{$self->jobs};
  
  $self->log->info("Executando $schedule jobs: " . join(', ', map { $_->job_name } @scheduled));
  
  my @results;
  for my $job (@scheduled) {
    my $result = $self->run_job($job->job_name);
    push @results, { job => $job->job_name, %$result };
  }
  
  return \@results;
}

1;
