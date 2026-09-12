package EduMaps::Roles::Business::SchoolNetwork::Geo;
use Mojo::Base -role, -signatures;
use Carp qw(croak);
use Encode qw(encode);

requires qw(schema);

our %REDE_NOMES = (
  federal   => 'Federal',
  estadual  => 'Estadual',
  municipal => 'Municipal',
  privada   => 'Privada',
);

=head2 markers($params)

GeoJSON (FeatureCollection) com as geometrias das escolas de uma rede em um município.

=head3 Parameters

=over 4

=item * C<codigo_ibge> (String) - Código IBGE do município (7 dígitos)

=item * C<rede> (String, optional) - Tipo de administração
(federal|estadual|municipal|privada)

=back

=head3 Returns

=over 4

=item * (String) - GeoJSON FeatureCollection com as escolas da rede

=back

=cut

sub markers($self, $params = {}) {
  my $rs = $self->schema->resultset('Escolas');

  croak "Need codigo_ibge" unless $params->{codigo_ibge};

  my $search = { 'municipio.codigo_ibge' => $params->{codigo_ibge} };
  if (my $rede = $params->{rede}) {
    my $nome = $REDE_NOMES{lc $rede} or croak "Rede inválida: $rede";
    $search->{'dependencia_administrativa'} = $nome;
  }

  my $feature = $rs->search_rs($search, { join => 'municipio' })
  ->not_null('me.geometry')
  ->geojson_features(
    'me.geometry',
    {
      escola => 'me.escola',
      codigo_inep => 'me.codigo_inep',
      dependencia_administrativa => 'me.dependencia_administrativa',
      municipio => 'me.municipio',
    },
  )->as_hash->first;

  return encode('UTF-8', $feature->{feature});
}

1;