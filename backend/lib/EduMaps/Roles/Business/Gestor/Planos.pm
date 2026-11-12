package EduMaps::Roles::Business::Gestor::Planos;
use Mojo::Base -role, -signatures;
use Mojo::JSON ();
use utf8;

# Planos de gestão da escola acompanháveis (#369, épico #368).
#
#   plano -> objetivos -> metas (mensuráveis)
#                      -> ações (responsável, prazo, situação, recurso),
#                         opcionalmente ligadas a uma meta do MESMO objetivo
#
# Regras:
#   * tudo é da escola (cod_inep): toda leitura e escrita passa pela posse;
#   * plano ENCERRADO é só leitura; a única mudança aceita é reabrir
#     (situacao -> vigente/rascunho), auditada como 'reaberto';
#   * plano ARQUIVADO sai da lista e das rotas (404), mas não é apagado;
#   * "atrasada" é derivada: prazo vencido (hoje em America/Sao_Paulo) e ação
#     não iniciada ou em andamento. Nunca é gravada;
#   * toda mudança gera auditoria e atualiza planos_gestao.updated_at.
#
# Atualização é PARCIAL: só os campos presentes no hash mudam (um campo
# presente com undef limpa o valor).
#
# Erros esperados saem como exceção EduMaps::Roles::Business::Gestor::Planos::Erro
# (status + mensagem), que o controller traduz em resposta HTTP.

requires qw(schema);

our @TIPOS          = qw(gestao acao ppp outro);
our @SITUACOES      = qw(rascunho vigente encerrado);
our @SENTIDOS       = qw(aumentar reduzir manter);
our @SITUACOES_ACAO = qw(nao_iniciada em_andamento concluida cancelada);
our @FONTES_RECURSO = qw(pdde fundeb proprio parceria outro);

use constant HOJE_SQL => q{(NOW() AT TIME ZONE 'America/Sao_Paulo')::date};

# ---------------------------------------------------------------------------
# erros
# ---------------------------------------------------------------------------

package EduMaps::Roles::Business::Gestor::Planos::Erro {
  use Mojo::Base -base, -signatures;
  has [qw(status mensagem)];
  use overload '""' => sub ($s, @) { $s->mensagem }, fallback => 1;
}

sub _falha ($self, $status, $mensagem) {
  die EduMaps::Roles::Business::Gestor::Planos::Erro->new(status => $status, mensagem => $mensagem);
}

# ---------------------------------------------------------------------------
# planos
# ---------------------------------------------------------------------------

sub planos_listar ($self, $cod_inep, $opt = {}) {
  my $hoje = HOJE_SQL;
  my $rows = $self->_pl_rows(
    qq{SELECT p.id, p.tipo, p.titulo, p.descricao, p.inicio, p.fim, p.situacao,
              p.documento_id, p.alertas_ativos, p.arquivado_em, p.created_at, p.updated_at,
              (SELECT count(*) FROM clean.planos_objetivos o WHERE o.plano_id = p.id) AS n_objetivos,
              (SELECT count(*) FROM clean.planos_metas m
                 JOIN clean.planos_objetivos o ON o.id = m.objetivo_id WHERE o.plano_id = p.id) AS n_metas,
              (SELECT count(*) FROM clean.planos_acoes a
                 JOIN clean.planos_objetivos o ON o.id = a.objetivo_id WHERE o.plano_id = p.id) AS n_acoes,
              (SELECT count(*) FROM clean.planos_acoes a
                 JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
                WHERE o.plano_id = p.id AND a.situacao = 'concluida') AS n_acoes_concluidas,
              (SELECT count(*) FROM clean.planos_acoes a
                 JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
                WHERE o.plano_id = p.id AND a.situacao IN ('nao_iniciada', 'em_andamento')
                  AND a.prazo < $hoje) AS n_acoes_atrasadas
       FROM   clean.planos_gestao p
       WHERE  p.cod_inep = ? AND (p.arquivado_em IS NULL OR ?)
       ORDER  BY CASE p.situacao WHEN 'vigente' THEN 0 WHEN 'rascunho' THEN 1 ELSE 2 END,
                 p.updated_at DESC, p.id DESC},
    $cod_inep + 0, $opt->{arquivados} ? 1 : 0,
  );
  return [ map { $self->_plano_out($_) } @$rows ];
}

