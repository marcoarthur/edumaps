package EduMaps::Roles::Business::SchoolNetwork::Profile;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

requires qw(schema);

our %REDE_CODS = (
  federal   => 1,
  estadual  => 2,
  municipal => 3,
  privada   => 4,
);

our %REDE_LABELS = reverse %REDE_CODS;

=head2 summary($params)

Resumo da rede de escolas de um município, segmentado por tipo de administração
(federal, estadual, municipal, privada).

=head3 Parameters

=over 4

=item * C<codigo_ibge> (String) - Código IBGE do município (7 dígitos)

=item * C<rede> (String, optional) - Filtra por tipo de administração
(federal|estadual|municipal|privada)

=back

=head3 Returns

=over 4

=item * (ArrayRef[HashRef]) - Uma entrada por rede com:
  - rede/codigo_rede: Identificação da rede
  - total_escolas, matrículas por etapa, docentes (total/formação)
  - desempenho (IDEB/SAEB) e indicadores derivados

=back

=cut

sub summary($self, $params = {}) {
  my $rs = $self->schema->resultset('RedeEscolas');

  croak "Need codigo_ibge" unless $params->{codigo_ibge};

  my $search = { co_municipio => $params->{codigo_ibge} };
  if (my $rede = $params->{rede}) {
    my $cod = $REDE_CODS{lc $rede} or croak "Rede inválida: $rede";
    $search->{codigo_rede} = $cod;
  }

  my $columns = [
    qw/
      co_municipio no_municipio sg_uf no_regiao codigo_rede rede
      total_escolas
      total_matriculas matriculas_infantil matriculas_fundamental
      matriculas_fundamental_ai matriculas_fundamental_af matriculas_medio
      matriculas_profissional matriculas_eja matriculas_especial matriculas_integral
      total_docentes docentes_superior docentes_concursados
      ideb_fund_i ideb_fund_ii ideb_medio nota_media_fund_ii
      nota_matematica_fund_ii nota_portugues_fund_ii nota_media_medio ano_ideb
      alunos_por_docente alunos_por_escola perc_docentes_superior perc_docentes_concursados
    /,
  ];

  my $results = $rs->search_rs($search)
  ->order_by('codigo_rede')
  ->columns($columns)
  ->as_hash->get_all;

  return $results->to_array;
}

=head2 schools($params)

Lista as escolas de uma rede em um município, com totais de matrículas por etapa.

=head3 Parameters

=over 4

=item * C<codigo_ibge> (String) - Código IBGE do município (7 dígitos)

=item * C<rede> (String, optional) - Tipo de administração
(federal|estadual|municipal|privada)

=item * C<limit> (Int, optional) - Limite de escolas (default: 100)

=item * C<ano> (Int, optional) - Ano do Censo para matrículas (default: 2025)

=back

=head3 Returns

=over 4

=item * (ArrayRef[HashRef]) - Uma entrada por escola:
  - co_entidade/no_entidade: Identificação da escola
  - tp_dependencia: Tipo de administração
  - latitude/longitude: Localização (geotag da escola)
  - matrículas por etapa

=back

=cut

sub schools($self, $params = {}) {
  my $rs = $self->schema->resultset('CensoEscolas');

  croak "Need codigo_ibge" unless $params->{codigo_ibge};

  my @fields = qw(qt_mat_bas qt_mat_inf qt_mat_fund qt_mat_fund_ai qt_mat_fund_af
    qt_mat_med qt_mat_prof qt_mat_eja qt_mat_esp qt_mat_bas_int);

  my $search = { co_municipio => $params->{codigo_ibge} };
  if (my $rede = $params->{rede}) {
    my $cod = $REDE_CODS{lc $rede} or croak "Rede inválida: $rede";
    $search->{tp_dependencia} = $cod;
  }

  my $anno = $params->{ano} // 2025;
  $search->{'matricula.nu_ano_censo'} = $anno;

  return $rs->search_rs($search, { join => 'matricula' })
  ->columns([
    qw/me.co_entidade me.no_entidade me.tp_dependencia me.latitude me.longitude/,
    map { { "matricula_$_" => { sum => "matricula.$_", -as => "matricula_$_" } } } @fields,
  ])
  ->group_by([qw/me.co_entidade me.no_entidade me.tp_dependencia me.latitude me.longitude/])
  ->order_by({ -desc => 'matricula_qt_mat_bas' })
  ->limit($params->{limit} // 100)
  ->as_hash->get_all;
}

1;