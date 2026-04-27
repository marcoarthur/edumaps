package EduMaps::Schema::ResultSet::MunicipiosSp;

use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

# creates a discretization by quantiles (bins = 5) to create a multivariated
# equi-frequently profile for the municipalities, using the economic data for
# its compound GDP.
sub economy_quantile_binning($self, $params = {}) {
  # TODO: params{n_tile} = 5 ; for Number of binnings
  my $QUERY =<<~'EOQ';
  WITH dados_recentes AS (
      -- Último ano com dados de PIB
      SELECT 
          ano,
          codigo_ibge,
          industria_percent,
          agro_percent,
          governo_percent,
          servicos_percent
      FROM clean.dados_ibge
      WHERE ano = (SELECT MAX(ano) FROM clean.dados_ibge WHERE 
      agro_percent IS NOT NULL
      AND governo_percent IS NOT NULL
      AND industria_percent IS NOT NULL
      AND servicos_percent IS NOT NULL)
  ),
  base_classificacao AS (
      SELECT 
          d.ano,
          m.codigo_ibge,
          m.nome AS municipio,
          m.sigla_estado AS estado,
          p.populacao_estimada,
          d.industria_percent,
          d.agro_percent,
          d.governo_percent,
          d.servicos_percent,
          -- Classificação por quintis (5 grupos) – ajuste o número conforme necessidade
          NTILE(5) OVER (ORDER BY p.populacao_estimada) AS quintil_pop,
          NTILE(5) OVER (ORDER BY d.industria_percent) AS quintil_ind,
          NTILE(5) OVER (ORDER BY d.agro_percent)     AS quintil_agro,
          NTILE(5) OVER (ORDER BY d.governo_percent)  AS quintil_gov,
          NTILE(5) OVER (ORDER BY d.servicos_percent) AS quintil_serv
      FROM clean.municipios_sp m
      LEFT JOIN dados_recentes d ON m.codigo_ibge = d.codigo_ibge
      LEFT JOIN clean.populacao_municipal p ON m.codigo_ibge = p.codigo_ibge
      WHERE d.codigo_ibge IS NOT NULL      -- apenas municípios com dados de PIB
  )
  SELECT 
      ano,
      codigo_ibge,
      municipio,
      estado,
      populacao_estimada,
      industria_percent,
      agro_percent,
      governo_percent,
      servicos_percent,
      -- Categorias isoladas (úteis para análises)
      CONCAT('Pop', quintil_pop) AS cat_populacao,
      CONCAT('Ind', quintil_ind) AS cat_industria,
      CONCAT('Agro', quintil_agro) AS cat_agropecuaria,
      CONCAT('Gov', quintil_gov) AS cat_governo,
      CONCAT('Serv', quintil_serv) AS cat_servicos,
      -- Classificação combinada (exemplo: agrupa municípios de perfil similar)
      CONCAT('P', quintil_pop, 
             '_I', quintil_ind, 
             '_A', quintil_agro, 
             '_G', quintil_gov, 
             '_S', quintil_serv) AS perfil_completo
  FROM base_classificacao
  ORDER BY perfil_completo, municipio
  EOQ

  my $cols = [
    qw(
      codigo_ibge municipio estado populacao_estimada perfil_completo
      industria_percent agro_percent governo_percent servicos_percent
    )
  ];

  # For default 5 bins we have
  my %categories = (1 => 'very low', 2 => 'low', 3 => 'medium', 4 => 'high', 5 => 'very high');
  # For default columns
  my %classifiers = (P => 'population', I => 'Industry', A => 'Agriculture', S => 'Services', G => 'Govern');

  my $results = $self->custom_query($QUERY, $cols)->as_hash->get_all;
  return {categories => \%categories, classifiers => \%classifiers, results => $results};
}

sub with_escolas_count($self) {
  my $escolas = $self->result_source->schema->resultset('MunicipiosSp')
  ->search_related_rs( 
    'escolas',
    {
      # this binds counting for each individual municipio in search result
      # TODO: how to garantee that nome_municipio will be used ?
      # OR how to use a guaranted identifier ?
      'municipio' => {-ident => "principal.nome_municipio" }
    },
  );

  $self->search_rs(
    undef,
    {
      '+select' => [
        {'' => $escolas->count_rs->as_query, -as => 'total_escolas'},
      ],
      '+as'     => ['total_escolas'],
      alias     => 'principal',
    }
  );
}

sub to_geojson($self) {
  my $geom = 'geometry';
  my $cols_map = { name => 'nome_municipio', area => 'area_km2', fid => 'codigo_ibge' };
  $self->geojson_features($geom, $cols_map);
}

sub details($self,$id) {
  my %counts = (
    fundamental   => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%ensino fundamental%')/,
    medio         => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Médio%')/,
    infantil      => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%infantil%')/,
    profissional  => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Educação Profissional%')/,
    eja           => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Educação de Jovens Adultos%')/,
    publicas      => \q/COUNT(escolas) FILTER(WHERE escolas.categoria_administrativa = 'Pública')/,
  );
  my @total_counts = map { +{"total_$_" => $counts{$_} } } keys %counts;

  my $cols = [
    { codigo_ibge => 'codigo_ibge' },
    { nome_municipio => 'nome_municipio' },
    { area => 'area_km2' },
    { total_escolas => { count => 'escolas' } },
    { populacao => 'populacao.populacao_estimada' },
    { estado => 'nome_estado' },
    @total_counts,
  ];

  my @params = ( 
    { 'me.codigo_ibge' => $id }, 
    { 
      join          => ['escolas', 'populacao'],
      'columns'     => $cols,
      result_class  => 'DBIx::Class::ResultClass::HashRefInflator',
      group_by      => ['me.codigo_ibge','populacao_estimada'],
    }
  );
  $self->search_rs( @params );
}

sub school_grades($self, %opts) {
  my $me = $self->current_source_alias;
  my $rs = $self
  ->join({ escolas => 'notas' })
  ->select_derived(
    codigo_inep       => 'escolas.codigo_inep',
    nome_municipio    => "$me.nome_municipio",
    portuguese_grades => { 
      jsonb_agg => { json_build_object => [ q/'nota'/, 'notas.nota_por', q/'ano'/, 'notas.ano'] } 
    },
    math_grades     => { 
      jsonb_agg => { json_build_object => [ q/'nota'/, 'notas.nota_mat', q/'ano'/, 'notas.ano'] } 
    },
  )
  ->group_by( ['codigo_inep',"$me.nome_municipio"] );
  return $rs->having( 
    { 
      -and => 
      [
        \["COUNT(notas.nota_mat) > ?",0],
        \["COUNT(notas.nota_por) > ?",0]
      ]
    }
  ) if $opts{graded_only};
  return $rs;
}

sub neighbor_cities($self) { $self->search_related_rs('vizinhos') }

1;
