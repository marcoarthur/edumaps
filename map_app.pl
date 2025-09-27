#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use lib qw(./lib);
use MyApp::Schema;

app->static->paths->[0] = './public';

helper dbic => sub ($c) { state $sch = MyApp::Schema->go; };
helper municipios => sub ($c) {
  state $m = $c->dbic->resultset('MunicipiosSp');
};
helper find_municipio => sub ($c, $name) {
  my $params = \[ qq{unaccent(nm_mun) ILIKE unaccent('%$name%')}];
  return $c->municipios->search_rs($params)
  ->feat_collection->get_column('feature')->first;
};

# Serve our main map page
get '/' => 'map';

# API endpoint to serve GeoJSON data
get '/api/geojson' => sub ($c) {
  my $city_name = $c->param('city');
  return unless $city_name;
  $c->render( text => $c->find_municipio($city_name) );
};

get '/api/details' => sub ($c) {
  my $fid = $c->param('fid');
  return unless $fid;
  my @params = ( 
    { fid => $fid }, 
    { 
      columns => [ 
        qw( 
          fid  cd_mun  nm_mun  cd_rgi  nm_rgi  cd_rgint  nm_rgint  cd_uf  nm_uf  
          sigla_uf  cd_regia  nm_regia  sigla_rg  cd_concu  nm_concu  area_km2 
        )
      ],
      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    }
  );
  $c->render( json => $c->municipios->search_rs( @params )->first );
};

app->start;
