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
  
  eval {
    $job->run($args);
    1;
  } or do {
    my $error = $@ || 'Erro desconhecido';
    $self->log->error("Job $job_name falhou: $error");
    return { success => 0, error => $error, duration => time - $start };
  };
  
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
