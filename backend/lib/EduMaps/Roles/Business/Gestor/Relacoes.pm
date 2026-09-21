package EduMaps::Roles::Business::Gestor::Relacoes;
use Mojo::Base -role, -signatures;
use Mojo::JSON ();
use DateTime;
use utf8;

# Relações institucionais da escola: entidades externas (órgãos, escolas,
# fornecedores, famílias, comunidade, parceiros, conselhos) e as relações da
# escola com elas (assunto/finalidade/responsável/próxima ação/prazo).
#
# NÃO é um CRM: o centro é a RELAÇÃO, não o contato. A gestão (interações,
# documentos, tarefas) entra em etapas seguintes.
#
# Flexibilidade: tipo/finalidade são texto livre apoiados por uma taxonomia
# editável (relacoes_categorias) semeada por escola; campos extras em JSONB.

requires qw(schema);

# Taxonomia inicial (semeada por escola, editável pelo gestor).
our %CATEGORIAS_PADRAO = (
  entidade => [
    'Órgãos públicos',
    'Outras escolas',
    'Fornecedores',
    'Famílias',
    'Comunidade',
    'Instituições parceiras',
    'Conselhos e representação',
  ],
  finalidade => [
    'Obrigação/regulação',
    'Solicitação',
    'Prestação de contas',
    'Contratação',
    'Comunicação',
    'Parceria',
    'Participação',
    'Resolução de problema',
    'Projeto',
    'Acompanhamento',
  ],
);

our @STATUS     = qw(aberta em_andamento aguardando concluida cancelada);
our @PRIORIDADES = qw(baixa media alta urgente);

# ---------------------------------------------------------------------------
# categorias (taxonomia editável)
# ---------------------------------------------------------------------------

sub sincronizar_categorias_padrao ($self, $cod_inep) {
  my $ja_tem = $self->_row(
    'SELECT 1 FROM clean.relacoes_categorias
     WHERE cod_inep = ? AND origem = \'padrao\' LIMIT 1',
    $cod_inep + 0,
  );
  return [] if $ja_tem;

  $self->_txn(sub {
    for my $eixo (keys %CATEGORIAS_PADRAO) {
      for my $nome (@{ $CATEGORIAS_PADRAO{$eixo} }) {
        $self->_row(
          'INSERT INTO clean.relacoes_categorias (cod_inep, gestor_id, eixo, nome, origem)
           VALUES (?, NULL, ?, ?, \'padrao\')
           ON CONFLICT DO NOTHING
           RETURNING id',
          $cod_inep + 0, $eixo, $nome,
        );
      }
    }
  });

  return 1;
}

sub list_relacoes_categorias ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT c.id, c.eixo, c.nome, c.origem,
            (SELECT COUNT(*) FROM clean.relacoes_entidades e
              WHERE e.cod_inep = c.cod_inep AND e.tipo = c.nome) AS n_entidades
     FROM   clean.relacoes_categorias c
     WHERE  c.cod_inep = ?
     ORDER  BY c.eixo, lower(c.nome)',
    $cod_inep + 0,
  );
  return [ map {
    { id => $_->{id} + 0, eixo => $_->{eixo}, nome => $_->{nome},
      origem => $_->{origem}, n_entidades => $_->{n_entidades} + 0 }
  } @$rows ];
}

sub create_relacoes_categoria ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.relacoes_categorias (cod_inep, gestor_id, eixo, nome, origem)
     VALUES (?, ?, ?, ?, \'manual\')
     RETURNING id, eixo, nome, origem',
    $cod_inep + 0, $self->_gestor_bind($gestor_id), $params->{eixo}, $params->{nome},
  ) or return;
  return { id => $row->{id} + 0, eixo => $row->{eixo}, nome => $row->{nome},
           origem => $row->{origem}, n_entidades => 0 };
}

