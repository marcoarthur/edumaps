package MyApp::OSM::Query;
use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::URL;
use Mojo::Log;
use Time::HiRes qw(gettimeofday tv_interval);
use Digest::SHA qw(sha1_hex);
use Mojo::UserAgent;
use List::Util qw(first);
require MyApp::Schema;

has municipio   => sub { die 'Need the municipio id' };
has config      => sub { die 'Need configuration' };
has log         => sub { Mojo::Log->new };
has _polygon    => sub { die 'Need a polygon' };
has _timeout    => sub { 3*60 };
has _ua         => sub ($self) { Mojo::UserAgent->new->connect_timeout($self->_timeout) };
has _overpass_url => sub {
  state $url = Mojo::URL->new('https://overpass-api.de/api/interpreter');
};
has _osm_raw    => sub { die "Get by run_query()" };
has _sch        => sub ($self) { 
  my $conf = $self->config;
  state $sch = MyApp::Schema->connect($conf->{db_params}->@*,$conf->{db_opts}); 
};
has _query      => sub { 'Die get query from db' };
has _srid       => sub { 4674 };
has _minion_job => sub { 'Need minion context' };
has _landuse    => sub { 'Need OsmLanduse resultset' };

sub new($class, @args) {
  my $self = $class->SUPER::new(@args);
  $self->_setup;
  return $self;
}

sub _setup($self) {
  my $city = $self->_sch->resultset('MunicipiosSp')->find(
    { fid => $self->municipio },
    { +columns => [ {geojson => { ST_AsGeoJSON => \"geog::geometry"}}] }
  );

  die sprintf ("Cannot find city with id %s", $self->municipio) unless $city;
  $self->_polygon( decode_json($city->get_column('geojson')) );
  $self->_landuse($self->_sch->resultset('OsmLanduse'));
}

sub _poly_string($self) {
  my @coords;
  for my $poly ($self->_polygon->{coordinates}->@*) {
    my $ring = $poly->[0];
    push @coords, map { sprintf("%.6f %.6f", $_->[1], $_->[0]) } @$ring;
  }
  return join(' ', @coords);
}

