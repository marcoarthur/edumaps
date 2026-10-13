package EduMaps::Ingestion::CLI;
use Mojo::Base -base, -signatures;
use utf8;

use Encode ();

use Getopt::Long qw(GetOptionsFromArray :config no_ignore_case);
use Mojo::File qw(path);
use EduMaps::Ingestion::Runner;

# Devolve o código de saída do processo: 0 só se TODOS os jobs tiverem
# sucesso. Antes disto o runner imprimia `✗` e saía com 0, portanto um cron,
# um CI ou um `&&` viajavam na ideia de que a carga tinha corrido — que é
# exactamente o modo de falha silencioso que a #156 denuncia.
#
# Códigos de saída (#231):
#   0  todos os jobs executados tiveram sucesso
#   1  pelo menos um job FALHOU (erro de rede, dado, bug, allowlist, stall)
#   3  nenhum falhou, mas pelo menos um ficou NÃO CARREGADO por bloqueio
#      conhecido (e-SIC não protocolado, API retirada, fora do objetivo) —
#      não é sucesso, e não pode ser confundido com ele num cron/`&&`
#   2  uso inválido da linha de comando (ex.: --arg mal formado)
use constant {
  EXIT_OK            => 0,
  EXIT_FALHA         => 1,
  EXIT_USO           => 2,
  EXIT_NAO_CARREGADA => 3,
};

sub run ($class, @argv) {
  my %opts = (
    job => '',
    schedule => '',
    list => 0,
    dry_run => 0,
    config => '',
  );
  my @args_brutos;

  GetOptionsFromArray \@argv,
    'job=s'      => \$opts{job},
    'schedule=s' => \$opts{schedule},
    'list'       => \$opts{list},
    'dry-run'    => \$opts{dry_run},
    'config=s'   => \$opts{config},
    'arg=s'      => \@args_brutos,
    '--stall-timeout=i'        => \$opts{stall_timeout},
    '--stall-check-interval=i' => \$opts{stall_check_interval},
    'help|h'     => sub { $class->usage(); exit 0 };
  
  my $args = eval { $class->parse_args(@args_brutos) };
  if (my $err = $@) {
    _saida(\*STDERR, $err);
    return EXIT_USO;
  }

  my $config = $class->load_config($opts{config});
  my $runner = EduMaps::Ingestion::Runner->new(
    dry_run                 => $opts{dry_run},
    config                  => $config,
    (defined $opts{stall_timeout}        ? (stall_timeout        => $opts{stall_timeout})        : ()),
    (defined $opts{stall_check_interval} ? (stall_check_interval => $opts{stall_check_interval}) : ()),
  );
  
  if ($opts{list}) {
    $class->list_jobs();
    return 0;
  }
  
  my $results =
      $opts{schedule} ? $runner->run_scheduled($opts{schedule})
    : $opts{job}      ? do {
        $runner->load_jobs([$opts{job}]);
        my $r = $runner->run_job($opts{job}, $args);
        [{ job => $opts{job}, %$r }];
      }
    :                    $runner->run_all([], $args);

  $class->print_results($results);
  return $class->exit_code($results);
}

# `--arg chave=valor` (repetível) -> hashref repassado ao `$job->run($args)`.
#
# Decisões (#231):
#   - o valor é SEMPRE string; vírgula NÃO vira lista aqui, porque há jobs
#     em que a vírgula é sintaxe da própria fonte (o período do SIDRA,
#     `--arg anos=2019,2020`). Quem aceita lista divide com
#     Base::arg_lista (ex.: SICONFI `--arg uf=SP,RJ`);
#   - a mesma chave repetida vira arrayref (`--arg uf=SP --arg uf=RJ`), que o
#     arg_lista também aceita;
#   - `--arg chave` sem `=` vale 1 (bandeira: `--arg dca`);
#   - chave tem de ser identificador (letras, dígitos, _); senão morre.
sub parse_args ($class, @brutos) {
  my %args;
  for my $b (@brutos) {
    $b = _texto($b);
    my ($k, $v) = $b =~ /=/ ? split(/=/, $b, 2) : ($b, 1);
    die "--arg inválido: '$b' (use --arg chave=valor; chave = letras, dígitos e _)\n"
      unless defined $k && $k =~ /\A[A-Za-z_]\w*\z/;
    if (exists $args{$k}) {
      $args{$k} = [ ref $args{$k} ? @{ $args{$k} } : $args{$k}, $v ];
    }
    else {
      $args{$k} = $v;
    }
  }
  return \%args;
}

sub exit_code ($class, $results) {
  my $falhas = grep { !$_->{success} && !$_->{nao_carregada} } @$results;
  my $nc     = grep { $_->{nao_carregada} } @$results;
  return $falhas ? EXIT_FALHA : $nc ? EXIT_NAO_CARREGADA : EXIT_OK;
}