sub update_relacoes_categoria ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.relacoes_categorias
     SET    eixo = ?, nome = ?, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id, eixo, nome, origem',
    $params->{eixo}, $params->{nome}, $id + 0, $cod_inep + 0,
  ) or return;
  return { id => $row->{id} + 0, eixo => $row->{eixo}, nome => $row->{nome},
           origem => $row->{origem} };
}

sub delete_relacoes_categoria ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.relacoes_categorias WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

# ---------------------------------------------------------------------------
# entidades externas
# ---------------------------------------------------------------------------

sub _entidade_select {
  return 'SELECT e.id, e.tipo, e.nome, e.identificador, e.responsavel_externo,
                 e.email, e.telefone, e.site, e.endereco, e.observacoes,
                 e.atributos, e.created_at, e.updated_at,
                 (SELECT COUNT(*) FROM clean.relacoes r WHERE r.entidade_id = e.id) AS n_relacoes
          FROM   clean.relacoes_entidades e';
}

sub list_entidades ($self, $cod_inep, $filtros = {}) {
  my @where = ('e.cod_inep = ?');
  my @binds = ($cod_inep + 0);

  if (my $tipo = $filtros->{tipo}) {
    push @where, 'e.tipo = ?';
    push @binds, $tipo;
  }
  if (my $q = $filtros->{q}) {
    $q =~ s/%/\\%/g;
    push @where, '(e.nome ILIKE ? ESCAPE \'\\\' OR e.responsavel_externo ILIKE ? ESCAPE \'\\\')';
    push @binds, '%' . $q . '%', '%' . $q . '%';
  }

  my $sql = $self->_entidade_select . ' WHERE ' . join(' AND ', @where)
    . ' ORDER BY lower(e.nome) LIMIT 500';

  return [ map { $self->_entidade_out($_) } @{ $self->_rows($sql, @binds) } ];
}

sub entidade_detail ($self, $id, $cod_inep) {
  my $r = $self->_row($self->_entidade_select . ' WHERE e.id = ? AND e.cod_inep = ?',
    $id + 0, $cod_inep + 0) or return;
  return $self->_entidade_out($r);
}

sub create_entidade ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.relacoes_entidades
       (cod_inep, gestor_id, tipo, nome, identificador, responsavel_externo,
        email, telefone, site, endereco, observacoes, atributos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)
     RETURNING id',
    $cod_inep + 0, $self->_gestor_bind($gestor_id),
    $params->{tipo}, $params->{nome}, $params->{identificador}, $params->{responsavel_externo},
    $params->{email}, $params->{telefone}, $params->{site}, $params->{endereco},
    $params->{observacoes}, $self->_encode_atributos($params->{atributos}),
  ) or return;
  return $self->entidade_detail($row->{id}, $cod_inep);
}

sub update_entidade ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.relacoes_entidades
     SET    tipo = ?, nome = ?, identificador = ?, responsavel_externo = ?,
            email = ?, telefone = ?, site = ?, endereco = ?, observacoes = ?,
            atributos = ?::jsonb, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $params->{tipo}, $params->{nome}, $params->{identificador}, $params->{responsavel_externo},
    $params->{email}, $params->{telefone}, $params->{site}, $params->{endereco},
    $params->{observacoes}, $self->_encode_atributos($params->{atributos}),
    $id + 0, $cod_inep + 0,
  ) or return;
  return $self->entidade_detail($id + 0, $cod_inep);
}

