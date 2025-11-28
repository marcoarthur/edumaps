package EduMaps::Schema::ResultSet::MunicipiosSp;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;


sub with_escolas_count($self) {
  my $escolas = $self->result_source->schema->resultset('MunicipiosSp')
  ->search_related_rs( 
    'escolas',
    {
      # this binds counting for each individual municipio in search result
      # TODO: how to garantee that nome_municipio will be used ?
      # OR how to use a guaranted identifier ?
      'municipio' => {-ident => "principal.nome_municipio" }
    },
  );

  $self->search_rs(
    undef,
    {
      '+select' => [
        {'' => $escolas->count_rs->as_query, -as => 'total_escolas'},
      ],
      '+as'     => ['total_escolas'],
      alias     => 'principal',
    }
  );
}

sub to_geojson($self) {
  my $geom = 'geometry';
  my $cols_map = { name => 'nome_municipio', area => 'area_km2', fid => 'codigo_ibge' };
  $self->geojson_features($geom, $cols_map);
}

sub details($self,$id) {

  my $cols = [
    { codigo_ibge => 'codigo_ibge' },
    { nome_municipio => 'nome_municipio' },
    { area => 'area_km2' },
    { total_escolas => { count => 'escolas' } },
    { populacao => 'populacao.populacao_estimada' },
  ];

  my @params = ( 
    { 'me.codigo_ibge' => $id }, 
    { 
      join          => ['escolas', 'populacao'],
      'columns'     => $cols,
      result_class  => 'DBIx::Class::ResultClass::HashRefInflator',
      group_by      => ['me.codigo_ibge','populacao_estimada'],
    }
  );
  $self->search_rs( @params );
}

1;
