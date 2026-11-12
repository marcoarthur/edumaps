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
    my $planos = $self->_pl_rows(
      q{SELECT p.id, p.cod_inep, p.tipo, p.titulo, p.situacao, p.inicio, p.fim, p.updated_at
          FROM clean.planos_gestao p
         WHERE p.cod_inep = ANY(?::bigint[]) AND p.arquivado_em IS NULL
         ORDER BY p.cod_inep, (p.situacao = 'vigente') DESC, p.updated_at DESC, p.id DESC}, \@ineps);
    my %vigente;
    my %n_vigentes;
    for my $p (@$planos) {
      $planos_de{ $p->{cod_inep} }++;
      next unless $p->{situacao} eq 'vigente';
      $n_vigentes{ $p->{cod_inep} }++;
      $vigente{ $p->{cod_inep} } //= $p;
    }
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

1;
