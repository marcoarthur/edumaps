use strictures 2;
use lib qw(t/lib lib);
use Imports;
use ok 'EventBus';
use Mojo::IOLoop;
use Mojo::Promise;
use open ':std', ':encoding(UTF-8)';
use utf8;

my $tag = '[EventBus]:';

subtest qq/
  $tag <Inscrições Pub\/Sub Básicas (on, once, onAny)>
    - valida recebimento de eventos, payloads e desinscrição
/ => sub {
  my $bus = EventBus->new;
  my $called_count = 0;
  my $last_payload;

  # 1. Teste de inscricao simples com on()
  my $unsub = $bus->on('user.created' => sub ($payload, $event) {
      $called_count++;
      $last_payload = $payload;
    });

  $bus->emit('user.created', { id => 1, name => 'Ubatuba' });
  is($called_count, 1, 'Handler disparado na primeira emissão');
  is($last_payload->{name}, 'Ubatuba', 'Payload correto entregue');

  # 2. Desinscrição
  $unsub->();
  $bus->emit('user.created', { id => 2, name => 'Caraguatatuba' });
  is($called_count, 1, 'Handler não disparado após unsubscribe');

  # 3. Teste de once()
  my $once_count = 0;
  $bus->once('order.placed' => sub ($payload, $event) {
      $once_count++;
    });

  $bus->emit('order.placed', { order_id => 100 });
  $bus->emit('order.placed', { order_id => 101 });
  is($once_count, 1, 'once() executa exatamente 1 vez e se desinscreve');

  # 4. Teste de onAny()
  my @global_events;
  my $unsub_any = $bus->onAny(sub ($payload, $event) {
      push @global_events, $event->{type};
    });

  $bus->emit('school.updated', { id => 10 });
  $bus->emit('census.processed', { total => 500 });
  is(\@global_events, ['school.updated', 'census.processed'], 'onAny captura todas as emissões');

  $unsub_any->();
  $bus->emit('school.updated', { id => 11 });
  is(scalar @global_events, 2, 'onAny desinscrito com sucesso');
};

subtest qq/
  $tag <Cadeia de Middlewares (use)>
  - valida interceptação, enriquecimento e cancelamento de eventos
/ => sub {
  my $bus = EventBus->new;
  my @execution_order;

  # Middleware 1: Logging / Adiciona metadata
  $bus->use(sub ($evt, $next) {
      push @execution_order, 'mw1_start';
      $evt->{payload}{traced} = 1;
      $next->($evt);
      push @execution_order, 'mw1_end';
    });

  # Middleware 2: Modifica ou valida payload
  $bus->use(sub ($evt, $next) {
      push @execution_order, 'mw2_start';
      $next->($evt);
      push @execution_order, 'mw2_end';
    });

  my $handler_executed = 0;
  $bus->on('test.event' => sub ($payload, $event) {
      push @execution_order, 'handler';
      $handler_executed = 1;
      ok($payload->{traced}, 'Middleware modificou o evento antes do handler');
    });

  $bus->emit('test.event', { msg => 'hello' });

  is($handler_executed, 1, 'Handler foi executado no final da cadeia');
  is(
    \@execution_order,
    ['mw1_start', 'mw2_start', 'handler', 'mw2_end', 'mw1_end'],
    'Cadeia de middlewares seguiu o padrão Onion (Koa/Express)'
  );

  # Teste de cancelamento por Middleware (sem chamar $next)
  my $bus_short = EventBus->new;
  $bus_short->use(sub ($evt, $next) {
      # Bloqueia se payload for inválido
      return if $evt->{payload}{blocked};
      $next->($evt);
    });

  my $blocked_called = 0;
  $bus_short->on('test.event' => sub ($payload, $event) { $blocked_called++ });

  $bus_short->emit('test.event', { blocked => 1 });
  is($blocked_called, 0, 'Middleware bloqueou a execução da cadeia');
};

subtest qq/
  $tag <Assincronismo e Timeouts (waitFor)>
  - testa resolução de promise por evento e limite de timeout
/ => sub {
  # 1. Sucesso no waitFor (evento disparado dentro do tempo)
  subtest 'Resolução com sucesso dentro do prazo' => sub {
    my $bus = EventBus->new;

    # Agenda um disparo para daqui 10ms usando o EventLoop do Mojo
    Mojo::IOLoop->timer(0.01 => sub {
        $bus->emit('async.data', { status => 'complete' });
      });

    my $p = $bus->waitFor('async.data', timeoutMs => 1000);

    # Aguarda a resolução da promise no IOLoop
    my $result;
    $p->then(sub($res){ $result = $res })->wait;
    is($result->{status}, 'complete', 'waitFor resolveu com o payload correto');
  };

  # 2. Timeout expirado no waitFor
  subtest 'Rejeição por timeout' => sub {
    my $bus = EventBus->new;

    # Configura um timeout curto (50ms) e NÃO emite o evento
    my $p = $bus->waitFor('never.happens', timeoutMs => 50);

    my $error;
    $p->catch(sub ($err) { $error = $err })->wait;

    like(
      $error,
      qr/Event 'never\.happens' expirou após 50ms/,
      'Promise foi rejeitada com a mensagem de timeout esperada'
    );
  };
};

subtest qq/
  $tag <Comandos Request \/ Response (handle e request)>
  - valida chamadas síncronas, assíncronas (async\/await) e erros
