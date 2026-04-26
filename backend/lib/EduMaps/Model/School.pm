package EduMaps::Model::School;

use Mojo::Base "EduMaps::Model::Base", -signatures;
use DateTime;
use Mojo::Exception qw(raise);
use DDP;
use utf8;

################################################################
# CLASS INTERNALS
################################################################
our $DEFAULT_COLS = [
  qw(escola codigo_inep latitude longitude endereco telefone municipio uf porte_escola),
  { osm => \q<'https://www.openstreetmap.org/?mlat=' || latitude || '&mlon=' || longitude ||'&zoom=18#map=18/' || latitude || '/' || longitude> },
  { whatsapp => \q<'https://wa.me/' || 55 || regexp_replace(telefone, '\D', '', 'g')> },
  { modalidades => \q<regexp_split_to_array(etapas_modalidades, '\s*,\s*')> },
  { tipo => 'dependencia_administrativa' },
];

sub _sanitize_like_pattern ($self, $string, $escape_char = '\\') {
    $$string =~ s/([%_\\])/$escape_char$1/g;
}

###########################################################################################
# PUBLIC METHODS
###########################################################################################
sub payroll($self, $cod_inep, $dt = DateTime->now(locale => 'pt')) {
  my $rs = $self->schema->resultset('Escolas');

  my $SQL =<<~'EOQ';
  WITH dados_escola AS (
      SELECT DISTINCT
          e.escola,
          e.codigo_inep,
          e.uf,
          e.municipio,
          e.localizacao,
          e.endereco,
          e.telefone,
          e.dependencia_administrativa,
          e.porte_escola
      FROM clean.escolas e
      WHERE e.codigo_inep = :cod_inep
  ),
  totais_gerais AS (
      SELECT 
          COUNT(DISTINCT r.cpf) AS total_profissionais,
          COUNT(*) AS total_registros,
          SUM(r.salario_total) AS total_salario_geral,
          ROUND(AVG(r.salario_total), 2) AS media_salario
      FROM clean.remuneracao_municipal r
      WHERE r.cod_inep = :cod_inep
        AND r.ano = :ano
        AND r.mes = :mes
  ),
  profissionais_detalhados AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'nome', r.nome_profissional,
                  'cpf', r.cpf,
                  'categoria', r.categoria,
                  'tipo', r.tipo,
                  'segmento_ensino', r.segmento_ensino,
                  'carga_horaria', r.carga_horaria,
                  'situacao', r.situacao,
                  'salario_base', r.salario_base,
                  'salario_fundeb_max', r.salario_fundeb_max,
                  'salario_fundeb_min', r.salario_fundeb_min,
                  'salario_outros', r.salario_outros,
                  'salario_total', r.salario_total
              )
              ORDER BY r.categoria, r.nome_profissional
          ) AS profissionais
      FROM clean.remuneracao_municipal r
      WHERE r.cod_inep = :cod_inep
        AND r.ano = :ano
        AND r.mes = :mes
  ),
  resumo_categoria AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'categoria', categoria,
                  'profissionais', profissionais,
                  'total_salarios', total_salarios
              )
          ) AS resumo_categoria
      FROM (
          SELECT 
              categoria,
              COUNT(DISTINCT cpf) AS profissionais,
              SUM(salario_total) AS total_salarios
          FROM clean.remuneracao_municipal
          WHERE cod_inep = :cod_inep
            AND ano = :ano
            AND mes = :mes
          GROUP BY categoria
          ORDER BY categoria
      ) cat
  ),
  resumo_segmento AS (
      SELECT 
          JSON_AGG(
              JSONB_BUILD_OBJECT(
                  'segmento', segmento_ensino,
                  'profissionais', profissionais,
                  'total_salarios', total_salarios
              )
          ) AS resumo_segmento
      FROM (
          SELECT 
              segmento_ensino,
              COUNT(DISTINCT cpf) AS profissionais,
              SUM(salario_total) AS total_salarios
          FROM clean.remuneracao_municipal
          WHERE cod_inep = :cod_inep
            AND ano = :ano
            AND mes = :mes
          GROUP BY segmento_ensino
          ORDER BY segmento_ensino
      ) seg
  )
  SELECT 
      e.*,
      :ano AS ano,
      :mes AS mes,
      t.*,
      p.profissionais,
      c.resumo_categoria,
      s.resumo_segmento
  FROM 
      dados_escola e
  CROSS JOIN 
      totais_gerais t
  CROSS JOIN 
      profissionais_detalhados p
  CROSS JOIN 
      resumo_categoria c
  CROSS JOIN 
      resumo_segmento s
  EOQ

  my ($year, $month) = ($dt->year, ucfirst($dt->month_name));
  my $params = {cod_inep => $cod_inep , ano => $year, mes => $month};
  my $resolved = $self->resolve_bindings($SQL, $params);
  my ($aggregates, $school_data) = ( 
    [qw(profissionais resumo_segmento resumo_categoria)],
    [qw(ano mes escola codigo_inep endereco telefone dependencia_administrativa)]
  );

  my $payroll = $rs->custom_query(
    $resolved->{sql},
    [@$aggregates, @$school_data],
    $resolved->{bind_values},
  )->as_hash->first;

  unless ($payroll) {
    return $self->json->encode({
        error => "Nenhum dado encontrado para a escola $cod_inep em $month/$year",
        escola => $cod_inep,
        periodo => "$month/$year"
      });
  }

  my $null = "null";
  my %dados_escola = map { $_ => $payroll->{$_} } @$school_data;
  my $json = sprintf q/{"escola":%s, "profissionais":%s, "resumo_categoria":%s, "resumo_segmento":%s}/,
  $self->json->encode(\%dados_escola),
  $payroll->{profissionais}     || $null,
  $payroll->{resumo_categoria}  || $null,
  $payroll->{resumo_segmento}   || $null;

  return $json;
}