sub delete_entidade ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.relacoes_entidades WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub entidade_state ($self, $id, $cod_inep) {
  return $self->_row(
    'SELECT id, cod_inep FROM clean.relacoes_entidades WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# relações
# ---------------------------------------------------------------------------

sub _relacao_select {
  return 'SELECT r.id, r.entidade_id, r.finalidade, r.assunto, r.descricao,
                 r.status, r.prioridade, r.responsavel_interno, r.inicio,
                 r.proxima_acao, r.prazo, r.atributos, r.created_at, r.updated_at,
                 e.nome AS entidade_nome, e.tipo AS entidade_tipo
          FROM   clean.relacoes r
          JOIN   clean.relacoes_entidades e ON e.id = r.entidade_id';
}

sub list_relacoes ($self, $cod_inep, $filtros = {}) {
  my @where = ('r.cod_inep = ?');
  my @binds = ($cod_inep + 0);

  if (my $eid = $filtros->{entidade_id}) {
    push @where, 'r.entidade_id = ?';
    push @binds, $eid + 0;
  }
  if (my $fin = $filtros->{finalidade}) {
    push @where, 'r.finalidade = ?';
    push @binds, $fin;
  }
  if (my $st = $filtros->{status}) {
    push @where, 'r.status = ?';
    push @binds, $st;
  }
  if (my $pri = $filtros->{prioridade}) {
    push @where, 'r.prioridade = ?';
    push @binds, $pri;
  }
  if ($filtros->{vencidas}) {
    push @where, 'r.prazo IS NOT NULL AND r.prazo < CURRENT_DATE'
      . ' AND r.status NOT IN (\'concluida\', \'cancelada\')';
  }
  if (my $q = $filtros->{q}) {
    $q =~ s/%/\\%/g;
    push @where, '(r.assunto ILIKE ? ESCAPE \'\\\' OR r.proxima_acao ILIKE ? ESCAPE \'\\\''
      . ' OR e.nome ILIKE ? ESCAPE \'\\\')';
    push @binds, '%' . $q . '%', '%' . $q . '%', '%' . $q . '%';
  }

  my $sql = $self->_relacao_select . ' WHERE ' . join(' AND ', @where)
    . ' ORDER BY (r.status IN (\'concluida\',\'cancelada\')) ASC,'
    . ' r.prazo NULLS LAST, r.prioridade DESC, r.id DESC LIMIT 500';

  return [ map { $self->_relacao_out($_) } @{ $self->_rows($sql, @binds) } ];
}

# Agenda institucional: visão temporal derivada de clean.relacoes (sem tabela
# nova). Lista as relações abertas com prazo e/ou próxima ação, ordenadas por
# prazo; separa as sem prazo definido e conta as vencidas.
sub agenda_relacoes ($self, $cod_inep, $filtros = {}) {
  my @where = ('r.cod_inep = ?');
  my @binds = ($cod_inep + 0);

  push @where, 'r.status NOT IN (\'concluida\', \'cancelada\')'
    unless $filtros->{incluir_encerradas};
  push @where, '(r.prazo IS NOT NULL OR r.proxima_acao IS NOT NULL)';

  if (my $de = $filtros->{de}) {
    push @where, 'r.prazo >= ?::date';
    push @binds, $de;
  }
  if (my $ate = $filtros->{ate}) {
    push @where, 'r.prazo <= ?::date';
    push @binds, $ate;
  }

  my $sql = $self->_relacao_select . ' WHERE ' . join(' AND ', @where)
    . ' ORDER BY r.prazo NULLS LAST, r.prioridade DESC, r.id DESC LIMIT 500';

  my @out = map { $self->_relacao_out($_) } @{ $self->_rows($sql, @binds) };
  my @com_prazo = grep { $_->{prazo} } @out;
  my @sem_prazo = grep { !$_->{prazo} } @out;

  return {
    de        => $filtros->{de},
    ate       => $filtros->{ate},
    total     => scalar(@out),
    vencidas  => scalar(grep { $_->{vencida} } @out),
    itens     => \@com_prazo,
    sem_prazo => \@sem_prazo,
  };
}

sub relacao_detail ($self, $id, $cod_inep) {
  my $r = $self->_row($self->_relacao_select . ' WHERE r.id = ? AND r.cod_inep = ?',
    $id + 0, $cod_inep + 0) or return;
  return $self->_relacao_out($r);
}
sub create_relacao ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.relacoes
       (cod_inep, gestor_id, entidade_id, finalidade, assunto, descricao,
        status, prioridade, responsavel_interno, inicio, proxima_acao, prazo, atributos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)
     RETURNING id',
    $cod_inep + 0, $self->_gestor_bind($gestor_id), $params->{entidade_id} + 0,
    $params->{finalidade}, $params->{assunto}, $params->{descricao},
    $params->{status} // 'aberta', $params->{prioridade} // 'media', $params->{responsavel_interno},
    $params->{inicio}, $params->{proxima_acao}, $params->{prazo},
    $self->_encode_atributos($params->{atributos}),
  ) or return;
  return $self->relacao_detail($row->{id}, $cod_inep);
}

