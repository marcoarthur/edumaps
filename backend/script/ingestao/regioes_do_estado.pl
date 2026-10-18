#!/usr/bin/env perl
# Lista as REGIÕES IMEDIATAS de uma UF e os municípios (código IBGE) de cada
# uma, uma linha por região:
#
#   <nome_regiao_imediata>\t<codigo_ibge,codigo_ibge,...>
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

my $uf = shift or die "uso: regioes_do_estado.pl <UF>\n";

my $runner = EduMaps::Ingestion::Runner->new(
  config => EduMaps::Ingestion::CLI->load_config(''),
);
my $dbh = $runner->app->schema->storage->dbh;
my $rows = $dbh->selectall_arrayref(
  'SELECT nome_regiao_imediata, codigo_ibge
     FROM clean.municipios_sp
    WHERE sigla_estado = ?
    ORDER BY 1, 2',
  undef, uc $uf);

my %reg;
push @{ $reg{ $_->[0] } }, $_->[1] for @$rows;
die "UF $uf: nenhum município em clean.municipios_sp\n" unless %reg;

print join("\t", $_, join(',', @{ $reg{$_} })), "\n" for sort keys %reg;
