# t/05-tasks/siope_recarga.t
# #536: recarregar a folha do mesmo município e ano troca as linhas, sem
# duplicar (a carga só inseria). A planilha é simulada: nada vai ao SIOPE.
use Mojo::Base -strict, -signatures;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use utf8;
use EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $minion = $t->app->minion;
my $rs = $t->app->schema->resultset('RemuneracaoMunicipal');
my ($COD, $ANO, $FILA) = ('600536', 2001, "teste_recarga_$$");
my @JOBS;

my $limpa = sub { $rs->search({ cod_municipio => $COD })->delete };
$limpa->();
END {
  $limpa->() if $rs;
  for my $id (@JOBS) { my $j = $minion->job($id) or next; $j->remove }
}

# Linhas como saem de get_and_process (16 colunas; a task acrescenta o
# município e a rede).
my @PLANILHA;
{
  no warnings 'redefine';
  *EduMaps::Task::Siope::Scrap::SpreadSheet::Gastos::get_and_process = sub ($self) {
    return [ map { [@$_] } @PLANILHA ];
  };
}
sub linha ($nome, $mes) {
  return [$ANO, $mes, $nome, 'xxx.111.222-xx', 60053601, 'ESCOLA DO TESTE', 40,
          'Profissionais do magistério', 'Docente', 'Efetivo', 'Ensino fundamental', 1000, 0, 0, 0, 1000];
}

sub carregar () {
  local $t->app->config->{minion_filas}{query_siope} = $FILA;
  my $id = $t->app->get_siope($COD, $ANO);
  push @JOBS, $id;
  $minion->perform_jobs({ queues => [$FILA] });
  return $minion->job($id);
}

@PLANILHA = (linha('GONÇALVES DO TESTE', 'Janeiro'), linha('GONÇALVES DO TESTE', 'Fevereiro'));
my $job = carregar();
is $job->info->{state}, 'finished', 'primeira carga';
is $rs->search({ cod_municipio => $COD, ano => $ANO })->count, 2, 'duas linhas';

@PLANILHA = (linha('GONÇALVES DO TESTE', 'Janeiro'), linha('GONÇALVES DO TESTE', 'Fevereiro'), linha('GONÇALVES DO TESTE', 'Março'));
$job = carregar();
is $job->info->{state}, 'finished', 'recarga';
is $rs->search({ cod_municipio => $COD, ano => $ANO })->count, 3, 'troca as linhas, sem duplicar (3, não 5)';

done_testing;
