package EduMaps::Model::Rank::SchoolDerived;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use List::Util qw(max);
use Scalar::Util qw(looks_like_number);
use Carp qw(croak);

# Indicadores concretos (a serem criados)
use EduMaps::Model::Indicator::School::IdebAI;
use EduMaps::Model::Indicator::School::IdebAF;
use EduMaps::Model::Indicator::School::NotaMatematica;
use EduMaps::Model::Indicator::School::NotaPortugues;
use EduMaps::Model::Indicator::School::Infra;
use EduMaps::Model::Indicator::School::Aprovacao;

has school_id       => undef;
has indicator_key   => undef;
has filters         => sub { { levels => ['cidade', 'estado'], redes => [] } };
has _school         => undef;   # registro da escola alvo
has _indicator      => undef;   # objeto indicador
has _cluster_defs   => sub { $self->_default_clusters };
has _all_indicators => sub { $self->_build_indicator_map };

# ============================================================================
# Inicialização
# ============================================================================
sub new ($class, @args) {
  my $self = $class->SUPER::new(@args);
  croak "school_id é obrigatório" unless $self->school_id;
  croak "indicator_key é obrigatório" unless $self->indicator_key;

  # Carrega a escola alvo
  my $school_rs = $self->schema->resultset('CensoEscolas')
  ->search({ codigo_inep => $self->school_id });
  croak "Escola não encontrada" unless $school_rs->count == 1;
  $self->_school($school_rs->first);

  # Instancia o indicador
  my $ind = $self->_all_indicators->{$self->indicator_key}
    or croak "Indicador '".$self->indicator_key."' não reconhecido";
  $self->_indicator($ind);

  return $self;
}

