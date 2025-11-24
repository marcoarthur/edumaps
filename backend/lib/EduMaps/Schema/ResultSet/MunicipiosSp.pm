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

1;
