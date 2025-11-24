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

=item * L<EduMaps::Schema::Result::Escolas> - Results ordered by distance, limited to $n nearest features within max distance

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

sub as_text($self, $col = undef ) {
  die "Need column name" unless $col;
  my $me = $self->current_source_alias;
  return $self->search_rs(
    {},
    {
      columns => [
        { codigo => \"${me}.${col}::text" },
      ]
    }
  )->get_column('codigo');
}

=pod

=encoding UTF-8

=head2 with_acessibility_radius_geom($radius = 5000)

Creates geometry (area_de_atendimento) around school with given radius.

=cut

=head3 Parameters

=over 4

=item * C<$radius> (Integer) - Buffer radius

Default: 5000

=back

=head3 Returns

=over 4

=item * L<EduMaps::Schema::Result::Escolas> - ResultSet with additional geometry column:

- area_de_atendimento: Geometry centered in school covering the circle given by radius 

=back

=head3 Example

  # Buscar escolas com área de atendimento de 2km
  my $escolas_com_area = $rs->with_acessibility_radius_geom(2000);

  while (my $escola = $escolas_com_area->next) {
    my $area_cobertura = $escola->get_column('area_de_atendimento');
    say "Área de atendimento: " . $area_cobertura->as_text;
  }

  # Usar com outras condições
  my $filtrado = $rs->search(
    { tipo => 'publica' }
  )->with_acessibility_radius_geom(3000);

=cut

sub with_acessibility_radius_geom($self, $radius = 5000) {
  my $me = $self->current_source_alias;
  my $st_buffer = "ST_Buffer($me.geometry::geography, $radius)::geometry";

  $self->search_rs(
    undef,
    {
      '+select' => [ {'' => \$st_buffer, -as => 'area_de_atendimento'} ],
      '+as'     => ['area_de_atendimento'],
    }
  );
}

=head2 expand_modalidades

Expands the C<etapas_modalidades> column into boolean columns indicating
the presence of each educational modality.

=cut

=head3 Description

For each modality — Early Childhood Education, Elementary Education,
High School, and Professional Education — this method adds a derived
(0/1) column to the resultset based on a C<CASE WHEN ... LIKE> expression.

=head3 Returns

=over 4

=item * L<EduMaps::Schema::Result::Escolas> — A new resultset with the following
additional columns:

  - tem_infantil
  - tem_fundamental
  - tem_medio
  - tem_profissional

Each column contains 1 if the modality appears in C<etapas_modalidades>,
otherwise 0.

=back

=head3 Example

  my $rs = $schema->resultset('Escola')->expand_modalidades;

  while (my $row = $rs->next) {
    say $row->nome, " infant? ", $row->get_column('tem_infantil');
  }

=cut

sub expand_modalidades($self) {
  my %cases = (
    tem_eja =>
    \q{CASE WHEN etapas_modalidades LIKE '%Educação de Jovens Adultos%' THEN 1 ELSE 0 END},
    tem_infantil =>
    \q{CASE WHEN etapas_modalidades LIKE '%Educação Infantil%' THEN 1 ELSE 0 END},
    tem_fundamental =>
    \q{CASE WHEN etapas_modalidades LIKE '%Ensino Fundamental%' THEN 1 ELSE 0 END},
    tem_medio =>
    \q{CASE WHEN etapas_modalidades LIKE '%Ensino Médio%' THEN 1 ELSE 0 END},
    tem_profissional =>
    \q{CASE WHEN etapas_modalidades LIKE '%Educação Profissional%' THEN 1 ELSE 0 END},
  );

  my @as = keys %cases;
  my @selects = map { 
    { 
      '' => $cases{$_},
      -as => $_,
    }
  } @as; 

  $self->search_rs(
    undef,
    {
      '+select' => [@selects],
      '+as' => [@as],
    }
  );
}

1;
