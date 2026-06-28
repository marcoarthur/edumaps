package EduMaps::Plugin::API::City;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has city_path => '/api/city';
has analytic_path => '/api/analytics';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->city_path);

  my $check = [codigo_ibge => qr/\d{7}/];

  $api->get('/:codigo_ibge/details' => $check)->to('city#details')->name('city_details');
  $api->get('/:codigo_ibge/schools' => $check)->to('city#schools')->name('city_schools');
  $api->get('/:codigo_ibge/osm_features' => $check)->to('city#osm_features')->name('city_osm_features');
  $api->get('/:codigo_ibge/payroll' => $check)->to('city#payroll')->name('city_payroll');
  $api->get('/:codigo_ibge/payroll/overall' => $check)->to('city#overall_payroll')->name('city_overall_payroll');
  $api->get('/:codigo_ibge/payroll/details' => $check)->to('city#payroll_details')->name('city_payroll_details');
  $api->get('/search/:name')->to('city#search_by_name')->name('city_search_by_name');
  $api->get('/detail/:name')->to('city#detail_by_name')->name('city_detail_by_name');

  # ------------------------------------------------------------
  # Grupo /api/analytics
  # ------------------------------------------------------------
  my $analytics = $r->under($self->analytic_path);
  $analytics->get('/city/:codigo_ibge/details' => $check)
  ->to('city#analytic_details')->name('city_analytic_details');

  $analytics->get('/cities/search')
  ->to('city#search_for_complete')->name('search_analityc_cities');

  $analytics->get('/cities/markers')
  ->to('city#search_in_bbox')->name('search_markers');
}

1;
