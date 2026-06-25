package EduMaps;
use Mojo::Base 'Mojolicious', -signatures;
use EduMaps::Schema;

# ABSTRACT: Plataforma de análise educacional geoespacial para municípios brasileiros

our $VERSION = '0.001';

has schema => sub { state $sch = EduMaps::Schema->go() };

sub startup ($self) {

  # ------------------------------------------------------------
  # Plugins
  # ------------------------------------------------------------
  my $conf = $self->plugin(Config => {file => $ENV{EDUMAPS_CONF} || './edu_maps.conf' });
  $self->plugin(Minion => {Pg => $conf->{db_url} });
  $self->plugin("EduMaps::Task::$_") for qw/Siope OSM/;
  
  # ------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------
  $self->helper(
    model => sub($c, $model) {
      my $class = "EduMaps::Model::$model";
      return $class->new( schema => $self->schema );
    }
  );

  push @{$self->routes->namespaces}, 'EduMaps::Controller';
  my $r = $self->routes;

  # ------------------------------------------------------------
  # Routes . Grupo /api/city
  # ------------------------------------------------------------
  my $city = $r->under('/api/city');

  $city->get('/:codigo_ibge/details' => [codigo_ibge => qr/\d{7}/])
  ->to('city#details')->name('city_details');

  $city->get('/:codigo_ibge/schools' => [codigo_ibge => qr/\d{7}/])
  ->to('city#schools')->name('city_schools');

  $city->get('/:codigo_ibge/osm_features' => [codigo_ibge => qr/\d{7}/])
  ->to('city#osm_features')->name('city_osm_features');

  $city->get('/:codigo_ibge/payroll' => [codigo_ibge => qr/\d{7}/])
  ->to('city#payroll')->name('city_payroll');

  $city->get('/:codigo_ibge/payroll/overall' => [codigo_ibge => qr/\d{7}/])
  ->to('city#overall_payroll')->name('city_overall_payroll');

  $city->get('/:codigo_ibge/payroll/details' => [codigo_ibge => qr/\d{7}/])
  ->to('city#payroll_details')->name('city_payroll_details');

  $city->get('/search/:name')
  ->to('city#search_by_name')->name('city_search_by_name');

  $city->get('/detail/:name')
  ->to('city#detail_by_name')->name('city_detail_by_name');

  # ------------------------------------------------------------
  # Grupo /api/analytics
  # ------------------------------------------------------------
  my $analytics = $r->under('/api/analytics');

  $analytics->get('/city/:codigo_ibge/details' => [codigo_ibge => qr/\d{7}/])
  ->to('city#analytic_details')->name('city_analytic_details');

  $analytics->get('/cities/search')
  ->to('city#search_for_complete')->name('search_analityc_cities');

  $analytics->get('/cities/markers')
  ->to('city#search_in_bbox')->name('search_markers');

  # ------------------------------------------------------------
  # Grupo /api/school
  # ------------------------------------------------------------
  my $school = $r->under('/api/school');

  $school->get('/:cod_inep/info' => [cod_inep => qr/\d+/])
  ->to('school#info')->name('school_info');

  $school->get('/:cod_inep/payroll' => [cod_inep => qr/\d+/])
  ->to('school#payroll')->name('school_payroll');

  $school->get('/:cod_inep/grades' => [cod_inep => qr/\d+/])
  ->to('school#grades')->name('school_grades');

  $school->get('/:cod_inep/full_grades' => [cod_inep => qr/\d+/])
  ->to('school#full_grades')->name('school_full_grades');

  $school->get('/:cod_inep/professionals' => [cod_inep => qr/\d+/])
  ->to('school#professionals')->name('school_professionals');

  $school->get('/search')
  ->to('school#search_all')->name('school_search_all');

  $school->get('/search/:term')
  ->to('school#search')->name('school_search');

  $school->get('/nearby/:lat/:lon' => [lat => qr/[^\/]+/, lon => qr/[^\/]+/])
  ->to('school#nearby')->name('school_nearby');

  $school->get('/cluster')
  ->to('school#cluster')->name('school_city_cluster');

  $school->get('/:codigo_inep/cover' => [codigo_inep => qr/\d+/])
  ->to('school#cover')->name('school_gis_cover');

  $school->get('/scores')
  ->to('school#scores')->name('school_scores');
}

1;

__END__

=head1 NAME

EduMaps - Plataforma de análise educacional geoespacial

=head1 DESCRIPTION

EduMaps integra dados do INEP, OSM, SIOPE e IPEA para análise
de cobertura escolar e acessibilidade em municípios brasileiros.

=head1 AUTHOR

Marco Arthur <arthurpbs@gmail.com>

=cut
