package EduMaps::Model::Rank::School;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use Carp qw(croak);
use EduMaps::Fontes;
use EduMaps::Porte;
use EduMaps::Regiao;

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

# Versão citável dos seis índices do Censo (#462, RX-01). REGRA: mudança de
# fórmula em clean.mv_escolas_scores (change nova no data_pipeline) sobe a
# versão aqui, ganha uma linha no histórico e vai no COMMENT da MV, na mesma
# change. O teste t/02-models/indices_versao.t compara o COMMENT com
# $INDICES_VERSAO. Formato: indices-vN, N inteiro que só sobe; a data é a do
# deploy da fórmula. Correção de texto do %METODO não sobe a versão.
our $INDICES_VERSAO = 'indices-v5';
our @INDICES_HISTORICO = (
  { versao => 'indices-v5', data => '2026-11-17',
    mudou  => 'Capacidade de atendimento: a parte de alunos por sala passa a ser por sala e por turno (antes, todas as matrículas sobre as salas, e a escola de dois ou três turnos parecia lotada).' },
  { versao => 'indices-v4', data => '2026-11-17',
    mudou  => 'Diversidade discente: a parte de cor/raça passa a ser calculada sobre as matrículas com cor declarada (antes, sobre o total, e a escola que não declarava parecia mais diversa). Com menos de metade das matrículas com cor declarada, a parte de cor/raça fica de fora e o peso dela vai para as outras três partes.' },
  { versao => 'indices-v3', data => '2026-11-17',
    mudou  => 'Escola sem registro de matrículas, docentes ou gestores no Censo fica sem o índice que depende desse registro (vazio), não com 0: capacidade de atendimento e diversidade discente sem matrículas, capacitação docente sem docentes, capacidade gestora sem gestores. As notas das demais escolas não mudam.' },
  { versao => 'indices-v2', data => '2026-11-16',
    mudou  => 'Diversidade discente: a parte da inclusão passa a ser a proporção de alunos da educação especial em classe comum (antes somava os turnos, e quase toda escola tinha a nota máxima nessa parte).' },
  { versao => 'indices-v1', data => '2026-06-04',
    mudou  => 'Fórmula original dos seis índices.' },
);

