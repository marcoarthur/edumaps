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

# 2. Garante que as tabelas existem. Sem apagar a telemetria do banco: os
#    eventos do teste levam marca própria (UA com o PID e sessões fixas), e só
#    eles são removidos no fim.
eval { $db->query('SELECT 1 FROM event_store LIMIT 0'); $db->query('SELECT 1 FROM session_tracking LIMIT 0') };
if ($@) {
  plan skip_all => 'Tabelas event_store/session_tracking ausentes. Execute as migrations do Sqitch antes de rodar os testes.';
}

# Helper: dispara o flush manual do EventLogger (comando registrado pelo
# middleware na primeira gravação) e devolve o nº de eventos persistidos.
sub flush_logger {
  my $res = $app->event_bus->request('event_logger.flush');
  return $res;
}

my $UA      = "TestAgent/1.0 ($$)";
my @SESSOES = ('abc123', 'sessao-teste-1');
my @FONTES  = ('Test::EventLogger', 'T', 'Test::Ping');

# O evento de cidade aciona o middleware SiopeTask, que enfileiraria um job
# SIOPE de verdade (o minion local o executaria contra a rede). Este teste é do
# EventLogger: o helper vira um stub que só anota a chamada.
my @SIOPE;
$app->helper(get_siope => sub { my ($c, @args) = @_; push @SIOPE, [@args]; return 0 });

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
      user_agent     => $UA,
    },
    source => 'Test::EventLogger'
  );

  # Nada no banco ANTES do flush (buffer em memória)
  my $doteste = \["payload->>'user_agent' = ?", $UA];
  my $pre = $db->select('event_store', 'COUNT(*)', { event_type => $event_type, codigo_ibge => $test_ibge, -and => [$doteste] })->array->[0];
  is $pre, 0, 'Evento ainda não persistido antes do flush (bufferizado)';

  flush_logger();

  my $row = $db->select('event_store', '*', { event_type => $event_type, codigo_ibge => $test_ibge, -and => [$doteste] })->hash;
  ok $row, 'Evento persistido após o flush';
  is $row->{event_type},     $event_type,          'event_type gravado corretamente';
  is $row->{codigo_ibge},    $test_ibge,           'codigo_ibge gravado corretamente';
  is $row->{source},         'Test::EventLogger',  'source da origem correto';
  is $row->{is_speculative}, 0,                    'Flag is_speculative com valor 0';

  # Valida deserialização do Payload JSONB
  my $payload = decode_json($row->{payload});
  is $payload->{user_agent}, $UA, 'Conteúdo do payload JSON retido com integridade';
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
      # Só os registros deste teste
      $app->pg->db->delete('event_store', { source => { -in => \@FONTES } });
      $app->pg->db->delete('event_store', { session_id => { -in => \@SESSOES } });
      $app->pg->db->delete('session_tracking', { session_id => { -in => \@SESSOES } });
    };
  }
}

done_testing();