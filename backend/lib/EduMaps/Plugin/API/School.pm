package EduMaps::Plugin::API::School;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

has school_path => '/api/school';
has analytic_path => '/api/analytics';

sub register ($self, $app, @args) {
  my $r = $app->routes;
  my $api = $r->under($self->school_path);

  my $check = [cod_inep => qr/\d{8}/];

  $api->get('/:cod_inep/panel/info' =>$check)->to('school#panel_info')->name('panel_school_info');

  $api->get('/:cod_inep/info' => $check)->to('school#info')->name('school_info');

  $api->get('/:cod_inep/payroll' => $check)->to('school#payroll')->name('school_payroll');

  $api->get('/:cod_inep/payroll/last' => $check)->to('school#payroll_last')->name('school_last_payroll');

  $api->get('/:cod_inep/grades' => $check)->to('school#grades')->name('school_grades');

  $api->get('/:cod_inep/full_grades' => $check)->to('school#full_grades')->name('school_full_grades');

  $api->get('/:cod_inep/professionals' => $check)->to('school#professionals')->name('school_professionals');

  $api->get('/search')->to('school#search')->name('school_search');

  $api->get('/suggestions')->to('school#search_suggestion')->name('school_search_suggestion');

  $api->get('/search/pageable')->to('school#search_pageable')->name('school_search_pageable');

  $api->get('/geo/search')->to('school#search_nearby')->name('school_nearby');

  $api->get('/cluster')->to('school#cluster_schools')->name('school_city_cluster');

  $api->get('/:cod_inep/cover' => $check)->to('school#cover')->name('school_gis_cover');

  $api->get('/scores')->to('school#scores')->name('school_scores');
}

1;
