package EduMaps::Plugin::API::SchoolNetwork;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has network_path => '/api/network';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->network_path);

  my $check = [codigo_ibge => qr/\d{7}/];

  $api->get('/:codigo_ibge/summary' => $check)->to('school_network#summary')->name('network_summary');
  $api->get('/:codigo_ibge/schools' => $check)->to('school_network#schools')->name('network_schools');
  $api->get('/:codigo_ibge/performance' => $check)->to('school_network#performance')->name('network_performance');
  $api->get('/:codigo_ibge/markers' => $check)->to('school_network#markers')->name('network_markers');
}

1;