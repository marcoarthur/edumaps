package EduMaps::Ingestion::CLI;
use Mojo::Base -base, -signatures;

use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use EduMaps::Ingestion::Runner;

sub run ($class, @argv) {
  my %opts = (
    job => '',
    schedule => '',
    list => 0,
    dry_run => 0,
    config => '',
  );
  
  GetOptionsFromArray \@argv,
    'job=s'      => \$opts{job},
    'schedule=s' => \$opts{schedule},
    'list'       => \$opts{list},
    'dry-run'    => \$opts{dry_run},
    'config=s'   => \$opts{config},
    'help|h'     => sub { $class->usage(); exit 0 };
  
  my $runner = EduMaps::Ingestion::Runner->new(
    dry_run => $opts{dry_run},
    config  => $opts{config}
  );
  
  if ($opts{list}) {
    $class->list_jobs();
    return;
  }
  
  if ($opts{schedule}) {
    my $runner = EduMaps::Ingestion::Runner->new(dry_run => $opts{dry_run});
    my $results = $runner->run_scheduled($opts{schedule});
    $class->print_results($results);
    return;
  }
  
  if ($opts{job}) {
    my $runner = EduMaps::Ingestion::Runner->new(dry_run => $opts{dry_run});
    $runner->load_jobs([$opts{job}]);
    my $result = $runner->run_job($opts{job});
    $class->print_results([{ job => $opts{job}, %$result }]);
    return;
  }
  
  # Default: roda todos
  my $runner_all = EduMaps::Ingestion::Runner->new(dry_run => $opts{dry_run});
  my $results = $runner_all->run_all;
  $class->print_results($results);
}

sub list_jobs ($class) {
  my @jobs = qw(
    BrazilCrime MapBiomas INMET ANTT Transportes
    SICONFI INEP MedidorConectada FNDE
    SecretariasMunicipais CensoEscolar
  );
  
  print "Jobs disponíveis:\n";
  for my $name (@jobs) {
    eval "require EduMaps::Ingestion::Job::$name";
    my $job = "EduMaps::Ingestion::Job::$name"->new(
      log => Mojo::Log->new,
      config => {},
      dry_run => 1,
      app => undef,  # will be set by runner when actually running
    );
    printf "  %-25s %s (%s)\n", $name, $job->description, $job->schedule;
  }
}

sub print_results ($class, $results) {
  print "\n=== RESULTADOS ===\n";
  for my $r (@$results) {
    my $status = $r->{success} ? '✓' : '✗';
    printf "%s %-25s %6ds %s\n", $status, $r->{job}, $r->{duration}, $r->{error} // '';
  }
}

sub usage ($class) {
  print <<"USAGE";
Uso: ingestion_runner.pl [opções]

Opções:
  --job=NOME           Executa job específico (ex: BrazilCrime)
  --schedule=TIPO      Executa jobs agendados (daily, weekly, monthly)
  --list               Lista jobs disponíveis
  --dry-run            Simula execução sem persistir
  --config=ARQUIVO     Arquivo de configuração
  --help, -h           Mostra esta ajuda

Exemplos:
  perl ingestion_runner.pl --job=BrazilCrime
  perl ingestion_runner.pl --schedule=daily
  perl ingestion_runner.pl --list
  perl ingestion_runner.pl --dry-run --job=BrazilCrime
USAGE
}

1;