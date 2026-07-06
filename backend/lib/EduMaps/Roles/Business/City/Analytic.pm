package EduMaps::Roles::Business::City::Analytic;
use Mojo::Base -role, -signatures;

requires qw(schema);

sub analytic_details($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');

  my $results = $rs->search_rs({ codigo_ibge => $params->{codigo_ibge} })
  ->search_related_rs('analise')
  ->as_hash->first;

  return $results;
}

sub similar_cities($self, $args = {}) {
  my $rs = $self->schema->resultset('MunicipioSimilaridade');
  my $search = {
    municipio_1 => substr($args->{codigo_ibge},0,6),
    $args->{similarity} ? (similaridade => {'>=' => $args->{similarity}}) : (),
  };

  my $ids = $rs->search_rs($search)
  ->alias('sim')
  ->limit($args->{limit})
  ->order_by({-desc => ['similaridade']});

  my $sim = $ids->as_hash->get_all;

  return $self->schema->resultset('MunicipiosSp')->search_rs(
    { codigo_ibge_antigo => { -in => $ids->get_column('municipio_2')->as_query } },
  )->exclude_columns(['geometry'])->as_hash->get_all->each(
    sub($x,$idx) {
      my $d = $sim->first( sub ($ele) { $ele->{municipio_2} == $x->{codigo_ibge_antigo} } );
      $x->{similaridade} = $d->{similaridade};
      $x->{distancia_euclidiana} = $d->{distancia_euclidiana};
    }
  );
}

1;
