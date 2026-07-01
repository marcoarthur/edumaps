package EduMaps::Roles::Business::School::Geo;
use Mojo::Base -role, -signatures;

sub search_nearby($self, $params = {}) {
  my $rs = $self->schema->resultset('Escolas');
  my ($limit, $opts) = ($params->{limit}, {max => 1000*$params->{distance}});
  my $columns = [
    $self->default_columns->@*,
    {distancia => \q/ROUND(distancia_metros::numeric,2)/}
  ];
  my $position = {lat => $params->{latitude}, lon => $params->{longitude}};

 return $rs->nearest_from($position, $limit, $opts)
  ->as_subselect_rs->columns($columns)->as_hash->get_all;
}

1;
