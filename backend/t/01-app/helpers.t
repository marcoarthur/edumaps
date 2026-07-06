# t/01-app/helpers.t
use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Test2::Mock;
use ok 'EduMaps';
use open ':std', ':encoding(UTF-8)';
use utf8;

my $tag = '[app basics] helpers:';

subtest qq/
$tag <monitoramento de Minion::Job>
  - monitorando com callback on_progress
  - disparo de callback on_finish
/ => sub {
  my $tester = Test::Mojo->new('EduMaps');

  # Variável para controlar os passos do loop do Job fictício
  my $loop_count = 1;

  # 1. Mock Minion::Job
  my $mock_job = Test2::Mock->new(
    class => 'Minion::Job',
    override => [
      info => sub {
        if ($loop_count == 1) {
          return { id => 123, state => 'active', notes => { progress => { percent => 40 } } };
        }
        elsif ($loop_count == 2 ) {
          return { id => 123, state => 'active', notes => { progress => { percent => 50 } } };
        }
        else {
          # Próxima iteração simula o job finalizado
          return { id => 123, state => 'finished', notes => { progress => { percent => 100 } }, result => { status => 'success' } };
        }
      }
    ]
  );

  # 2. Mock Minion para que ela retorne uma instância do Job mockado
  my $mock_minion = Test2::Mock->new(
    class => 'Minion',
    override => [
      job => sub ($, $id) {
        return $id == 123 ? bless({}, 'Minion::Job') : undef;
      }
    ]
  );

  # Varíáveis para capturar os retornos dentro das closures do helper
  my @progress_events;
  my $finished_result;

  # 3. Injetamos uma rota de teste no App
  $tester->app->routes->get('/test-monitor' => sub ($c) {
      $c->render_later; # Mantém a conexão aberta para o IOLoop trabalhar

      $c->monitor_job({
          job_id      => 123,
          poll_time   => 0.01, # Rápido para não segurar a suite de testes
          on_progress => sub ($msg) {
            $loop_count++; # avança o estado do job
            push @progress_events, $msg;
          },
          on_finish   => sub ($result) {
            $finished_result = $result;
            $c->render( text => 'Ok' );
          }
        });
    });

  # 4. Executa a requisição
  $tester->get_ok('/test-monitor')->text_is('Ok');

  # 5. Testa
  is scalar(@progress_events), 2, 'O callback on_progress foi acionado exatamente duas vezes';

  like $progress_events[0]->{text}, qr/"percent":40/, 'Primeiro evento reportou 40%';
  like $progress_events[1]->{text}, qr/"percent":50/, 'Segundo evento reportou 50%';

  is $finished_result, { status => 'success' },'O callback on_finish recebeu a estrutura esperada do Job';
};

done_testing;
