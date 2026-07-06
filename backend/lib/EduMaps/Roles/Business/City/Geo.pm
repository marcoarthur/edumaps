package EduMaps::Roles::Business::City::Geo;
use Mojo::Base -role, -signatures;

sub search_in_bbox($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');

  $self->set_params_map(
    params => $params,
    map => {
      bbox => [qw/bbox/],
      limit => [qw/limit/],
      zoom => [qw/zoom/],
    },
  );

  my $query = sprintf q<SELECT get_cities_markers('%s',%d,%d) AS markers>, $params->{bbox}, $params->{zoom}, $params->{limit};
  my $results = $rs->custom_query($query, ['markers'])->as_hash->first;
  return $results->{markers};
}

sub search_analytic($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');

  my @fields = qw(
    total_escolas escolas_publicas escolas_privadas escolas_urbanas escolas_rurais
    total_alunos alunos_infantil alunos_fundamental alunos_medio alunos_eja
    total_docentes perc_docentes_superior perc_docentes_concursados score_infra_medio
    score_tecnologia_medio score_acessibilidade_medio score_gestao_medio
    ideb_fund_i ideb_fund_ii ideb_medio ano_ideb populacao_estimada
  );
  my $properties = [
    'nome_municipio',
    'nome_regiao',
    'sigla_estado',
    'codigo_ibge',
    map { "analise.$_"} @fields
  ];

  my $results = $self->_search_unaccent($params->{term})
  ->limit($params->{limit} // 10)
  ->join('analise')
  ->geojson_features('geometry', $properties)
  ->as_hash->first;

  return $results->{feature};
}

1;
