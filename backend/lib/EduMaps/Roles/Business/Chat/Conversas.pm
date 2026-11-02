package EduMaps::Roles::Business::Chat::Conversas;
use Mojo::Base -role, -signatures;
use utf8;

requires 'schema';

# Salva uma conversa completa (perguntas + respostas) para o gestor logado.
# $args = { titulo => '...', messages => [ {role, content, meta}, ... ] }
sub save_conversa ($self, $gestor_id, $args) {
  my $titulo = $args->{titulo} // undef;
  my $messages = $args->{messages} // [];

  return unless @$messages;

  my $txn = $self->schema->txn_scope_guard;

  my $conv = $self->schema->resultset('ChatConversa')->create({
    gestor_id => $gestor_id,
    titulo    => $titulo,
  });

  for my $msg (@$messages) {
    $conv->add_to_mensagens({
      role    => $msg->{role},
      content => $msg->{content},
      # O `meta` é jsonb: a serialização é do ChatMensagem (ver o inflate/deflate
      # da coluna), a role entrega a estrutura.
      meta    => $msg->{meta},
    });
  }

  $txn->commit;
  return $conv->id;
}

# Filtro por DIA de created_at, inclusivo nas duas pontas, no fuso `tz`
# (o do navegador; sem ele, UTC, que é o fuso dos bancos) — o mesmo critério
# do calendário. Usado pela lista e pelo export. Devolve pares para o `where`.
sub _filtro_dia ($opts) {
  my ($from, $to) = @{$opts}{qw(from to)};
  my $tz = $opts->{tz} // 'UTC';
  my @dia;
  push @dia, \[ '(created_at AT TIME ZONE ?)::date >= ?::date', $tz, $from ] if $from;
  push @dia, \[ '(created_at AT TIME ZONE ?)::date <= ?::date', $tz, $to ]   if $to;
  return @dia ? (-and => \@dia) : ();
}

# Lista conversas do gestor (paginado, ordenado por created_at DESC)
sub list_conversas ($self, $gestor_id, $opts = {}) {
  my $page     = $opts->{page} // 1;
  my $per_page = $opts->{per_page} // 20;
  my $from     = $opts->{from};
  my $to       = $opts->{to};

  # Comparar o timestamp com 'YYYY-MM-DD' cortava o próprio dia `to`
  # (virava até 00:00 dele); ver _filtro_dia.
  my $where = { gestor_id => $gestor_id, _filtro_dia($opts) };

  my $rs = $self->schema->resultset('ChatConversa')->search(
    $where,
    { order_by => { -desc => 'created_at' }, page => $page, rows => $per_page },
  );

  my $pager = $rs->pager;
  my @items;
  while (my $c = $rs->next) {
    push @items, {
      id         => $c->id + 0,
      titulo     => $c->titulo,
      created_at => $c->created_at,
      updated_at => $c->updated_at,
      msg_count  => $c->mensagens->count,
    };
  }

  return {
    items      => \@items,
    page       => $page + 0,
    per_page   => $per_page + 0,
    total      => $pager->total_entries + 0,
    total_pages=> $pager->last_page + 0,
  };
}

# Detalha uma conversa com todas as mensagens
sub get_conversa ($self, $gestor_id, $id) {
  my $conv = $self->schema->resultset('ChatConversa')->find($id);
  return unless $conv && $conv->gestor_id == $gestor_id;

  my @msgs;
  for my $m ($conv->mensagens->search({}, { order_by => 'created_at' })->all) {
    push @msgs, {
      id        => $m->id + 0,
      role      => $m->role,
      content   => $m->content,
      meta      => $m->meta,
      created_at=> $m->created_at,
    };
  }

  return {
    id         => $conv->id + 0,
    titulo     => $conv->titulo,
    created_at => $conv->created_at,
    updated_at => $conv->updated_at,
    messages   => \@msgs,
  };
}

# Exclui uma conversa do gestor
sub delete_conversa ($self, $gestor_id, $id) {
  my $conv = $self->schema->resultset('ChatConversa')->find($id);
  return 0 unless $conv && $conv->gestor_id == $gestor_id;
  $conv->delete;
  return 1;
}

