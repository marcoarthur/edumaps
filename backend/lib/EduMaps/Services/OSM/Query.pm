package EduMaps::Services::OSM::Query;

use Mojo::Base -base, -signatures;
use Digest::SHA qw(sha1_hex);
use Mojo::Log;
use utf8;

=head1 NAME

EduMaps::Services::OSM::Query - Descreve uma consulta ao Overpass (OSM)

=head1 DESCRIPTION

Objeto de valor que descreve UMA consulta ao Overpass API de forma
generalizada e gera o Overpass QL correspondente (antes o QL era hardcoded
na Task). Suporta dois alvos:

  * C<around> - buffer de um ponto: C<{ type =E<gt> 'around', lat, lon, raio }>
    (raio em metros, 100..10000 = 0.1..10 km)
  * C<poly>   - polígono GeoJSON: C<{ type =E<gt> 'poly', geometry =E<gt> {...} }>

Os filtros vêm de C<filters> (lista de C<{ key, value? }>) e/ou de C<profiles>
(nomes do catálogo curado L</PROFILES>). Sem filtros nem perfis, usa o perfil
default C<equipamentos_publicos>.

=cut

# Catálogo curado de equipamentos públicos: perfil -> lista de filtros.
# value ausente = qualquer valor da chave.
our %PROFILES = (
  transporte => [
    { key => 'highway',          value => 'bus_stop' },
    { key => 'public_transport', value => 'platform' },
    { key => 'public_transport', value => 'station' },
    { key => 'railway',          value => 'station' },
    { key => 'railway',          value => 'halt' },
    { key => 'railway',          value => 'tram_stop' },
    { key => 'railway',          value => 'subway_entrance' },
    { key => 'amenity',          value => 'bus_station' },
    { key => 'amenity',          value => 'ferry_terminal' },
    { key => 'aeroway',          value => 'aerodrome' },
  ],
  saude => [
    { key => 'amenity',    value => 'hospital' },
    { key => 'amenity',    value => 'clinic' },
    { key => 'amenity',    value => 'doctors' },
    { key => 'amenity',    value => 'dentist' },
    { key => 'amenity',    value => 'pharmacy' },
    { key => 'healthcare' },
  ],
  educacao => [
    { key => 'amenity', value => 'school' },
    { key => 'amenity', value => 'college' },
    { key => 'amenity', value => 'university' },
    { key => 'amenity', value => 'kindergarten' },
    { key => 'amenity', value => 'library' },
  ],
  assistencia => [
    { key => 'amenity', value => 'social_facility' },
    { key => 'amenity', value => 'community_centre' },
    { key => 'amenity', value => 'nursing_home' },
  ],
  cultura_lazer => [
    { key => 'leisure', value => 'park' },
    { key => 'leisure', value => 'playground' },
    { key => 'leisure', value => 'sports_centre' },
    { key => 'leisure', value => 'pitch' },
    { key => 'amenity', value => 'theatre' },
    { key => 'amenity', value => 'cinema' },
    { key => 'amenity', value => 'arts_centre' },
    { key => 'amenity', value => 'library' },
    { key => 'amenity', value => 'museum' },
  ],
  seguranca => [
    { key => 'amenity', value => 'police' },
    { key => 'amenity', value => 'fire_station' },
  ],
  administracao => [
    { key => 'amenity', value => 'townhall' },
    { key => 'amenity', value => 'courthouse' },
    { key => 'amenity', value => 'post_office' },
    { key => 'office',  value => 'government' },
  ],
);

has target  => sub { die 'Need target ({ type => around|poly, ... })' };
has filters => sub { [] };
has profiles => sub { [] };
has timeout => sub { 60 };
has log     => sub { Mojo::Log->new };

our $DEFAULT_PROFILE = 'equipamentos_publicos';
our ($MIN_RADIUS, $MAX_RADIUS) = (100, 10_000);

sub new($class, %args) {
  my $profile = delete $args{profile};
  my $self = $class->SUPER::new(%args);

  # Aceita também o nome de um único perfil em `profile` (atalho).
  $self->profiles([$profile]) if defined $profile;

  if (!@{ $self->filters } && !@{ $self->profiles }) {
    $self->profiles([$DEFAULT_PROFILE]);
  }

  $self->_validate_target;
  $self->_validate_filters( $self->expanded_filters );
  return $self;
}

# Nomes de perfis disponíveis (inclui o default agregador).
sub available_profiles($class) {
  return sort keys %PROFILES;
}

