# t/04-api/admin/telemetry.t
# Testes da API de telemetria do Painel de Administração
# (/api/admin/telemetry/overview):
#   auth (401 sem token, 403 gestor comum, 200 admin), validação da janela,
#   KPIs agregados (logins por janela, sessões logadas/anônimas, rotas, busca,
#   série temporal) e ausência de dado pessoal na resposta. Só roda onde
#   event_store/session_tracking e gestor_access_role foram aplicados.
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
  seed_telemetry();

  my $d = $t->get_ok('/api/admin/telemetry/overview?window=24h', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;

  is $d->{window}, '24h', 'janela ecoada';
  is $d->{granularity}, 'hour', 'granularidade por hora em 24h';

  # logins: 3 gestores distintos em 24h; 2 em 6h/12h (o de 20h fica de fora).
  is $d->{logins}{'24h'}, 3, 'logins 24h = 3 gestores distintos';
  is $d->{logins}{'12h'}, 2, 'logins 12h = 2';
  is $d->{logins}{'6h'},  2, 'logins 6h = 2';

  # sessões: 4 ativas em 24h (3 logadas + 1 anônima); 3 ativas em 6h.
  is $d->{sessions}{active},    4, 'sessões ativas 24h = 4';
  is $d->{sessions}{logged},    3, 'sessões logadas 24h = 3';
  is $d->{sessions}{anonymous}, 1, 'sessões anônimas 24h = 1';
  is $d->{searches}, 1, 'buscas 24h = 1';
  is $d->{events},  10, 'eventos 24h = 10';

  my ($top) = @{ $d->{top_routes} };
  is $top->{route}, '/escola/search', 'rota mais acessada';
  is $top->{count}, 3, 'top rota com 3 acessos';
  is $top->{share_pct}, 50, 'share 50% (3 de 6 navegações)';
  my @rotas = map { $_->{route} } @{ $d->{top_routes} };
  is join(',', @rotas), '/escola/search,/about,/p/:token', 'ranking completo de rotas';

  ok ref $d->{series} eq 'ARRAY' && @{ $d->{series} }, 'série temporal não vazia';
  my $serie_ev = 0;
  $serie_ev += $_->{events} for @{ $d->{series} };
  is $serie_ev, 10, 'soma da série = eventos da janela';

  # janela de 6h: corte descarta os eventos/sessões de 20h.
  my $d6 = $t->get_ok('/api/admin/telemetry/overview?window=6h', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;
  is $d6->{events},        8, 'eventos 6h = 8';
  is $d6->{sessions}{active}, 3, 'sessões ativas 6h = 3';
  is $d6->{searches},      1, 'buscas 6h = 1';

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
    'events,generated_at,granularity,logins,searches,series,sessions,top_routes,window',
    'conjunto de chaves do topo';
  my $txt = $t->tx->res->body;
  unlike $txt, qr/tel-test-s\d/,     'não expõe session_id';
  unlike $txt, qr/anon-tel-test-s/,  'não expõe ip_anon';
  unlike $txt, qr/102\.0\.0|203\.0\.113/, 'não expõe IP';
};

done_testing;
