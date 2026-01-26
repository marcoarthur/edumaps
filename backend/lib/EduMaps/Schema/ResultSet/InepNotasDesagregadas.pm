package EduMaps::Schema::ResultSet::InepNotasDesagregadas;
use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;

sub with_deltas($self) {
  my $alias = $self->current_source_alias;
  my $tmpl  = "(%s - LAG(%s) OVER ( PARTITION BY %s ORDER BY %s ))::numeric";
  my ($por, $mat, $esc, $ano) =  ("$alias.nota_por", "$alias.nota_mat", "$alias.no_escola", "$alias.ano");
  $self->search_rs(
    undef,
    {
      '+select' => [
        { round => [ \sprintf($tmpl, $por, $por, $esc, $ano), 2], -as => 'delta_por' },
        { round => [ \sprintf($tmpl, $mat, $mat, $esc, $ano), 2], -as => 'delta_mat' },
      ],
      '+as' => [ qw(delta_por delta_mat) ],
    }
  );
}

sub from_cities($self, $cities) {
  $cities = ref $cities ? $cities : [ $cities ];

  my $city_search = $self->search_in('MunicipiosSp')
  ->filter_by( nome_municipio => $cities )
  ->get_column('codigo_ibge');

  $self->search_rs(
    { codigo_ibge => { -in => $city_search->as_query } }
  );
}

sub from_school_name($self, $name) {
  $self->search_rs({ no_escola => { -ilike => "%${name}%" } });
}

1;
