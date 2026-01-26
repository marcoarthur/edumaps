package EduMaps::OSM::Service;
use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;
use Mojo::JSON qw(decode_json encode_json);
use List::Util qw(first);
use Mojo::URL;
use Mojo::Log;
use Mojo::File qw(path);
use Mojo::UserAgent;
use Time::HiRes qw(gettimeofday tv_interval);
use Mojo::Template;

has log           => sub { Mojo::Log->new };
has polygon       => sub { die 'Need a polygon' };
has timeout       => sub { 3*60 };
has query         => sub ($self) { $self->_build_query };
has _overpass_url => sub {
  state $url = Mojo::URL->new('https://overpass-api.de/api/interpreter');
};
has _ua           => sub ($self) { Mojo::UserAgent->new->connect_timeout($self->timeout) };
has _osm_raw      => sub { die 'require run_query() first' };
has _osm_geojson  => sub { die 'require run_query() first' };

# how many decimal points in coordinates
has _precision    => sub { 6 };
has _tmpl         => sub { Mojo::Template->new };


# for OFFLINE testing only
has _testing_data => sub {
  require Mojo::JSON;
  my $raw = Mojo::JSON::decode_json(path('t', 'raw_osm.json')->slurp);
  return Mojo::Promise->resolve($raw);
};

has _testing => sub { 0 };

sub _poly_string($self) {
  my @coords;
  my $digits = $self->_precision;
  my $format = "%.${digits}f %.${digits}f";
  for my $poly ($self->polygon->{coordinates}->@*) {
    my $ring = $poly->[0];
    push @coords, map { sprintf($format, $_->[1], $_->[0]) } @$ring;
  }
  return join(' ', @coords);
}

sub _build_query($self) {
  my $poly_str = $self->_poly_string;
  my $tout = $self->timeout;
  return <<~"QUERY";
  [out:json][timeout:$tout];
  (
    way["landuse"](poly:"$poly_str");
    way["natural"](poly:"$poly_str");
    way["leisure"](poly:"$poly_str");
    way["man_made"](poly:"$poly_str");
  );
  out body;
  >;
  out skel qt;
  QUERY
}

sub _build_query_tmpl($self, $tmpl) {
  my $params = { timeout => $self->timeout, poly => $self->_poly_string };
  my $code    = path($tmpl)->slurp;
  return $self->_tmpl->render($code,$params);
}

async sub run_query_p($self) {
  $self->log->info(sprintf 'Requesting OSM service...');
  my $q = $self->_build_query;
  $self->emit( query => $q );
  my $data = await $self->_testing ? $self->_testing_data : $self->_get_from_osm($q);
  $self->emit(osm_data => $data);
  return $self->_osm_raw($data);
}

async sub _get_from_osm($self, $q = $self->_build_query) {
  $self->log->info("Getting data from OSM service");
  $self->emit( progress => { total => 0, processed => 0, phase => 'osm' } );
  my $t0 = [ gettimeofday ];
  my $tx = await $self->_ua->post_p( $self->_overpass_url => form => { data => $q } );
  my $res = $tx->res;

  if ($res->is_success) {
    my $osm_data = {
      query => $q,
      data  => $res->body,
      elapsed => tv_interval($t0),
    };
    $self->emit( query_data => $osm_data );
  } else {
    $self->log->error( sprintf "Failed query: %s, Error %s", $q, $res->message );
  }
  return decode_json($res->body);
}

sub run_query($self) { 
  $self->run_query_p->wait; 
  $self->_process_raw_data;
}

sub _process_raw_data($self, $osm_data = $self->_osm_raw) {
  $self->log->info('Processing OSM raw data into GeoJSON format');
  my @nodes = grep { $_->{type} eq 'node' } $osm_data->{elements}->@*;
  my @ways;
  my $total = scalar( $osm_data->{elements}->@* ) - scalar( @nodes );
  my $processed = 0;

  $self->emit(progress => {total => ($total-1), processed => $processed, phase => 'geojson'});

  foreach my $el ($osm_data->{elements}->@*) {
    next unless $el->{type} eq 'way';
    my $props = { properties => { $el->{tags}->%* , id => $el->{id} } };
    my $coords = [];

    # find the nodes of polygon
    foreach my $node ($el->{nodes}->@*) {
      my $n = first { $_->{id} eq $node } @nodes;
      push @$coords, [$n->{lon}, $n->{lat}];
    }
    my $type;
    if (
      $coords->[0][0] == $coords->[-1][0]
      &&
      $coords->[0][1] == $coords->[-1][1]
    ) {
      $type = 'Polygon';
    } else {
      $type = 'LineString';
    }
    my $feat = {
      type => 'Feature',
      geometry => { 
        type => $type,
        coordinates => $type eq 'LineString' ? $coords : [ $coords ],
      },
      $props->%*
    };
    push @ways, $feat;
    $self->emit( feature => $feat );
    $self->emit( progress => { total => $total, processed => ++$processed, phase => 'geojson' });
  }
  # make geojson
  my $json = { type => 'FeatureCollection', features => [@ways] };
  $self->_osm_geojson($json);
  return $json
}

1;

__END__


=head1 DESCRIPTION

Fetches geographic features (landuse, natural areas, leisure facilities, and man-made structures)
within municipal boundaries and converts them to GeoJSON format querin OpenStreetMap
by overpass-api.

=cut