sub update_relacao ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.relacoes
     SET    entidade_id = ?, finalidade = ?, assunto = ?, descricao = ?,
            status = ?, prioridade = ?, responsavel_interno = ?, inicio = ?,
            proxima_acao = ?, prazo = ?, atributos = ?::jsonb, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $params->{entidade_id} + 0, $params->{finalidade}, $params->{assunto}, $params->{descricao},
    $params->{status}, $params->{prioridade}, $params->{responsavel_interno}, $params->{inicio},
    $params->{proxima_acao}, $params->{prazo}, $self->_encode_atributos($params->{atributos}),
    $id + 0, $cod_inep + 0,
  ) or return;
  return $self->relacao_detail($id + 0, $cod_inep);
}

sub delete_relacao ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.relacoes WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub _relacao_out ($self, $r) {
  my $hoje = DateTime->today(time_zone => 'local')->ymd;
  my $aberta = $r->{status} ne 'concluida' && $r->{status} ne 'cancelada';
  my $vencida = ($r->{prazo} && $aberta && substr($r->{prazo}, 0, 10) lt $hoje) ? 1 : 0;

  return {
    id                  => $r->{id} + 0,
    entidade_id         => $r->{entidade_id} + 0,
    entidade_nome       => $r->{entidade_nome},
    entidade_tipo       => $r->{entidade_tipo},
    finalidade          => $r->{finalidade},
    assunto             => $r->{assunto},
    descricao           => $r->{descricao},
    status              => $r->{status},
    prioridade          => $r->{prioridade},
    responsavel_interno => $r->{responsavel_interno},
    inicio              => $r->{inicio},
    proxima_acao        => $r->{proxima_acao},
    prazo               => $r->{prazo},
    vencida             => $vencida,
    atributos           => $self->_decode_atributos($r->{atributos}),
    updated_at          => $r->{updated_at},
  };
}

sub _entidade_out ($self, $r) {
  return {
    id                  => $r->{id} + 0,
    tipo                => $r->{tipo},
    nome                => $r->{nome},
    identificador       => $r->{identificador},
    responsavel_externo => $r->{responsavel_externo},
    email               => $r->{email},
    telefone            => $r->{telefone},
    site                => $r->{site},
    endereco            => $r->{endereco},
    observacoes         => $r->{observacoes},
    atributos           => $self->_decode_atributos($r->{atributos}),
    n_relacoes          => ($r->{n_relacoes} // 0) + 0,
    updated_at          => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _gestor_bind ($self, $gestor_id) {
  return defined $gestor_id && $gestor_id ? $gestor_id + 0 : undef;
}

sub _encode_atributos ($self, $atributos) {
  return '{}' unless ref $atributos eq 'HASH' && %$atributos;
  return Mojo::JSON::encode_json($atributos);
}

sub _decode_atributos ($self, $json) {
  return {} unless defined $json && length $json;
  my $decoded = eval { Mojo::JSON::decode_json($json) };
  return ref $decoded eq 'HASH' ? $decoded : {};
}

sub _txn ($self, $code) {
  my $ok = eval { $self->schema->storage->txn_do(sub { $code->() }); 1 };
  return 1 if $ok;
  die $@ || 'Erro de transação';
}

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;
