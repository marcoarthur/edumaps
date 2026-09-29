package EduMaps::Task::OSM::Service;

use Mojo::Base 'Mojo::EventEmitter', -signatures, -async_await;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Log;
use Mojo::File qw(path);
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Template;
use utf8;
require EduMaps::Services::OSM;

=head1 NAME

EduMaps::Task::OSM::Service - (compat) Service legado OSM

=head1 DESCRIPTION

Mantido para compatibilidade: preserva a API antiga (C<polygon>,
C<run_query>, C<_build_query>, C<_build_query_tmpl>, C<_precision>,
C<_testing>) e as consultas legadas de landuse, mas **delega** o HTTP e o
parse para o L<EduMaps::Services::OSM> generalizado. Código novo deve usar
diretamente C<EduMaps::Services::OSM> + C<EduMaps::Model::OSM>.

=cut

has log           => sub { Mojo::Log->new };
has polygon       => sub { die 'Need a polygon' };
has timeout       => sub { 3*60 };
has query         => sub ($self) { $self->_build_query };
has _precision    => sub { 6 };
has _tmpl         => sub { Mojo::Template->new };
has _osm_raw      => sub { die 'require run_query() first' };
has _osm_geojson  => sub { die 'require run_query() first' };
has _testing      => sub { 0 };

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

# Constrói o Services::OSM com o QL legado (e o fixture offline quando em teste).
sub _new_service($self) {
  return EduMaps::Services::OSM->new(
    ql      => $self->_build_query,
    log     => $self->log,
    timeout => $self->timeout,
    offline => $self->_testing,
    ( $self->_testing ? (fixture => path('t', 'raw_osm.json')->to_string) : () ),
  );
}

sub _forward_events($self, $svc) {
  for my $ev (qw(query query_data feature progress)) {
    $svc->on($ev => sub { my (undef, @args) = @_; $self->emit($ev => @args) });
  }
  return $svc;
}

sub run_query_p($self) {
  my $svc = $self->_forward_events( $self->_new_service );
  return $svc->run_p;
}

sub run_query($self) {
  my $svc = $self->_forward_events( $self->_new_service );
  my $geojson = $svc->run;
  $self->_osm_raw( $svc->raw );
  $self->_osm_geojson($geojson);
  return $geojson;
}

1;