sub plano_detalhe ($self, $cod_inep, $id) {
  my $p = $self->_plano_ou_404($cod_inep, $id);
  my $hoje = HOJE_SQL;

  my $objetivos = $self->_pl_rows(
    'SELECT id, titulo, descricao, ordem FROM clean.planos_objetivos
      WHERE plano_id = ? ORDER BY ordem, id', $id + 0);
  my $metas = $self->_pl_rows(
    'SELECT m.id, m.objetivo_id, m.descricao, m.unidade, m.sentido, m.indicador_codigo,
            m.linha_base, m.alvo, m.prazo
       FROM clean.planos_metas m JOIN clean.planos_objetivos o ON o.id = m.objetivo_id
      WHERE o.plano_id = ? ORDER BY m.id', $id + 0);
  my $acoes = $self->_pl_rows(
    qq{SELECT a.id, a.objetivo_id, a.meta_id, a.descricao, a.responsavel, a.inicio, a.prazo,
              a.situacao, a.concluida_em, a.custo_previsto, a.fonte_recurso,
              (a.situacao IN ('nao_iniciada', 'em_andamento') AND a.prazo < $hoje) AS atrasada
       FROM   clean.planos_acoes a JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
       WHERE  o.plano_id = ? ORDER BY a.prazo NULLS LAST, a.id}, $id + 0);

  my %por_obj;
  push @{ $por_obj{ $_->{objetivo_id} }{metas} }, $self->_meta_out($_) for @$metas;
  push @{ $por_obj{ $_->{objetivo_id} }{acoes} }, $self->_acao_out($_) for @$acoes;

  my $out = $self->_plano_out($p);
  $out->{objetivos} = [ map {
    my $o = $self->_objetivo_out($_);
    $o->{metas} = $por_obj{ $_->{id} }{metas} // [];
    $o->{acoes} = $por_obj{ $_->{id} }{acoes} // [];
    $o;
  } @$objetivos ];
  $out->{resumo} = {
    n_objetivos        => scalar @$objetivos,
    n_metas            => scalar @$metas,
    n_acoes            => scalar @$acoes,
    n_acoes_concluidas => scalar(grep { $_->{situacao} eq 'concluida' } @$acoes),
    n_acoes_atrasadas  => scalar(grep { $_->{atrasada} } @$acoes),
  };
  return $out;
}

sub plano_criar ($self, $cod_inep, $gestor_id, $p) {
  $self->_documento_da_escola($cod_inep, $p->{documento_id});
  $self->_falha(400, 'O fim do plano não pode ser antes do início.')
    if defined $p->{inicio} && defined $p->{fim} && $p->{fim} lt $p->{inicio};
  my $id;
  $self->_pl_txn(sub {
    my $row = $self->_pl_row(
      'INSERT INTO clean.planos_gestao
         (cod_inep, criado_por, tipo, titulo, descricao, inicio, fim, situacao, documento_id, alertas_ativos)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id',
      $cod_inep + 0, $self->_pl_gestor($gestor_id), $p->{tipo}, $p->{titulo}, $p->{descricao},
      $p->{inicio}, $p->{fim}, $p->{situacao} // 'rascunho', $p->{documento_id},
      exists $p->{alertas_ativos} ? ($p->{alertas_ativos} ? 1 : 0) : 1,
    );
    $id = $row->{id};
    $self->_pl_auditar($id, $cod_inep, $gestor_id, 'plano', $id, 'criado',
      { titulo => $p->{titulo}, tipo => $p->{tipo} });
  });
  return $self->plano_detalhe($cod_inep, $id);
}

sub plano_atualizar ($self, $cod_inep, $gestor_id, $id, $p) {
  my $atual = $self->_plano_ou_404($cod_inep, $id);

  my $acao = 'alterado';
  if ($atual->{situacao} eq 'encerrado') {
    # Encerrado só aceita reabrir — e nada mais junto.
    my @outros = grep { $_ ne 'situacao' } keys %$p;
    my $reabre = exists $p->{situacao} && $p->{situacao} ne 'encerrado';
    $self->_falha(409, 'Plano encerrado é só leitura. Reabra o plano para editar.')
      if !$reabre || @outros;
    $acao = 'reaberto';
  }
  elsif (($p->{situacao} // '') eq 'encerrado') {
    $acao = 'encerrado';
  }

  $self->_documento_da_escola($cod_inep, $p->{documento_id}) if exists $p->{documento_id};
  my %novo = (%$atual, %$p);
  $self->_falha(400, 'O fim do plano não pode ser antes do início.')
    if defined $novo{inicio} && defined $novo{fim} && $novo{fim} lt $novo{inicio};

  $self->_pl_txn(sub {
    $self->_pl_rows(
      'UPDATE clean.planos_gestao
          SET tipo = ?, titulo = ?, descricao = ?, inicio = ?, fim = ?, situacao = ?,
              documento_id = ?, alertas_ativos = ?, updated_at = NOW()
        WHERE id = ? AND cod_inep = ?',
      @novo{qw(tipo titulo descricao inicio fim situacao documento_id)},
      $novo{alertas_ativos} ? 1 : 0, $id + 0, $cod_inep + 0,
    );
    $self->_pl_auditar($id, $cod_inep, $gestor_id, 'plano', $id, $acao, _pl_mudancas($atual, $p));
  });
  return $self->plano_detalhe($cod_inep, $id);
}

sub plano_arquivar ($self, $cod_inep, $gestor_id, $id) {
  $self->_plano_ou_404($cod_inep, $id);
  $self->_pl_txn(sub {
    $self->_pl_rows(
      'UPDATE clean.planos_gestao SET arquivado_em = NOW(), updated_at = NOW()
        WHERE id = ? AND cod_inep = ?', $id + 0, $cod_inep + 0);
    $self->_pl_auditar($id, $cod_inep, $gestor_id, 'plano', $id, 'arquivado', {});
  });
  return 1;
}

sub plano_auditoria ($self, $cod_inep, $id) {
  $self->_plano_ou_404($cod_inep, $id);
  my $rows = $self->_pl_rows(
    'SELECT a.id, a.entidade, a.entidade_id, a.acao, a.detalhes::text AS detalhes, a.criado_em,
            g.nome AS gestor
       FROM clean.planos_auditoria a LEFT JOIN clean.gestores g ON g.id = a.gestor_id
      WHERE a.plano_id = ? ORDER BY a.criado_em DESC, a.id DESC LIMIT 200', $id + 0);
  return [ map { {
    id          => $_->{id} + 0,
    entidade    => $_->{entidade},
    entidade_id => $_->{entidade_id} + 0,
    acao        => $_->{acao},
    detalhes    => eval { Mojo::JSON::decode_json($_->{detalhes}) } // {},
    criado_em   => $_->{criado_em},
    gestor      => $_->{gestor},
  } } @$rows ];
}

# ---------------------------------------------------------------------------
# objetivos
# ---------------------------------------------------------------------------

sub objetivo_criar ($self, $cod_inep, $gestor_id, $plano_id, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      'INSERT INTO clean.planos_objetivos (plano_id, titulo, descricao, ordem)
       VALUES (?, ?, ?, COALESCE(?, (SELECT COALESCE(max(ordem), 0) + 1
                                       FROM clean.planos_objetivos WHERE plano_id = ?)))
       RETURNING id, titulo, descricao, ordem',
      $plano_id + 0, $p->{titulo}, $p->{descricao}, $p->{ordem}, $plano_id + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'objetivo', $row->{id}, 'criado',
      { titulo => $p->{titulo} });
  });
  return { %{ $self->_objetivo_out($row) }, metas => [], acoes => [] };
}

sub objetivo_atualizar ($self, $cod_inep, $gestor_id, $plano_id, $oid, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_objetivo_ou_404($plano_id, $oid);
  my %novo = (%$atual, %$p);
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      'UPDATE clean.planos_objetivos SET titulo = ?, descricao = ?, ordem = ?, updated_at = NOW()
        WHERE id = ? AND plano_id = ? RETURNING id, titulo, descricao, ordem',
      @novo{qw(titulo descricao ordem)}, $oid + 0, $plano_id + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'objetivo', $oid, 'alterado', _pl_mudancas($atual, $p));
  });
  return $self->_objetivo_out($row);
}

