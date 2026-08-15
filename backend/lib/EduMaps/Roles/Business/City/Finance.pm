package EduMaps::Roles::Business::City::Finance;
use Mojo::Base -role, -signatures;

requires qw(schema);

=head2 payroll($ibge_code, $date)

Get payroll for the city in month and year.

=cut

sub payroll($self, $ibge_code, $date){
  my ($school, $city) = map { $self->schema->resultset($_) } qw(Escolas MunicipiosSp);

  my $params = { 
    ano => $date->year,mes => ucfirst($date->month_name) 
  },
  my $payroll = $school->search_rs(
    { 
      municipio => { 
        '=' => $city->search_rs( { codigo_ibge => $ibge_code } )->get_column('nome_municipio')->as_query 
      }
    }
  )->search_related_rs(
    'folha_pagamentos',
    { ano => $date->year, mes => ucfirst($date->month_name) },
    {
      columns => [
        { total_professores => { count => 'nome_profissional' } },
        { total_salarios => { sum => 'salario_total' } },
        qw(escola mes ano)
      ],
      group_by => [ qw(folha_pagamentos.escola mes ano) ]
    }
  )->as_hash->get_all;

  return $payroll;
  #return $self->json->encode($payroll->to_array);
}

=head2 payroll_details($ibge_code,$date)

Get the list of all schools and they payroll related data for the month and year
specified by C<$date>.

=cut

=head3 Parameters

=over 4

=item * C<$ibge_code> (String) - String representing ibge_code of city

=item * C<$date> (DateTime) - DateTime object representing Year/Month of payroll

=back

=head3 Returns

=over 4

=item * String - JSON string with all payrolls found for each school of the city

=back

=head3 Notes

This method relates to C<EduMaps::Model::School::payroll> that list all workers and
their salaries for specific School.

=cut

sub payroll_details($self, $ibge_code, $date) {
  my $city_rs = $self->schema->resultset('MunicipiosSp');
  my $city_param = { codigo_ibge => $ibge_code };
  my $school_ids = $self->schema->resultset('Escolas')->search_rs(
    { municipio =>
      { '=' => $city_rs->search_rs($city_param)->get_column('nome_municipio')->as_query}
    },
    { columns => [qw(codigo_inep)] }
  )->as_hash->get_all;

  my $school = EduMaps::Model::School->new( schema => $self->schema );
  my $school_payroll = $school_ids->map(
    sub { $school->payroll($_->{codigo_inep}, $date)}
  );
  return sprintf('[%s]', $school_payroll->join(',')->to_string);
}

sub overall_payroll($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  $self->set_params_map(
    params => $params,
    map => {
      codigo_ibge => [qw/codigo_ibge/],
    },
  );
  return $self->json->encode([]) unless $params->{codigo_ibge};

  my $results = $rs->search_rs(
    {codigo_ibge => $params->{codigo_ibge}},
    {
      join => ['remuneracao_educacao'],
      columns => [
        qw(nome_municipio codigo_ibge nome_estado),
        { ano => 'remuneracao_educacao.ano' },
        { total_folha_salario => { sum => 'salario_total' }},
        { total_registros => { count => '*'} },
      ],
      distinct => 1,
    }
  )->as_hash->get_all;

  return $self->json->encode($results->to_array);
}

1;
