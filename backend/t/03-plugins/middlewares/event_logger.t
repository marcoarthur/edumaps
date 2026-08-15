use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(decode_json);
use Mojo::IOLoop;
use open ':std', ':encoding(UTF-8)';
use utf8;

# Inicializa o app através do Test::Mojo
my $t   = Test::Mojo->new('EduMaps');
my $app = $t->app;

# 1. Verifica se a integração com Postgres (Mojo::Pg) está disponível
unless ($app->pg) {
  plan skip_all => 'Mojo::Pg não disponível para testes de integração';
}

my $db = $app->pg->db;

# 2. Garante que a tabela event_store existe e limpa registros anteriores
eval { $db->delete('event_store') };
if ($@) {
  plan skip_all => 'Tabela event_store ausente. Execute as migrations do Sqitch antes de rodar os testes.';
}

# --- SUBTESTES ---

subtest 'Gravação assíncrona de evento válido' => sub {
  my $test_ibge  = '3550308'; # São Paulo
  my $event_type = 'city.details.requested';

  # Dispara evento no EventBus
  $app->event_bus->emit(
    $event_type,
    {
      codigo_ibge    => $test_ibge,
      is_speculative => 0,
      user_agent     => 'TestAgent/1.0',
    },
    source => 'Test::EventLogger'
  );

  # Como a gravação é feita via Promise não-bloqueante (insert_p),
  # avançamos o IOLoop em ticks até a gravação ser efetuada no Postgres
  my $row;
  for (1 .. 10) {
    $row = $db->select('event_store', '*', { event_type => $event_type, codigo_ibge => $test_ibge })->hash;
    last if $row;
    Mojo::IOLoop->one_tick;
  }

  ok $row, 'Evento foi persistido assincronamente na tabela event_store';
  is $row->{event_type},     $event_type,          'event_type gravado corretamente';
  is $row->{codigo_ibge},    $test_ibge,           'codigo_ibge gravado corretamente';
  is $row->{source},         'Test::EventLogger',  'source da origem correto';
  is $row->{is_speculative}, 0,                    'Flag is_speculative com valor 0';

  # Valida deserialização do Payload JSONB
  my $payload = decode_json($row->{payload});
  is $payload->{user_agent}, 'TestAgent/1.0', 'Conteúdo do payload JSON retido com integridade';
};

subtest 'Eventos ignorados não devem ser persistidos' => sub {
  my $ping_type = 'system.ping';

  $app->event_bus->emit(
    $ping_type,
    { timestamp => time() },
    source => 'Test::Ping'
  );

  # Roda alguns ticks do IOLoop para dar tempo de um (indesejado) insert acontecer
  Mojo::IOLoop->one_tick for 1 .. 3;

  my $count = $db->select('event_store', 'COUNT(*)', { event_type => $ping_type })->array->[0];
  is $count, 0, 'Evento "system.ping" configurado para descarte não foi gravado no banco';
};

# --- TEARDOWN DE TESTES ---
# O bloco END executa no encerramento da suíte (mesmo em caso de falha de asserção)
END {
  if ($app->pg) {
    eval {
      # Remove os jobs do Minion agendados pelo SiopeTask durante este teste
      $app->pg->db->delete('minion_jobs', { task => 'query_siope' });

      # Limpa os registros de teste da event_store
      $app->pg->db->delete('event_store');
    };
  }
}

done_testing();
