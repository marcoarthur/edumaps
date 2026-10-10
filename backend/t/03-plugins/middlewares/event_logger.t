use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::JSON qw(decode_json);
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

# 2. Garante que as tabelas existem e limpa registros anteriores
eval { $db->delete('event_store'); $db->delete('session_tracking') };
if ($@) {
  plan skip_all => 'Tabelas event_store/session_tracking ausentes. Execute as migrations do Sqitch antes de rodar os testes.';
}

# Helper: dispara o flush manual do EventLogger (comando registrado pelo
# middleware na primeira gravação) e devolve o nº de eventos persistidos.
sub flush_logger {
  my $res = $app->event_bus->request('event_logger.flush');
  return $res;
}

# --- SUBTESTES ---

subtest 'Gravação de evento válido via flush em lote' => sub {
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

  # Nada no banco ANTES do flush (buffer em memória)
  my $pre = $db->select('event_store', 'COUNT(*)', { event_type => $event_type, codigo_ibge => $test_ibge })->array->[0];
  is $pre, 0, 'Evento ainda não persistido antes do flush (bufferizado)';

  flush_logger();

  my $row = $db->select('event_store', '*', { event_type => $event_type, codigo_ibge => $test_ibge })->hash;
  ok $row, 'Evento persistido após o flush';
  is $row->{event_type},     $event_type,          'event_type gravado corretamente';
  is $row->{codigo_ibge},    $test_ibge,           'codigo_ibge gravado corretamente';
  is $row->{source},         'Test::EventLogger',  'source da origem correto';
  is $row->{is_speculative}, 0,                    'Flag is_speculative com valor 0';

  # Valida deserialização do Payload JSONB
  my $payload = decode_json($row->{payload});
  is $payload->{user_agent}, 'TestAgent/1.0', 'Conteúdo do payload JSON retido com integridade';
};

subtest 'IP é removido do payload persistido (LGPD — fica só na sessão)' => sub {
  my $event_type = 'session.request';
  $app->event_bus->emit(
    $event_type,
    {
      session_id => 'abc123',
      ip         => '203.0.113.9',
      user_agent => 'Agent/1.0',
      route      => '/api/school/search',
      status     => 200,
    },
    source => 'Test::EventLogger'
  );

  flush_logger();

  my $row = $db->select('event_store', '*', { event_type => $event_type, session_id => 'abc123' })->hash;
  ok $row, 'evento session.request persistido';
  my $payload = decode_json($row->{payload});
  ok !exists $payload->{ip}, 'IP não está no payload JSONB do event_store';
  is $payload->{user_agent}, 'Agent/1.0', 'user_agent mantido no payload';
};

subtest 'Sessão é agregada em session_tracking no flush' => sub {
  my $sid = 'sessao-teste-1';

  $app->event_bus->emit('session.request', { session_id => $sid, ip => '203.0.113.9', user_agent => 'Ua/1' }, source => 'T');
  $app->event_bus->emit('session.request', { session_id => $sid, ip => '203.0.113.9', user_agent => 'Ua/1' }, source => 'T');
  flush_logger();

  my $s = $db->select('session_tracking', '*', { session_id => $sid })->hash;
  ok $s, 'sessão criada em session_tracking';
  is $s->{seen_count}, 2, 'seen_count = 2 interações';
  is $s->{ip}, '203.0.113.9', 'IP registrado na dimensão de sessão';
  ok $s->{ip_anon}, 'ip_anon (HMAC) gerado para análise';
  isnt $s->{ip_anon}, $s->{ip}, 'ip_anon difere do IP cru';
  is $s->{is_logged}, 0, 'visitante anônimo (is_logged = false)';
};

subtest 'Eventos ignorados não devem ser persistidos' => sub {
  my $ping_type = 'system.ping';

  $app->event_bus->emit(
    $ping_type,
    { timestamp => time() },
    source => 'Test::Ping'
  );

  flush_logger();

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

      # Limpa os registros de teste do event_store e session_tracking
      $app->pg->db->delete('event_store');
      $app->pg->db->delete('session_tracking');
    };
  }
}

done_testing();