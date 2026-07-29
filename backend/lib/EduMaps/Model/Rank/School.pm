package EduMaps::Model::Rank::School;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Carp qw(croak);

# ============================================================================
# Registro de redes de ensino
# ============================================================================
#
# A user story restringe o filtro a município/estadual/privada — Federal
# existe no dado (confirmado via SELECT DISTINCT rede) mas fica de fora
# do enum aceito, por decisão explícita do escopo da história, não por
# limitação técnica.
#
# As duas fontes representam rede de forma diferente:
# - mv (via join com censo_escolas.tp_dependencia): smallint documentado
# - ideb (ideb_notas_escolas.rede): varchar, confirmado capitalizado
#
# As CHAVES deste hash (municipal/estadual/privada) são também os valores
# aceitos em analytics.ranking_escola.rede — mantidos em minúsculo para
# as duas fontes por consistência (o refresh job usa exatamente estas
# chaves ao gravar a coluna 'rede').
has network_map => sub {
  return {
    mv => {
      municipal => 3,
      estadual  => 2,
      privada   => 4,
    },
    ideb => {
      municipal => 'Municipal',
      estadual  => 'Estadual',
      privada   => 'Privada',
    },
  };
};

has indicator_registry => sub {
  return {
    infraestrutura => { source => 'mv', column => 'score_infraestrutura', label => 'Infraestrutura' },
    capacidade_atendimento => { source => 'mv', column => 'score_capacidade_atendimento', label => 'Capacidade de Atendimento' },
    capacitacao_docente => { source => 'mv', column => 'score_capacitacao_docente', label => 'Capacitação Docente' },
    diversidade_discente => { source => 'mv', column => 'score_diversidade_discente', label => 'Diversidade Discente' },
    capacidade_gestora => { source => 'mv', column => 'score_capacidade_gestora', label => 'Capacidade Gestora' },
    sustentabilidade => { source => 'mv', column => 'score_sustentabilidade', label => 'Sustentabilidade' },
    ideb_anos_iniciais => { source => 'ideb', column => 'ideb_observado', etapa => 'fundamental_i', label => 'IDEB – Anos Iniciais' },
    ideb_anos_finais => { source => 'ideb', column => 'ideb_observado', etapa => 'fundamental_ii', label => 'IDEB – Anos Finais' },
    ideb_ensino_medio => { source => 'ideb', column => 'ideb_observado', etapa => 'ensino_medio', label => 'IDEB – Ensino Médio' },
    nota_matematica_fund_ii => { source => 'ideb', column => 'nota_matematica', etapa => 'fundamental_ii', label => 'Nota Matemática – Anos Finais' },
    nota_matematica_medio => { source => 'ideb', column => 'nota_matematica', etapa => 'ensino_medio', label => 'Nota Matemática – Ensino Médio' },
    nota_portugues_fund_ii => { source => 'ideb', column => 'nota_portugues', etapa => 'fundamental_ii', label => 'Nota Português – Anos Finais' },
    nota_portugues_medio => { source => 'ideb', column => 'nota_portugues', etapa => 'ensino_medio', label => 'Nota Português – Ensino Médio' },
    taxa_aprovacao_fund_i => { source => 'ideb', column => 'aprovacao_si_4', etapa => 'fundamental_i', label => 'Taxa de Aprovação – Anos Iniciais' },
    taxa_aprovacao_fund_ii => { source => 'ideb', column => 'aprovacao_si_4', etapa => 'fundamental_ii', label => 'Taxa de Aprovação – Anos Finais' },
    taxa_aprovacao_medio => { source => 'ideb', column => 'aprovacao_si_4', etapa => 'ensino_medio', label => 'Taxa de Aprovação – Ensino Médio' },
  };
};

# ============================================================================
# API pública
# ============================================================================
sub available_indicators ($self, $cod_inep) {
  my $registry = $self->indicator_registry;
  my $has_mv_row = $self->schema->resultset('MvEscolasScores')->search_rs(
    { co_entidade => $cod_inep },
    { order_by => { -desc => 'nu_ano_censo' }, rows => 1 }
  )->first;
  my %ideb_etapas_presentes = map { $_->etapa => 1 }
  $self->schema->resultset('IdebNotasEscolas')->search_rs(
    { id_escola => $cod_inep },
    { columns => ['etapa'], distinct => 1 }
  )->all;
  return [
    map {
      my ($id, $def) = ($_, $registry->{$_});
      my $available =
      $def->{source} eq 'mv'
      ? (defined $has_mv_row && defined $has_mv_row->get_column($def->{column}))
      : $ideb_etapas_presentes{ $def->{etapa} };
      { id => $id, label => $def->{label}, available => $available ? \1 : \0 };
    } sort keys %$registry
  ];
}