sub objetivo_excluir ($self, $cod_inep, $gestor_id, $plano_id, $oid) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_objetivo_ou_404($plano_id, $oid);
  $self->_pl_txn(sub {
    $self->_pl_rows('DELETE FROM clean.planos_objetivos WHERE id = ? AND plano_id = ?', $oid + 0, $plano_id + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'objetivo', $oid, 'excluido',
      { titulo => $atual->{titulo} });
  });
  return 1;
}

# ---------------------------------------------------------------------------
# metas
# ---------------------------------------------------------------------------

sub meta_criar ($self, $cod_inep, $gestor_id, $plano_id, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  $self->_objetivo_ou_404($plano_id, $p->{objetivo_id}, 400);
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      'INSERT INTO clean.planos_metas (objetivo_id, descricao, unidade, sentido, linha_base, alvo, prazo)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       RETURNING id, objetivo_id, descricao, unidade, sentido, indicador_codigo, linha_base, alvo, prazo',
      $p->{objetivo_id} + 0, $p->{descricao}, $p->{unidade}, $p->{sentido} // 'aumentar',
      $p->{linha_base}, $p->{alvo}, $p->{prazo});
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $row->{id}, 'criado',
      { descricao => $p->{descricao} });
  });
  return $self->_meta_out($row);
}

