package EduMaps::Roles::Business::Chat::Conversas;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(encode_json decode_json);

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
    my $meta = $msg->{meta};
    $meta = encode_json($meta) if ref $meta eq 'HASH';
    $conv->add_to_mensagens({
      role    => $msg->{role},
      content => $msg->{content},
      meta    => $meta,
    });
  }

  $txn->commit;
  return $conv->id;
}

# Lista conversas do gestor (paginado, ordenado por created_at DESC)
sub list_conversas ($self, $gestor_id, $opts = {}) {
  my $page     = $opts->{page} // 1;
  my $per_page = $opts->{per_page} // 20;
  my $from     = $opts->{from};
  my $to       = $opts->{to};

  my $where = { gestor_id => $gestor_id };
  if ($from || $to) {
    $where->{created_at} = {};
    $where->{created_at}{'>='} = $from if $from;
    $where->{created_at}{'<='} = $to if $to;
  }

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

# Busca full-text no conteúdo das mensagens (plainto_tsquery)
# Retorna conversas distintas que têm match
sub search_conversas ($self, $gestor_id, $q, $opts = {}) {
  return { items => [], total => 0 } unless $q && length($q);

  my $page     = $opts->{page} // 1;
  my $per_page = $opts->{per_page} // 20;
  my $offset   = ($page - 1) * $per_page;

  # Usa CTE para preparar o tsquery de forma segura
  my $sql = <<"SQL";
    WITH tsq AS (
      SELECT plainto_tsquery('portuguese', ?) AS query
    )
    SELECT DISTINCT c.id, c.titulo, c.created_at, c.updated_at,
           ts_headline('portuguese', m.content, tsq.query) AS snippet
    FROM clean.chat_conversas c
    JOIN clean.chat_mensagens m ON m.conversa_id = c.id
    CROSS JOIN tsq
    WHERE c.gestor_id = ?
      AND to_tsvector('portuguese', m.content) @@ tsq.query
    ORDER BY c.created_at DESC
    LIMIT ? OFFSET ?
SQL

  my $sth = $self->schema->storage->dbh->prepare($sql);
  $sth->execute($q, $gestor_id, $per_page, $offset);

  my @items;
  while (my $row = $sth->fetchrow_hashref) {
    push @items, {
      id         => $row->{id} + 0,
      titulo     => $row->{titulo},
      created_at => $row->{created_at},
      updated_at => $row->{updated_at},
      snippet    => $row->{snippet},
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

# Calendário: dias com conversas no intervalo [from, to]
# Retorna { "YYYY-MM-DD" => count, ... }
sub calendar_conversas ($self, $gestor_id, $from, $to) {
  return {} unless $from && $to;

  my $sql = <<'SQL';
    SELECT to_char(created_at, 'YYYY-MM-DD') AS dia, COUNT(*) AS total
    FROM clean.chat_conversas
    WHERE gestor_id = ?
      AND to_char(created_at, 'YYYY-MM-DD') >= ?
      AND to_char(created_at, 'YYYY-MM-DD') <= ?
    GROUP BY dia
    ORDER BY dia
SQL

  my $sth = $self->schema->storage->dbh->prepare($sql);
  $sth->execute($gestor_id, $from, $to);

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

  my $where = { gestor_id => $gestor_id };
  $where->{id} = { -in => \@ids } if @ids && !$all;

  my $rs = $self->schema->resultset('ChatConversa')->search(
    $where,
    { order_by => { -desc => 'me.created_at' }, prefetch => 'mensagens' },
  );

  my $md = '';
  while (my $c = $rs->next) {
    my $titulo = $c->titulo // 'Sem título';
    my $data   = $c->created_at;
    $md .= "# Conversa: $titulo\n";
    $md .= "**Data:** $data\n\n---\n\n";

    my $n = 0;
    for my $m ($c->mensagens->search({}, { order_by => 'created_at' })->all) {
      next unless $m->role =~ /^(user|assistant)$/;
      $n++ if $m->role eq 'user';
      my $label = $m->role eq 'user' ? "Pergunta $n" : "Resposta $n";
      my $hora  = $m->created_at;
      $md .= "## $label\n**$hora** — " . $m->content . "\n\n---\n\n";
    }
  }

  return $md;
}

1;