=head2 rank($cod_inep, $indicator_id, \%opts)

\%opts:
national => 0|1
network  => 'municipal' | 'estadual' | 'privada' | undef

Quando C<network> é informado, o filtro se aplica a TODO o conjunto de
comparação — ou seja, "2º lugar no município" passa a significar 2º entre
as escolas da mesma rede naquele município, não mais entre todas as
escolas. Isso vale para os três escopos (município/estado/nacional)
simultaneamente.

Lê primeiro de analytics.ranking_escola (pré-computada pelo job
  bin/refresh_ranking_escola.pl). Só recorre ao cálculo ao vivo via
window functions se a linha ainda não existir na tabela — caso raro
(escola nova / refresh atrasado), logado para acompanhamento.

=cut
sub rank ($self, $cod_inep, $indicator_id, $opts = {}) {
  my $def = $self->indicator_registry->{$indicator_id}
    or croak "Indicador desconhecido: $indicator_id";

  my $network = $opts->{network};
  if (defined $network) {
    croak "Rede de ensino desconhecida: $network"
    unless exists $self->network_map->{ $def->{source} }{$network};
  }

  my $rede = defined $network ? $network : 'todas';

  my $row = $self->schema->resultset('RankingEscola')->find({
      indicador_id => $indicator_id,
      rede         => $rede,
      id_escola    => $cod_inep,
    });

  return $self->_format_result_from_ranking_escola($indicator_id, $def, $row, $network, $opts)
  if $row;

  # Fallback: linha ainda não existe na tabela pré-computada. Mantém a
  # app funcionando via cálculo ao vivo, mas isso deveria ser exceção —
  # se aparecer com frequência, é sinal de que o refresh job está
  # atrasado ou falhando para este indicador/rede.
  $self->log->warn(
    "ranking_escola sem linha para indicador=$indicator_id id_escola=$cod_inep "
    . "rede=$rede — caindo para cálculo ao vivo"
  ) if $self->can('log') && $self->log;

  my $include_national = $opts->{national} ? 1 : 0;
  return $def->{source} eq 'mv'
  ? $self->_rank_from_mv($cod_inep, $indicator_id, $def, $include_national, $network)
  : $self->_rank_from_ideb($cod_inep, $indicator_id, $def, $include_national, $network);
}

# ============================================================================
# Privado: formata uma linha de analytics.ranking_escola
# ============================================================================
sub _format_result_from_ranking_escola ($self, $indicator_id, $def, $row, $network, $opts) {
  my $scope = sub ($rank, $total) {
    return undef unless defined $rank;
    my $percentile = $total > 1 ? int((($total - $rank) / ($total - 1)) * 100 + 0.5) : 100;
    return { posicao => 0 + $rank, total => 0 + $total, percentil => $percentile };
  };

  return {
    indicador => {
      id    => $indicator_id,
      label => $def->{label},
      valor => 0 + $row->valor,
    },
    ano => 0 + $row->ano,
    rede => $network,
    ranking => {
      municipio => $scope->($row->rank_municipio, $row->total_municipio),
      estado    => $scope->($row->rank_estado, $row->total_estado),
      # rank_nacional/total_nacional sempre existem na linha (o refresh
        # job calcula os três escopos de uma vez), mas só expomos quando
      # opts.national foi pedido — mantém o mesmo contrato da API
      # anterior, em que o cálculo nacional era opcional.
      nacional  => $opts->{national} ? $scope->($row->rank_nacional, $row->total_nacional) : undef,
    },
  };
}

# ============================================================================
# Privado: fallback ao vivo — ranking a partir de clean.mv_escolas_scores
# (usado apenas quando a linha correspondente ainda não está em
# analytics.ranking_escola)
# ============================================================================
sub _rank_from_mv ($self, $cod_inep, $indicator_id, $def, $include_national, $network) {
  my $column = $self->_assert_known_column($def->{column});
  my $dbh = $self->schema->storage->dbh;

  my $network_filter_sql = '';
  my @network_bind;
  if (defined $network) {
    my $tp_dependencia = $self->network_map->{mv}{$network};
    $network_filter_sql = 'AND esc.tp_dependencia = ?';
    @network_bind = ($tp_dependencia);
  }

  my ($year) = $dbh->selectrow_array(
    q{SELECT MAX(nu_ano_censo) FROM clean.mv_escolas_scores WHERE } . $column . q{ IS NOT NULL}
  );
  return undef unless $year;

  my $national_sql = $self->_national_window_sql($column, $include_national);
  my $sql = qq{
    SELECT * FROM (
      SELECT
      me.co_entidade,
      me.$column AS value,
      RANK()  OVER (PARTITION BY esc.co_municipio ORDER BY me.$column DESC) AS rank_municipio,
      COUNT(*) OVER (PARTITION BY esc.co_municipio) AS total_municipio,
      RANK()  OVER (PARTITION BY esc.co_uf ORDER BY me.$column DESC) AS rank_estado,
      COUNT(*) OVER (PARTITION BY esc.co_uf) AS total_estado
      $national_sql
      FROM clean.mv_escolas_scores me
      JOIN clean.censo_escolas esc
      ON esc.co_entidade = me.co_entidade
      AND esc.nu_ano_censo = me.nu_ano_censo
      WHERE me.nu_ano_censo = ?
      AND me.$column IS NOT NULL
      AND esc.tp_situacao_funcionamento = 1
      $network_filter_sql
    ) ranked
    WHERE co_entidade = ?
  };
  my $row = $dbh->selectrow_hashref($sql, undef, $year, @network_bind, $cod_inep);
  return undef unless $row;

  return $self->_format_result_live($indicator_id, $def, $year, $row, $network);
}

