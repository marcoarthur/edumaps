# t/06-tools/inep_teste_unico.t
# Cada arquivo de teste que cria escola de teste (clean.escolas ou
# clean.censo_escolas) usa INEPs só dele.
#
# Com a suíte em paralelo (`prove -j4`), dois arquivos com o mesmo INEP de
# teste apagavam a escola e os dados um do outro (contatos, reuniões, pastas)
# no meio da execução: um terminava e o outro passava a receber 404. Também
# fica proibido criar a 99999999, que vários testes usam como "escola que não
# existe" e o SIOPE usa como agregado da secretaria municipal.
#
# Convenção conferida: `my $NOME = 'NNNNNNNN';` (como os testes já declaram).
# INEP novo de teste: prefixo 60 (não há UF 60, nunca é escola real) e um
# número ainda livre — este teste diz qual arquivo já usa o que estiver em
# conflito.
use strict;
use warnings;
use utf8;
use Test::More;
use File::Find;

my %dono;   # inep => [arquivos]
find({ no_chdir => 1, wanted => sub {
  return unless /\.t\z/ && -f;
  open my $fh, '<:encoding(UTF-8)', $_ or die "$_: $!";
  my $src = do { local $/; <$fh> };
  return unless $src =~ /(?:INSERT\s+INTO|DELETE\s+FROM)\s+clean\.(?:escolas|censo_escolas)\b/;
  my %aqui;
  $aqui{$1} = 1 while $src =~ /\bmy\s+\$\w+\s*=\s*'(\d{8})'\s*;/g;
  push @{ $dono{$_} }, $File::Find::name for keys %aqui;
} }, 't');

ok scalar(keys %dono) > 20, 'achou os INEPs de teste (conferência do próprio teste)';

for my $inep (sort keys %dono) {
  my @arq = sort @{ $dono{$inep} };
  ok @arq == 1, "INEP $inep num arquivo só" or diag "repetido em: @arq";
}
ok !$dono{99999999}, '99999999 não é criada por nenhum teste'
  or diag "criada em: @{ $dono{99999999} }";

done_testing;
