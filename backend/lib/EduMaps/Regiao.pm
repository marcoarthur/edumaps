package EduMaps::Regiao;
use Mojo::Base -strict, -signatures;
use utf8;

# Regiões geográficas do IBGE (#445, BA-02): sigla, nome e as UFs de cada uma.
# As siglas são as do geotag dos relatórios (N, NE, SE, S, CO). Usado pelo
# ranking de redes; o frontend repete os ids em
# features/ranking-recorte/constants.js.
our @REGIOES = (
  { id => 'N',  label => 'Norte',        ufs => [qw(AC AM AP PA RO RR TO)] },
  { id => 'NE', label => 'Nordeste',     ufs => [qw(AL BA CE MA PB PE PI RN SE)] },
  { id => 'SE', label => 'Sudeste',      ufs => [qw(ES MG RJ SP)] },
  { id => 'S',  label => 'Sul',          ufs => [qw(PR RS SC)] },
  { id => 'CO', label => 'Centro-Oeste', ufs => [qw(DF GO MS MT)] },
);
# Sem cache: as buscas varrem as cinco regiões, e um teste pode estender
# @REGIOES com `local` (UFs fictícias).
sub _por_id ($id) { defined $id ? (grep { $_->{id} eq $id } @REGIOES)[0] : undef }

sub ids ($class) { map { $_->{id} } @REGIOES }

sub valido ($class, $id) { _por_id($id) ? 1 : 0 }

sub nome ($class, $id) { my $r = _por_id($id); $r ? $r->{label} : undef }

sub ufs ($class, $id) { my $r = _por_id($id); $r ? [ @{ $r->{ufs} } ] : undef }

# CASE SQL que devolve o nome da região para a expressão de UF dada (#448).
# A expressão vem do código (nunca do usuário).
sub case_sql ($class, $expr) {
  my @w = map {
    my $r = $_;
    "WHEN $expr IN (" . join(', ', map { "'$_'" } @{ $r->{ufs} }) . ") THEN '$r->{label}'"
  } @REGIOES;
  return 'CASE ' . join(' ', @w) . ' END';
}

# Região (id) de uma UF (#449); undef para UF desconhecida.
sub de_uf ($class, $uf) {
  return undef unless defined $uf;
  for my $r (@REGIOES) { return $r->{id} if grep { $_ eq $uf } @{ $r->{ufs} } }
  return undef;
}

sub lista ($class) { [ map { +{ id => $_->{id}, label => $_->{label}, ufs => [ @{ $_->{ufs} } ] } } @REGIOES ] }

1;