sub _build_query($self) {
  my $poly_str = $self->_poly_string;
  my $tout = $self->_timeout;
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

async sub run_query_p($self) {
  $self->log->info(sprintf 'Start query for municipio id %s', $self->municipio);
  my $q = $self->_build_query;
  my $data = $self->_get_from_db($q);
  $data = await $self->_get_from_osm($q) unless $data;

  $self->_osm_raw($data);
}

sub run_query($self) {
  $self->run_query_p->wait;
}

sub _get_from_db($self, $q) {
  $self->log->info('Searching OSM data in DB');
  my $query = $self->_sch->resultset('OsmQuery')
  ->find( { digest => sha1_hex($q) });
  return unless $query;
  $self->_query($query);
  return decode_json($query->raw_results);
}

async sub _get_from_osm($self, $q) {
  $self->log->info("Getting data from OSM service");
  $self->emit( progress => { total => 0, processed => 0, phase => 'osm' } );
  my $t0 = [gettimeofday];
  my $tx  = await $self->_ua->post_p( $self->_overpass_url => form => { data => $q } );
  my $res = $tx->res;

  if ($res->is_success) {
    $self->_save_query(
      { 
        query => $q,
        data => $res->body,
        elapsed => tv_interval($t0),
      }
    );
  } else {
    $self->log->error( sprintf "Failed query: %s, Error %s", $q, $res->message );
  }
  return decode_json($res->body);
}

sub _collect_from_db($self) {
  $self->log->info('Gathering geometry features from DB');
  my $geo = $self->_landuse
  ->search_rs( { municipio_id => $self->municipio })
  ->feat_collection->get_column('feature')->first;
  $geo = decode_json($geo);

  my $total = scalar $geo->{features}->@*;
  $self->log->info("Found $total features in DataBase");
  return $geo;
}

sub to_geojson($self) {
  # get from database the geometries
  my $geo = $self->_collect_from_db;
  if ( my $total = $geo->{features}->@* ) {
    $self->emit( progress => { total => $total, processed => $total, phase => 'geojson' } );
    return $geo;
  }
  
  # otherwise: process and save in database
  $self->_set_feature_save;
  $self->_raw_to_geojson;
}

sub _raw_to_geojson($self, $osm_data = $self->_osm_raw) {
  $self->log->info('Processing raw data into GeoJSON format');
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
  return { type => 'FeatureCollection', features => [@ways] };
}

sub _save_query($self, $info) {
  $self->log->info('Saving OSM results into DB');
  my $query = $self->_sch->resultset('OsmQuery')
  ->create( 
    { 
      digest        => sha1_hex($info->{query}),
      query         => $info->{query}, 
      raw_results   => $info->{data},
      elapsed_time  => $info->{elapsed},
      city_fid      => $self->municipio,
    }
  );
  $self->_query($query);
  return $query;
}

sub _set_feature_save($self) {
  # data
  my $land = $self->_sch->resultset('OsmLanduse');
  my $srid = $self->_srid;
  # call back to save in database
  my $save_db = sub ($evt, $f) {
    my $geom = encode_json($f->{geometry});
    my $id = $f->{properties}{id};
    my $sql = qq~ST_Transform(ST_GeomFromGeoJSON('$geom'::json), $srid)~;
    $self->log->info(sprintf 'Saving landuse to DB, OSM %s', $id);
    eval {
      $land->create(
        {
          osm_id        => $id,
          municipio_id  => $self->municipio,
          osm_query_id  => $self->_query->digest,
          geom          => \$sql,
          properties    => encode_json($f->{properties}),
        }
      );
    };
    $self->log->warn("OSM feature $id already in database!") if $@;
  };
  # callback to pass job metadata (progress)
  my $inform_user = sub ($job, $progress) {
    $self->_minion_job->note(progress => $progress);
  };

  # set the callbacks
  $self->on( progress => $inform_user);
  $self->on( feature => $save_db );
}

1;

__END__

=head1 NAME

MyApp::OSM::Query - Fetch and cache OpenStreetMap data for geographic areas

=head1 SYNOPSIS

use MyApp::OSM::Query;

# Synchronous interface
my $query = MyApp::OSM::Query->new(
  municipio => 123,
  log       => Mojo::Log->new
);
$query->run_query;
my $geojson = $query->_raw_to_geojson;

# Asynchronous interface  
my $query = MyApp::OSM::Query->new(municipio => 456);
await $query->run_query_p;
my $geojson = $query->_raw_to_geojson;

=head1 DESCRIPTION

This module provides a caching proxy for OpenStreetMap data queries. It fetches
geographic features (landuse, natural areas, leisure facilities, and man-made structures)
within municipal boundaries and converts them to GeoJSON format. The module implements
smart caching to avoid repeated API calls to the Overpass API and includes automatic
geometry type detection (Polygon vs LineString).

=head1 ATTRIBUTES

=head2 municipio

my $id = $query->municipio;

Required. The municipality ID (fid) used to lookup geographic boundaries
from the database.

=head2 log

$query->log->info('Processing query');

A L<Mojo::Log> instance for logging operations. Defaults to a new Mojo::Log instance.

=head2 osm_raw

my $raw_data = $query->osm_raw;

The raw OSM data as retrieved from the API or cache. Dies if accessed before
L</run_query> is called.

=head1 METHODS

=head2 new

my $query = MyApp::OSM::Query->new(municipio => 123);

Constructor. Creates a new query instance and sets up the geographic polygon
from the database.

=head2 run_query

$query->run_query;

Synchronous method to execute the OSM query. Fetches data from cache or live API,
  and stores results in L</osm_raw>.

=head2 run_query_p

await $query->run_query_p;

Asynchronous version of L</run_query>. Returns a L<Mojo::Promise>.

=head2 _raw_to_geojson

my $geojson_string = $query->_raw_to_geojson;
my $geojson_string = $query->_raw_to_geojson($custom_osm_data);

Converts OSM data to GeoJSON format. Automatically detects geometry types
(Polygon for closed ways, LineString for open ways). Returns a JSON string
representing a GeoJSON FeatureCollection.

=head1 INTERNAL METHODS

These methods are for internal use but documented for maintenance purposes.

=head2 _setup

Called automatically during object construction. Retrieves the municipality
boundary polygon from the database and prepares it for querying.

=head2 _build_query

Builds the Overpass QL query string using the municipality boundary polygon.
Queries for landuse, natural features, leisure facilities, and man-made structures.

=head2 _poly_string

Converts the internal GeoJSON polygon representation to the coordinate string
format required by Overpass API.

=head2 _get_from_db

my $cached_data = $query->_get_from_db($query_string);

Searches the database for cached query results using SHA1 digest of the query.
Returns undef if no cached data found.

=head2 _get_from_osm

my $live_data = await $query->_get_from_osm($query_string);

Fetches data from the Overpass API. Records query timing and saves results
to database cache.

=head2 _save_query

my $query_id = $query->_save_query({
    query   => $query_string,
    data    => $response_data,
    elapsed => $processing_time
  });

Stores query results in the database cache with timing information.

=head1 DATABASE SCHEMA

The module requires these main tables:

=head2 municipios_sp

fid        INTEGER PRIMARY KEY,
geog       GEOGRAPHY(Geometry)  -- Municipality boundaries

=head2 osm_query

id            SERIAL PRIMARY KEY,
digest        TEXT UNIQUE,      -- SHA1 of query string
query         TEXT NOT NULL,    -- Original Overpass QL
last_run      TIMESTAMP DEFAULT NOW(),
elapsed_time  FLOAT,            -- Query execution time
raw_results   JSON              -- Cached OSM data

=head1 ERROR HANDLING

The module uses a combination of exceptions (die) and logged errors:

=over

=item * Constructor dies if municipio is missing or not found

=item * API failures are logged but don't die

=item * Invalid data may cause exceptions during processing

=back

=head1 PERFORMANCE

=over

=item * Query results are cached by SHA1 digest

=item * Database lookups avoid expensive API calls

=item * Asynchronous operations prevent blocking

=item * Consider adding spatial indexes to database tables

=back

=head1 EXAMPLES

=head2 Basic Usage

my $query = MyApp::OSM::Query->new(
  municipio => 42,
  log       => Mojo::Log->new(level => 'debug')
);

$query->run_query;
my $geojson = $query->_raw_to_geojson;

# Use $geojson in web applications or mapping tools

=head2 Integration with Web Framework

get '/municipio/:id/osm' => sub ($c) {
  my $query = MyApp::OSM::Query->new(
    municipio => $c->param('id'),
    log       => $c->app->log
  );

  $query->run_query;
  $c->render(
    json => $query->_raw_to_geojson,
    format => 'geojson'
  );
};

=head1 SEE ALSO

=over

=item * L<Overpass API|https://overpass-api.de>

=item * L<GeoJSON Specification|https://geojson.org>

=item * L<Mojo::UserAgent> - For HTTP requests

=item * L<DBIx::Class> - Database abstraction

=back

=head1 AUTHOR

Marco Arthur, E<lt>arthurpbs@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Marco Arthur

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
