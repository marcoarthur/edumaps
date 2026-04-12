package EduMaps::Schema::ResultSet::RemuneracaoMunicipal;
use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

sub from_municipio($self, $city_name) {
  my $mu_rs = $self->result_source->schema->resultset('MunicipiosSp')
  ->search_rs(
    { nome_municipio => $city_name },
    # workaround to convert codigo_ibge_antigo to the same (wrong!) type in RemuneracaoMunicipal
    { columns => [ { cod => \"codigo_ibge_antigo::bigint" }] }
  )->get_column('cod');

  $self->search_rs( { cod_municipio => { '=' => $mu_rs->as_query } } );
}

sub count_workers($self) {

  $self->columns(qw/nome_profissional cpf tipo/)
  ->distinct
  ->as_subselect_rs
  ->count_of( [qw(tipo)], 'total');
}

sub add_rank_for_column($self, $column) {
  $self->add_derived(
    "rank_$column" => qq<RANK() OVER (ORDER BY $column DESC)>,
  );
}

sub add_extra_info($self) {
  $self->add_derived(
    salario_hora      => q<salario_base / NULLIF(carga_horaria * 4, 0)>,
    proporcao_fundeb  => q<(salario_fundeb_max + salario_fundeb_min) / NULLIF(salario_total, 0)>,
    mes_ano           => q<mes || '/' || ano>,
    periodo_salario   => q< CASE 
                              WHEN mes ILIKE 'jan%' THEN MAKE_DATE(ano, 1, 1)
                              WHEN mes ILIKE 'fev%' THEN MAKE_DATE(ano, 2, 1)
                              WHEN mes ILIKE 'mar%' THEN MAKE_DATE(ano, 3, 1)
                              WHEN mes ILIKE 'abr%' THEN MAKE_DATE(ano, 4, 1)
                              WHEN mes ILIKE 'mai%' THEN MAKE_DATE(ano, 5, 1)
                              WHEN mes ILIKE 'jun%' THEN MAKE_DATE(ano, 6, 1)
                              WHEN mes ILIKE 'jul%' THEN MAKE_DATE(ano, 7, 1)
                              WHEN mes ILIKE 'ago%' THEN MAKE_DATE(ano, 8, 1)
                              WHEN mes ILIKE 'set%' THEN MAKE_DATE(ano, 9, 1)
                              WHEN mes ILIKE 'out%' THEN MAKE_DATE(ano, 10, 1)
                              WHEN mes ILIKE 'nov%' THEN MAKE_DATE(ano, 11, 1)
                              WHEN mes ILIKE 'dez%' THEN MAKE_DATE(ano, 12, 1)
                              ELSE NULL
                            END >,
    uf                => q<LEFT(cod_municipio::text, 2)>,
  );
}

# Siope Service providing the xlsx file with data, requires this order
sub siope_column_order($self) {
  return [ 
    qw(ano mes nome_profissional cpf cod_inep escola carga_horaria tipo categoria 
      situacao segmento_ensino salario_base salario_fundeb_max salario_fundeb_min
      salario_outros salario_total cod_municipio rede)
  ];
}

1;
