use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Task Minion `refresh_entorno_socioeconomico` (#137, bloco B / Tier 3): dispara
# clean.refresh_escola_entorno_socioeconomico(). A lógica/validação da
# arealização está em t/escola_entorno_socioeconomico.t (função SQL); aqui só se
# guarda o wiring — a task e o helper têm de existir quando a app carrega
# (senão o plugin nem registra).

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $app    = $t->app;
my $minion = $app->minion;

subtest 'task Minion registrada' => sub {
  ok $minion->tasks->{refresh_entorno_socioeconomico},
    'refresh_entorno_socioeconomico registrada no Minion';
};

subtest 'helper disponível na app' => sub {
  ok $app->helper('refresh_entorno_socioeconomico'),
    'helper refresh_entorno_socioeconomico instalado';
};

done_testing;
