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
  # Plano encerrado fica congelado: não recebe medições oficiais novas.
  $self->_sincronizar_oficiais($id) unless $p->{situacao} eq 'encerrado';

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

  my $metas_out = $self->_metas_enriquecidas($cod_inep, $metas);

  my %por_obj;
  push @{ $por_obj{ $_->{objetivo_id} }{metas} }, $_ for @$metas_out;
  push @{ $por_obj{ $_->{objetivo_id} }{acoes} }, $self->_acao_out($_) for @$acoes;

  my $out = $self->_plano_out($p);
  $out->{objetivos} = [ map {
    my $o = $self->_objetivo_out($_);
    $o->{metas} = $por_obj{ $_->{id} }{metas} // [];
    $o->{acoes} = $por_obj{ $_->{id} }{acoes} // [];
    $o->{progresso} = _pl_agregar($o->{metas});
    $o;
  } @$objetivos ];
  $out->{resumo} = {
    n_objetivos        => scalar @$objetivos,
    n_metas            => scalar @$metas,
    n_acoes            => scalar @$acoes,
    n_acoes_concluidas => scalar(grep { $_->{situacao} eq 'concluida' } @$acoes),
    n_acoes_atrasadas  => scalar(grep { $_->{atrasada} } @$acoes),
    progresso          => _pl_agregar($metas_out),
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
  my %m = (sentido => 'aumentar', %$p);
  if (defined $m{indicador_codigo}) {
    my $ind = $self->_indicador_ou_400($m{indicador_codigo});
    # Meta oficial: unidade do catálogo; linha de base sugerida pelo último
    # valor da escola (se o gestor não informou).
    $m{unidade} //= $ind->{unidade};
    if (!exists $p->{linha_base}) {
      my $ult = $self->_ultimo_oficial($cod_inep, $m{indicador_codigo});
      $m{linha_base} = $ult ? $ult->{valor} : undef;
    }
  }
  $self->_sentido_coerente(\%m);
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      'INSERT INTO clean.planos_metas
         (objetivo_id, descricao, unidade, sentido, indicador_codigo, linha_base, alvo, prazo)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       RETURNING id, objetivo_id, descricao, unidade, sentido, indicador_codigo, linha_base, alvo, prazo',
      $m{objetivo_id} + 0, @m{qw(descricao unidade sentido indicador_codigo linha_base alvo prazo)});
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $row->{id}, 'criado',
      { descricao => $m{descricao}, indicador => $m{indicador_codigo} });
  });
  $self->_sincronizar_oficiais($plano_id, $row->{id});
  return $self->_metas_enriquecidas($cod_inep, [$row])->[0];
}

sub meta_atualizar ($self, $cod_inep, $gestor_id, $plano_id, $mid, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $atual = $self->_meta_ou_404($plano_id, $mid);
  $self->_objetivo_ou_404($plano_id, $p->{objetivo_id}, 400) if exists $p->{objetivo_id};
  $self->_indicador_ou_400($p->{indicador_codigo}) if defined $p->{indicador_codigo};
  my %novo = (%$atual, %$p);
  $self->_sentido_coerente(\%novo);
  my $troca_indicador = exists $p->{indicador_codigo}
    && ($p->{indicador_codigo} // '') ne ($atual->{indicador_codigo} // '');
  my $row;
  $self->_pl_txn(sub {
    # Trocou (ou tirou) o indicador: as medições oficiais eram do indicador
    # antigo. As manuais de uma meta que passa a ser oficial também saem —
    # a meta tem uma origem só.
    if ($troca_indicador) {
      $self->_pl_rows(
        q{DELETE FROM clean.planos_metas_medicoes WHERE meta_id = ? AND (origem = 'oficial' OR ?)},
        $mid + 0, defined $novo{indicador_codigo} ? 1 : 0);
    }
    # Meta que muda de objetivo solta as ações do objetivo antigo (a ação só
    # pode apontar para meta do próprio objetivo — trigger).
    if ($novo{objetivo_id} != $atual->{objetivo_id}) {
      $self->_pl_rows('UPDATE clean.planos_acoes SET meta_id = NULL, updated_at = NOW() WHERE meta_id = ?', $mid + 0);
    }
    $row = $self->_pl_row(
      'UPDATE clean.planos_metas
          SET objetivo_id = ?, descricao = ?, unidade = ?, sentido = ?, indicador_codigo = ?,
              linha_base = ?, alvo = ?, prazo = ?, updated_at = NOW()
        WHERE id = ?
        RETURNING id, objetivo_id, descricao, unidade, sentido, indicador_codigo, linha_base, alvo, prazo',
      @novo{qw(objetivo_id descricao unidade sentido indicador_codigo linha_base alvo prazo)}, $mid + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $mid, 'alterado', _pl_mudancas($atual, $p));
  });
  $self->_sincronizar_oficiais($plano_id, $mid);
  return $self->_metas_enriquecidas($cod_inep, [$row])->[0];
}

# ---------------------------------------------------------------------------
# medições (manuais) e catálogo de indicadores oficiais
# ---------------------------------------------------------------------------

sub medicao_criar ($self, $cod_inep, $gestor_id, $plano_id, $mid, $p) {
  $self->_plano_editavel($cod_inep, $plano_id);
  my $meta = $self->_meta_ou_404($plano_id, $mid);
  $self->_falha(400, 'Meta ligada a indicador oficial: o valor vem da fonte, não é informado à mão.')
    if defined $meta->{indicador_codigo};
  my $row;
  $self->_pl_txn(sub {
    $row = $self->_pl_row(
      q{INSERT INTO clean.planos_metas_medicoes (meta_id, origem, data_ref, valor, nota, created_by)
        VALUES (?, 'manual', ?, ?, ?, ?) RETURNING id},
      $mid + 0, $p->{data_ref}, $p->{valor}, $p->{nota}, $self->_pl_gestor($gestor_id));
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $mid, 'alterado',
      { medicao => { data_ref => $p->{data_ref}, valor => $p->{valor} } });
  });
  return $self->_metas_enriquecidas($cod_inep, [$meta])->[0];
}