# Método dos índices do Censo (#457, VK-01), lido de
# data_pipeline/deploy/escolas_scores.sql. Escala 0 a 10, maior é melhor;
# no índice, item sem resposta no Censo conta como ausente, e escola sem o
# registro (docentes, gestores, matrículas) fica sem o índice (NULL, #467).
my $SEM_DADO = 'Item sem resposta no Censo conta como ausente.';
our %METODO = (
  infraestrutura => 'Índice de 0 a 10 (maior é melhor): média de quatro grupos de peso igual. '
    . 'Básico: água potável, energia da rede pública, esgoto da rede ou fossa séptica, coleta de lixo e banheiro. '
    . 'Salas e equipamentos: biblioteca ou sala de leitura, laboratórios de ciências e de informática, quadra, cozinha, refeitório e salas da diretoria, da secretaria e dos professores. '
    . 'Acessibilidade: rampas, corrimão, piso tátil, sinalização e banheiro adaptado. '
    . 'Tecnologia: computador, internet, lousa digital, multimídia e impressora. '
    . 'Não é infraestrutura básica: o básico pesa um quarto, e energia de gerador ou solar conta como falta. Para água, energia, esgoto e banheiro, use "Infraestrutura básica". '
    . $SEM_DADO,
  capacidade_atendimento => 'Índice de 0 a 10 (maior é melhor). 40%: alunos por sala e por turno (matrículas ÷ salas × turnos com matrícula, contando matutino, vespertino e noturno, 10 sem lotação, 0 com 50 ou mais). '
    . '20%: etapas oferecidas, de 7 (creche, pré-escola, anos iniciais, anos finais, ensino médio, EJA e educação profissional). '
    . '20%: proporção de matrículas em tempo integral. 20%: alimentação escolar. '
    . 'Sem salas informadas, a parte de alunos por sala conta 0. '
    . 'Escola sem matrículas no Censo fica sem o índice (vazio, não 0). '
    . 'A parte de alunos por sala passou a contar os turnos na versão indices-v5, de 17/11/2026 (antes, a escola de dois ou três turnos parecia lotada). ' . $SEM_DADO,
  capacitacao_docente => 'Índice de 0 a 10 (maior é melhor). 30%: docentes com ensino superior. '
    . '30%: com pós-graduação (especialização, mestrado ou doutorado). 20%: concursados. '
    . '20%: com formação continuada (soma das formações específicas do Censo, limitada ao total). '
    . 'Escola sem registro de docentes no Censo fica sem o índice (vazio, não 0).',
  diversidade_discente => 'Índice de 0 a 10 (maior é melhor). 35%: diversidade de cor/raça das matrículas com cor declarada (1 menos a soma dos quadrados das proporções). '
    . '25%: equilíbrio entre meninas e meninos. 20%: inclusão (proporção de alunos da educação especial em classe comum). '
    . '20%: proporção de matrículas na EJA. Escola sem matrículas no Censo fica sem o índice (vazio, não 0). '
    . 'Com menos de metade das matrículas com cor declarada, a parte de cor/raça fica de fora e o peso dela vai para as outras três. '
    . 'A parte de cor/raça foi corrigida na versão indices-v4, de 17/11/2026 (antes era sobre o total de matrículas, e quem não declarava a cor parecia mais diverso), '
    . 'e a da inclusão na indices-v2, de 16/11/2026: notas de versões anteriores não são comparáveis.',
  capacidade_gestora => 'Índice de 0 a 10 (maior é melhor). 30%: formação dos gestores (superior e pós-graduação). '
    . '20%: gestores com formação em gestão. 20%: gestores por aluno (10 com um gestor para cada 200 alunos ou menos). '
    . '20%: órgãos colegiados (associação de pais, de pais e mestres, conselho escolar, grêmio e outros, de 5). '
    . '10%: acesso ao cargo por concurso, eleição ou processo seletivo. Escola sem registro de gestores no Censo fica sem o índice (vazio, não 0).',
  sustentabilidade => 'Índice de 0 a 10 (maior é melhor): média de quatro partes de peso igual. '
    . 'Energia renovável; reciclagem ou reaproveitamento do lixo; área verde e área de plantio (meio ponto cada); educação ambiental. '
    . $SEM_DADO,
);

# Indicadores só da lista de escolas de um município (#457): ficam fora do
# indicator_registry, que o job de ranking pré-calculado (bin/ranking.pl) e
# o painel da escola percorrem só com as fontes mv e ideb.
our %BASICA = (
  agua     => ['água',     'e.in_agua_inexistente = 0',    'e.in_agua_inexistente'],
  energia  => ['energia',  'e.in_energia_inexistente = 0', 'e.in_energia_inexistente'],
  esgoto   => ['esgoto',   'e.in_esgoto_inexistente = 0',  'e.in_esgoto_inexistente'],
  banheiro => ['banheiro', 'e.in_banheiro = 1',            'e.in_banheiro'],
);
our @BASICA_ORDEM = qw(agua energia esgoto banheiro);
has indicadores_municipio => sub {
  return {
    infraestrutura_basica => {
      source => 'censo_basica', label => 'Infraestrutura básica',
      metodo => 'Quantos dos 4 itens básicos a escola tem, de 0 a 4 (maior é melhor): água, energia elétrica, '
        . 'esgotamento sanitário (da rede, fossa ou outro) e banheiro, como declarados ao Censo Escolar. '
        . '"Sem água", "sem energia" e "sem esgoto" são as respostas "inexistente" do Censo: poço, gerador, '
        . 'energia solar e fossa contam como tem. "Menor primeiro" mostra as escolas com mais faltas.',
    },
  };
};

