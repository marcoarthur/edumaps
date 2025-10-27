package MyApp::OSM::Query;
use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::URL;
use Mojo::Log;
use Digest::SHA qw(sha1_hex);
use Mojo::UserAgent;
use DDP;
require MyApp::Schema;
require MyApp::OSM::Service;

has municipio   => sub { die 'Need the municipio id' };
has config      => sub { die 'Need configuration' };
has log         => sub { Mojo::Log->new };
has save_db     => sub { 0 };
has _service    => sub { die 'Need MyApp::OSM::Service object'};
has _sch        => sub ($self) { 
  my $conf = $self->config;
  state $sch = MyApp::Schema->connect($conf->{db_params}->@*,$conf->{db_opts}); 
};
has _query      => sub { 'Die get query from db' };
has _srid       => sub { 4674 };
has _minion_job => sub { undef };
has _landuse    => sub { die 'Need OsmLanduse resultset' };

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
  $self->_service( 
    MyApp::OSM::Service->new( polygon => decode_json($city->get_column('geojson')))
  );
  $self->_landuse($self->_sch->resultset('OsmLanduse'));
  if ($self->_minion_job) {
    $self->_service->on(
      progress => sub( $evt, $data ) { $self->_minion_job->note( progress => $data ) }
    );
  }
}

sub from_db($self) {
  $self->log->info(sprintf 'Searching OSM data for id %s in DB', $self->municipio);
  return $self->_get_from_db;
}

sub _get_from_db($self, $q = $self->_service->query) {
  my $data = $self->_sch->resultset('OsmQuery')
  ->search_rs({ digest => sha1_hex($q) })
  ->search_related( 'osm_landuses', {})->feat_collection->get_column('feature')->first;
  return decode_json($data);
}

sub from_osm($self) {
  $self->_set_dbsave if $self->save_db;
  $self->emit( progress => { processed => 'None', total => 'Unknown', phase => 'osm', });
  my $osm_data = $self->_service->run_query;
  $self->emit( progress => { processed => 'Raw', total => 'Unknown', phase => 'osm', });
  return $osm_data;
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

sub _set_dbsave($self) {
  $self->log->info('Setting to save OSM data into DB');
  # data
  my $land = $self->_sch->resultset('OsmLanduse');
  my $srid = $self->_srid;
  # callback to save in database
  my $save_feature = sub ($evt, $f) {
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

  # set the callbacks
  $self->_service->on( query_data => sub ( $evt, $data) { $self->_save_query($data) });
  $self->_service->on( feature => $save_feature );
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
  my $geo_data = $query->from_db;


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


=head1 INTERNAL METHODS

These methods are for internal use but documented for maintenance purposes.

=head2 _setup

Called automatically during object construction. Retrieves the municipality
boundary polygon from the database and prepares it for querying.

=head2 _get_from_db

my $cached_data = $query->_get_from_db($query_string);

Searches the database for cached query results using SHA1 digest of the query.
Returns undef if no cached data found.

=head2 _get_from_osm

my $live_data = await $query->_get_from_osm($query_string);

Fetches data from the Overpass API. Records query timing and saves results
to database cache.


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

# Use $geojson in web applications or mapping tools

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
