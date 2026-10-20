use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Task Minion `refresh_ivet` (#296): enfileira o refresh do IVET
# materializado na fila `analytics` (POST /ivet/refresh no Plumber ->
# ivet_refresh() -> upsert em analytics.ivet_escola). A medição em si é
# do serviço analítico — aqui só se guarda o wiring: a task e o helper
# têm de existir quando a app carrega (senão o plugin nem registra).

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $app    = $t->app;
my $minion = $app->minion;

subtest 'task Minion registrada' => sub {
  ok $minion->tasks->{refresh_ivet}, 'refresh_ivet registrada no Minion';
};

subtest 'helper disponível na app' => sub {
  # ⚠️ NÃO usar $app->helper('nome') como getter: com um só argumento ele
  # é add_helper($nome, undef) — sobrescreve o helper e quebra o dynamic
  # method do controller. O getter real é renderer->get_helper.
  ok $app->renderer->get_helper('apply_ivet_refresh'),
    'helper apply_ivet_refresh instalado';
};

subtest 'helper enfileira na fila analytics' => sub {
  my $c = $app->build_controller;

  my $id = $c->apply_ivet_refresh();
  ok $id, 'job enfileirado';

  my $job = $minion->job($id);
  ok $job, 'job existe no Minion';
  is $job->info->{queue}, 'analytics', 'na fila analytics';
  is $job->task, 'refresh_ivet', 'task refresh_ivet';

  my $args = $job->args;
  is scalar @$args, 1, 'um hashref de argumentos';
  is scalar keys %{$args->[0]}, 0, 'sem argumentos = defaults';

  # com argumentos explícitos, os args passam adiante para o client
  my $id2 = $c->apply_ivet_refresh({ censo_ano => 2024, raio_m => 2000 });
  my $args2 = $minion->job($id2)->args;
  is $args2->[0]{censo_ano}, 2024, 'censo_ano preservado';
  is $args2->[0]{raio_m}, 2000, 'raio_m preservado';
};

done_testing;
