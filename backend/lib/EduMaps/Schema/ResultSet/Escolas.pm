package EduMaps::Schema::ResultSet::Escolas;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;
use DateTime;
use utf8;

sub with_geojson($self) {

  $self->search_rs(
    undef,
    {
      '+select' => [{ST_AsGeoJSON => 'geometry', -as => 'coordenadas'}],
      '+as'     => [qw/coordenadas/],
    }
  );
}

sub find_by_city_id($self, $id) {
  $self->search_rs(
    { 'municipio.codigo_ibge' => $id },
    {
      join => [ 'municipio' ],
    }
  )->geojson_features(
    'me.geometry',
    [ qw(endereco escola municipio categoria_administrativa telefone etapas_modalidades codigo_inep) ],
  );
}

sub find_by_city_name($self, $name) {
  $self->search_rs({municipio => $name})
  ->geojson_features(
    'me.geometry',
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

=pod

=head2 payroll_by_city($city_name, $date = DateTime->now(locale => 'pt'))

Returns payroll summary by school for a specific city.

=cut

=head3 Parameters

=over 4

=item * C<$city_name> (String or SubQuery) - City name to filter schools

=item * C<$date> (DateTime) - Date object for month/year filtering

Default: Current date with Portuguese locale

=back

=head3 Returns

=over 4

=item * L<EduMaps::Schema::ResultSet> - ResultSet with aggregated payroll data grouped by school:

=over 8

=item * escola - School name

=item * mes - Month name in Portuguese (capitalized)

=item * ano - Year

=item * total_professores - Count of professionals

=item * total_salarios - Sum of total salaries

=back

=back

=head3 Example

  # Get payroll for current month
  my $payroll_rs = $rs->payroll_by_city('São Paulo');
  
  while (my $row = $payroll_rs->next) {
    say "School: " . $row->escola;
    say "Period: " . $row->mes . "/" . $row->ano;
    say "Teachers: " . $row->total_professores;
    say "Total salary: R$ " . $row->total_salarios;
  }
  
  # With specific date
  use DateTime;
  my $date = DateTime->new(year => 2025, month => 5, locale => 'pt');
  my $may_payroll = $rs->payroll_by_city('Rio de Janeiro', $date);

=cut

sub payroll_by_city($self, $city_name, $date = DateTime->now( locale => 'pt')) {

  # if we have a query for city id use it, otherwise assume a simple string
  my $params = {
    municipio => ref $city_name ? { -in => $city_name } : $city_name,
  };
  # parameters for payroll
  my $params_folha = {
    # since we don't have 2026 yet we should assume 2025 if 2026
    ano => do { 
      $date->year == 2026 ? 2025 : $date->year
    },
    # since 2025 has incomplete data, if we have this year we set month manually
    mes => (
      $date->year == 2025 && $date->month > 6 ? 'Junho' : ucfirst($date->month_name)
    ),
  };

  $self->search_rs($params)
  ->search_related(
    'folha_pagamentos', 
    $params_folha,
    { 
      columns => [
        { total_professores => { count  => 'nome_profissional' }},
        { total_salarios    => { sum    => 'salario_total' } },
        qw(escola mes ano),
      ],
      group_by => [ qw(folha_pagamentos.escola mes ano) ],
    },
  );
}

sub count_by_size($self, $city) {
  $self->search_rs(
    { municipio => $city, porte_escola => { '<>' => q/''/} },
    {
      columns => [
        'porte_escola',
        { total_por_porte => { count => '*' } },
        { ids_escola => { string_agg => [\'codigo_inep::text', \"','"]} },
      ],
      group_by  => [ qw(municipio porte_escola) ],
    }
  );
}

sub add_osm_url($self) {
  $self->add_derived(
    osm_url => q<
      FORMAT(
        'https://www.openstreetmap.org/search?query=%s%%2C%s',
        REPLACE(ROUND(latitude::numeric, 6)::text, ',', '.'),
        REPLACE(ROUND(longitude::numeric, 6)::text, ',', '.')
      )
    >
  );
}

sub reduce_convex_hull_by($self, %opts) {
  my $me = $self->current_source_alias;
  my $group_cols = $opts{group_by} or die "group_by is mandatory";

  # pairs: json_attr_name : value
  my $properties = join(
    ",\n",
    map { 
      my ($table, $col) = $self->separate_fqn($_);
      sprintf q/'%s', %s/, $col, defined $table ? "$table.$col" : "$me.$col";
    } @$group_cols
  );
  my $props_sql = \qq{
    jsonb_build_object( 
      $properties,
      'total_escolas', COUNT(*),
      'hull_area_km2', ROUND(CAST(ST_Area(ST_Transform(ST_ConvexHull(ST_Collect($me.geometry)), 5880)) / 1000000 AS numeric), 3)
    )
  };

  $self->select_derived(
    geojson => {
      jsonb_build_object => [
        qw/'type' 'FeatureCollection' 'features'/,
        {
          jsonb_build_array => {
            jsonb_build_object => [
              qw/'type' 'Feature' 'geometry'/,
              \"ST_AsGeoJSON(ST_ConvexHull(ST_Collect($me.geometry)))::jsonb",
              "'properties'",
              $props_sql,
            ]
          }
        }
      ]
    }
  )->group_by( $group_cols );
}

sub reduce_centroid($self, %opts) {
  my $me = $self->current_source_alias;
  my $centroid = $opts{as} // 'centroid';
  $self->select_derived(
    $centroid => "ST_SetSRID(ST_Centroid(ST_Collect($me.geometry)), 4674)" 
  );
}

1;
