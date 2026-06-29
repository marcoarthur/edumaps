package EduMaps::Roles::Business::City::Analytic;
use Mojo::Base -role, -signatures;

requires qw(schema);

sub analytic_details($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');

  $self->set_params_map(
    params => $params,
    map => {
      codigo_ibge => [qw/codigo_ibge/],
    },
  );

  my $results = $rs->search_rs({ codigo_ibge => $params->{codigo_ibge} })
  ->search_related_rs('analise')
  ->as_hash->first;

  return $results;
}

1;
