package EduMaps::Porte;
use Mojo::Base -strict, -signatures;
use utf8;

# Porte do município (#439, RV-05): as classes de tamanho da população do
# IBGE, sobre a estimativa populacional carregada (clean.populacao_municipal).
# O limite superior entra na classe ("até 5 mil" inclui 5.000). Usado pelo
# ranking de redes e pela base de análise; o frontend repete os ids em
# features/ranking-recorte/constants.js.
our @PORTES = (
  { id => 'ate_5mil',    label => 'Até 5 mil habitantes',            max => 5_000 },
  { id => '5_10mil',     label => 'De 5 mil a 10 mil habitantes',    max => 10_000 },
  { id => '10_20mil',    label => 'De 10 mil a 20 mil habitantes',   max => 20_000 },
  { id => '20_50mil',    label => 'De 20 mil a 50 mil habitantes',   max => 50_000 },
  { id => '50_100mil',   label => 'De 50 mil a 100 mil habitantes',  max => 100_000 },
  { id => '100_500mil',  label => 'De 100 mil a 500 mil habitantes', max => 500_000 },
  { id => 'mais_500mil', label => 'Mais de 500 mil habitantes',      max => undef },
);
my %VALIDO = map { $_->{id} => 1 } @PORTES;

sub ids ($class) { map { $_->{id} } @PORTES }

sub valido ($class, $id) { defined $id && $VALIDO{$id} ? 1 : 0 }

sub lista ($class) { [ map { +{ id => $_->{id}, label => $_->{label} } } @PORTES ] }

# CASE SQL que devolve o id do porte para a expressão de população dada.
# A expressão vem do código (nunca do usuário).
sub case_sql ($class, $expr) {
  my @w = map { defined $_->{max} ? "WHEN $expr <= $_->{max} THEN '$_->{id}'" : "ELSE '$_->{id}'" } @PORTES;
  return "CASE WHEN $expr IS NULL THEN NULL " . join(' ', @w) . ' END';
}

1;