sub meta_atualizar ($self, $cod_inep, $gestor_id, $plano_id, $mid, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_meta_ou_404($plano_id, $mid);
  $self->_objetivo_ou_404($plano_id, $p->{objetivo_id}, 400) if exists $p->{objetivo_id};
  my %novo = (%$atual, %$p);
  my $row;
  $self->_pl_txn(sub {
    # Meta que muda de objetivo solta as ações do objetivo antigo (a ação só
    # pode apontar para meta do próprio objetivo — trigger).
    if ($novo{objetivo_id} != $atual->{objetivo_id}) {
      $self->_pl_rows('UPDATE clean.planos_acoes SET meta_id = NULL, updated_at = NOW() WHERE meta_id = ?', $mid + 0);
    }
    $row = $self->_pl_row(
      'UPDATE clean.planos_metas
          SET objetivo_id = ?, descricao = ?, unidade = ?, sentido = ?, linha_base = ?, alvo = ?,
              prazo = ?, updated_at = NOW()
        WHERE id = ?
        RETURNING id, objetivo_id, descricao, unidade, sentido, indicador_codigo, linha_base, alvo, prazo',
      @novo{qw(objetivo_id descricao unidade sentido linha_base alvo prazo)}, $mid + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $mid, 'alterado', _pl_mudancas($atual, $p));
  });
  return $self->_meta_out($row);
}

sub meta_excluir ($self, $cod_inep, $gestor_id, $plano_id, $mid) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_meta_ou_404($plano_id, $mid);
  $self->_pl_txn(sub {
    $self->_pl_rows('DELETE FROM clean.planos_metas WHERE id = ?', $mid + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $mid, 'excluido',
      { descricao => $atual->{descricao} });
  });
  return 1;
}