# Texto para o terminal. Os módulos com `use utf8` dão caracteres; uma
# string sem a flag (mensagem de DBI, de outro módulo sem `use utf8`) é
# tratada como bytes UTF-8 e decodificada — se não for UTF-8 válido, passa
# como Latin-1. Assim o handle pode ficar em :encoding(UTF-8) sem mojibake e
# sem "Wide character".
sub _texto ($s) {
  return '' unless defined $s;
  return $s if utf8::is_utf8($s) || $s !~ /[\x80-\xff]/;
  my $copia = $s;
  my $d = eval { Encode::decode('UTF-8', $copia, Encode::FB_CROAK()) };
  return defined $d ? $d : $s;
}

sub _saida ($fh, @partes) {
  binmode $fh, ':encoding(UTF-8)';
  print {$fh} map { _texto($_) } @partes;
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

  _saida(\*STDOUT, "Jobs disponíveis:\n");
  for my $name (@jobs) {
    eval "require EduMaps::Ingestion::Job::$name";
    next if $@;
    my $job = "EduMaps::Ingestion::Job::$name"->new(
      log => Mojo::Log->new,
      config => {},
      dry_run => 1,
      app => undef,  # --list não toca na BD; nunca se acede a ->schema
    );
    _saida(\*STDOUT, sprintf("  %-25s %s (%s)\n", $name, _texto($job->description), $job->schedule));
  }
}

# Devolve o NÚMERO de jobs sem sucesso (falhados + não carregados) — quem
# decide o código de saída é `exit_code`.
sub print_results ($class, $results) {
  _saida(\*STDOUT, "\n=== RESULTADOS ===\n");
  my ($falhas, $nc) = (0, 0);
  for my $r (@$results) {
    my $status = $r->{success} ? '✓' : $r->{nao_carregada} ? '⊘' : '✗';
    _saida(\*STDOUT, sprintf("%s %-25s %6ds %s\n", $status, $r->{job},
      $r->{duration} // 0, _texto($r->{error} // '')));
    next if $r->{success};
    $r->{nao_carregada} ? $nc++ : $falhas++;
  }
  _saida(\*STDOUT, sprintf("\n%d job(s) executado(s), %d falha(s), %d não carregado(s)\n",
    scalar @$results, $falhas, $nc));
  return $falhas + $nc;
}

sub usage ($class) {
  _saida(\*STDOUT, <<"USAGE");
Uso: ingestion_runner.pl [opções]

Opções:
  --job=NOME           Executa job específico (ex: BrazilCrime)
  --schedule=TIPO      Executa jobs agendados (daily, weekly, monthly)
  --list               Lista jobs disponíveis
  --dry-run            Simula execução sem gravar na base de dados
  --config=ARQUIVO     Arquivo de configuração (hashref Perl)
  --arg CHAVE=VALOR    Argumento repassado ao job (repetível). O valor é
                       string; vírgula não vira lista (o job decide: o
                       SICONFI aceita uf=SP,RJ; o IBGE repassa anos=2019,2020
                       ao SIDRA). Chave repetida vira lista. Sem "=" vale 1.
  --stall-timeout=N    Segundos sem progresso antes de abortar (padrão 600)
  --stall-check-interval=N  Intervalo de verificação de progresso (padrão 60)
  --help, -h           Mostra esta ajuda

Exemplos:
  perl ingestion_runner.pl --job=BrazilCrime
  perl ingestion_runner.pl --schedule=daily
  perl ingestion_runner.pl --list
  perl ingestion_runner.pl --dry-run --job=BrazilCrime
  perl ingestion_runner.pl --job=SICONFI --arg uf=SP,RJ --arg exercicio=2025
  perl ingestion_runner.pl --job=SICONFI --arg uf=SP --arg dca --arg exercicio=2024
  perl ingestion_runner.pl --job=IBGE --arg anos=2019,2020,2021

Args por job:
  SICONFI  cod_ibge | uf=SP,RJ | todos; exercicio, nr_periodo, dca,
           max_municipios, dt_snapshot
  IBGE     anos (sintaxe do SIDRA: "last 10", "2019,2020", "2010-2021")

Os downloads ficam preservados em <raw_dir>/<fonte>/<AAAA-MM-DD>/
(raw_dir: --config raw_dir, ou EDUMAPS_RAW_DIR, ou /srv/edumaps/raw).

Código de saída: 0 = todos com sucesso; 1 = pelo menos uma falha;
3 = nenhuma falha, mas fonte(s) NÃO CARREGADA(S) por bloqueio conhecido
(e-SIC, API retirada, fora do objetivo); 2 = uso inválido.
USAGE
}

1;
