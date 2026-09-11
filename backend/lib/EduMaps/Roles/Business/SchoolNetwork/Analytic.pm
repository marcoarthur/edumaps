package EduMaps::Roles::Business::SchoolNetwork::Analytic;
use Mojo::Base -role, -signatures;
use Carp qw(croak);

requires qw(schema);

=head2 performance($params)

Agregados de desempenho em exames (IDEB/SAEB) da rede de um município.

=head3 Parameters

=over 4

=item * C<codigo_ibge> (String) - Código IBGE do município (7 dígitos)

=item * C<rede> (String, optional) - Tipo de administração
(federal|estadual|municipal|privada)

=item * C<etapa> (String, optional) - Etapa de ensino
(fundamental_i|fundamental_ii|ensino_medio)

=item * C<desde> (Int, optional) - Ano inicial da série

=item * C<ate> (Int, optional) - Ano final da série

=back

=head3 Returns

=over 4

=item * (ArrayRef[HashRef]) - Série agregada por (ano, rede, etapa):
  - rede/etapa/ano: Identificação
  - numero_escolas: Escolas com resultado no ano
  - ideb_medio, nota_matematica, nota_portugues, nota_media, aprovacao_media:
    Médias da rede

=back

=cut

sub performance($self, $params = {}) {
  my $rs = $self->schema->resultset('IdebNotasEscolas');

  croak "Need codigo_ibge" unless $params->{codigo_ibge};

  my $search = { co_municipio => $params->{codigo_ibge} };
  if (my $rede = $params->{rede}) {
    $search->{rede} = $self->_capitalize(lc $rede);
  }

  my $etapa = $params->{etapa} // [qw/fundamental_i fundamental_ii ensino_medio/];
  $etapa = [$etapa] unless ref $etapa;
  $search->{etapa} = { -in => $etapa };

  if ($params->{desde} || $params->{ate}) {
    my $range = {};
    $range->{'>='} = $params->{desde} if $params->{desde};
    $range->{'<='} = $params->{ate} if $params->{ate};
    $search->{ano} = $range;
  }

  my $results = $rs->search_rs($search)
  ->columns([
    'rede', 'etapa', 'ano',
    { numero_escolas => { count => 'id_escola' } },
    { ideb_medio => { avg => 'ideb_observado' } },
    { nota_matematica => { avg => 'nota_matematica' } },
    { nota_portugues => { avg => 'nota_portugues' } },
    { nota_media => { avg => 'nota_media' } },
    { aprovacao_media => { avg => 'aprovacao_si_4' } },
  ])
  ->group_by([qw/rede etapa ano/])
  ->order_by({ -asc => 'ano' });

  my @out;
  my $rows = $results->as_hash->get_all;
  $rows->each(sub {
    my $row = $_;
    push @out, {
      rede => $row->{rede},
      etapa => $row->{etapa},
      ano => $row->{ano},
      numero_escolas => $row->{numero_escolas},
      ideb_medio => $self->_num($row->{ideb_medio}),
      nota_matematica => $self->_num($row->{nota_matematica}),
      nota_portugues => $self->_num($row->{nota_portugues}),
      nota_media => $self->_num($row->{nota_media}),
      aprovacao_media => $self->_num($row->{aprovacao_media}),
    };
  });

  return \@out;
}

sub _num($self, $v) {
  return undef unless defined $v;
  return $v =~ /\./ ? sprintf('%.2f', $v) : $v;
}

sub _capitalize($self, $word) {
  return ucfirst lc $word;
}

1;