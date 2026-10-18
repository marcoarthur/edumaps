#!/usr/bin/env perl
# Lista as REGIÕES IMEDIATAS de uma UF e os municípios (código IBGE) de cada
# uma, uma linha por região:
#
#   <nome_regiao_imediata>\t<codigo_ibge,codigo_ibge,...>[\t<pendentes>]
#
# O 3º campo — nº de escolas da região ainda SEM linha em
# `clean.mapbiomas_escola_risco` para o ano × raio — só aparece quando ano e
# raio são passados. É o que permite ao script de ingestão RETOMAR sem refazer
# os blocos já carregados.
#
# Uso:
#   regioes_do_estado.pl <UF>
#   regioes_do_estado.pl <UF> <ano> <raio>
#
# Usado pelo script de ingestão `mapbiomas_risco.sh` para aplicar a extração
# "aos poucos" (bloco a bloco), em vez de uma chamada nacional.
use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../../lib";

# O nome da região vem do banco em latin1; o shell compara em UTF-8. Sem isto,
# o filtro de região (`mapbiomas_risco.sh SP ... "São José dos Campos"`) nunca
# casa.
binmode STDOUT, ':encoding(UTF-8)';

use EduMaps::Ingestion::CLI;
use EduMaps::Ingestion::Runner;

my ($uf, $ano, $raio) = @ARGV;
$uf or die "uso: regioes_do_estado.pl <UF> [ano raio]\n";
$uf = uc $uf;
my $com_pendentes = defined $ano && defined $raio;

my $runner = EduMaps::Ingestion::Runner->new(
  config => EduMaps::Ingestion::CLI->load_config(''),
);
my $dbh = $runner->app->schema->storage->dbh;

my $rows = $dbh->selectall_arrayref(
  'SELECT nome_regiao_imediata, codigo_ibge
     FROM clean.municipios_sp
    WHERE sigla_estado = ?
    ORDER BY 1, 2',
  undef, $uf);

my %reg;
push @{ $reg{ $_->[0] } }, $_->[1] for @$rows;
die "UF $uf: nenhum município em clean.municipios_sp\n" unless %reg;

# Mesma seleção do job (escola_influencia JOIN censo_escolas, tier=raio), menos
# as escolas que já têm linha para este ano × raio.
my $sql_pendentes = q{
  SELECT count(*)
    FROM clean.escola_influencia i
    JOIN clean.censo_escolas e
      ON e.co_entidade = i.co_entidade AND e.nu_ano_censo = i.nu_ano_censo
   WHERE i.tier = 'buffer' AND i.raio_m = ?
     AND e.sg_uf = ?
     AND e.co_municipio::text = ANY(?::text[])
     AND NOT EXISTS (
       SELECT 1 FROM clean.mapbiomas_escola_risco r
        WHERE r.co_entidade = i.co_entidade
          AND r.ano = ? AND r.raio_m = i.raio_m)
};

for my $regiao (sort keys %reg) {
  my @cod = @{ $reg{$regiao} };
  print join("\t", $regiao, join(',', @cod));
  if ($com_pendentes) {
    my ($n) = $dbh->selectrow_array($sql_pendentes, undef, $raio, $uf, \@cod, $ano);
    print "\t", ($n // 0);
  }
  print "\n";
}