# Busca full-text no conteúdo das mensagens (plainto_tsquery).
# Uma linha por CONVERSA (a primeira mensagem que casa dá o trecho): antes
# era uma por mensagem, e a mesma conversa voltava repetida.
#
# O trecho vem em dois formatos:
#   snippet         texto puro, sem marcação (compatível);
#   snippet_partes  [{ texto, destaque }] — o cliente monta o destaque sem
#                   interpretar HTML. O ts_headline marcava com <b>…</b>, que
#                   a tela mostrava cru.
# Os delimitadores do destaque são caracteres de uso privado (U+E000/E001),
# removidos do conteúdo antes, para não colidirem com o texto.
my $INI = "\x{E000}";
my $FIM = "\x{E001}";

# Tira a marcação de Markdown que aparecia crua no trecho (**negrito**,
# __itálico__, `código`, # títulos) e junta as linhas.
sub _trecho_limpo ($texto) {
  $texto //= '';
  $texto =~ s/\*\*|__|`//g;
  $texto =~ s/(^|\n)\s*#+\s*/$1/g;
  $texto =~ s/\s+/ /g;
  return $texto;
}

sub _partes_do_trecho ($headline) {
  my @partes;
  for my $peda (split /(\x{E000}.*?\x{E001})/s, $headline // '') {
    next unless length $peda;
    my $destaque = $peda =~ s/^\x{E000}(.*)\x{E001}$/$1/s ? 1 : 0;
    my $texto = _trecho_limpo($peda);
    next unless length $texto;
    push @partes, { texto => $texto, destaque => $destaque ? \1 : \0 };
  }
  # aparas nas pontas (o ts_headline começa/termina no meio da frase)
  if (@partes) {
    $partes[0]{texto}  =~ s/^\s+//;
    $partes[-1]{texto} =~ s/\s+$//;
  }
  return [ grep { length $_->{texto} } @partes ];
}

sub search_conversas ($self, $gestor_id, $q, $opts = {}) {
  return { items => [], total => 0 } unless $q && length($q);

  my $page     = $opts->{page} // 1;
  my $per_page = $opts->{per_page} // 20;
  my $offset   = ($page - 1) * $per_page;

  my $sql = <<"SQL";
    WITH tsq AS (
      SELECT plainto_tsquery('portuguese', ?) AS query
    ),
    casadas AS (
      SELECT DISTINCT ON (c.id)
             c.id, c.titulo, c.created_at, c.updated_at,
             ts_headline('portuguese',
                         translate(m.content, ?, ''),
                         tsq.query, ?) AS headline
      FROM clean.chat_conversas c
      JOIN clean.chat_mensagens m ON m.conversa_id = c.id
      CROSS JOIN tsq
      WHERE c.gestor_id = ?
        AND to_tsvector('portuguese', m.content) @@ tsq.query
      ORDER BY c.id, m.created_at, m.id
    )
    SELECT k.*,
           (SELECT COUNT(*) FROM clean.chat_mensagens mm WHERE mm.conversa_id = k.id) AS msg_count
    FROM casadas k
    ORDER BY k.created_at DESC, k.id DESC
    LIMIT ? OFFSET ?
SQL

  my $sth = $self->schema->storage->dbh->prepare($sql);
  $sth->execute($q, "$INI$FIM", "StartSel=$INI, StopSel=$FIM", $gestor_id, $per_page, $offset);

  my @items;
  while (my $row = $sth->fetchrow_hashref) {
    my $partes = _partes_do_trecho($row->{headline});
    push @items, {
      id             => $row->{id} + 0,
      titulo         => $row->{titulo},
      created_at     => $row->{created_at},
      updated_at     => $row->{updated_at},
      msg_count      => $row->{msg_count} + 0,
      snippet        => join('', map { $_->{texto} } @$partes),
      snippet_partes => $partes,
    };
  }

  # total count
  my $count_sql = <<"SQL";
    WITH tsq AS (
      SELECT plainto_tsquery('portuguese', ?) AS query
    )
    SELECT COUNT(DISTINCT c.id)
    FROM clean.chat_conversas c
    JOIN clean.chat_mensagens m ON m.conversa_id = c.id
    CROSS JOIN tsq
    WHERE c.gestor_id = ?
      AND to_tsvector('portuguese', m.content) @@ tsq.query
SQL

  my $total = $self->schema->storage->dbh->selectrow_array($count_sql, {}, $q, $gestor_id) // 0;

  return {
    items      => \@items,
    page       => $page + 0,
    per_page   => $per_page + 0,
    total      => $total + 0,
    total_pages=> ($per_page > 0 ? int(($total + $per_page - 1) / $per_page) : 0),
  };
}

# Fuso conhecido pelo Postgres? (`tz` vem do navegador; um nome inválido
# faria o AT TIME ZONE estourar em 500.)
sub fuso_valido ($self, $tz) {
  return 0 unless defined $tz && length $tz <= 64;
  my ($ok) = $self->schema->storage->dbh->selectrow_array(
    'SELECT 1 FROM pg_timezone_names WHERE name = ?', undef, $tz);
  return $ok ? 1 : 0;
}

# Calendário: dias com conversas no intervalo [from, to], com o dia contado
# no fuso `tz` (default UTC) — o mesmo critério do filtro da lista.
# Retorna { "YYYY-MM-DD" => count, ... }
sub calendar_conversas ($self, $gestor_id, $from, $to, $tz = 'UTC') {
  return {} unless $from && $to;

  my $sql = <<'SQL';
    SELECT to_char(created_at AT TIME ZONE ?, 'YYYY-MM-DD') AS dia, COUNT(*) AS total
    FROM clean.chat_conversas
    WHERE gestor_id = ?
      AND (created_at AT TIME ZONE ?)::date BETWEEN ?::date AND ?::date
    GROUP BY dia
    ORDER BY dia
SQL

  my $sth = $self->schema->storage->dbh->prepare($sql);
  $sth->execute($tz, $gestor_id, $tz, $from, $to);

  my %map;
  while (my $row = $sth->fetchrow_hashref) {
    $map{$row->{dia}} = $row->{total} + 0;
  }
  return \%map;
}

# Exporta conversas para Markdown
# $opts = { ids => [1,2,3], all => 1 }
sub export_conversas ($self, $gestor_id, $opts = {}) {
  my @ids = $opts->{ids} ? @{$opts->{ids}} : ();
  my $all = $opts->{all} // 0;

  # `from`/`to`/`tz` recortam por dia (o dia escolhido no calendário),
  # inclusive no "todas": exportar "todas" com um dia escolhido é exportar
  # as daquele dia.
  my $where = { gestor_id => $gestor_id, _filtro_dia($opts) };
  $where->{id} = { -in => \@ids } if @ids && !$all;

  # Sem `prefetch`: o loop abaixo já busca as mensagens com
  # `$c->mensagens->search(...)`, ou seja o prefetch trazia um JOIN que
  # (a) era descartado e (b) deixava `id` ambíguo entre `chat_conversas` e
  # `chat_mensagens` — o filtro por ids estourava com "column reference id
  # is ambiguous" (500) sempre que se exportava uma seleção.
  # Datas no fuso de quem exporta, legíveis ("25/09/2026 23:03"). Antes
  # saía o timestamp cru do banco, em UTC: a conversa das 23h do dia 25 vinha
  # "2026-09-26 02:03:39.129883+00" dentro do arquivo do dia 25. Sem `tz`,
  # UTC, e o arquivo diz que é UTC.
  my $tz       = $opts->{tz} // 'UTC';
  my $sufixo   = defined $opts->{tz} ? '' : ' (UTC)';
  my $local    = \[ "to_char(me.created_at AT TIME ZONE ?, 'DD/MM/YYYY HH24:MI')", $tz ];
  my $rs = $self->schema->resultset('ChatConversa')->search(
    $where,
    { order_by => { -desc => 'created_at' }, '+select' => [$local], '+as' => ['data_local'] },
  );

  my $md = '';
  while (my $c = $rs->next) {
    my $titulo = $c->titulo // 'Sem título';
    my $data   = $c->get_column('data_local') . $sufixo;
    $md .= "# Conversa: $titulo\n";
    $md .= "**Data:** $data\n\n---\n\n";

    my $n = 0;
    my $msgs = $c->mensagens->search({},
      { order_by => 'created_at', '+select' => [$local], '+as' => ['data_local'] });
    for my $m ($msgs->all) {
      next unless $m->role =~ /^(user|assistant)$/;
      $n++ if $m->role eq 'user';
      my $label = $m->role eq 'user' ? "Pergunta $n" : "Resposta $n";
      my $hora  = $m->get_column('data_local') . $sufixo;
      $md .= "## $label\n**$hora** — " . $m->content . "\n\n---\n\n";
    }
  }

  return $md;
}

1;