# ---------------------------------------------------------------------------
# ações
# ---------------------------------------------------------------------------

sub acao_criar ($self, $cod_inep, $gestor_id, $plano_id, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  $self->_objetivo_ou_404($plano_id, $p->{objetivo_id}, 400);
  $self->_meta_do_objetivo($p->{meta_id}, $p->{objetivo_id});
  $self->_periodo_ok($p->{inicio}, $p->{prazo});
  my $situacao = $p->{situacao} // 'nao_iniciada';
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      'INSERT INTO clean.planos_acoes
         (objetivo_id, meta_id, descricao, responsavel, inicio, prazo, situacao, concluida_em,
          custo_previsto, fonte_recurso)
       VALUES (?, ?, ?, ?, ?, ?, ?, CASE WHEN ? = \'concluida\' THEN NOW() END, ?, ?)
       RETURNING id',
      $p->{objetivo_id} + 0, $p->{meta_id}, $p->{descricao}, $p->{responsavel}, $p->{inicio},
      $p->{prazo}, $situacao, $situacao, $p->{custo_previsto}, $p->{fonte_recurso});
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'acao', $row->{id}, 'criado',
      { descricao => $p->{descricao} });
  });
  return $self->_acao_por_id($plano_id, $row->{id});
}

sub acao_atualizar ($self, $cod_inep, $gestor_id, $plano_id, $aid, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_acao_ou_404($plano_id, $aid);
  $self->_objetivo_ou_404($plano_id, $p->{objetivo_id}, 400) if exists $p->{objetivo_id};
  my %novo = (%$atual, %$p);
  # Mudou de objetivo sem dizer a meta: a meta antiga não vale mais.
  $novo{meta_id} = undef
    if exists $p->{objetivo_id} && !exists $p->{meta_id} && $novo{objetivo_id} != $atual->{objetivo_id};
  $self->_meta_do_objetivo($novo{meta_id}, $novo{objetivo_id});
  $self->_periodo_ok($novo{inicio}, $novo{prazo});
  $self->_pl_txn(sub {
    $self->_pl_rows(
      'UPDATE clean.planos_acoes
          SET objetivo_id = ?, meta_id = ?, descricao = ?, responsavel = ?, inicio = ?, prazo = ?,
              situacao = ?,
              concluida_em = CASE WHEN ? = \'concluida\' THEN COALESCE(concluida_em, NOW()) END,
              custo_previsto = ?, fonte_recurso = ?, updated_at = NOW()
        WHERE id = ?',
      @novo{qw(objetivo_id meta_id descricao responsavel inicio prazo situacao situacao
               custo_previsto fonte_recurso)}, $aid + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'acao', $aid, 'alterado', _pl_mudancas($atual, $p));
  });
  return $self->_acao_por_id($plano_id, $aid);
}

sub acao_excluir ($self, $cod_inep, $gestor_id, $plano_id, $aid) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_acao_ou_404($plano_id, $aid);
  $self->_pl_txn(sub {
    $self->_pl_rows('DELETE FROM clean.planos_acoes WHERE id = ?', $aid + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'acao', $aid, 'excluido',
      { descricao => $atual->{descricao} });
  });
  return 1;
}

# ---------------------------------------------------------------------------
# posse e regras
# ---------------------------------------------------------------------------

sub _plano_ou_404 ($self, $cod_inep, $id) {
  my $p = $self->_pl_row(
    'SELECT id, tipo, titulo, descricao, inicio, fim, situacao, documento_id, alertas_ativos,
            arquivado_em, created_at, updated_at
       FROM clean.planos_gestao WHERE id = ? AND cod_inep = ? AND arquivado_em IS NULL',
    $id + 0, $cod_inep + 0);
  $self->_falha(404, 'Plano não encontrado.') unless $p;
  return $p;
}

sub _plano_editavel ($self, $cod_inep, $id) {
  my $p = $self->_plano_ou_404($cod_inep, $id);
  $self->_falha(409, 'Plano encerrado é só leitura. Reabra o plano para editar.')
    if $p->{situacao} eq 'encerrado';
  return $p;
}

