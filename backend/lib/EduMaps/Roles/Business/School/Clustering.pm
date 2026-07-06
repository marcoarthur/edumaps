package EduMaps::Roles::Business::School::Clustering;
use Mojo::Base -role, -signatures;
use DateTime;
use Carp qw(croak);

requires qw(schema);

sub simple_cluster_school($self, $params = {}) {
  my $v = $self->validation;
  $v->input($params);
  $v->required('codigo_ibge','trim')->like(qr/^\d{7}$/);

  croak "Invalid or missing code for city" if $v->has_error;

  my $ids = $self->schema->resultset('MunicipiosSp')
  ->search_rs($params)
  ->search_related_rs('censo_escolas')
  ->columns('co_entidade')->get_all;

  # not found
  return if $ids->size == 0;

  my $id_list = $ids->map('co_entidade')->join(',');

  my $QUERY =<<~"EOQ";
  WITH lista_escolas AS (
      SELECT unnest(ARRAY[$id_list]) AS id_escola
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

  my $results = $self->schema->resultset('Escolas')
  ->custom_query($QUERY, $columns)
  ->columns($columns)->as_hash->get_all->each(
    sub ($ele, $idx){
      eval {
        # Remove utf8 because the database already set it for us
        $ele->{escolas} = $self->json->utf8(0)->decode($ele->{escolas});
      };
      if ($@) {
        # Should not be here, in any case: dies
        warn "Error: couldn't decode the json from database: $@\n";
        warn $ele->{escolas};
        die "Critical error";
      }
    }
  );

  return $results;
}

1;

__END__

=encoding UTF-8

=head1 NAME

EduMaps::Roles::Business::School::Clustering - Agrupamento de escolas por desempenho

=head1 DESCRIPTION

Agrupa escolas de um município em clusters baseados em IDEB, notas SAEB, aprovação e tendência temporal. Utiliza normalização intra-município e classificação por percentis.

=head2 simple_cluster_school

    $clusters = $model->simple_cluster_school({ codigo_ibge => '3550308' });

Parâmetro obrigatório: C<codigo_ibge> (7 dígitos).

Retorna array de clusters com:

=over 4

=item * C<cluster_id> (1-6): 1-Alto, 2-Médio-alto, 3-Médio-baixo, 4-Baixo, 5-Declínio, 6-Ascensão

=item * C<total_escolas>, C<media_ideb>, C<media_notas>, C<media_aprovacao_percent>, C<tendencia_media>

=item * C<rede_municipal|estadual|federal|privada> - contagem por rede

=item * C<escolas> - array JSON com detalhes de cada escola

=back

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
