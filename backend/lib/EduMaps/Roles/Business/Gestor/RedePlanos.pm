package EduMaps::Roles::Business::Gestor::RedePlanos;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON ();
use EduMaps::Roles::Business::Gestor::Planos ();

# Painel da rede (#396, visão da rede #375): os planos de TODAS as escolas da
# rede numa passada, em poucas consultas em lote (sem uma consulta por plano).
# Só leitura: não sincroniza medições oficiais — o andamento usa as medições
# já gravadas (as oficiais entram quando a escola abre o plano).
#
# Recebe as escolas já autorizadas (rede_escolas da conta) e devolve, por
# escola, o plano vigente mais recente (ou nenhum), com andamento ("N de M
# metas medidas"; sem medida = null, nunca 0%), ações atrasadas, que vencem
# em 7 dias, evidências e a última atualização; mais os totais da rede.

use constant HOJE_SQL => q{(NOW() AT TIME ZONE 'America/Sao_Paulo')::date};

sub rede_painel ($self, $escolas) {
  my @ineps = map { $_->{cod_inep} + 0 } @$escolas;
  my %por_escola;
  my %planos_de;    # cod_inep -> quantos planos não arquivados (qualquer situação)
  my $hoje = HOJE_SQL;

  if (@ineps) {
    # 1) planos não arquivados das escolas; o vigente mais recente de cada uma
    my ($vig, $n_vig, $pd) = $self->_rp_vigentes(\@ineps);
    my %vigente    = %$vig;
    my %n_vigentes = %$n_vig;
    %planos_de     = %$pd;
    my @ids = map { $_->{id} + 0 } values %vigente;

    my (%metas_de, %acoes_de, %evid_de);
    if (@ids) {
      # 2) metas dos planos vigentes com a medição mais recente de cada uma
      my $metas = $self->_pl_rows(
        q{SELECT o.plano_id, m.id, m.sentido, m.linha_base, m.alvo, u.valor AS atual
            FROM clean.planos_metas m
            JOIN clean.planos_objetivos o ON o.id = m.objetivo_id
            LEFT JOIN LATERAL (
              SELECT md.valor FROM clean.planos_metas_medicoes md
               WHERE md.meta_id = m.id ORDER BY md.data_ref DESC, md.id DESC LIMIT 1
            ) u ON TRUE
           WHERE o.plano_id = ANY(?::bigint[])}, \@ids);
      for my $m (@$metas) {
        my ($p) = EduMaps::Roles::Business::Gestor::Planos->progresso_meta(
          $m->{sentido}, $m->{linha_base}, $m->{alvo}, $m->{atual});
        push @{ $metas_de{ $m->{plano_id} } }, { progresso => $p };
      }
      # 3) ações por plano: total, atrasadas, que vencem em 7 dias
      my $acoes = $self->_pl_rows(
        qq{SELECT o.plano_id,
                  count(*) AS n_acoes,
                  count(*) FILTER (WHERE a.situacao IN ('nao_iniciada', 'em_andamento')
                                     AND a.prazo < $hoje) AS n_atrasadas,
                  count(*) FILTER (WHERE a.situacao IN ('nao_iniciada', 'em_andamento')
                                     AND a.prazo BETWEEN $hoje AND $hoje + 7) AS n_vencem_7d,
                  count(*) FILTER (WHERE a.situacao = 'concluida') AS n_concluidas
             FROM clean.planos_acoes a JOIN clean.planos_objetivos o ON o.id = a.objetivo_id
            WHERE o.plano_id = ANY(?::bigint[])
            GROUP BY o.plano_id}, \@ids);
      $acoes_de{ $_->{plano_id} } = $_ for @$acoes;
      # 4) evidências por plano (de ações e de metas)
      my $evid = $self->_pl_rows(
        q{SELECT o.plano_id, count(*) AS n
            FROM clean.planos_evidencias e
            LEFT JOIN clean.planos_acoes a ON a.id = e.acao_id
            LEFT JOIN clean.planos_metas m ON m.id = e.meta_id
            JOIN clean.planos_objetivos o ON o.id = COALESCE(a.objetivo_id, m.objetivo_id)
           WHERE o.plano_id = ANY(?::bigint[])
           GROUP BY o.plano_id}, \@ids);
      $evid_de{ $_->{plano_id} } = $_->{n} + 0 for @$evid;
    }

    for my $inep (keys %vigente) {
      my $p  = $vigente{$inep};
      my $ac = $acoes_de{ $p->{id} } // {};
      $por_escola{$inep} = {
        id            => $p->{id} + 0,
        tipo          => $p->{tipo},
        titulo        => $p->{titulo},
        inicio        => $p->{inicio},
        fim           => $p->{fim},
        progresso     => EduMaps::Roles::Business::Gestor::Planos::_pl_agregar($metas_de{ $p->{id} } // []),
        n_acoes       => ($ac->{n_acoes}      // 0) + 0,
        n_concluidas  => ($ac->{n_concluidas} // 0) + 0,
        n_atrasadas   => ($ac->{n_atrasadas}  // 0) + 0,
        n_vencem_7d   => ($ac->{n_vencem_7d}  // 0) + 0,
        n_evidencias  => $evid_de{ $p->{id} } // 0,
        atualizado_em => $p->{updated_at},
        n_vigentes    => $n_vigentes{$inep} + 0,
      };
    }
  }

  my @linhas = map { {
    %$_,
    plano    => $por_escola{ $_->{cod_inep} },
    n_planos => $planos_de{ $_->{cod_inep} } // 0,
  } } @$escolas;

  my ($com, $atrasadas) = (0, 0);
  for (@linhas) {
    next unless $_->{plano};
    $com++;
    $atrasadas += $_->{plano}{n_atrasadas};
  }
  return {
    totais => {
      escolas          => scalar @linhas,
      com_plano_vigente => $com,
      sem_plano_vigente => scalar(@linhas) - $com,
      acoes_atrasadas  => $atrasadas,
    },
    escolas => \@linhas,
  };
}

# Planos não arquivados das escolas: (vigente mais recente por escola,
# quantos vigentes por escola, quantos planos por escola).
sub _rp_vigentes ($self, $ineps) {
  my $planos = $self->_pl_rows(
    q{SELECT p.id, p.cod_inep, p.tipo, p.titulo, p.situacao, p.inicio, p.fim, p.updated_at
        FROM clean.planos_gestao p
       WHERE p.cod_inep = ANY(?::bigint[]) AND p.arquivado_em IS NULL
       ORDER BY p.cod_inep, (p.situacao = 'vigente') DESC, p.updated_at DESC, p.id DESC}, $ineps);
  my (%vigente, %n_vigentes, %planos_de);
  for my $p (@$planos) {
    $planos_de{ $p->{cod_inep} }++;
    next unless $p->{situacao} eq 'vigente';
    $n_vigentes{ $p->{cod_inep} }++;
    $vigente{ $p->{cod_inep} } //= $p;
  }
  return (\%vigente, \%n_vigentes, \%planos_de);
}

# Metas comparáveis (#397, P2-PG-03): nas escolas da rede, as metas do plano
# vigente que seguem o MESMO indicador do catálogo, consolidadas por indicador
# (quantas escolas têm a meta, quantas mediram, andamento médio das medidas) e
# a lista das escolas, com a base ajustada marcada (P2-PG-05). Metas manuais
# não se comparam: entram só na contagem à parte. Só leitura.
sub rede_indicadores ($self, $escolas) {
  my %escola = map { $_->{cod_inep} => $_ } @$escolas;
  my @ineps  = keys %escola;
  my ($vigente) = @ineps ? $self->_rp_vigentes([ map { $_ + 0 } @ineps ]) : ({});
  my %plano_de = map { $vigente->{$_}{id} => $vigente->{$_} } keys %$vigente;
  my @ids = keys %plano_de;

  my $catalogo = $self->_pl_rows(
    'SELECT codigo, rotulo, unidade, fonte FROM analytics.indicadores_meta_catalogo ORDER BY ordem, codigo');
  my %cat = map { $_->{codigo} => $_ } @$catalogo;

  my (%por_ind, %manuais_escolas);
  my $n_manuais = 0;
  if (@ids) {
    my $metas = $self->_pl_rows(
      q{SELECT o.plano_id, m.id, m.objetivo_id, m.descricao, m.unidade, m.sentido, m.indicador_codigo,
               m.linha_base, m.alvo, m.prazo, m.linha_base_oficial,
               u.valor AS atual, u.ano_ref AS atual_ano, u.data_ref AS atual_data
          FROM clean.planos_metas m
          JOIN clean.planos_objetivos o ON o.id = m.objetivo_id
          LEFT JOIN LATERAL (
            SELECT md.valor, md.ano_ref, md.data_ref FROM clean.planos_metas_medicoes md
             WHERE md.meta_id = m.id ORDER BY md.data_ref DESC, md.id DESC LIMIT 1
          ) u ON TRUE
         WHERE o.plano_id = ANY(?::bigint[])
         ORDER BY m.id}, [ map { $_ + 0 } @ids ]);
    for my $m (@$metas) {
      my $plano = $plano_de{ $m->{plano_id} };
      unless (defined $m->{indicador_codigo} && $cat{ $m->{indicador_codigo} }) {
        $n_manuais++;
        $manuais_escolas{ $plano->{cod_inep} } = 1;
        next;
      }
      my ($p, $estado) = EduMaps::Roles::Business::Gestor::Planos->progresso_meta(
        $m->{sentido}, $m->{linha_base}, $m->{alvo}, $m->{atual});
      my $out = $self->_meta_out($m);
      $out->{atual} = defined $m->{atual}
        ? { valor => 0 + $m->{atual}, ano_ref => defined $m->{atual_ano} ? $m->{atual_ano} + 0 : undef,
            data_ref => $m->{atual_data} }
        : undef;
      $out->{progresso} = $p;
      $out->{estado}    = $estado eq 'sem_medicao' ? 'sem_dado' : $estado;
      my $e = $escola{ $plano->{cod_inep} };
      push @{ $por_ind{ $m->{indicador_codigo} } }, {
        cod_inep     => $plano->{cod_inep} + 0,
        nome         => $e->{nome},
        municipio    => $e->{municipio},
        uf           => $e->{uf},
        plano_id     => $plano->{id} + 0,
        plano_titulo => $plano->{titulo},
        meta         => $out,
      };
    }
  }

  my @indicadores;
  for my $codigo (keys %por_ind) {
    my $lista = [ sort { $a->{nome} cmp $b->{nome} } @{ $por_ind{$codigo} } ];
    my %escolas_ind = map { $_->{cod_inep} => 1 } @$lista;
    my @medidas = grep { defined $_->{meta}{progresso} } @$lista;
    my $soma = 0;
    $soma += $_->{meta}{progresso} for @medidas;
    my $c = $cat{$codigo};
    push @indicadores, {
      codigo           => $codigo,
      rotulo           => $c->{rotulo},
      unidade          => $c->{unidade},
      fonte            => $c->{fonte},
      n_escolas        => scalar keys %escolas_ind,
      n_metas          => scalar @$lista,
      n_medidas        => scalar @medidas,
      andamento_medio  => @medidas ? 0 + sprintf('%.4f', $soma / @medidas) : undef,
      n_base_ajustada  => scalar(grep { $_->{meta}{base_ajustada} } @$lista),
      escolas          => $lista,
    };
  }
  @indicadores = sort { $b->{n_escolas} <=> $a->{n_escolas} || $a->{rotulo} cmp $b->{rotulo} } @indicadores;

  return {
    indicadores         => \@indicadores,
    manuais             => { n_metas => $n_manuais, n_escolas => scalar keys %manuais_escolas },
    n_escolas           => scalar @$escolas,
    n_com_plano_vigente => scalar keys %$vigente,
  };
}

# Custo por fonte na rede (#398, RF-109): previsto × executado por fonte de
# recurso, por escola e consolidado. Por escola, o plano vigente que o painel
# mostra (o mais recente), com os MESMOS números do relatório dele (mesma
# função _pl_custos, canceladas fora, sem valor não é R$ 0). O consolidado
# soma só esses planos vigentes; os planos encerrados das escolas da rede vêm
# numa linha à parte. Rascunho não entra. Só leitura. Com exercício (#404),
# as mesmas regras de _pl_custos; `exercicios` do consolidado lista os anos.
sub rede_custos ($self, $escolas, $exercicio = undef) {
  $exercicio = $self->_pl_exercicio($exercicio);
  my %escola = map { $_->{cod_inep} => $_ } @$escolas;
  my @ineps  = map { $_ + 0 } keys %escola;
  my ($vigente) = @ineps ? $self->_rp_vigentes(\@ineps) : ({});
  my %vig_id = map { $vigente->{$_}{id} => $_ } keys %$vigente;

  my (%acoes_vig, @acoes_enc, %planos_enc, %escolas_enc);
  if (@ineps) {
    my $acoes = $self->_pl_rows(
      q{SELECT p.id AS plano_id, p.cod_inep, p.situacao AS plano_situacao,
               a.custo_previsto, a.fonte_recurso, a.custo_executado, a.prazo, a.executado_em
          FROM clean.planos_gestao p
          JOIN clean.planos_objetivos o ON o.plano_id = p.id
          JOIN clean.planos_acoes a ON a.objetivo_id = o.id
         WHERE p.cod_inep = ANY(?::bigint[]) AND p.arquivado_em IS NULL
           AND p.situacao IN ('vigente', 'encerrado') AND a.situacao <> 'cancelada'}, \@ineps);
    for my $a (@$acoes) {
      if ($a->{plano_situacao} eq 'encerrado') {
        push @acoes_enc, $a;
        $planos_enc{ $a->{plano_id} } = 1;
        $escolas_enc{ $a->{cod_inep} } = 1;
      }
      elsif (exists $vig_id{ $a->{plano_id} }) {
        push @{ $acoes_vig{ $a->{plano_id} } }, $a;
      }
    }
  }

  my @linhas;
  for my $inep (keys %$vigente) {
    my $p = $vigente->{$inep};
    my $e = $escola{$inep};
    push @linhas, {
      cod_inep     => $inep + 0,
      nome         => $e->{nome},
      municipio    => $e->{municipio},
      uf           => $e->{uf},
      plano_id     => $p->{id} + 0,
      plano_titulo => $p->{titulo},
      custos       => EduMaps::Roles::Business::Gestor::Planos::_pl_custos($acoes_vig{ $p->{id} } // [], $exercicio),
    };
  }
  @linhas = sort { $a->{nome} cmp $b->{nome} } @linhas;

  my $consolidado = EduMaps::Roles::Business::Gestor::Planos::_pl_custos([ map { @$_ } values %acoes_vig ], $exercicio);
  $consolidado->{n_escolas_com_custo} = scalar grep { @{ $_->{custos}{por_fonte} } } @linhas;
  my $encerrados = EduMaps::Roles::Business::Gestor::Planos::_pl_custos(\@acoes_enc, $exercicio);
  $encerrados->{n_planos}  = scalar keys %planos_enc;
  $encerrados->{n_escolas} = scalar keys %escolas_enc;
  my %anos = map { $_ => 1 } @{ $consolidado->{exercicios} }, @{ $encerrados->{exercicios} };

  return {
    exercicio           => $exercicio,
    exercicios          => [ sort { $a <=> $b } keys %anos ],
    consolidado         => $consolidado,
    encerrados          => $encerrados,
    escolas             => \@linhas,
    n_escolas           => scalar @$escolas,
    n_com_plano_vigente => scalar keys %$vigente,
  };
}

1;