# ============================================================================
# Métodos públicos
# ============================================================================
sub get_ranking ($self) {
  my $school  = $self->_school;
  my $ind     = $self->_indicator;
  my $filters = $self->filters;

  # 1. Valor do indicador para a escola alvo
  my $target_value = $ind->calculate($school);
  croak "Indicador não disponível para esta escola" unless defined $target_value;

  # 2. Obter ResultSets filtrados para os níveis solicitados
  my $rs_cidade = $self->_build_resultset(
    nivel => 'cidade',
    cod_ibge => $school->co_municipio,
    filters => $filters,
  );
  my $rs_estado = $self->_build_resultset(
    nivel => 'estado',
    uf => $school->sg_uf,
    filters => $filters,
  );
  # Nacional (se desejado)
  my $rs_nacional = $self->_build_resultset(
    nivel => 'pais',
    filters => $filters,
  ) if grep { $_ eq 'pais' } @{$filters->{levels} // []};

  # 3. Calcular rankings
  my $ranking = {};
  if (grep { $_ eq 'cidade' } @{$filters->{levels} // []}) {
    $ranking->{municipio} = $self->_compute_ranking($rs_cidade, $target_value);
  }
  if (grep { $_ eq 'estado' } @{$filters->{levels} // []}) {
    $ranking->{estado} = $self->_compute_ranking($rs_estado, $target_value);
  }
  if ($rs_nacional) {
    $ranking->{nacional} = $self->_compute_ranking($rs_nacional, $target_value);
  } else {
    $ranking->{nacional} = undef;
  }

  # 4. Calcular cluster
  my $cluster = $self->_compute_cluster($target_value);

  # 5. Montar resposta
  return {
    indicator => {
      id    => $self->indicator_key,
      label => $self->_indicator_label,
      value => $target_value,
    },
    ranking   => $ranking,
    cluster   => $cluster,
  };
}

# ============================================================================
# Métodos internos
# ============================================================================
sub _compute_ranking ($self, $rs, $target_value) {
  # Ordena todos os registros pelo valor do indicador (decrescente)
  my $ind = $self->_indicator;
  my @schools_with_values;
  while (my $school = $rs->next) {
    my $v = $ind->calculate($school);
    next unless defined $v;  # descarta escolas sem o indicador
    push @schools_with_values, { school => $school, value => $v };
  }

  # Ordena por valor decrescente
  my @sorted = sort { $b->{value} <=> $a->{value} } @schools_with_values;
  my $total = scalar @sorted;

  # Encontra a posição da escola alvo (1-indexed)
  my $position;
  for my $i (0 .. $#sorted) {
    if ($sorted[$i]{school}{codigo_inep} == $self->school_id) {
      $position = $i + 1;
      last;
    }
  }

  croak "Escola não encontrada no ResultSet" unless $position;

  # Percentil: (1 - posição/total) * 100
  my $percentile = $total > 0 ? int((1 - $position / $total) * 100) : 0;

  return {
    position   => $position,
    total      => $total,
    percentile => $percentile,
  };
}

sub _compute_cluster ($self, $value) {
  my $defs = $self->_cluster_defs->{$self->indicator_key}
    or croak "Não há definição de cluster para o indicador '".$self->indicator_key."'";

  my $cluster;
  for my $c (@$defs) {
    if ($value >= $c->{min} && $value <= $c->{max}) {
      $cluster = $c;
      last;
    }
  }
  croak "Valor fora das faixas definidas" unless $cluster;

  # Escolas de referência: as 5 melhores dentro do mesmo cluster
  my $ref_schools = $self->_reference_schools($cluster);

  return {
    id    => $cluster->{id},
    name  => $cluster->{name},
    description => $cluster->{description},
    reference_schools => $ref_schools,
  };
}

sub _reference_schools ($self, $cluster) {
  my $ind = $self->_indicator;
  my $rs = $self->_build_resultset(
    nivel => 'pais',  # todas as escolas do país, mas vamos filtrar por estado/município da escola alvo?
    filters => $self->filters,
  );

  my @candidates;
  while (my $school = $rs->next) {
    next if $school->codigo_inep == $self->school_id;
    my $v = $ind->calculate($school);
    next unless defined $v;
    # Verifica se o valor está na mesma faixa do cluster
    if ($v >= $cluster->{min} && $v <= $cluster->{max}) {
      push @candidates, { school => $school, value => $v };
    }
  }

  # Ordena por valor decrescente e pega os 5 primeiros
  my @sorted = sort { $b->{value} <=> $a->{value} } @candidates;
  my @top = splice(@sorted, 0, 5);

  return [ map {
      {
        codigo_inep => $_->{school}->codigo_inep,
        escola      => $_->{school}->escola,
        municipio   => $_->{school}->municipio,
        uf          => $_->{school}->uf,
        value       => $_->{value},
      }
    } @top ];
}

sub _build_resultset ($self, %args) {
  my $nivel = $args{nivel};
  my $filters = $self->filters;

  # Base: todas as escolas que têm o indicador disponível (não nulo)
  my $ind = $self->_indicator;
  my @weight_cols = $self->_indicator_columns($ind);
  my $not_null_cond = { -and => [ map { $_ => { '!=' => undef } } @weight_cols ] };

  my $search = { -and => [$not_null_cond] };

  # Filtro de rede (ex: 'municipal', 'estadual')
  if (@{$filters->{redes} // []}) {
    push @{$search->{-and}}, { dependencia_administrativa => { -in => $filters->{redes} } };
  }

  # Filtro geográfico por nível
  if ($nivel eq 'cidade') {
    push @{$search->{-and}}, { co_municipio => $args{cod_ibge} };
  } elsif ($nivel eq 'estado') {
    push @{$search->{-and}}, { sg_uf => $args{uf} };
  } elsif ($nivel eq 'pais') {
    # sem filtro adicional
  }

  return $self->schema->resultset('CensoEscolas')->search_rs($search);
}

sub _indicator_columns ($self, $ind) {
  my @cols;
  for my $pair ($ind->weights->@*) {
    my ($col) = @$pair;
    next if ref $col eq 'CODE';
    push @cols, $col;
  }
  return @cols;
}

sub _indicator_label ($self) {
  my $map = $self->_all_indicators;
  return $map->{$self->indicator_key}->label // $self->indicator_key;
}

# ============================================================================
# Definição de clusters para cada indicador (fixo)
# ============================================================================
sub _default_clusters ($self) {
  return {
    ideb_anos_finais => [
      { id => 1, min => 7.0, max => 10.0, name => 'Excelência', description => 'IDEB acima de 7,0 – escolas com alto desempenho consistente.' },
      { id => 2, min => 6.0, max => 6.9, name => 'Alto Desempenho', description => 'IDEB entre 6,0 e 7,0 – escolas com bom desempenho e potencial de crescimento.' },
      { id => 3, min => 4.5, max => 5.9, name => 'Médio Desempenho', description => 'IDEB entre 4,5 e 6,0 – escolas que precisam de melhorias direcionadas.' },
      { id => 4, min => 0.0, max => 4.4, name => 'Baixo Desempenho', description => 'IDEB abaixo de 4,5 – escolas com necessidade de intervenção.' },
    ],
    ideb_anos_iniciais => [ # similar, com faixas ajustadas
      { id => 1, min => 7.5, max => 10.0, name => 'Excelência', description => 'IDEB Anos Iniciais acima de 7,5.' },
      { id => 2, min => 6.0, max => 7.4, name => 'Alto Desempenho', description => 'IDEB entre 6,0 e 7,5.' },
      { id => 3, min => 4.5, max => 5.9, name => 'Médio Desempenho', description => 'IDEB entre 4,5 e 6,0.' },
      { id => 4, min => 0.0, max => 4.4, name => 'Baixo Desempenho', description => 'IDEB abaixo de 4,5.' },
    ],
    # ... adicionar para os demais indicadores
    nota_matematica => [
      { id => 1, min => 8.0, max => 10.0, name => 'Excelência', description => 'Nota média em Matemática acima de 8,0.' },
      { id => 2, min => 6.0, max => 7.9, name => 'Alto Desempenho', description => 'Nota entre 6,0 e 8,0.' },
      { id => 3, min => 4.0, max => 5.9, name => 'Médio Desempenho', description => 'Nota entre 4,0 e 6,0.' },
      { id => 4, min => 0.0, max => 3.9, name => 'Baixo Desempenho', description => 'Nota abaixo de 4,0.' },
    ],
    # ... etc.
  };
}

# ============================================================================
# Mapeamento de indicadores frontend -> classes
# ============================================================================
sub _build_indicator_map ($self) {
  return {
    'ideb_anos_finais'  => EduMaps::Model::Indicator::School::IdebAF->new,
    'ideb_anos_iniciais'=> EduMaps::Model::Indicator::School::IdebAI->new,
    'nota_matematica'   => EduMaps::Model::Indicator::School::NotaMatematica->new,
    'nota_portugues'    => EduMaps::Model::Indicator::School::NotaPortugues->new,
    'infraestrutura'    => EduMaps::Model::Indicator::School::Infra->new,
    'taxa_aprovacao'    => EduMaps::Model::Indicator::School::Aprovacao->new,
  };
}

1;
