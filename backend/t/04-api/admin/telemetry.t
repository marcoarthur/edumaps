# t/04-api/admin/telemetry.t
# Testes da API de telemetria do Painel de Administração
# (/api/admin/telemetry/overview):
#   auth (401 sem token, 403 gestor comum, 200 admin), validação da janela,
#   KPIs agregados (logins por janela, sessões logadas/anônimas, rotas, busca,
#   série temporal) e ausência de dado pessoal na resposta. Só roda onde
#   event_store/session_tracking e gestor_access_role foram aplicados.
#
# O banco pode ter tráfego real na janela (stack local em uso): as contagens
# são conferidas como diferença sobre uma leitura feita antes de semear, e a
# ordem e os percentuais só quando a janela estava vazia (como no CI).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('clean.event_store')")
  && $dbh->selectrow_array("SELECT to_regclass('clean.session_tracking')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $INEP_ADMIN = '99999997';
my $INEP_USER  = '88888887';
my $ADMIN_EMAIL = sprintf('admin.telemetry.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.telemetry.%d@edumaps.test', $$);
my $SENHA = 'senha123';

my ($admin_token, $user_token);

my @SIDS = qw(tel-test-s1 tel-test-s2 tel-test-s3 tel-test-s4);

# Limite do ranking de rotas do painel.
use EduMaps::Roles::Business::Admin::Telemetry ();
my $TOP_ROTAS = $EduMaps::Roles::Business::Admin::Telemetry::TOP_ROUTES;

sub overview ($w) {
  $t->get_ok("/api/admin/telemetry/overview?window=$w", { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;
}

sub rotas ($d) { +{ map { $_->{route} => $_->{count} } @{ $d->{top_routes} // [] } } }
sub soma_serie ($d) { my $n = 0; $n += $_->{events} for @{ $d->{series} // [] }; $n }

END {
  return if !$has_tables;
  local $dbh->{RaiseError} = 0;
  $dbh->do('DELETE FROM clean.event_store WHERE session_id = ANY(?::text[])', {}, '{' . join(',', @SIDS) . '}');
  $dbh->do('DELETE FROM clean.session_tracking WHERE session_id = ANY(?::text[])', {}, '{' . join(',', @SIDS) . '}');
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

sub seed_telemetry {
  $dbh->do('DELETE FROM clean.event_store WHERE session_id = ANY(?::text[])', {}, '{' . join(',', @SIDS) . '}');
  $dbh->do('DELETE FROM clean.session_tracking WHERE session_id = ANY(?::text[])', {}, '{' . join(',', @SIDS) . '}');

  # Dimensão de sessão: S1/S2 logadas (gestores 101/102), S3 anônima, S4 logada
  # (gestor 103) há 20h — usada para exercitar o corte das janelas.
  my @track = (
    [ 'tel-test-s1', 1, 101, '30 minutes' ],
    [ 'tel-test-s2', 1, 102, '1 hour' ],
    [ 'tel-test-s3', 0, undef, '20 minutes' ],
    [ 'tel-test-s4', 1, 103, '20 hours' ],
  );
  for my $r (@track) {
    $dbh->do(
      q{INSERT INTO clean.session_tracking
          (session_id, ip_anon, is_logged, gestor_id, first_seen_at, last_seen_at, seen_count)
        VALUES (?, ?, ?, ?, now() - ?::interval, now() - ?::interval, 1)},
      {}, $r->[0], 'anon-' . $r->[0], $r->[1], $r->[2], $r->[3], $r->[3],
    );
  }

  # Interações em event_store (created_at deslocado de now()).
  my @events = (
    [ 'tel-test-s1', 'session.login',    '{"ok":true}', 101, '1 hour' ],
    [ 'tel-test-s1', 'session.navigate', '{"route":"/escola/search"}', 101, '50 minutes' ],
    [ 'tel-test-s1', 'session.navigate', '{"route":"/escola/search"}', 101, '40 minutes' ],
    [ 'tel-test-s1', 'session.search',   '{"q_len":7,"result_count":5}', 101, '30 minutes' ],
    [ 'tel-test-s2', 'session.login',    '{"ok":true}', 102, '2 hours' ],
    [ 'tel-test-s2', 'session.navigate', '{"route":"/about"}', 102, '1 hour' ],
    [ 'tel-test-s3', 'session.navigate', '{"route":"/about"}', undef, '30 minutes' ],
    [ 'tel-test-s3', 'session.navigate', '{"route":"/escola/search"}', undef, '20 minutes' ],
    [ 'tel-test-s4', 'session.login',    '{"ok":true}', 103, '20 hours' ],
    [ 'tel-test-s4', 'session.navigate', '{"route":"/p/:token"}', 103, '20 hours' ],
  );
  my $i = 0;
  for my $e (@events) {
    $i++;
    $dbh->do(
      q{INSERT INTO clean.event_store
          (event_id, event_type, source, payload, session_id, gestor_id, created_at)
        VALUES (?, ?, 'frontend', ?::jsonb, ?, ?, now() - ?::interval)},
      {}, sprintf('tel-test-ev-%d', $i), $e->[1], $e->[2], $e->[0], $e->[3], $e->[4],
    );
  }
}

subtest 'setup: escolas + gestores (admin e comum)' => sub {
  plan skip_all => 'clean.event_store/session_tracking/access_role ausente'
    unless $has_tables;

  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da telemetria admin');
  }

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin Telemetry', email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Gestor Comum', email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200);

  my $admin_id = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $ADMIN_EMAIL);
  $dbh->do('UPDATE clean.gestores SET access_role = ? WHERE id = ?', {}, 'admin', $admin_id);

  $admin_token = $t->post_ok('/api/gestor/login', json => {
    email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};
  $user_token = $t->post_ok('/api/gestor/login', json => {
    email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};
};

subtest 'auth: 401 sem token, 403 gestor comum, 200 admin' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->get_ok('/api/admin/telemetry/overview')->status_is(401);
  $t->get_ok('/api/admin/telemetry/overview', { Authorization => "Bearer $user_token" })
    ->status_is(403)->json_has('/error');
  $t->get_ok('/api/admin/telemetry/overview', { Authorization => "Bearer $admin_token" })
    ->status_is(200);
};

subtest 'janela inválida -> 400' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->get_ok('/api/admin/telemetry/overview?window=1a', { Authorization => "Bearer $admin_token" })
    ->status_is(400)->json_has('/error');
};

subtest 'overview: KPIs agregados por janela' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;
  my $b   = overview('24h');
  my $b6  = overview('6h');
  my $vazia = !$b->{events} && !@{ $b->{top_routes} // [] };
  seed_telemetry();

  my $d = overview('24h');

  is $d->{window}, '24h', 'janela ecoada';
  is $d->{granularity}, 'hour', 'granularidade por hora em 24h';

  # logins: 3 gestores distintos em 24h; 2 em 6h/12h (o de 20h fica de fora).
  is $d->{logins}{'24h'} - $b->{logins}{'24h'}, 3, 'logins 24h = +3 gestores distintos';
  is $d->{logins}{'12h'} - $b->{logins}{'12h'}, 2, 'logins 12h = +2';
  is $d->{logins}{'6h'}  - $b->{logins}{'6h'},  2, 'logins 6h = +2';

  # sessões: 4 ativas em 24h (3 logadas + 1 anônima); 3 ativas em 6h.
  is $d->{sessions}{active}    - $b->{sessions}{active},    4, 'sessões ativas 24h = +4';
  is $d->{sessions}{logged}    - $b->{sessions}{logged},    3, 'sessões logadas 24h = +3';
  is $d->{sessions}{anonymous} - $b->{sessions}{anonymous}, 1, 'sessões anônimas 24h = +1';
  is $d->{searches} - $b->{searches}, 1, 'buscas 24h = +1';
  is $d->{events}   - $b->{events},  10, 'eventos 24h = +10';

  # O ranking tem limite de itens: com tráfego real, uma rota semeada com
  # poucos acessos pode ficar fora da lista. Só se confere a rota que aparece
  # (ou toda a lista, quando ela não chegou ao limite).
  my ($rb, $rd) = (rotas($b), rotas($d));
  my $cheia = @{ $d->{top_routes} // [] } >= $TOP_ROTAS;
  my %esperado = ('/escola/search' => 3, '/about' => 2, '/p/:token' => 1);
  for my $r (sort keys %esperado) {
    if (!exists $rd->{$r} && $cheia) {
      note "rota $r fora do ranking (lista no limite de $TOP_ROTAS)";
      next;
    }
    is +($rd->{$r} // 0) - ($rb->{$r} // 0), $esperado{$r}, "navegações semeadas em $r";
  }

  ok ref $d->{series} eq 'ARRAY' && @{ $d->{series} }, 'série temporal não vazia';
  is soma_serie($d) - soma_serie($b), 10, 'soma da série = +10 eventos';

  SKIP: {
    skip 'janela de 24h com tráfego real: ordem e percentual dependem dele', 4 unless $vazia;
    my ($top) = @{ $d->{top_routes} };
    is $top->{route}, '/escola/search', 'rota mais acessada';
    is $top->{count}, 3, 'top rota com 3 acessos';
    is $top->{share_pct}, 50, 'share 50% (3 de 6 navegações)';
    my @rotas = map { $_->{route} } @{ $d->{top_routes} };
    is join(',', @rotas), '/escola/search,/about,/p/:token', 'ranking completo de rotas';
  }

  # janela de 6h: corte descarta os eventos/sessões de 20h.
  my $d6 = overview('6h');
  is $d6->{events} - $b6->{events},                     8, 'eventos 6h = +8';
  is $d6->{sessions}{active} - $b6->{sessions}{active}, 3, 'sessões ativas 6h = +3';
  is $d6->{searches} - $b6->{searches},                 1, 'buscas 6h = +1';

  # janelas longas respondem 200 e ecoam a chave.
  for my $w (qw(hoje 7d 30d)) {
    my $dx = $t->get_ok("/api/admin/telemetry/overview?window=$w", { Authorization => "Bearer $admin_token" })
      ->status_is(200)->tx->res->json;
    is $dx->{window}, $w, "janela $w ecoada";
  }
};

subtest 'privacidade: resposta só tem agregados' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $d = $t->get_ok('/api/admin/telemetry/overview?window=24h', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;

  is join(',', sort keys %$d),
    'events,generated_at,granularity,logins,searches,series,sessions,top_routes,tours,window',
    'conjunto de chaves do topo';
  my $txt = $t->tx->res->body;
  unlike $txt, qr/tel-test-s\d/,     'não expõe session_id';
  unlike $txt, qr/anon-tel-test-s/,  'não expõe ip_anon';
  unlike $txt, qr/102\.0\.0|203\.0\.113/, 'não expõe IP';
};

subtest 'tours: aberturas por gatilho, conclusão e passo de abandono' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;
  seed_telemetry();
  my %base = map { $_->{tour_id} => $_ } @{ overview('24h')->{tours} // [] };

  # busca-escola: 4 aberturas (2 auto, 1 botão, 1 link), 1 conclusão,
  # 3 fechamentos (2 no passo 3, 1 no passo 5). painel-gestor: só fechamento,
  # sem abertura na janela (taxa = null, nunca 0). Um evento antigo (40h) fica
  # fora da janela de 24h.
  my @tour = (
    [ 'busca-escola', 'start',    'auto',   undef, 7, '50 minutes' ],
    [ 'busca-escola', 'start',    'auto',   undef, 7, '40 minutes' ],
    [ 'busca-escola', 'start',    'button', undef, 7, '30 minutes' ],
    [ 'busca-escola', 'start',    'link',   undef, 7, '20 minutes' ],
    [ 'busca-escola', 'complete', undef,    7,     7, '45 minutes' ],
    [ 'busca-escola', 'dismiss',  undef,    3,     7, '35 minutes' ],
    [ 'busca-escola', 'dismiss',  undef,    3,     7, '25 minutes' ],
    [ 'busca-escola', 'dismiss',  undef,    5,     7, '15 minutes' ],
    [ 'painel-gestor', 'dismiss', undef,    2,     8, '10 minutes' ],
    [ 'analises',      'start',   'auto',   undef, 6, '40 hours' ],
  );
  my $i = 0;
  for my $e (@tour) {
    my %p = (tour_id => $e->[0], action => $e->[1], total => $e->[4]);
    $p{trigger} = $e->[2] if defined $e->[2];
    $p{step}    = $e->[3] if defined $e->[3];
    $dbh->do(
      q{INSERT INTO clean.event_store
          (event_id, event_type, source, payload, session_id, created_at)
        VALUES (?, 'session.tour', 'frontend', ?::jsonb, 'tel-test-s3', now() - ?::interval)},
      {}, sprintf('tel-test-tour-%d', ++$i), Mojo::JSON::encode_json(\%p), $e->[5],
    );
  }

  my $d = overview('24h');
  my %por = map { $_->{tour_id} => $_ } @{ $d->{tours} };
  my $sem_base = !%base;
  my $delta = sub ($id, $k) {
    (($por{$id}  // {})->{$k} // 0) - (($base{$id} // {})->{$k} // 0);
  };

  is $delta->('busca-escola', 'started'),        4, 'aberturas';
  is $delta->('busca-escola', 'started_auto'),   2, 'aberturas automáticas';
  is $delta->('busca-escola', 'started_button'), 1, 'aberturas pelo botão';
  is $delta->('busca-escola', 'started_link'),   1, 'aberturas por link';
  is $delta->('busca-escola', 'completed'),      1, 'conclusões';
  is $delta->('busca-escola', 'dismissed'),      3, 'fechamentos';
  is $delta->('painel-gestor', 'started'),       0, 'painel-gestor sem abertura na janela';
  is $delta->('painel-gestor', 'dismissed'),     1, 'fechamento do painel';

  SKIP: {
    skip 'tours reais na janela: ordem, taxas e passos dependem deles', 7 unless $sem_base;
    is join(',', map { $_->{tour_id} } @{ $d->{tours} }), 'busca-escola,painel-gestor',
      'ordenado por aberturas; tour só fora da janela não aparece';
    my $b = $por{'busca-escola'};
    is $b->{completion_pct}, 25, 'taxa de conclusão 25% (1 de 4)';
    is $b->{top_dismiss_step}, 3, 'passo em que mais se fecha';
    is $b->{total_steps},    7, 'total de passos';
    my $p = $por{'painel-gestor'};
    is $p->{started}, 0, 'painel-gestor sem abertura';
    ok !defined $p->{completion_pct}, 'taxa sem abertura = null, não 0 (#154)';
    is $p->{top_dismiss_step}, 2, 'passo de abandono do painel';
  }
};

done_testing;
