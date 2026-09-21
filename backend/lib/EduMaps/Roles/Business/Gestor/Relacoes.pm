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
  my $out = $self->_relacao_out($r);
  $out->{interacoes} = $self->list_interacoes_relacao($id + 0, $cod_inep);
  $out->{documentos} = $self->list_documentos_relacao($id + 0, $cod_inep);
  $out->{tarefas}    = $self->list_tarefas_relacao($id + 0, $cod_inep);
  return $out;
}

sub relacao_state ($self, $id, $cod_inep) {
  return $self->_row(
    'SELECT id, cod_inep FROM clean.relacoes WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# interações (timeline da relação)
# ---------------------------------------------------------------------------

sub list_interacoes_relacao ($self, $relacao_id, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT i.id, i.data, i.canal, i.participante, i.assunto, i.descricao,
            i.resultado, i.created_at, i.updated_at
     FROM   clean.relacoes_interacoes i
     JOIN   clean.relacoes r ON r.id = i.relacao_id
     WHERE  i.relacao_id = ? AND r.cod_inep = ?
     ORDER  BY i.data DESC NULLS LAST, i.id DESC',
    $relacao_id + 0, $cod_inep + 0,
  );
  return [ map { $self->_interacao_out($_) } @$rows ];
}

sub create_interacao_relacao ($self, $relacao_id, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.relacoes_interacoes
       (relacao_id, gestor_id, data, canal, participante, assunto, descricao, resultado)
     SELECT ?, ?, ?, ?, ?, ?, ?, ?
     WHERE EXISTS (SELECT 1 FROM clean.relacoes WHERE id = ? AND cod_inep = ?)
     RETURNING id',
    $relacao_id + 0, $self->_gestor_bind($gestor_id),
    $params->{data}, $params->{canal}, $params->{participante},
    $params->{assunto}, $params->{descricao}, $params->{resultado},
    $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_interacao_row($row->{id}, $relacao_id, $cod_inep);
}

sub update_interacao_relacao ($self, $id, $relacao_id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.relacoes_interacoes i
     SET    data = ?, canal = ?, participante = ?, assunto = ?, descricao = ?,
            resultado = ?, updated_at = NOW()
     FROM   clean.relacoes r
     WHERE  i.id = ? AND i.relacao_id = ? AND r.id = i.relacao_id AND r.cod_inep = ?
     RETURNING i.id',
    $params->{data}, $params->{canal}, $params->{participante},
    $params->{assunto}, $params->{descricao}, $params->{resultado},
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_interacao_row($row->{id}, $relacao_id, $cod_inep);
}

sub delete_interacao_relacao ($self, $id, $relacao_id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.relacoes_interacoes i
     USING  clean.relacoes r
     WHERE  i.id = ? AND i.relacao_id = ? AND r.id = i.relacao_id AND r.cod_inep = ?
     RETURNING i.id',
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub _interacao_row ($self, $id, $relacao_id, $cod_inep) {
  my $r = $self->_row(
    'SELECT i.id, i.data, i.canal, i.participante, i.assunto, i.descricao,
            i.resultado, i.created_at, i.updated_at
     FROM   clean.relacoes_interacoes i
     JOIN   clean.relacoes r ON r.id = i.relacao_id
     WHERE  i.id = ? AND i.relacao_id = ? AND r.cod_inep = ?',
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_interacao_out($r);
}

sub _interacao_out ($self, $r) {
  return {
    id           => $r->{id} + 0,
    data         => $r->{data},
    canal        => $r->{canal},
    participante => $r->{participante},
    assunto      => $r->{assunto},
    descricao    => $r->{descricao},
    resultado    => $r->{resultado},
    created_at   => $r->{created_at},
    updated_at   => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# documentos (anexos da relação; arquivo físico no upload_dir)
# ---------------------------------------------------------------------------

sub list_documentos_relacao ($self, $relacao_id, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT d.id, d.tipo, d.data, d.referencia, d.nome_original, d.mime,
            d.tamanho, d.created_at
     FROM   clean.relacoes_documentos d
     JOIN   clean.relacoes r ON r.id = d.relacao_id
     WHERE  d.relacao_id = ? AND r.cod_inep = ?
     ORDER  BY d.created_at DESC, d.id DESC',
    $relacao_id + 0, $cod_inep + 0,
  );
  return [ map {
    { id => $_->{id} + 0, tipo => $_->{tipo}, data => $_->{data},
      referencia => $_->{referencia}, nome_original => $_->{nome_original},
      mime => $_->{mime}, tamanho => $_->{tamanho} + 0, created_at => $_->{created_at} }
  } @$rows ];
}

sub registrar_documento_relacao ($self, $relacao_id, $cod_inep, $gestor_id, $info = {}) {
  return unless $self->relacao_state($relacao_id, $cod_inep);
  my $row = $self->_row(
    'INSERT INTO clean.relacoes_documentos
       (relacao_id, gestor_id, tipo, data, referencia, nome_original, caminho, mime, tamanho)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     RETURNING id',
    $relacao_id + 0, $self->_gestor_bind($gestor_id),
    $info->{tipo}, $info->{data}, $info->{referencia},
    $info->{nome_original}, $info->{caminho}, $info->{mime}, $info->{tamanho} + 0,
  ) or return;
  return { id => $row->{id} + 0, documentos => $self->list_documentos_relacao($relacao_id, $cod_inep) };
}

sub documento_relacao_row ($self, $relacao_id, $cod_inep, $documento_id) {
  return $self->_row(
    'SELECT d.id, d.nome_original, d.caminho, d.mime, d.tamanho
     FROM   clean.relacoes_documentos d
     JOIN   clean.relacoes r ON r.id = d.relacao_id
     WHERE  d.id = ? AND d.relacao_id = ? AND r.cod_inep = ?',
    $documento_id + 0, $relacao_id + 0, $cod_inep + 0,
  );
}

sub delete_documento_relacao ($self, $relacao_id, $cod_inep, $documento_id) {
  return $self->_row(
    'DELETE FROM clean.relacoes_documentos d
     USING  clean.relacoes r
     WHERE  d.id = ? AND d.relacao_id = ? AND r.id = d.relacao_id AND r.cod_inep = ?
     RETURNING d.caminho',
    $documento_id + 0, $relacao_id + 0, $cod_inep + 0,
  );
}

sub documentos_relacao_caminhos ($self, $relacao_id, $cod_inep) {
  return $self->_rows(
    'SELECT d.caminho
     FROM   clean.relacoes_documentos d
     JOIN   clean.relacoes r ON r.id = d.relacao_id
     WHERE  d.relacao_id = ? AND r.cod_inep = ?',
    $relacao_id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# tarefas (checklist da relação)
# ---------------------------------------------------------------------------

sub list_tarefas_relacao ($self, $relacao_id, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT t.id, t.descricao, t.responsavel, t.prazo, t.status, t.concluida_em,
            t.created_at, t.updated_at
     FROM   clean.relacoes_tarefas t
     JOIN   clean.relacoes r ON r.id = t.relacao_id
     WHERE  t.relacao_id = ? AND r.cod_inep = ?
     ORDER  BY (t.status = \'concluida\'), t.prazo NULLS LAST, t.id',
    $relacao_id + 0, $cod_inep + 0,
  );
  return [ map { $self->_tarefa_out($_) } @$rows ];
}

sub create_tarefa_relacao ($self, $relacao_id, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.relacoes_tarefas (relacao_id, gestor_id, descricao, responsavel, prazo, status)
     SELECT ?, ?, ?, ?, ?, ?
     WHERE EXISTS (SELECT 1 FROM clean.relacoes WHERE id = ? AND cod_inep = ?)
     RETURNING id',
    $relacao_id + 0, $self->_gestor_bind($gestor_id),
    $params->{descricao}, $params->{responsavel}, $params->{prazo},
    $params->{status} // 'pendente',
    $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_tarefa_row($row->{id}, $relacao_id, $cod_inep);
}

sub update_tarefa_relacao ($self, $id, $relacao_id, $cod_inep, $params = {}) {
  my $status = $params->{status} // 'pendente';
  my $row = $self->_row(
    'UPDATE clean.relacoes_tarefas t
     SET    descricao = ?, responsavel = ?, prazo = ?, status = ?,
            concluida_em = CASE WHEN ? = \'concluida\' THEN COALESCE(t.concluida_em, NOW()) ELSE NULL END,
            updated_at = NOW()
     FROM   clean.relacoes r
     WHERE  t.id = ? AND t.relacao_id = ? AND r.id = t.relacao_id AND r.cod_inep = ?
     RETURNING t.id',
    $params->{descricao}, $params->{responsavel}, $params->{prazo}, $status, $status,
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_tarefa_row($row->{id}, $relacao_id, $cod_inep);
}

sub delete_tarefa_relacao ($self, $id, $relacao_id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.relacoes_tarefas t
     USING  clean.relacoes r
     WHERE  t.id = ? AND t.relacao_id = ? AND r.id = t.relacao_id AND r.cod_inep = ?
     RETURNING t.id',
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub _tarefa_row ($self, $id, $relacao_id, $cod_inep) {
  my $r = $self->_row(
    'SELECT t.id, t.descricao, t.responsavel, t.prazo, t.status, t.concluida_em,
            t.created_at, t.updated_at
     FROM   clean.relacoes_tarefas t
     JOIN   clean.relacoes r ON r.id = t.relacao_id
     WHERE  t.id = ? AND t.relacao_id = ? AND r.cod_inep = ?',
    $id + 0, $relacao_id + 0, $cod_inep + 0,
  ) or return;
  return $self->_tarefa_out($r);
}

sub _tarefa_out ($self, $r) {
  return {
    id           => $r->{id} + 0,
    descricao    => $r->{descricao},
    responsavel  => $r->{responsavel},
    prazo        => $r->{prazo},
    status       => $r->{status},
    concluida_em => $r->{concluida_em},
    created_at   => $r->{created_at},
    updated_at   => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# indicadores (derivados de relacoes/interacoes/tarefas — sem tabela nova)
# ---------------------------------------------------------------------------

sub indicadores_relacoes ($self, $cod_inep) {
  my $inep = $cod_inep + 0;

  my $resumo = $self->_row(
    'SELECT
       COUNT(*) FILTER (WHERE status NOT IN (\'concluida\', \'cancelada\')) AS abertas,
       COUNT(*) FILTER (WHERE prazo < CURRENT_DATE
                          AND status NOT IN (\'concluida\', \'cancelada\')) AS vencidas,
       COUNT(*) FILTER (WHERE status = \'concluida\') AS concluidas
     FROM clean.relacoes WHERE cod_inep = ?',
    $inep,
  ) // {};

  my $entidades = $self->_row(
    'SELECT COUNT(*) AS n FROM clean.relacoes_entidades WHERE cod_inep = ?', $inep,
  )->{n};

  my $tarefas = $self->_row(
    'SELECT
       COUNT(*) FILTER (WHERE t.status = \'pendente\') AS pendentes,
       COUNT(*) FILTER (WHERE t.status = \'pendente\' AND t.prazo < CURRENT_DATE) AS vencidas
     FROM clean.relacoes_tarefas t
     JOIN clean.relacoes r ON r.id = t.relacao_id
     WHERE r.cod_inep = ?',
    $inep,
  ) // {};

  my $por_grupo = $self->_rows(
    'SELECT COALESCE(e.tipo, \'Sem grupo\') AS grupo,
            COUNT(*) AS total,
            COUNT(*) FILTER (WHERE r.prazo < CURRENT_DATE
                               AND r.status NOT IN (\'concluida\', \'cancelada\')) AS vencidas
     FROM   clean.relacoes r
     JOIN   clean.relacoes_entidades e ON e.id = r.entidade_id
     WHERE  r.cod_inep = ?
     GROUP  BY 1
     ORDER  BY total DESC, grupo',
    $inep,
  );

  my $sem_atividade = $self->_rows(
    'SELECT r.id, r.assunto, e.nome AS entidade_nome, r.status, r.prioridade, r.prazo,
            MAX(i.data) AS ultima_interacao
     FROM   clean.relacoes r
     JOIN   clean.relacoes_entidades e ON e.id = r.entidade_id
     LEFT JOIN clean.relacoes_interacoes i ON i.relacao_id = r.id
     WHERE  r.cod_inep = ? AND r.status NOT IN (\'concluida\', \'cancelada\')
     GROUP  BY r.id, e.nome
     HAVING MAX(i.data) IS NULL OR MAX(i.data) < CURRENT_DATE - INTERVAL \'60 days\'
     ORDER  BY MAX(i.data) NULLS FIRST, r.prazo NULLS LAST
     LIMIT  10',
    $inep,
  );

  my $tempo = $self->_row(
    'SELECT ROUND(AVG(f.first_dia - r.created_at::date)) AS dias
     FROM   clean.relacoes r
     JOIN  (SELECT relacao_id, MIN(data) AS first_dia
            FROM clean.relacoes_interacoes GROUP BY relacao_id) f ON f.relacao_id = r.id
     WHERE  r.cod_inep = ?',
    $inep,
  ) // {};

  return {
    resumo => {
      relacoes_abertas    => ($resumo->{abertas} // 0) + 0,
      vencidas            => ($resumo->{vencidas} // 0) + 0,
      concluidas          => ($resumo->{concluidas} // 0) + 0,
      entidades           => ($entidades // 0) + 0,
      tarefas_pendentes   => ($tarefas->{pendentes} // 0) + 0,
      tarefas_vencidas    => ($tarefas->{vencidas} // 0) + 0,
    },
    por_grupo => [ map {
      { grupo => $_->{grupo}, total => $_->{total} + 0, vencidas => $_->{vencidas} + 0 }
    } @$por_grupo ],
    sem_atividade => [ map {
      { id => $_->{id} + 0, assunto => $_->{assunto}, entidade_nome => $_->{entidade_nome},
        status => $_->{status}, prioridade => $_->{prioridade}, prazo => $_->{prazo},
        ultima_interacao => $_->{ultima_interacao} }
    } @$sem_atividade ],
    tempo_medio_primeira_interacao_dias =>
      defined $tempo->{dias} ? $tempo->{dias} + 0 : undef,
  };
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