# $status_falha: 404 quando o id vem da rota; 400 quando vem do corpo.
sub _objetivo_ou_404 ($self, $plano_id, $oid, $status_falha = 404) {
  my $o = defined $oid ? $self->_pl_row(
    'SELECT id, titulo, descricao, ordem FROM clean.planos_objetivos WHERE id = ? AND plano_id = ?',
    $oid + 0, $plano_id + 0) : undef;
  $self->_falha($status_falha, 'Objetivo não encontrado neste plano.') unless $o;
  return $o;
}

sub _meta_ou_404 ($self, $plano_id, $mid) {
  my $m = $self->_pl_row(
    'SELECT m.id, m.objetivo_id, m.descricao, m.unidade, m.sentido, m.indicador_codigo,
            m.linha_base, m.alvo, m.prazo
       FROM clean.planos_metas m JOIN clean.planos_objetivos o ON o.id = m.objetivo_id
      WHERE m.id = ? AND o.plano_id = ?', $mid + 0, $plano_id + 0);
  $self->_falha(404, 'Meta não encontrada neste plano.') unless $m;
  return $m;
}

sub _acao_ou_404 ($self, $plano_id, $aid) {
  my $a = $self->_pl_row(
    'SELECT a.id, a.objetivo_id, a.meta_id, a.descricao, a.responsavel, a.inicio, a.prazo,
            a.situacao, a.custo_previsto, a.fonte_recurso
       FROM clean.planos_acoes a JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
      WHERE a.id = ? AND o.plano_id = ?', $aid + 0, $plano_id + 0);
  $self->_falha(404, 'Ação não encontrada neste plano.') unless $a;
  return $a;
}

sub _acao_por_id ($self, $plano_id, $aid) {
  my $hoje = HOJE_SQL;
  my $a = $self->_pl_row(
    qq{SELECT a.id, a.objetivo_id, a.meta_id, a.descricao, a.responsavel, a.inicio, a.prazo,
              a.situacao, a.concluida_em, a.custo_previsto, a.fonte_recurso,
              (a.situacao IN ('nao_iniciada', 'em_andamento') AND a.prazo < $hoje) AS atrasada
       FROM   clean.planos_acoes a JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
       WHERE  a.id = ? AND o.plano_id = ?}, $aid + 0, $plano_id + 0);
  return $self->_acao_out($a);
}

sub _meta_do_objetivo ($self, $meta_id, $objetivo_id) {
  return unless defined $meta_id;
  $self->_falha(400, 'A meta escolhida não pertence ao objetivo da ação.')
    unless $self->_pl_row('SELECT 1 FROM clean.planos_metas WHERE id = ? AND objetivo_id = ?',
                          $meta_id + 0, $objetivo_id + 0);
}

sub _periodo_ok ($self, $inicio, $prazo) {
  $self->_falha(400, 'O prazo da ação não pode ser antes do início.')
    if defined $inicio && defined $prazo && $prazo lt $inicio;
}

sub _documento_da_escola ($self, $cod_inep, $documento_id) {
  return unless defined $documento_id;
  $self->_falha(400, 'Documento não encontrado nesta escola.')
    unless $self->_pl_row('SELECT 1 FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
                          $documento_id + 0, $cod_inep + 0);
}

# Campo => [antes, depois] só do que mudou (para a auditoria).
sub _pl_mudancas ($antes, $p) {
  my %m;
  for my $k (sort keys %$p) {
    my ($a, $d) = ($antes->{$k}, $p->{$k});
    next if (defined $a ? $a : "\0undef") eq (defined $d ? $d : "\0undef");
    $m{$k} = [ $a, $d ];
  }
  return \%m;
}

# ---------------------------------------------------------------------------
# saída (tipos estáveis para o frontend)
# ---------------------------------------------------------------------------

sub _pl_num ($v) { defined $v ? 0 + $v : undef }

sub _plano_out ($self, $r) {
  my %o = (
    id             => $r->{id} + 0,
    tipo           => $r->{tipo},
    titulo         => $r->{titulo},
    descricao      => $r->{descricao},
    inicio         => $r->{inicio},
    fim            => $r->{fim},
    situacao       => $r->{situacao},
    documento_id   => _pl_num($r->{documento_id}),
    alertas_ativos => $r->{alertas_ativos} ? Mojo::JSON::true : Mojo::JSON::false,
    arquivado      => $r->{arquivado_em} ? Mojo::JSON::true : Mojo::JSON::false,
    criado_em      => $r->{created_at},
    atualizado_em  => $r->{updated_at},
  );
  if (exists $r->{n_objetivos}) {
    $o{resumo} = { map { $_ => $r->{$_} + 0 }
      qw(n_objetivos n_metas n_acoes n_acoes_concluidas n_acoes_atrasadas) };
  }
  return \%o;
}

sub _objetivo_out ($self, $r) {
  return { id => $r->{id} + 0, titulo => $r->{titulo}, descricao => $r->{descricao}, ordem => $r->{ordem} + 0 };
}

sub _meta_out ($self, $r) {
  return {
    id               => $r->{id} + 0,
    objetivo_id      => $r->{objetivo_id} + 0,
    descricao        => $r->{descricao},
    unidade          => $r->{unidade},
    sentido          => $r->{sentido},
    indicador_codigo => $r->{indicador_codigo},
    linha_base       => _pl_num($r->{linha_base}),
    alvo             => _pl_num($r->{alvo}),
    prazo            => $r->{prazo},
  };
}

sub _acao_out ($self, $r) {
  return {
    id             => $r->{id} + 0,
    objetivo_id    => $r->{objetivo_id} + 0,
    meta_id        => _pl_num($r->{meta_id}),
    descricao      => $r->{descricao},
    responsavel    => $r->{responsavel},
    inicio         => $r->{inicio},
    prazo          => $r->{prazo},
    situacao       => $r->{situacao},
    concluida_em   => $r->{concluida_em},
    custo_previsto => _pl_num($r->{custo_previsto}),
    fonte_recurso  => $r->{fonte_recurso},
    atrasada       => $r->{atrasada} ? Mojo::JSON::true : Mojo::JSON::false,
  };
}

# ---------------------------------------------------------------------------
# banco (nomes próprios: o Model::Gestor compõe várias roles com helpers
# homônimos; estes não dependem de qual delas foi composta primeiro)
# ---------------------------------------------------------------------------

sub _pl_tocar ($self, $plano_id) {
  $self->_pl_rows('UPDATE clean.planos_gestao SET updated_at = NOW() WHERE id = ?', $plano_id + 0);
}

sub _pl_auditar ($self, $plano_id, $cod_inep, $gestor_id, $entidade, $entidade_id, $acao, $detalhes) {
  $self->_pl_rows(
    'INSERT INTO clean.planos_auditoria (plano_id, cod_inep, gestor_id, entidade, entidade_id, acao, detalhes)
     VALUES (?, ?, ?, ?, ?, ?, ?::jsonb)',
    $plano_id + 0, $cod_inep + 0, $self->_pl_gestor($gestor_id), $entidade, $entidade_id + 0, $acao,
    Mojo::JSON::encode_json($detalhes // {}));
}

sub _pl_gestor ($self, $gestor_id) { $gestor_id ? $gestor_id + 0 : undef }

sub _pl_txn ($self, $code) {
  my $ok = eval { $self->schema->storage->txn_do(sub { $code->() }); 1 };
  return 1 if $ok;
  die $@ || 'Erro de transação';
}

sub _pl_rows ($self, $sql, @binds) {
  my $rows;
  $self->schema->storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _pl_row ($self, $sql, @binds) { $self->_pl_rows($sql, @binds)->[0] }

1;
