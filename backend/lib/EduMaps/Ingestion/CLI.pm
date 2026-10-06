package EduMaps::Ingestion::CLI;
use Mojo::Base -base, -signatures;

use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Mojo::File qw(path);
use EduMaps::Ingestion::Runner;

# Devolve o código de saída do processo: 0 só se TODOS os jobs tiverem
# sucesso. Antes disto o runner imprimia `✗` e saía com 0, portanto um cron,
# um CI ou um `&&` viajavam na ideia de que a carga tinha corrido — que é
# exactamente o modo de falha silencioso que a #156 denuncia.
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
    config  => $class->load_config($opts{config}),
  );
  
  if ($opts{list}) {
    $class->list_jobs();
    return 0;
  }
  
  my $results =
      $opts{schedule} ? $runner->run_scheduled($opts{schedule})
    : $opts{job}      ? do {
        $runner->load_jobs([$opts{job}]);
        my $r = $runner->run_job($opts{job});
        [{ job => $opts{job}, %$r }];
      }
    :                    $runner->run_all;
  
  return $class->print_results($results) ? 1 : 0;
}

# `--config=ARQUIVO` chega como caminho; os jobs esperam um hashref
# (`$self->config->{dir_trabalho}`, `$self->config->{renavam_zip}`). O ramo
# `--job` e o ramo `--schedule` criavam Runners novos sem propagar a opção,
# por isso `--config` era lido e deitado fora.
sub load_config ($class, $file) {
  return {} unless defined $file && length $file;
  die "Arquivo de configuração não encontrado: $file\n" unless -f $file;
  my $conf = do "$file";
  die "Erro ao avaliar $file: $@" if $@;
  die "$file não retornou uma hashref (não termina com `;`?)\n" unless ref $conf eq 'HASH';
  return $conf;
}

sub list_jobs ($class) {
  my @jobs = EduMaps::Ingestion::Runner->job_names;

  print "Jobs disponíveis:\n";
  for my $name (@jobs) {
    eval "require EduMaps::Ingestion::Job::$name";
    next if $@;
    my $job = "EduMaps::Ingestion::Job::$name"->new(
      log => Mojo::Log->new,
      config => {},
      dry_run => 1,
      app => undef,  # --list não toca na BD; nunca se acede a ->schema
    );
    printf "  %-25s %s (%s)\n", $name, $job->description, $job->schedule;
  }
}

# Devolve o NÚMERO de jobs falhados — quem decide o código de saída é `run`.
#
# Sem `binmode :encoding(UTF-8)`: a maioria dos módulos em `Ingestion/Job/`
# não tem `use utf8`, portanto as suas strings são bytes UTF-8. Colocar o
# handle em `:encoding(UTF-8)` tornaria esses bytes em Latin-1 e corromperia
# o que hoje está correcto. Ver "encoding misto" no PR.
sub print_results ($class, $results) {
  print "\n=== RESULTADOS ===\n";
  my $falhas = 0;
  for my $r (@$results) {
    my $status = $r->{success} ? '✓' : '✗';
    printf "%s %-25s %6ds %s\n", $status, $r->{job}, $r->{duration} // 0, $r->{error} // '';
    $falhas++ unless $r->{success};
  }
  printf "\n%d job(s) executado(s), %d falha(s)\n", scalar @$results, $falhas;
  return $falhas;
}

sub usage ($class) {
  print <<"USAGE";
Uso: ingestion_runner.pl [opções]

Opções:
  --job=NOME           Executa job específico (ex: BrazilCrime)
  --schedule=TIPO      Executa jobs agendados (daily, weekly, monthly)
  --list               Lista jobs disponíveis
  --dry-run            Simula execução sem gravar na base de dados
  --config=ARQUIVO     Arquivo de configuração (hashref Perl)
  --help, -h           Mostra esta ajuda

Exemplos:
  perl ingestion_runner.pl --job=BrazilCrime
  perl ingestion_runner.pl --schedule=daily
  perl ingestion_runner.pl --list
  perl ingestion_runner.pl --dry-run --job=BrazilCrime

O código de saída é 0 só quando todos os jobs executados têm sucesso;
qualquer falha devolve 1.
USAGE
}

1;