# ============================================================================
# Privado: fallback ao vivo — ranking a partir de clean.ideb_notas_escolas
# ============================================================================
sub _rank_from_ideb ($self, $cod_inep, $indicator_id, $def, $include_national, $network) {
  my $column = $self->_assert_known_column($def->{column});
  my $etapa = $def->{etapa} or croak "Indicador ideb sem etapa definida: $indicator_id";
  my $dbh = $self->schema->storage->dbh;

  my $network_filter_sql = '';
  my @network_bind;
  if (defined $network) {
    my $rede = $self->network_map->{ideb}{$network};
    $network_filter_sql = 'AND rede = ?';
    @network_bind = ($rede);
  }

  my ($year) = $dbh->selectrow_array(
    q{SELECT MAX(ano) FROM clean.ideb_notas_escolas WHERE etapa = ? AND } . $column . q{ IS NOT NULL}
    . ($network ? ' AND rede = ?' : ''),
    undef, $etapa, ($network ? $self->network_map->{ideb}{$network} : ())
  );
  return undef unless $year;

  my $national_sql = $self->_national_window_sql($column, $include_national);
  my $sql = qq{
    SELECT * FROM (
      SELECT id_escola AS co_entidade,
      $column AS value,
      RANK()  OVER (PARTITION BY co_municipio ORDER BY $column DESC) AS rank_municipio,
      COUNT(*) OVER (PARTITION BY co_municipio) AS total_municipio,
      RANK()  OVER (PARTITION BY sg_uf ORDER BY $column DESC) AS rank_estado,
      COUNT(*) OVER (PARTITION BY sg_uf) AS total_estado
      $national_sql
      FROM clean.ideb_notas_escolas
      WHERE ano = ?
      AND etapa = ?
      AND $column IS NOT NULL
      $network_filter_sql
    ) ranked
    WHERE co_entidade = ?
  };
  my $row = $dbh->selectrow_hashref($sql, undef, $year, $etapa, @network_bind, $cod_inep);
  return undef unless $row;

  return $self->_format_result_live($indicator_id, $def, $year, $row, $network);
}

# ============================================================================
# Helpers privados
# ============================================================================
sub _assert_known_column ($self, $column) {
  my %known = map { $_->{column} => 1 } values %{ $self->indicator_registry };
  croak "Coluna não registrada em indicator_registry: $column"
  unless $known{$column};
  return $column;
}

sub _national_window_sql ($self, $column, $include_national) {
  return '' unless $include_national;
  return qq{
    , RANK() OVER (ORDER BY $column DESC) AS rank_nacional
    , COUNT(*) OVER () AS total_nacional
  };
}

# Formata o resultado do cálculo ao vivo (fallback). Mantido em separado de
# _format_result_from_ranking_escola porque a origem dos dados é diferente
# (hashref cru do dbh vs. Result row do DBIC).
sub _format_result_live ($self, $indicator_id, $def, $year, $row, $network) {
  my $scope = sub ($rank, $total) {
    return undef unless defined $rank;
    my $percentile = $total > 1 ? int((($total - $rank) / ($total - 1)) * 100 + 0.5) : 100;
    return { posicao => 0 + $rank, total => 0 + $total, percentil => $percentile };
  };

  return {
    indicador => {
      id    => $indicator_id,
      label => $def->{label},
      valor => 0 + $row->{value},
    },
    ano => 0 + $year,
    rede => $network,
    ranking => {
      municipio => $scope->($row->{rank_municipio}, $row->{total_municipio}),
      estado    => $scope->($row->{rank_estado}, $row->{total_estado}),
      nacional  => $scope->($row->{rank_nacional}, $row->{total_nacional}),
    },
  };
}

1;
