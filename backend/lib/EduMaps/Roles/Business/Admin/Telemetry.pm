package EduMaps::Roles::Business::Admin::Telemetry;
use Mojo::Base -role, -signatures;
use utf8;

# Telemetria de sessão do Painel de Administração: agrega o fluxo de acesso
# (KPIs) a partir de clean.event_store + clean.session_tracking. Só agregados —
# nunca IP cru, User-Agent, ip_anon, texto digitado ou sessão individual.
#
# Semântica das métricas:
#   - logins  = gestores distintos (gestor_id único) com evento session.login
#               ok=true na janela. As três janelas fixas (6h/12h/24h) são
#               sempre devolvidas, independentemente da janela selecionada.
#   - sessões  = de clean.session_tracking (atividade por last_seen_at), com
#               quebra logado (is_logged) vs. anônimo.
#   - rotas    = session.navigate (páginas da SPA), top N com share.
#   - série    = eventos por hora/dia, com buckets contínuos (sem furos).
#
# Os dados chegam em lote (flush ~30s do EventLogger): o painel é
# near-real-time, não streaming.

requires qw(schema);

our $DEFAULT_WINDOW = '24h';
our $TOP_ROUTES     = 10;
our @LOGIN_WINDOWS  = qw(6h 12h 24h);

# Janelas aceitas (whitelist). Cada uma fixa: o corte inferior (`since`), o
# início da série contínua (`start`), a granularidade (`bucket`) e o passo
# (`step`). Os trechos SQL são constantes do servidor, nunca vêm do cliente.
our %WINDOWS = (
  '6h' => {
    since  => q{now() - interval '6 hours'},
    start  => q{date_trunc('hour', now()) - interval '6 hours'},
    bucket => 'hour',
    step   => q{interval '1 hour'},
  },
  '12h' => {
    since  => q{now() - interval '12 hours'},
    start  => q{date_trunc('hour', now()) - interval '12 hours'},
    bucket => 'hour',
    step   => q{interval '1 hour'},
  },
  '24h' => {
    since  => q{now() - interval '24 hours'},
    start  => q{date_trunc('hour', now()) - interval '24 hours'},
    bucket => 'hour',
    step   => q{interval '1 hour'},
  },
  'hoje' => {
    since  => q{date_trunc('day', now())},
    start  => q{date_trunc('day', now())},
    bucket => 'hour',
    step   => q{interval '1 hour'},
  },
  '7d' => {
    since  => q{now() - interval '7 days'},
    start  => q{date_trunc('day', now()) - interval '7 days'},
    bucket => 'day',
    step   => q{interval '1 day'},
  },
  '30d' => {
    since  => q{now() - interval '30 days'},
    start  => q{date_trunc('day', now()) - interval '30 days'},
    bucket => 'day',
    step   => q{interval '1 day'},
  },
);

sub window_keys ($self) { [ sort keys %WINDOWS ] }

sub is_window ($self, $key) { defined $key && exists $WINDOWS{$key} }

# Visão consolidada de uma janela. Devolve hashref pronto para JSON.
sub overview ($self, $params = {}) {
  my $window = $params->{window};
  $window = $DEFAULT_WINDOW unless $self->is_window($window);
  my $w = $WINDOWS{$window};

  my %logins;
  $logins{$_} = $self->_logins_since($WINDOWS{$_}{since}) for @LOGIN_WINDOWS;

  return {
    window       => $window,
    granularity  => $w->{bucket},
    generated_at => $self->_now,
    logins       => \%logins,
    sessions     => $self->_sessions_since($w->{since}),
    searches     => $self->_count_events('session.search', $w->{since}),
    events       => $self->_count_events(undef, $w->{since}),
    top_routes   => $self->_top_routes($w->{since}),
    series       => $self->_series($w),
  };
}

# --- métricas --------------------------------------------------------------

# Gestores distintos que fizeram login bem-sucedido na janela.
sub _logins_since ($self, $since) {
  my $row = $self->_row(
    "SELECT COUNT(DISTINCT st.gestor_id)::int AS n
       FROM clean.event_store e
       JOIN clean.session_tracking st ON st.session_id = e.session_id
      WHERE e.event_type = 'session.login'
        AND e.payload->>'ok' = 'true'
        AND e.created_at >= $since
        AND st.gestor_id IS NOT NULL"
  );
  return $row->{n} // 0;
}

# Sessões ativas na janela, quebradas em logadas vs. anônimas.
sub _sessions_since ($self, $since) {
  my $row = $self->_row(
    "SELECT COUNT(*)::int AS active,
            COUNT(*) FILTER (WHERE is_logged)::int AS logged,
            COUNT(*) FILTER (WHERE NOT is_logged)::int AS anonymous
       FROM clean.session_tracking
      WHERE last_seen_at >= $since"
  );
  return {
    active    => $row->{active}    // 0,
    logged    => $row->{logged}    // 0,
    anonymous => $row->{anonymous} // 0,
  };
}

sub _count_events ($self, $type, $since) {
  my ($sql, @binds) = defined $type
    ? (
      "SELECT COUNT(*)::int AS n
         FROM clean.event_store
        WHERE event_type = ? AND created_at >= $since",
      $type,
    )
    : (
      "SELECT COUNT(*)::int AS n
         FROM clean.event_store
        WHERE created_at >= $since",
    );
  my $row = $self->_row($sql, @binds);
  return $row->{n} // 0;
}

# Top N rotas de frontend (session.navigate) com participação percentual.
sub _top_routes ($self, $since) {
  my $top = $TOP_ROUTES;
  return $self->_rows(
    "SELECT e.payload->>'route' AS route,
            COUNT(*)::int AS count,
            ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 1)::float8 AS share_pct
       FROM clean.event_store e
      WHERE e.event_type = 'session.navigate'
        AND e.created_at >= $since
        AND e.payload->>'route' IS NOT NULL
      GROUP BY 1
      ORDER BY count DESC, route ASC
      LIMIT $top"
  );
}

# Série temporal de eventos/sessões, com buckets contínuos (generate_series).
sub _series ($self, $w) {
  my $bucket = $w->{bucket};    # 'hour' | 'day' (whitelist do servidor)
  my $fmt    = $bucket eq 'day' ? 'YYYY-MM-DD' : 'YYYY-MM-DD"T"HH24:MI';
  return $self->_rows(
    "WITH buckets AS (
       SELECT generate_series($w->{start}, date_trunc('$bucket', now()), $w->{step}) AS bucket
     )
     SELECT to_char(b.bucket, '$fmt') AS bucket,
            COUNT(e.id)::int AS events,
            COUNT(DISTINCT e.session_id)::int AS sessions
       FROM buckets b
       LEFT JOIN clean.event_store e
         ON e.created_at >= b.bucket
        AND e.created_at < b.bucket + $w->{step}
      GROUP BY b.bucket
      ORDER BY b.bucket"
  );
}

sub _now ($self) {
  my $row = $self->_row(q{SELECT to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF') AS t});
  return $row->{t};
}

# --- helpers SQL (padrão das roles de negócio) -----------------------------

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0] // {};
}

1;
