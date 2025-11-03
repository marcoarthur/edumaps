package EduMaps::Schema::ResultSet::Escolas;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

sub with_geojson($self) {

  $self->search_rs(
    undef,
    {
      '+select' => [{ST_AsGeoJSON => 'geometry', -as => 'coordenadas'}],
      '+as'     => [qw/coordenadas/],
    }
  );
}

sub find_by_city_name($self, $name) {
  $self->search_rs({municipio => $name})
  ->geojson_features(
    'geometry',
    [ qw(endereco escola municipio categoria_administrativa telefone) ]
  );
}

=head2 nearest_from($point, $n = 5, $opts = {})

Find the nearest C<$n> schools to a reference C<$point>.

=cut

=head3 Parameters

=over 4

=item * C<$point> (HashRef) - Reference point coordinates

Required keys:
  - lon: Longitude
  - lat: Latitude

=item * C<$n> (Integer) - Number of results to return

Default: 5

=item * C<$opts> (HashRef) - Options

Available options:
  - srid: Spatial reference ID (default: 4674)
  - max: Maximum search distance in meters (default: 5000)

=back

=head3 Returns

=over 4

=item * L<DBIx::Class::ResultSet::Escola> - Results ordered by distance, limited to $n nearest features within max distance

=back

=head3 Example

  my $nearest = $rs->nearest_from(
    { lon => -46.6333, lat => -23.5505 },
    10,
    { max => 2000 }
  );

  while (my $row = $nearest->next) {
    say $row->escola . ": " . $row->get_column('distancia_metros') . " meters";
  }

=cut

sub nearest_from($self, $point, $n = 5, $opts = {}) {
  my $me        = $self->current_source_alias;
  $opts->{srid} //= 4674;
  $opts->{max}  //= 5000;

  # set the reference point
  my $ref_point = qq/ST_SetSRID(ST_MakePoint($point->{lon}, $point->{lat}), $opts->{srid})::geography/;
  # knn bounding-box distance operator of school and the fixed ref point
  my $knn_dist = qq/${me}.geometry::geography <-> $ref_point/;
  $self->search_rs(
    undef,
    {
      '+select' => [ 
        { 
          ST_Distance => 
          [
            \'geometry::geography',
            \$ref_point,
          ],
          -as => 'distancia_metros'
        }
      ],
      '+as'     => [ 'distancia_metros' ],
      rows      => $n,
      order_by  => [\$knn_dist],
      where     => \[qq/ST_DWithin(${me}.geometry::geography, $ref_point, $opts->{max})/]
    }
  );
}

1;
