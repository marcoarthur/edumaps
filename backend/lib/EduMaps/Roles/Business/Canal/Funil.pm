package EduMaps::Roles::Business::Canal::Funil;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(true false);

# ============================================================================
# FUNIL DE CONVERSÃO POR LISTA (issue #216 — Fase 3, onda 2, RF-306)
# ============================================================================
#
# Acessos ao QR: o GET 200 da página pública de inscrição soma 1 em
# `canal_qr_acessos (qrcode_id, dia)` — dia em America/Sao_Paulo, upsert, só
# contagem (sem IP, user agent ou cookie). 404/410 não contam.
#
# Funil (`lista_funil`), por dia (America/Sao_Paulo), TODOS os dias do
# intervalo (zeros incluídos):
#
#   acessos      soma de canal_qr_acessos dos QRs da lista;
#   inscricoes   linhas de canal_inscricoes da lista criadas no dia;
#   confirmados  membros ATUAIS com estado geral `confirmado`, no dia do
#                GREATEST(confirmado_em, email_confirmado_em) — null (totais
#                e série) se a lista não exige confirmação;
#   optouts      canal_optouts.created_at da lista.
#
# Taxas com 4 casas; null quando o denominador é 0 ou `confirmados` é null.
#
# Composta no model Canal; usa os helpers SQL de Canal::Listas.

requires qw(_rows _row _sql_estado_membro _sql_geral_confirmado);

our $TZ = 'America/Sao_Paulo';
our $FUNIL_DIAS_PADRAO = 30;
our $FUNIL_DIAS_MAX    = 366;

# Soma um acesso ao QR no dia corrente (upsert).
sub qr_registrar_acesso ($self, $qrcode_id) {
  return unless defined $qrcode_id && $qrcode_id =~ /^\d+\z/;
  $self->_rows(
    qq{INSERT INTO clean.canal_qr_acessos (qrcode_id, dia, acessos)
       VALUES (?, (NOW() AT TIME ZONE '$TZ')::date, 1)
       ON CONFLICT (qrcode_id, dia)
       DO UPDATE SET acessos = clean.canal_qr_acessos.acessos + 1},
    $qrcode_id + 0,
  );
  return 1;
}