# Filtros de um perfil (o default agrega todos).
sub profile_filters($class, $name) {
  return undef unless defined $name;

  if ($name eq $DEFAULT_PROFILE) {
    my %seen;
    my @all;
    for my $key (sort keys %PROFILES) {
      for my $f (@{ $PROFILES{$key} }) {
        my $sig = $f->{key} . '=' . ($f->{value} // '');
        push @all, $f unless $seen{$sig}++;
      }
    }
    return \@all;
  }

  die "Perfil OSM desconhecido: $name" unless exists $PROFILES{$name};
  return $PROFILES{$name};
}

# Filtros efetivos = profiles expandidos + filters explícitos (dedup).
sub expanded_filters($self) {
  my %seen;
  my @out;

  for my $name (@{ $self->profiles }) {
    for my $f (@{ $self->profile_filters($name) }) {
      my $sig = $f->{key} . '=' . ($f->{value} // '');
      push @out, $f unless $seen{$sig}++;
    }
  }
  for my $f (@{ $self->filters }) {
    my $sig = $f->{key} . '=' . ($f->{value} // '');
    push @out, $f unless $seen{$sig}++;
  }

  return \@out;
}

sub _validate_target($self) {
  my $t = $self->target;
  my $type = $t->{type} // '';

  if ($type eq 'around') {
    for my $k (qw(lat lon raio)) {
      die "Need target->{$k} for around" unless defined $t->{$k};
    }
    die "lat fora de [-90,90]" unless $t->{lat} >= -90 && $t->{lat} <= 90;
    die "lon fora de [-180,180]" unless $t->{lon} >= -180 && $t->{lon} <= 180;
    my $r = $t->{raio};
    die "raio ($r m) fora do intervalo [$MIN_RADIUS, $MAX_RADIUS]"
      unless $r >= $MIN_RADIUS && $r <= $MAX_RADIUS;
  }
  elsif ($type eq 'poly') {
    die "Need target->{geometry} for poly" unless ref $t->{geometry} eq 'HASH';
  }
  else {
    die "Tipo de alvo OSM desconhecido: '$type' (use around|poly)";
  }
}

sub _validate_filters($self, $filters) {
  for my $f (@$filters) {
    my $key = $f->{key} // '';
    die "Filtro OSM sem 'key'" unless length $key;
    die "Chave OSM inválida: '$key'" unless $key =~ /\A[A-Za-z0-9_:.-]+\z/;
    if (defined $f->{value}) {
      my $v = $f->{value};
      die "Valor OSM inválido: '$v'" unless $v =~ /\A[A-Za-z0-9_:.-]+\z/;
    }
  }
}

# Uma cláusula Overpass para um filtro, dado o sufixo de localização.
sub _clause($self, $f, $loc) {
  my $key = $f->{key};
  my $tag = defined $f->{value}
    ? qq{"$key"="$f->{value}"}
    : qq{"$key"};
  return qq{nwr[$tag]($loc)};
}

# Lista de strings de localização: uma por anel (poly) ou uma só (around).
sub _locations($self) {
  my $t = $self->target;

  if (($t->{type} // '') eq 'around') {
    return (sprintf 'around:%d,%s,%s', $t->{raio}, $t->{lat}, $t->{lon});
  }

  my @rings = _poly_rings($t->{geometry});
  die 'Polígono OSM sem anéis' unless @rings;
  return map { qq{poly:"$_"} } @rings;
}

# Extrai anéis (outer) de um GeoJSON Polygon/MultiPolygon como
# "lat lon lat lon ..." (Overpass usa lat/lon e fecha o anel).
sub _poly_rings($geometry) {
  my $type = $geometry->{type} // '';
  my $coords = $geometry->{coordinates} // [];

  my @polys = $type eq 'Polygon' ? ($coords) : @$coords;

  my @rings;
  for my $poly (@polys) {
    my $ring = $poly->[0] // [];
    next unless @$ring > 2;
    push @rings, join(' ', map { sprintf '%.6f %.6f', $_->[1], $_->[0] } @$ring);
  }
  return @rings;
}

sub to_ql($self) {
  my $t = $self->timeout;
  my @loc = $self->_locations;
  my @filters = @{ $self->expanded_filters };

  die 'Consulta OSM sem filtros' unless @filters;

  my @clauses;
  for my $loc (@loc) {
    push @clauses, map { $self->_clause($_, $loc) } @filters;
  }

  my $body = join(";\n  ", @clauses);
  return <<~"QUERY";
  [out:json][timeout:$t];
  (
    $body;
  );
  out body;
  >;
  out skel qt;
  QUERY
}

sub digest($self) {
  return sha1_hex( $self->to_ql );
}

# Dado um hash de tags OSM, devolve (key, value, category) do primeiro filtro
# que casa — usado para classificar a feature persistida.
sub classify($self, $tags) {
  $tags //= {};

  for my $f (@{ $self->expanded_filters }) {
    my $key = $f->{key};
    next unless exists $tags->{$key};
    if (defined $f->{value}) {
      next unless defined $tags->{$key} && $tags->{$key} eq $f->{value};
      return ($key, $f->{value}, "$key=$f->{value}");
    }
    return ($key, $tags->{$key}, "$key=$tags->{$key}");
  }

  return (undef, undef, undef);
}

1;
