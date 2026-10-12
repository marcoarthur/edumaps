package EduMaps::Roles::Business::Gestor::Relatorios;
use Mojo::Base -role, -signatures;
use utf8;

# Assistente de Relatório (#219): recorte-padrão da escola do gestor e as
# tabelas de referência usadas para validar o `geotag` ({nivel, codigo}).
# Fonte: clean.censo_escolas (edição mais recente em que a escola aparece).

requires qw(schema);

# co_regiao do Censo (1..5) -> sigla do contrato do geotag.
our %REGIAO_SIGLA = (1 => 'N', 2 => 'NE', 3 => 'SE', 4 => 'S', 5 => 'CO');

our %REGIAO_NOME = (
  N  => 'Norte',
  NE => 'Nordeste',
  SE => 'Sudeste',
  S  => 'Sul',
  CO => 'Centro-Oeste',
);

our %UF_NOME = (
  AC => 'Acre',             AL => 'Alagoas',            AP => 'Amapá',
  AM => 'Amazonas',         BA => 'Bahia',              CE => 'Ceará',
  DF => 'Distrito Federal', ES => 'Espírito Santo',     GO => 'Goiás',
  MA => 'Maranhão',         MT => 'Mato Grosso',        MS => 'Mato Grosso do Sul',
  MG => 'Minas Gerais',     PA => 'Pará',               PB => 'Paraíba',
  PR => 'Paraná',           PE => 'Pernambuco',         PI => 'Piauí',
  RJ => 'Rio de Janeiro',   RN => 'Rio Grande do Norte', RS => 'Rio Grande do Sul',
  RO => 'Rondônia',         RR => 'Roraima',            SC => 'Santa Catarina',
  SP => 'São Paulo',        SE => 'Sergipe',            TO => 'Tocantins',
);

our @NIVEIS = qw(escola municipio uf regiao);

# Recorte-padrão da escola: escola, município, UF e região. Devolve undef se
# a escola não está no Censo.
sub recorte_padrao($self, $cod_inep) {
  return unless defined $cod_inep && $cod_inep =~ /^\d{8}$/;

  my $row = $self->schema->resultset('CensoEscolas')
    ->search_rs(
      { co_entidade => $cod_inep },
      { order_by => { -desc => 'nu_ano_censo' }, rows => 1 },
    )
    ->columns([qw(co_entidade no_entidade co_municipio no_municipio
                  sg_uf no_uf co_regiao no_regiao)])
    ->as_hash->first;
  return unless $row;

  my $uf     = defined $row->{sg_uf} ? uc $row->{sg_uf} : undef;
  my $regiao = defined $row->{co_regiao} ? $REGIAO_SIGLA{ $row->{co_regiao} } : undef;

  return {
    escola => {
      cod_inep => '' . $row->{co_entidade},
      nome     => $row->{no_entidade},
    },
    municipio => {
      codigo => defined $row->{co_municipio} ? sprintf('%07d', $row->{co_municipio}) : undef,
      nome   => $row->{no_municipio},
    },
    uf => {
      codigo => $uf,
      nome   => $row->{no_uf} // ($uf ? $UF_NOME{$uf} : undef),
    },
    regiao => {
      codigo => $regiao,
      nome   => $row->{no_regiao} // ($regiao ? $REGIAO_NOME{$regiao} : undef),
    },
  };
}

# Valida o geotag {nivel, codigo} contra o contrato. `escola` só é aceito
# para o INEP do próprio gestor. Devolve ({nivel, codigo}, undef) normalizado
# ou (undef, mensagem de erro).
sub geotag_valido($self, $geotag, $cod_inep_gestor) {
  return (undef, 'geotag deve ser um objeto {nivel, codigo}')
    unless ref $geotag eq 'HASH';

  my $nivel  = $geotag->{nivel}  // '';
  my $codigo = $geotag->{codigo} // '';
  return (undef, 'geotag.nivel inválido (use escola, municipio, uf ou regiao)')
    unless !ref $nivel && grep { $_ eq $nivel } @NIVEIS;
  return (undef, 'geotag.codigo inválido') if ref $codigo;
  $codigo = "$codigo";

  if ($nivel eq 'municipio') {
    return (undef, 'geotag.codigo do município deve ter 7 dígitos')
      unless $codigo =~ /^\d{7}\z/;
  }
  elsif ($nivel eq 'uf') {
    return (undef, 'geotag.codigo da UF deve ser uma sigla válida (ex.: SP)')
      unless $codigo =~ /^[A-Z]{2}\z/ && exists $UF_NOME{$codigo};
  }
  elsif ($nivel eq 'regiao') {
    return (undef, 'geotag.codigo da região deve ser N, NE, SE, S ou CO')
      unless exists $REGIAO_NOME{$codigo};
  }
  else {    # escola
    return (undef, 'Relatórios por escola só são permitidos para a sua própria escola.')
      unless $codigo =~ /^\d{8}\z/ && $codigo eq ('' . ($cod_inep_gestor // ''));
  }

  return ({ nivel => $nivel, codigo => $codigo }, undef);
}

1;