has indicator_registry => sub {
  return {
    infraestrutura => { source => 'mv', column => 'score_infraestrutura', label => 'Infraestrutura', metodo => $METODO{infraestrutura} },
    capacidade_atendimento => { source => 'mv', column => 'score_capacidade_atendimento', label => 'Capacidade de Atendimento', metodo => $METODO{capacidade_atendimento} },
    capacitacao_docente => { source => 'mv', column => 'score_capacitacao_docente', label => 'Capacitação Docente', metodo => $METODO{capacitacao_docente} },
    diversidade_discente => { source => 'mv', column => 'score_diversidade_discente', label => 'Diversidade Discente', metodo => $METODO{diversidade_discente} },
    capacidade_gestora => { source => 'mv', column => 'score_capacidade_gestora', label => 'Capacidade Gestora', metodo => $METODO{capacidade_gestora} },
    sustentabilidade => { source => 'mv', column => 'score_sustentabilidade', label => 'Sustentabilidade', metodo => $METODO{sustentabilidade} },
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


# ============================================================================
# Ranking por recorte (#430, AN-11)
# ============================================================================
#
# Duas leituras novas, ao vivo (recortes pequenos e indexados):
#
#   escolas_do_municipio — todas as escolas de um município (opcionalmente de
#   uma rede) ordenadas por um indicador do registry, com o INSE ao lado;
#
#   redes_municipais — as redes MUNICIPAIS dos municípios de uma UF (ou do
#   Brasil), por um indicador do IDEB/SAEB. Decisões (informadas ao
#   developer):
#     * valor da rede = média simples das escolas da rede com dado (não é o
#       IDEB oficial da rede, que não está carregado) — o rótulo diz isso;
#     * rede com menos de MIN_ESCOLAS escolas com dado fica de fora, contada;
#     * variação = média da edição atual − média da edição anterior (cada
#       uma sobre as escolas com dado naquela edição);
#     * leitura não punitiva: INSE médio das escolas da rede e a média dos
#       municípios do mesmo quinto de INSE no recorte ("esperado pelo
#       contexto"), em vez de cor de pior/melhor.

our $MIN_ESCOLAS_REDE = 3;
# Mínimo ajustável na tela (#437) e o limite do salto atípico: variação a
# mais de $DESVIOS_ATIPICO desvios padrão da média das variações do recorte,
# para cima ou para baixo.
our ($MIN_ESCOLAS_LIMITE_INF, $MIN_ESCOLAS_LIMITE_SUP) = (3, 30);
our $DESVIOS_ATIPICO = 2;

# Porte do município (#439): classes em EduMaps::Porte.

sub escolas_do_municipio ($self, $codigo_ibge, $indicator_id, $opts = {}) {
  my $def = $self->indicator_registry->{$indicator_id} // $self->indicadores_municipio->{$indicator_id}
    or croak "Indicador desconhecido: $indicator_id";
  my $basica = $def->{source} eq 'censo_basica';
  my $fonte_rede = $basica ? 'mv' : $def->{source};    # o Censo usa o mapa de tp_dependencia
  my $network = $opts->{network};
  if (defined $network) {
    croak "Rede de ensino desconhecida: $network"
      unless exists $self->network_map->{$fonte_rede}{$network};
  }
  my $column = $basica ? undef : $self->_assert_known_column($def->{column});
  my $dbh = $self->schema->storage->dbh;

  my ($sql, @bind, $ano);
  if ($basica) {
    # #457: itens básicos presentes (0 a 4) e os que faltam, do último Censo.
    ($ano) = $dbh->selectrow_array(
      'SELECT max(nu_ano_censo) FROM clean.censo_escolas WHERE co_municipio = ? AND tp_situacao_funcionamento = 1',
      undef, $codigo_ibge);
    return undef unless $ano;
    my @tem = map { "($BASICA{$_}[1])" } @BASICA_ORDEM;
    my $valor = join ' + ', map { "($_)::int" } @tem;
    my $faltam = 'array_remove(ARRAY[' . join(', ', map { "CASE WHEN NOT ($BASICA{$_}[1]) THEN '$BASICA{$_}[0]' END" } @BASICA_ORDEM) . '], NULL)';
    # Escola sem resposta em algum item fica fora (ausência não vira falta).
    my $completo = join ' AND ', map { "$BASICA{$_}[2] IS NOT NULL" } @BASICA_ORDEM;
    my $rede_sql = defined $network ? 'AND e.tp_dependencia = ?' : '';
    $sql = qq{
      SELECT e.co_entidade, e.no_entidade, e.tp_dependencia, ($valor)::float8 AS valor, $faltam AS faltam
        FROM clean.censo_escolas e
       WHERE e.nu_ano_censo = ? AND e.co_municipio = ? AND e.tp_situacao_funcionamento = 1 AND $completo $rede_sql
    };
    @bind = ($ano, $codigo_ibge, (defined $network ? ($self->network_map->{mv}{$network}) : ()));
  }
  elsif ($def->{source} eq 'mv') {
    ($ano) = $dbh->selectrow_array(
      "SELECT max(s.nu_ano_censo) FROM clean.mv_escolas_scores s
         JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
        WHERE e.co_municipio = ? AND s.$column IS NOT NULL", undef, $codigo_ibge);
    return undef unless $ano;
    my $rede_sql = defined $network ? 'AND e.tp_dependencia = ?' : '';
    $sql = qq{
      SELECT s.co_entidade, e.no_entidade, e.tp_dependencia, s.${column}::float8 AS valor
        FROM clean.mv_escolas_scores s
        JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
       WHERE s.nu_ano_censo = ? AND e.co_municipio = ? AND s.$column IS NOT NULL $rede_sql
    };
    @bind = ($ano, $codigo_ibge, (defined $network ? ($self->network_map->{mv}{$network}) : ()));
  } else {
    ($ano) = $dbh->selectrow_array(
      "SELECT max(ano) FROM clean.ideb_notas_escolas WHERE co_municipio = ? AND etapa = ? AND $column IS NOT NULL",
      undef, $codigo_ibge, $def->{etapa});
    return undef unless $ano;
    my $rede_sql = defined $network ? 'AND i.rede = ?' : '';
    $sql = qq{
      SELECT i.id_escola AS co_entidade, COALESCE(e.no_entidade, i.no_escola) AS no_entidade,
             e.tp_dependencia, i.${column}::float8 AS valor
        FROM clean.ideb_notas_escolas i
        LEFT JOIN clean.censo_escolas e
          ON e.co_entidade = i.id_escola AND e.nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.censo_escolas)
       WHERE i.ano = ? AND i.co_municipio = ? AND i.etapa = ? AND i.$column IS NOT NULL $rede_sql
    };
    @bind = ($ano, $codigo_ibge, $def->{etapa}, (defined $network ? ($self->network_map->{ideb}{$network}) : ()));
  }

  # INSE da edição mais recente do SAEB (mesma regra do perfil da escola),
  # num join só: o índice do inse começa pelo ano, e a busca por escola
  # linha a linha custava segundos em municípios grandes.
  my $rows = $dbh->selectall_arrayref(qq{
    WITH base AS ($sql),
    inse AS (
      SELECT id_escola, media_inse FROM clean.inse
       WHERE nu_ano_saeb = (SELECT max(nu_ano_saeb) FROM clean.inse)
    )
    SELECT b.*, RANK() OVER (ORDER BY b.valor DESC) AS posicao, n.media_inse::float8 AS inse
      FROM base b
      LEFT JOIN inse n ON n.id_escola = b.co_entidade
     ORDER BY b.valor DESC, b.no_entidade
  }, { Slice => {} }, @bind);

  my %rede_nome = (1 => 'Federal', 2 => 'Estadual', 3 => 'Municipal', 4 => 'Privada');
  my ($municipio, $uf) = $dbh->selectrow_array(
    'SELECT no_municipio, sg_uf FROM clean.censo_escolas WHERE co_municipio = ? LIMIT 1', undef, $codigo_ibge);

  return {
    indicador => { id => $indicator_id, label => $def->{label}, fonte => $def->{source} eq 'ideb' ? 'ideb' : 'censo',
                   (defined $def->{metodo} ? (metodo => $def->{metodo}) : ()),
                   ($def->{source} eq 'mv' ? (versao => $INDICES_VERSAO, versao_data => $INDICES_HISTORICO[0]{data}) : ()),
                   ($basica ? (maximo => 0 + @BASICA_ORDEM) : ()) },
    ano       => 0 + $ano,
    municipio => { codigo_ibge => "$codigo_ibge", nome => $municipio, uf => $uf },
    rede      => $network,
    total     => scalar @$rows,
    escolas   => [ map { +{
      co_entidade => "$_->{co_entidade}",
      no_entidade => $_->{no_entidade},
      rede        => defined $_->{tp_dependencia} ? $rede_nome{ $_->{tp_dependencia} } : undef,
      valor       => 0 + $_->{valor},
      posicao     => 0 + $_->{posicao},
      inse        => defined $_->{inse} ? 0 + $_->{inse} : undef,
      ($basica ? (faltam => $_->{faltam} // []) : ()),
    } } @$rows ],
  };
}

sub redes_municipais ($self, $indicator_id, $opts = {}) {
  my $def = $self->indicator_registry->{$indicator_id}
    or croak "Indicador desconhecido: $indicator_id";
  croak "Ranking de redes só para indicadores do IDEB/SAEB: $indicator_id"
    unless $def->{source} eq 'ideb';
  my $column = $self->_assert_known_column($def->{column});
  my $dbh = $self->schema->storage->dbh;
  my $uf = $opts->{uf};
  my $regiao = $uf ? undef : $opts->{regiao};
  croak "Região desconhecida: $regiao" if defined $regiao && !EduMaps::Regiao->valido($regiao);
  croak "Informe a UF, a região ou o recorte nacional" unless $uf || $regiao || $opts->{national};

  # #445 (BA-02): a UF vence a região, e a região vence o nacional; a região
  # só restringe as UFs, antes da posição, do INSE e do salto atípico.
  my $uf_sql = $uf ? 'AND sg_uf = ?' : $regiao ? 'AND sg_uf = ANY(?)' : '';
  my @uf_bind = $uf ? ($uf) : $regiao ? (EduMaps::Regiao->ufs($regiao)) : ();
  my $porte = $opts->{porte};
  croak "Porte desconhecido: $porte" if defined $porte && !EduMaps::Porte->valido($porte);
  my $porte_case = EduMaps::Porte->case_sql('pm.populacao_estimada');

  my $anos = $dbh->selectcol_arrayref(
    "SELECT DISTINCT ano FROM clean.ideb_notas_escolas
      WHERE etapa = ? AND rede = 'Municipal' AND $column IS NOT NULL $uf_sql
      ORDER BY ano DESC LIMIT 2", undef, $def->{etapa}, @uf_bind);
  return undef unless @$anos;
  my ($ano, $ano_ant) = @$anos;

  my $min = $opts->{minimo} // $MIN_ESCOLAS_REDE;
  croak "Mínimo de escolas fora de $MIN_ESCOLAS_LIMITE_INF..$MIN_ESCOLAS_LIMITE_SUP: $min"
    unless $min =~ /^\d+$/ && $min >= $MIN_ESCOLAS_LIMITE_INF && $min <= $MIN_ESCOLAS_LIMITE_SUP;
  $min = 0 + $min;
  my $rows = $dbh->selectall_arrayref(qq{
    WITH inse_ult AS (
      SELECT id_escola, media_inse FROM clean.inse
       WHERE nu_ano_saeb = (SELECT max(nu_ano_saeb) FROM clean.inse)
    ),
    pop AS (
      SELECT pm.codigo_ibge, pm.populacao_estimada AS populacao, $porte_case AS porte
        FROM clean.populacao_municipal pm
    ),
    atual AS (
      SELECT i.co_municipio, max(i.no_municipio) AS no_municipio, max(i.sg_uf) AS sg_uf,
             count(*) AS n, avg(i.$column)::float8 AS media,
             avg(x.media_inse)::float8 AS inse
        FROM clean.ideb_notas_escolas i
        LEFT JOIN inse_ult x ON x.id_escola = i.id_escola
       WHERE i.ano = ? AND i.etapa = ? AND i.rede = 'Municipal' AND i.$column IS NOT NULL $uf_sql
       GROUP BY i.co_municipio
    ),
    anterior AS (
      SELECT co_municipio, count(*) AS n, avg($column)::float8 AS media
        FROM clean.ideb_notas_escolas
       WHERE ano = ? AND etapa = ? AND rede = 'Municipal' AND $column IS NOT NULL $uf_sql
       GROUP BY co_municipio
    ),
    -- O filtro de porte entra aqui, antes da posição, dos quintos de INSE e
    -- do salto atípico: o ranking é entre as redes do mesmo porte.
    elegiveis AS (
      SELECT a.co_municipio, a.no_municipio, a.sg_uf, a.n, a.media,
             CASE WHEN p.n >= $min THEN a.media - p.media END AS variacao,
             a.inse, po.populacao, po.porte
        FROM atual a
        LEFT JOIN anterior p USING (co_municipio)
        LEFT JOIN pop po ON po.codigo_ibge = a.co_municipio::text
       WHERE a.n >= $min @{[ defined $porte ? 'AND po.porte = ?' : '' ]}
    ),
    quintos AS (
      SELECT e.*, CASE WHEN e.inse IS NOT NULL THEN ntile(5) OVER (PARTITION BY e.inse IS NOT NULL ORDER BY e.inse) END AS quinto_inse
        FROM elegiveis e
    )
    SELECT q.*,
           CASE WHEN q.quinto_inse IS NOT NULL THEN avg(q.media) OVER (PARTITION BY q.quinto_inse) END AS media_quinto,
           RANK() OVER (ORDER BY q.media DESC) AS posicao,
           CASE WHEN q.variacao IS NOT NULL THEN RANK() OVER (ORDER BY q.variacao DESC NULLS LAST) END AS posicao_variacao
      FROM quintos q
     ORDER BY q.media DESC, q.no_municipio
  }, { Slice => {} },
    $ano, $def->{etapa}, @uf_bind,
    (defined $ano_ant ? $ano_ant : -1), $def->{etapa}, @uf_bind,
    (defined $porte ? ($porte) : ()));

  my $porte_fora = defined $porte
    ? "AND EXISTS (SELECT 1 FROM clean.populacao_municipal pm
                    WHERE pm.codigo_ibge = i.co_municipio::text AND $porte_case = ?)"
    : '';
  my ($fora) = $dbh->selectrow_array(qq{
    SELECT count(*) FROM (
      SELECT co_municipio FROM clean.ideb_notas_escolas i
       WHERE ano = ? AND etapa = ? AND rede = 'Municipal' AND $column IS NOT NULL $uf_sql $porte_fora
       GROUP BY co_municipio HAVING count(*) < $min
    ) t}, undef, $ano, $def->{etapa}, @uf_bind, (defined $porte ? ($porte) : ()));

  # Ano da estimativa populacional, do catálogo de fontes (#428).
  my $pop_ano = eval { EduMaps::Fontes->versao($dbh, 'ibge_populacao')->{ibge_populacao}{periodo} };

  my $num = sub ($v) { defined $v ? 0 + $v : undef };

  # Salto atípico (#437): variação a mais de $DESVIOS_ATIPICO desvios
  # padrão da média das variações do recorte. Com menos de 3 variações ou
  # desvio zero, ninguém é marcado.
  my @vars = map { 0 + $_->{variacao} } grep { defined $_->{variacao} } @$rows;
  my ($vmedia, $vdp);
  if (@vars >= 3) {
    $vmedia += $_ / @vars for @vars;
    my $ss = 0; $ss += ($_ - $vmedia) ** 2 for @vars;
    $vdp = sqrt($ss / (@vars - 1));
  }
  my $atipico = sub ($v) {
    return \0 unless defined $v && $vdp;
    return abs($v - $vmedia) > $DESVIOS_ATIPICO * $vdp ? \1 : \0;
  };
  my $marcadas = grep { ${ $atipico->($_->{variacao}) } } @$rows;
  my $arred = sub ($v) { defined $v ? 0 + sprintf('%.4f', $v) : undef };

  # #449 (RG-03): o município destacado, e por que a rede dele não está na
  # lista quando não está. Uma consulta a mais, só com `destaque`.
  my $destaque = defined $opts->{destaque}
    ? $self->_destaque_rede($opts->{destaque}, $rows, {
        column => $column, etapa => $def->{etapa}, ano => $ano, min => $min,
        uf => $uf, regiao => $regiao, porte => $porte, porte_case => $porte_case })
    : undef;

  return {
    indicador => { id => $indicator_id, label => $def->{label} },
    (defined $destaque ? (destaque => $destaque) : ()),
    atipico => {
      desvios       => $DESVIOS_ATIPICO,
      media_variacao => $arred->($vmedia),
      desvio_variacao => $arred->($vdp),
      limite_inferior => defined $vdp ? $arred->($vmedia - $DESVIOS_ATIPICO * $vdp) : undef,
      limite_superior => defined $vdp ? $arred->($vmedia + $DESVIOS_ATIPICO * $vdp) : undef,
      marcadas      => 0 + $marcadas,
    },
    ano => 0 + $ano,
    ano_anterior => defined $ano_ant ? 0 + $ano_ant : undef,
    recorte => {
      ($uf ? (uf => $uf) : $regiao ? (regiao => { id => $regiao, nome => EduMaps::Regiao->nome($regiao) }) : (nacional => \1)),
      (defined $porte ? (porte => $porte) : ()),
    },
    portes  => EduMaps::Porte->lista,
    regioes => EduMaps::Regiao->lista,
    populacao_fonte => { ano => $pop_ano, descricao => 'Estimativa da população do IBGE' },
    minimo_escolas => $min,
    total => scalar @$rows,
    fora_por_poucas_escolas => 0 + ($fora // 0),
    redes => [ map { +{
      codigo_ibge => "$_->{co_municipio}",
      municipio   => $_->{no_municipio},
      uf          => $_->{sg_uf},
      escolas     => 0 + $_->{n},
      media       => $num->($_->{media}),
      variacao    => $num->($_->{variacao}),
      inse        => $num->($_->{inse}),
      quinto_inse => $num->($_->{quinto_inse}),
      media_quinto_inse => $num->($_->{media_quinto}),
      posicao     => 0 + $_->{posicao},
      posicao_variacao => $num->($_->{posicao_variacao}),
      atipico     => $atipico->($_->{variacao}),
      populacao   => $num->($_->{populacao}),
      porte       => $_->{porte},
    } } @$rows ],
  };
}

# Situação da rede de um município no ranking (#449): no_ranking (com a
# posição), fora_do_recorte (outra UF ou região), sem_populacao ou
# fora_do_porte (com filtro de porte), sem_dado (nenhuma escola com o
# indicador na edição, ou município desconhecido) ou poucas_escolas.
sub _destaque_rede ($self, $codigo, $rows, $c) {
  my $dbh = $self->schema->storage->dbh;
  my $col = $c->{column};
  my ($nome, $uf) = $dbh->selectrow_array(
    'SELECT no_municipio, sg_uf FROM clean.ideb_notas_escolas WHERE co_municipio = ? ORDER BY ano DESC LIMIT 1',
    undef, $codigo);
  ($nome, $uf) = $dbh->selectrow_array(
    'SELECT no_municipio, sg_uf FROM clean.censo_escolas WHERE co_municipio = ? ORDER BY nu_ano_censo DESC LIMIT 1',
    undef, $codigo) unless defined $nome;
  my ($pop, $porte) = $dbh->selectrow_array(
    "SELECT pm.populacao_estimada, $c->{porte_case} FROM clean.populacao_municipal pm WHERE pm.codigo_ibge = ?",
    undef, "$codigo");
  my ($n) = $dbh->selectrow_array(
    "SELECT count(*) FROM clean.ideb_notas_escolas
      WHERE co_municipio = ? AND ano = ? AND etapa = ? AND rede = 'Municipal' AND $col IS NOT NULL",
    undef, $codigo, $c->{ano}, $c->{etapa});
  my ($row) = grep { "$_->{co_municipio}" eq "$codigo" } @$rows;

  my $situacao =
      $row                                     ? 'no_ranking'
    : !defined $nome                           ? 'sem_dado'
    : (defined $c->{uf} && $uf ne $c->{uf})
      || (defined $c->{regiao} && (EduMaps::Regiao->de_uf($uf) // '') ne $c->{regiao})
                                               ? 'fora_do_recorte'
    : defined $c->{porte} && !defined $porte   ? 'sem_populacao'
    : defined $c->{porte} && $porte ne $c->{porte} ? 'fora_do_porte'
    : !$n                                      ? 'sem_dado'
    : $n < $c->{min}                           ? 'poucas_escolas'
    :                                            'sem_dado';

  return {
    codigo_ibge => "$codigo",
    municipio   => $nome,
    uf          => $uf,
    regiao      => EduMaps::Regiao->de_uf($uf),
    populacao   => defined $pop ? 0 + $pop : undef,
    porte       => $porte,
    escolas     => 0 + ($n // 0),
    situacao    => $situacao,
    posicao     => $row ? 0 + $row->{posicao} : undef,
  };
}

1;