/ => sub {
  my $bus = EventBus->new;

  # 1. Handler Síncrono
  $bus->handle('calculate.sum' => sub ($payload) {
      return $payload->{a} + $payload->{b};
    });

  my $res;
  $bus->request('calculate.sum', { a => 10, b => 20 })
  ->then( sub ($sum) {$res = $sum} )->wait;
  is($res, 30, 'Comando síncrono respondeu corretamente');

  # 2. Handler Assíncrono (Retorna Mojo::Promise / async)
  $bus->handle('fetch.remote' => sub ($payload) {
      my $promise = Mojo::Promise->new;
      Mojo::IOLoop->timer(0.01 => sub {
          $promise->resolve({ data => 'census_2024' });
        });
      return $promise;
    });

  my $async_res;
  $bus->request('fetch.remote')->then(sub ($res) { $async_res = $res })->wait;
  is($async_res->{data}, 'census_2024', 'Comando assíncrono (Promise) resolvido via request');

  # 3. Exceção para comandos duplicados
  eval {
    $bus->handle('calculate.sum' => sub { });
  };
  like($@, qr/Já existe um handler registrado para o comando/, 'Impede re-registro de comandos existentes');

  # 4. Exceção para comando inexistente
  my $err;
  $bus->request('unknown.command')->catch(sub ($e) { $err = $e })->wait;
  like($err, qr/Nenhum handler registrado para o comando "unknown.command"/, 'Lança erro ao chamar comando sem handler');
};

subtest qq/
  $tag <Ciclo de Vida e Destruição (destroy)>
  - garante limpeza total de recursos e proteção contra chamadas pós-morte
/ => sub {
  my $bus = EventBus->new;

  $bus->on('evt' => sub { });
  $bus->use(sub { });
  $bus->handle('cmd' => sub { });

  # Destrói a instância
  $bus->destroy;
  ok($bus->destroyed, 'Flag destroyed ativado com sucesso');

  # Tentar registrar ou emitir após destruído deve lançar exceção
  eval { $bus->on('evt' => sub { }) };
  like($@, qr/EventBus já foi destruído/, 'on() lança exceção em objeto destruído');

  eval { $bus->emit('evt') };
  like($@, qr/EventBus já foi destruído/, 'emit() lança exceção em objeto destruído');

  eval { $bus->handle('cmd2' => sub { }) };
  like($@, qr/EventBus já foi destruído/, 'handle() lança exceção em objeto destruído');

  eval { $bus->waitFor('evt') };
  like($@, qr/EventBus já foi destruído/, 'waitFor() lança exceção em objeto destruído');

  # Destruir uma segunda vez deve ser idempotente (não lança erro)
  eval { $bus->destroy };
  is($@, '', 'Segundo chamamento de destroy() é inofensivo');
};

# --- 1. Removendo Middlewares e Comandos via callback (unsubscribe) ---
subtest qq/
  $tag <Desinscrição de Middlewares e Comandos (unsubscribe)>
  - valida a remoção correta de middlewares e handlers de comando executando o coderef retornado
/ => sub {
  my $bus = EventBus->new;

  # Unsubscribe Middleware
  my $unsub_mw = $bus->use(sub { $_[1]->($_[0]) });
  is(scalar @{$bus->middlewares}, 1, 'Middleware registrado com sucesso');
  $unsub_mw->();
  is(scalar @{$bus->middlewares}, 0, 'Middleware removido com sucesso via callback');

  # Unsubscribe Command
  my $unsub_cmd = $bus->handle('ping' => sub { 'pong' });
  ok(exists $bus->commands->{ping}, 'Comando registrado com sucesso');
  $unsub_cmd->();
  ok(!exists $bus->commands->{ping}, 'Comando removido com sucesso via callback');
};

# --- 2. Captura de Exceções e Emissão de Avisos (eval / $@ / warn) ---
subtest qq/
  $tag <Tratamento de Exceções em Handlers e Callbacks>
  - garante que falhas em handlers de evento e no callback onAny emitam avisos via warn sem interromper o ciclo
/ => sub {
  my $bus = EventBus->new;

  $bus->on('fail_event' => sub { die "falha no handler\n" });
  $bus->onAny(sub { die "falha no onAny\n" });

  my @warnings;
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };

  $bus->emit('fail_event');

  like($warnings[0] // '', qr/Erro no handler para 'fail_event'/, 'Aviso emitido para falha no handler específico');
  like($warnings[1] // '', qr/Erro no handler onAny/, 'Aviso emitido para falha no handler onAny');
};

# --- 3. Execução de Unsubscribes em Objeto Destruído ---
subtest qq/
  $tag <Desinscrição em Objeto Destruído>
  - garante que invocar callbacks de unsubscribe após destroy() seja inofensivo e não lance exceções
/ => sub {
  my $bus = EventBus->new;

  my $unsub_on  = $bus->on('evt' => sub { });
  my $unsub_any = $bus->onAny(sub { });
  my $unsub_mw  = $bus->use(sub { });
  my $unsub_cmd = $bus->handle('cmd' => sub { });

  $bus->destroy;

  eval {
    $unsub_on->();
    $unsub_any->();
    $unsub_mw->();
    $unsub_cmd->();
  };
  is($@, '', 'Chamadas de unsubscribe em objeto destruído são silenciosas e não lançam erro');
};

# --- 4. Sobrescrita de 'source' no emit ---
subtest qq/
  $tag <Opções de Emissão de Eventos (source)>
  - valida a atribuição e o repasse explícito do parâmetro source no meta-objeto do evento
/ => sub {
  my $bus = EventBus->new;

  $bus->on('custom_evt' => sub {
      my ($payload, $evt) = @_;
      is($evt->{source}, 'origem_customizada', 'Campo source informado explicitamente é preservado');
    });

  $bus->emit('custom_evt', {}, source => 'origem_customizada');
};

done_testing;