# Funil da lista. %p: de, ate (YYYY-MM-DD; padrão ate = hoje, de = ate − 29
# dias). Devolve undef (lista não é da escola), { error } (400) ou
# { de, ate, exige_confirmacao, totais, taxas, serie }.
sub lista_funil ($self, $cod_inep, $lista_id, %p) {
  return unless defined $lista_id && $lista_id =~ /^\d+\z/;
  my $l = $self->_row(
    'SELECT id, exige_confirmacao FROM clean.canal_listas WHERE id = ? AND cod_inep = ?',
    $lista_id + 0, $cod_inep + 0,
  ) or return;

  my $msg = "Período inválido: use de/ate no formato YYYY-MM-DD, de ≤ ate, "
          . "até $FUNIL_DIAS_MAX dias.";
  my %d;
  for my $k (qw(de ate)) {
    my $v = $p{$k};
    $v = undef if defined $v && !ref $v && $v !~ /\S/;
    if (defined $v) {
      return { error => $msg } if ref $v;
      $v =~ s/^\s+|\s+$//g;
      return { error => $msg } unless $v =~ /^\d{4}-\d\d-\d\d\z/;
    }
    $d{$k} = $v;
  }
  my $per = eval {
    $self->_row(
      qq{SELECT to_char(x.de, 'YYYY-MM-DD') AS de, to_char(x.ate, 'YYYY-MM-DD') AS ate,
                (x.ate - x.de) AS dias
         FROM (SELECT COALESCE(?::date, a.ate - ?::int) AS de, a.ate
               FROM (SELECT COALESCE(?::date, (NOW() AT TIME ZONE '$TZ')::date) AS ate) a) x},
      $d{de}, $FUNIL_DIAS_PADRAO - 1, $d{ate},
    );
  };
  return { error => $msg }
    unless $per && $per->{dias} >= 0 && $per->{dias} < $FUNIL_DIAS_MAX;

  my $exige = $l->{exige_confirmacao} ? 1 : 0;
  my ($ultima) = $self->_sql_estado_membro;
  my $geral = $self->_sql_geral_confirmado;
  my ($de, $ate) = @$per{qw(de ate)};
  my $ini = qq{((?::date)::timestamp AT TIME ZONE '$TZ')};
  my $fim = qq{(((?::date) + 1)::timestamp AT TIME ZONE '$TZ')};

  my $rows = $self->_rows(
    qq{WITH dias AS (
         SELECT g::date AS dia FROM generate_series(?::date, ?::date, interval '1 day') g
       ), ac AS (
         SELECT a.dia, sum(a.acessos)::int AS n
         FROM   clean.canal_qr_acessos a
         JOIN   clean.canal_qrcodes q ON q.id = a.qrcode_id
         WHERE  q.lista_id = ? AND a.dia BETWEEN ?::date AND ?::date
         GROUP  BY a.dia
       ), ins AS (
         SELECT (i.created_at AT TIME ZONE '$TZ')::date AS dia, count(*)::int AS n
         FROM   clean.canal_inscricoes i
         WHERE  i.lista_id = ? AND i.created_at >= $ini AND i.created_at < $fim
         GROUP  BY 1
       ), conf AS (
         SELECT (GREATEST(m.confirmado_em, m.email_confirmado_em) AT TIME ZONE '$TZ')::date AS dia,
                count(*)::int AS n
         FROM   clean.canal_lista_membros m
         JOIN   clean.contatos c ON c.id = m.contato_id
         $ultima
         WHERE  m.lista_id = ? AND $geral
           AND  GREATEST(m.confirmado_em, m.email_confirmado_em) >= $ini
           AND  GREATEST(m.confirmado_em, m.email_confirmado_em) <  $fim
         GROUP  BY 1
       ), opt AS (
         SELECT (o.created_at AT TIME ZONE '$TZ')::date AS dia, count(*)::int AS n
         FROM   clean.canal_optouts o
         WHERE  o.lista_id = ? AND o.created_at >= $ini AND o.created_at < $fim
         GROUP  BY 1
       )
       SELECT to_char(d.dia, 'YYYY-MM-DD') AS dia,
              COALESCE(ac.n, 0)   AS acessos,
              COALESCE(ins.n, 0)  AS inscricoes,
              COALESCE(conf.n, 0) AS confirmados,
              COALESCE(opt.n, 0)  AS optouts
       FROM   dias d
       LEFT JOIN ac   ON ac.dia   = d.dia
       LEFT JOIN ins  ON ins.dia  = d.dia
       LEFT JOIN conf ON conf.dia = d.dia
       LEFT JOIN opt  ON opt.dia  = d.dia
       ORDER  BY d.dia},
    $de, $ate,
    $l->{id} + 0, $de, $ate,
    $l->{id} + 0, $de, $ate,
    $l->{id} + 0, $de, $ate,
    $l->{id} + 0, $de, $ate,
  );

  my %tot = (acessos => 0, inscricoes => 0, confirmados => ($exige ? 0 : undef), optouts => 0);
  my @serie;
  for my $r (@$rows) {
    my %dia = (
      dia         => $r->{dia},
      acessos     => $r->{acessos} + 0,
      inscricoes  => $r->{inscricoes} + 0,
      confirmados => ($exige ? $r->{confirmados} + 0 : undef),
      optouts     => $r->{optouts} + 0,
    );
    for my $k (qw(acessos inscricoes optouts)) { $tot{$k} += $dia{$k} }
    $tot{confirmados} += $dia{confirmados} if $exige;
    push @serie, \%dia;
  }

  my $taxa = sub ($num, $den) {
    return undef unless defined $num && defined $den && $den > 0;
    return 0 + sprintf('%.4f', $num / $den);
  };
  return {
    de                => $de,
    ate               => $ate,
    exige_confirmacao => $exige ? true : false,
    totais            => \%tot,
    taxas             => {
      acesso_inscricao      => $taxa->($tot{inscricoes}, $tot{acessos}),
      inscricao_confirmacao => $taxa->($tot{confirmados}, $tot{inscricoes}),
    },
    serie             => \@serie,
  };
}

1;
