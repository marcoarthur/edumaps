#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use lib qw(./lib);
use MyApp::Schema;

app->static->paths->[0] = './public';

helper dbic => sub ($c) { state $sch = MyApp::Schema->go; };
helper municipios => sub ($c) {
  state $m = $c->dbic->resultset('MunicipiosSp');
};
helper escolas => sub ($c) {
  state $e = $c->dbic->resultset('Escola');
};
helper find_municipio => sub ($c, $name) {
  my $params = \[ qq{unaccent(nm_mun) ILIKE unaccent('%$name%')}];
  return $c->municipios->search_rs($params)
  ->feat_collection->get_column('feature')->first;
};
helper find_escolas => sub ($c, $name) {
  return $c->escolas->find_by_city_name($name)->get_column('feature')->first;
};

get '/' => 'map';

get '/api/geojson' => sub ($c) {
  my $city_name = $c->param('city');
  return unless $city_name;
  $c->render( text => $c->find_municipio($city_name) );
};

get '/api/details' => sub ($c) {
  my $fid = $c->param('fid');
  return unless $fid;
  $c->render( json => $c->municipios->details($fid)->first );
};

get '/api/schools' => sub ($c) {
  my $city_name = $c->param('city');
  return unless $city_name;
  $c->render( text => $c->find_escolas($city_name) );
};

app->start;