sub medicao_excluir ($self, $cod_inep, $gestor_id, $plano_id, $mid, $medicao_id) {
  $self->_plano_editavel($cod_inep, $plano_id);
  $self->_meta_ou_404($plano_id, $mid);
  my $med = $self->_pl_row(
    'SELECT id, origem, data_ref, valor FROM clean.planos_metas_medicoes WHERE id = ? AND meta_id = ?',
    $medicao_id + 0, $mid + 0);
  $self->_falha(404, 'Medição não encontrada nesta meta.') unless $med;
  $self->_falha(409, 'Medição oficial não se exclui: ela é o histórico da fonte.') if $med->{origem} eq 'oficial';
  $self->_pl_txn(sub {
    $self->_pl_rows('DELETE FROM clean.planos_metas_medicoes WHERE id = ?', $medicao_id + 0);
    $self->_pl_tocar($plano_id);
    $self->_pl_auditar($plano_id, $cod_inep, $gestor_id, 'meta', $mid, 'alterado',
      { medicao_excluida => { data_ref => $med->{data_ref}, valor => _pl_num($med->{valor}) } });
  });
  return 1;
}

# Catálogo com o último valor da escola. Indicador sem valor para a escola
# vem com `ultimo => undef` ("sem dado"), nunca 0 (#154).
sub indicadores_catalogo ($self, $cod_inep) {
  my $rows = $self->_pl_rows(
    'SELECT c.codigo, c.grupo, c.rotulo, c.unidade, c.fonte, c.sentido_sugerido,
            u.ano, u.valor
       FROM analytics.indicadores_meta_catalogo c
       LEFT JOIN LATERAL (
         SELECT v.ano, v.valor FROM analytics.escola_indicadores_meta v
          WHERE v.cod_inep = ? AND v.codigo = c.codigo
          ORDER BY v.ano DESC LIMIT 1) u ON TRUE
      ORDER BY c.ordem', $cod_inep + 0);
  return [ map { {
    codigo           => $_->{codigo},
    grupo            => $_->{grupo},
    rotulo           => $_->{rotulo},
    unidade          => $_->{unidade},
    fonte            => $_->{fonte},
    sentido_sugerido => $_->{sentido_sugerido},
    ultimo           => defined $_->{ano} ? { ano => $_->{ano} + 0, valor => _pl_num($_->{valor}) } : undef,
  } } @$rows ];
}

# ---------------------------------------------------------------------------
# progresso
# ---------------------------------------------------------------------------

# progresso_meta(sentido, base, alvo, atual) -> (fração 0..1 | undef, estado)
#   aumentar: (atual − base) / (alvo − base), com alvo > base
#   reduzir : (base − atual) / (base − alvo), com alvo < base
#   manter  : não cair abaixo do alvo — 1 se atual ≥ alvo, senão 0
# Estados: medida | sem_medicao (falta valor atual) | rascunho (falta base ou
# alvo) | incoerente (alvo do lado errado da base para o sentido).
sub progresso_meta ($class_or_self, $sentido, $base, $alvo, $atual) {
  return (undef, 'rascunho') if !defined $alvo || ($sentido ne 'manter' && !defined $base);
  return (undef, 'sem_medicao') unless defined $atual;
  my $p;
  if ($sentido eq 'manter') {
    $p = $atual >= $alvo ? 1 : 0;
  }
  elsif ($sentido eq 'aumentar') {
    return (undef, 'incoerente') unless $alvo > $base;
    $p = ($atual - $base) / ($alvo - $base);
  }
  else {
    return (undef, 'incoerente') unless $alvo < $base;
    $p = ($base - $atual) / ($base - $alvo);
  }
  $p = 0 if $p < 0;
  $p = 1 if $p > 1;
  return (0 + sprintf('%.4f', $p), 'medida');
}

# Média das metas medidas, sempre com "N de M" (a média de 1 meta em 5 não
# pode parecer o plano inteiro).
sub _pl_agregar ($metas) {
  my @med = grep { defined $_->{progresso} } @$metas;
  my $soma = 0;
  $soma += $_->{progresso} for @med;
  return {
    valor        => @med ? 0 + sprintf('%.4f', $soma / @med) : undef,
    n_medidas    => scalar @med,
    n_metas      => scalar @$metas,
  };
}

sub _metas_enriquecidas ($self, $cod_inep, $metas) {
  return [] unless @$metas;
  my @ids = map { $_->{id} + 0 } @$metas;
  my $meds = $self->_pl_rows(
    'SELECT id, meta_id, origem, data_ref, ano_ref, valor, nota
       FROM clean.planos_metas_medicoes WHERE meta_id = ANY(?::bigint[])
      ORDER BY data_ref, id', \@ids);
  my %por_meta;
  push @{ $por_meta{ $_->{meta_id} } }, $_ for @$meds;

  my %catalogo = map { $_->{codigo} => $_ } @{ $self->_pl_rows(
    'SELECT codigo, rotulo, unidade, fonte FROM analytics.indicadores_meta_catalogo') };

  return [ map {
    my $m = $self->_meta_out($_);
    my $hist = $por_meta{ $_->{id} } // [];
    my $ult = @$hist ? $hist->[-1] : undef;
    $m->{medicoes} = [ map { {
      id       => $_->{id} + 0,
      origem   => $_->{origem},
      data_ref => $_->{data_ref},
      ano_ref  => defined $_->{ano_ref} ? $_->{ano_ref} + 0 : undef,
      valor    => _pl_num($_->{valor}),
      nota     => $_->{nota},
    } } @$hist ];
    $m->{atual} = $ult ? $m->{medicoes}[-1] : undef;
    if (my $c = defined $m->{indicador_codigo} ? $catalogo{ $m->{indicador_codigo} } : undef) {
      $m->{indicador} = { codigo => $c->{codigo}, rotulo => $c->{rotulo}, unidade => $c->{unidade}, fonte => $c->{fonte} };
    }
    my ($p, $estado) = $self->progresso_meta($m->{sentido}, $m->{linha_base}, $m->{alvo},
      $m->{atual} ? $m->{atual}{valor} : undef);
    # Meta oficial sem nenhum valor da escola na fonte: "sem dado", não "sem medição".
    $estado = 'sem_dado' if $estado eq 'sem_medicao' && $m->{indicador};
    $m->{progresso} = $p;
    $m->{estado}    = $estado;
    $m;
  } @$metas ];
}

# Grava como medição oficial cada (ano, valor) da fonte ainda não gravado para
# as metas oficiais do plano (ou de uma meta). Idempotente: uma por ano.
sub _sincronizar_oficiais ($self, $plano_id, $meta_id = undef) {
  $self->_pl_rows(
    q{INSERT INTO clean.planos_metas_medicoes (meta_id, origem, data_ref, ano_ref, valor)
      SELECT m.id, 'oficial', make_date(v.ano, 12, 31), v.ano, v.valor
        FROM clean.planos_metas m
        JOIN clean.planos_objetivos o ON o.id = m.objetivo_id
        JOIN clean.planos_gestao p ON p.id = o.plano_id
        JOIN analytics.escola_indicadores_meta v
          ON v.cod_inep = p.cod_inep AND v.codigo = m.indicador_codigo
       WHERE o.plano_id = ? AND (?::bigint IS NULL OR m.id = ?::bigint)
      ON CONFLICT (meta_id, ano_ref) WHERE origem = 'oficial' DO NOTHING
      RETURNING id},
    $plano_id + 0, $meta_id, $meta_id);
}

sub _indicador_ou_400 ($self, $codigo) {
  my $c = $self->_pl_row('SELECT codigo, unidade FROM analytics.indicadores_meta_catalogo WHERE codigo = ?', $codigo);
  $self->_falha(400, "Indicador '$codigo' não está no catálogo.") unless $c;
  return $c;
}

sub _ultimo_oficial ($self, $cod_inep, $codigo) {
  return $self->_pl_row(
    'SELECT ano, valor FROM analytics.escola_indicadores_meta
      WHERE cod_inep = ? AND codigo = ? ORDER BY ano DESC LIMIT 1', $cod_inep + 0, $codigo);
}

sub _sentido_coerente ($self, $m) {
  my ($s, $b, $a) = @$m{qw(sentido linha_base alvo)};
  return unless defined $b && defined $a && defined $s;
  $self->_falha(400, 'Para aumentar, o alvo tem de ser maior que a linha de base.')
    if $s eq 'aumentar' && $a <= $b;
  $self->_falha(400, 'Para reduzir, o alvo tem de ser menor que a linha de base.')
    if $s eq 'reduzir' && $a >= $b;
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
