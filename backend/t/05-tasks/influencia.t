use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Task Minion `refresh_influencia` (#255/#137, influencia-v1): dispara
# clean.refresh_escola_influencia(). A lógica/validação de geometria está em
# t/escola_influencia.t (função SQL); aqui só se guarda o wiring — a task e o
# helper têm de existir quando a app carrega (senão o plugin nem registra).

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $app    = $t->app;
my $minion = $app->minion;

subtest 'task Minion registrada' => sub {
  ok $minion->tasks->{refresh_influencia}, 'refresh_influencia registrada no Minion';
};

subtest 'helper disponível na app' => sub {
  ok $app->helper('refresh_influencia'), 'helper refresh_influencia instalado';
};

done_testing;