sub payroll_monthly($self, $cod_inep, $months, $year) {
  my @dates = map { 
    raise 'EduMaps::Exception::Date', "$_ month is out of range" if ($_ < 1 || $_ > 12);
    DateTime->new(year => $year, month => $_, locale => 'pt');
  } $months->@*;
  my @reports = map {$self->payroll($cod_inep, $_)} @dates;
  return sprintf "[%s]", join(',', @reports);
}

sub grades($self, $params = {}) {
  my $notas = $self->schema->resultset('InepNotasDesagregadas');
  $self->set_params_map(
    params => $params,
    map => {
      id_escola => [qw/cod_inep inep/],
      ano => [
        [[qw(since)],[qw(until)]],
        sub ($since, $until = DateTime->now->year) { return {-between => [$since, $until]} }
      ],
    }
  );

  my $columns = [
    'ano',
    { portugues => \q{round(nota_por/50, 2)} },
    { matematica => \q{round(nota_mat/50, 2)} },
    { media => \q{nota_media} },
  ];

  my $grades = $notas->search_rs($params)->columns($columns)->as_hash->get_all->each(
    sub {$self->_format_float_nums($_)}
  );
  return $self->json->encode($grades->to_array);
}

sub full_inep_grades($self, $params = {}) {
  my $inep = $self->schema->resultset('Inep');

  return $inep->full_grade($params->{cod_inep});
}

sub info($self, $cod_inep) {
  my $info = $self->schema->resultset('Escolas')->search_rs({codigo_inep => $cod_inep})
  ->columns($DEFAULT_COLS)->as_hash->first;

  unless ($info) {
    return $self->json->encode({error => "Escola com código $cod_inep não encontrada"});
  }

  return $self->json->encode($info);
}

sub workers($self, $params = {}) {
  my $payroll = $self->schema->resultset('RemuneracaoMunicipal');

  $self->set_params_map(
    params => $params,
    map => {
      cod_inep  => [qw/cod_inep inep/],
      ano       => [qw/year ano/],
      categoria => [qw/category categoria/],
    }
  );

  my $columns = [qw(nome_profissional cpf segmento_ensino situacao carga_horaria ano categoria)];
  my $results = $payroll->search_rs($params)
  ->columns($columns)->distinct->as_hash->get_all;

  unless ($results->size) {
    return $self->json->encode({error => "Profissionais não encontrados", parametros => $params});
  }

  return $self->json->encode($results->to_array);
}

