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

  my %counts = (
    fundamental   => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%ensino fundamental%')/,
    medio         => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Médio%')/,
    infantil      => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%infantil%')/,
    profissional  => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Educação Profissional%')/,
    eja           => \q/COUNT(escolas) FILTER(WHERE escolas.etapas_modalidades ILIKE '%Educação de Jovens Adultos%')/,
    publicas      => \q/COUNT(escolas) FILTER(WHERE escolas.categoria_administrativa = 'Pública')/,
  );
  my @total_counts = map { +{"total_$_" => $counts{$_} } } keys %counts;

  my $cols = [
    { codigo_ibge => 'codigo_ibge' },
    { nome_municipio => 'nome_municipio' },
    { area => 'area_km2' },
    { total_escolas => { count => 'escolas' } },
    { populacao => 'populacao.populacao_estimada' },
    { estado => 'nome_estado' },
    @total_counts,
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

sub school_grades($self, %opts) {
  my $me = $self->current_source_alias;
  my $rs = $self
  ->join({ escolas => 'notas' })
  ->select_derived(
    codigo_inep       => 'escolas.codigo_inep',
    nome_municipio    => "$me.nome_municipio",
    portuguese_grades => { 
      jsonb_agg => { json_build_object => [ q/'nota'/, 'notas.nota_por', q/'ano'/, 'notas.ano'] } 
    },
    math_grades     => { 
      jsonb_agg => { json_build_object => [ q/'nota'/, 'notas.nota_mat', q/'ano'/, 'notas.ano'] } 
    },
  )
  ->group_by( ['codigo_inep',"$me.nome_municipio"] );
  return $rs->having( 
    { 
      -and => 
      [
        \["COUNT(notas.nota_mat) > ?",0],
        \["COUNT(notas.nota_por) > ?",0]
      ]
    }
  ) if $opts{graded_only};
  return $rs;
}

sub neighbor_cities($self) { $self->search_related_rs('vizinhos') }

1;