sub search($self, $params = {}) {
  my $school = $self->schema->resultset('Escolas');

  $self->set_params_map(
    params => $params,
    map => {
      escola => [
        [qw(term)],
        sub ($term) {  $self->_sanitize_like_pattern(\$term); +{ -ilike => "%$term%" } }
      ],
      municipio => [
        [qw(cidade)],
        sub ($cidade) { $self->_sanitize_like_pattern(\$cidade); +{-ilike => "$cidade"} }
      ],
      uf => [qw(estado uf)],
    }
  );

  my $results = $school->search_rs($params)->order_by('escola')->columns($DEFAULT_COLS)->as_hash->get_all;
  return $self->json->encode($results->to_array);
}

sub search_all_from($self, $params = {}) {
  my $school = $self->schema->resultset('Escolas');

  $self->set_params_map(
    params => $params,
    map => {
      municipio => [
        [qw(cidade)],
        sub ($cidade) { $self->_sanitize_like_pattern(\$cidade); +{-ilike => "$cidade"} }
      ],
    }
  );

  my $results = $school->search_rs($params)->columns($DEFAULT_COLS)->as_hash->get_all;
  return $self->json->encode($results->to_array);
}

sub search_nearby($self, $params = {}) {
  my $sch = $self->schema->resultset('Escolas');
  my ($max_results, $opts) = (10, $params->{opts} // { max => 5000 });
  my $columns = [@$DEFAULT_COLS, {distancia => \q/ROUND(distancia_metros::numeric,2)/}];

  my $results = $sch->nearest_from($params, $max_results, $opts)
  ->as_subselect_rs->columns($columns)->as_hash->get_all;
  return $self->json->encode($results->to_array);
}

sub cluster_schools($self, $params = {}) {
  $self->set_params_map(
    params => $params,
    map => {
      codigo_ibge => [qw(ibge cidade cod_cidade)],
    }
  );

  my $ids = $self->schema->resultset('MunicipiosSp')
  ->search_rs($params)
  ->search_related_rs('escolas')
  ->columns('codigo_inep')->get_all
  ->map('codigo_inep')->join(',');

  #TODO: no results return error
  my $QUERY =<<~"EOQ";
  WITH lista_escolas AS (
      SELECT unnest(ARRAY[$ids]) AS id_escola -- 👈 PARÂMETRO DINÂMICO
  ),
  school_features AS (
      SELECT 
          i.id_escola,
          i.no_escola,
          i.sg_uf,
          i.no_municipio,
          i.rede,
          
          AVG(i.vl_observado_2007) AS avg_ideb,
          AVG(i.vl_observado_2009) AS avg_ideb_2009,
          AVG(i.vl_observado_2011) AS avg_ideb_2011,
          AVG(i.vl_observado_2013) AS avg_ideb_2013,
          AVG(i.vl_observado_2015) AS avg_ideb_2015,
          AVG(i.vl_observado_2017) AS avg_ideb_2017,
          AVG(i.vl_observado_2019) AS avg_ideb_2019,
          AVG(i.vl_observado_2023) AS avg_ideb_2023,
          
          AVG(i.vl_nota_media_2007) AS avg_media_geral,
          AVG(i.vl_nota_media_2009) AS avg_media_2009,
          AVG(i.vl_nota_media_2011) AS avg_media_2011,
          AVG(i.vl_nota_media_2013) AS avg_media_2013,
          AVG(i.vl_nota_media_2015) AS avg_media_2015,
          AVG(i.vl_nota_media_2017) AS avg_media_2017,
          AVG(i.vl_nota_media_2019) AS avg_media_2019,
          AVG(i.vl_nota_media_2023) AS avg_media_2023,
          
          AVG(i.vl_indicador_rend_2007) AS avg_aprovacao,
          AVG(i.vl_indicador_rend_2009) AS avg_aprovacao_2009,
          AVG(i.vl_indicador_rend_2011) AS avg_aprovacao_2011,
          AVG(i.vl_indicador_rend_2013) AS avg_aprovacao_2013,
          AVG(i.vl_indicador_rend_2015) AS avg_aprovacao_2015,
          AVG(i.vl_indicador_rend_2017) AS avg_aprovacao_2017,
          AVG(i.vl_indicador_rend_2019) AS avg_aprovacao_2019,
          AVG(i.vl_indicador_rend_2023) AS avg_aprovacao_2023,
          
          (COALESCE(i.vl_observado_2023, 0) - COALESCE(i.vl_observado_2007, 0)) AS tendencia_ideb,
          (COALESCE(i.vl_nota_media_2023, 0) - COALESCE(i.vl_nota_media_2007, 0)) AS tendencia_nota,
          (COALESCE(i.vl_indicador_rend_2023, 0) - COALESCE(i.vl_indicador_rend_2007, 0)) AS tendencia_aprovacao
          
      FROM clean.inep i
      INNER JOIN lista_escolas l ON i.id_escola = l.id_escola
      WHERE i.vl_observado_2023 IS NOT NULL 
        AND i.vl_nota_media_2023 IS NOT NULL
      GROUP BY i.id_escola, i.no_escola, i.sg_uf, i.no_municipio, i.rede,
               i.vl_observado_2023, i.vl_observado_2007,
               i.vl_nota_media_2023, i.vl_nota_media_2007,
               i.vl_indicador_rend_2023, i.vl_indicador_rend_2007
  ),
  -- Normalização dos dados (escala 0-1) - AGORA DENTRO DO SUBCONJUNTO
  normalized_features AS (
      SELECT 
          *,
          -- Normalizar IDEB (dentro do conjunto selecionado)
          (avg_ideb_2023 - MIN(avg_ideb_2023) OVER()) / 
          NULLIF(MAX(avg_ideb_2023) OVER() - MIN(avg_ideb_2023) OVER(), 0) AS norm_ideb,
          
          -- Normalizar Notas (dentro do conjunto selecionado)
          (avg_media_2023 - MIN(avg_media_2023) OVER()) / 
          NULLIF(MAX(avg_media_2023) OVER() - MIN(avg_media_2023) OVER(), 0) AS norm_nota,
          
          -- Normalizar Aprovação (dentro do conjunto selecionado)
          (avg_aprovacao_2023 - MIN(avg_aprovacao_2023) OVER()) / 
          NULLIF(MAX(avg_aprovacao_2023) OVER() - MIN(avg_aprovacao_2023) OVER(), 0) AS norm_aprovacao,
          
          -- Normalizar Tendência (dentro do conjunto selecionado)
          (tendencia_ideb - MIN(tendencia_ideb) OVER()) / 
          NULLIF(MAX(tendencia_ideb) OVER() - MIN(tendencia_ideb) OVER(), 0) AS norm_tendencia
          
      FROM school_features
  ),
  -- K-Means manual (usando aproximação por percentis dentro do conjunto)
  clusters AS (
      SELECT 
          *,
          CASE 
              -- Cluster 1: Alto desempenho (top 25% do conjunto)
              WHEN norm_ideb >= 0.75 AND norm_nota >= 0.7 THEN 1
              
              -- Cluster 2: Médio-alto desempenho (50-75%)
              WHEN norm_ideb >= 0.5 AND norm_ideb < 0.75 
               AND norm_nota >= 0.5 THEN 2
               
              -- Cluster 3: Médio-baixo desempenho (25-50%)
              WHEN norm_ideb >= 0.25 AND norm_ideb < 0.5 
               AND norm_nota >= 0.25 THEN 3
               
              -- Cluster 4: Baixo desempenho (bottom 25%)
              WHEN norm_ideb < 0.25 OR norm_nota < 0.25 THEN 4
              
              -- Cluster 5: Em declínio (tendência negativa)
              WHEN norm_tendencia < 0.3 AND tendencia_ideb < 0 THEN 5
              
              -- Cluster 6: Em ascensão (tendência positiva forte)
              WHEN norm_tendencia > 0.7 AND tendencia_ideb > 0.5 THEN 6
              
              ELSE 3
          END AS cluster_id
      FROM normalized_features
  )
  -- Resultado final
  SELECT 
      cluster_id,
      COUNT(*) AS total_escolas,
      ROUND(AVG(avg_ideb_2023), 2) AS media_ideb,
      ROUND(AVG(avg_media_2023), 2) AS media_notas,
      ROUND(AVG(avg_aprovacao_2023) * 100, 1) AS media_aprovacao_percent,
      ROUND(AVG(tendencia_ideb), 2) AS tendencia_media,
      
      -- Distribuição por rede
      COUNT(CASE WHEN rede = 'Municipal' THEN 1 END) AS rede_municipal,
      COUNT(CASE WHEN rede = 'Estadual' THEN 1 END) AS rede_estadual,
      COUNT(CASE WHEN rede = 'Federal' THEN 1 END) AS rede_federal,
      COUNT(CASE WHEN rede = 'Privada' THEN 1 END) AS rede_privada,
      
      -- Lista completa das escolas do cluster
      json_agg(
          json_build_object(
              'escola', no_escola,
              'municipio', no_municipio,
              'latitude', e.latitude,
              'longitude', e.longitude,
              'uf', sg_uf,
              'rede', e.dependencia_administrativa,
              'id_escola', id_escola,
              'ideb', ROUND(avg_ideb_2023, 2),
              'nota', ROUND(avg_media_2023, 2),
              'aprovacao', ROUND(avg_aprovacao_2023 * 100, 1),
              'tendencia', ROUND(tendencia_ideb, 2),
              'cluster_id', cluster_id
          )
          ORDER BY avg_ideb_2023 DESC
      ) AS escolas
  FROM clusters c1 JOIN clean.escolas e ON c1.id_escola = e.codigo_inep
  GROUP BY cluster_id
  ORDER BY cluster_id
  EOQ

  my $columns = [
    qw(
      cluster_id total_escolas media_ideb media_notas media_aprovacao_percent 
      tendencia_media rede_municipal rede_estadual rede_federal rede_federal
      escolas
    )
  ];

  my $results = $self->schema->resultset('Escolas')->custom_query($QUERY, $columns)
  ->columns($columns)->as_hash->get_all->each(
    sub ($r, $idx) {
      my $raw = $r->{escolas};
      $r->{escolas} = $self->json->decode(Encode::encode('UTF-8', Encode::decode('ISO-8859-1', $raw)) );
    }
  );

  return $self->json->encode($results->to_array);
}

sub gis_cover($self, $params = {}) {
  my $rs = $self->schema->resultset('Escolas');

  $self->set_params_map(
    params => $params,
    map => {
      codigo_inep => [qw(inep codigo_inep)],
      radius => [qw(radius raio)],
    }
  );

  my $properties = [qw/escola codigo_inep dependencia_administrativa raio_km/]; # properties
  my $radius = $params->{radius} || 5; # cover radius
  my $cover = qq<ST_Transform(
    ST_SetSRID(ST_Buffer(geography(geometry), $radius*1000)::geometry, 4674 ), 4326
  )>; # cover area

  return $self->json->encode( 
    {error => "raio ($radius) demasiado grande, máximo 10 km"}
  ) if $radius > 10;

  my $results = $rs->search_rs( { codigo_inep => $params->{codigo_inep} } )
  ->add_derived(cobertura => $cover, raio_km => $radius )
  ->as_subselect_rs->geojson_features('cobertura', $properties)
  ->as_hash->first;

  return $results->{feature};
}

1;

################################################################################
# DOCUMENTATION
################################################################################
__END__

=pod

=encoding UTF-8

=head1 NAME

EduMaps::Model::School - School data model for the EduMaps educational mapping system

=head1 SYNOPSIS

  use EduMaps::Model::School;
  
  my $school_model = EduMaps::Model::School->new;
  
  # Get complete school payroll for March 2025
  my $payroll = $school_model->payroll(11000040, DateTime->new(year => 2025, month => 3));
  
  # Parse and use the data
  my $data = decode_json($payroll);
  print "School: " . $data->{escola}{escola} . "\n";
  print "Total teachers: " . $data->{resumo_categoria}[0]{profissionais} . "\n";

=head1 DESCRIPTION

This module provides comprehensive school data management functionality for the EduMaps platform, including payroll processing, school information retrieval, and statistical analysis of educational institutions and their personnel.

=head1 AUTHOR

EduMaps Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 EduMaps. All rights reserved.

This software is part of the EduMaps educational mapping platform.

=cut
