#!/usr/bin/env perl
# EduMaps Ingestion Runner
# Uso: perl -Ilib ingestion_runner.pl [--job=NOME] [--arg chave=valor ...] [--schedule=daily] [--list] [--dry-run]
#
# Saída: 0 = todos com sucesso; 1 = alguma falha; 3 = fonte(s) NÃO CARREGADA(S)
# por bloqueio conhecido (e-SIC, API retirada, fora do objetivo); 2 = uso inválido.
# Ver `--help`.

use strict;
use warnings;
use lib 'lib';

use EduMaps::Ingestion::CLI;

exit EduMaps::Ingestion::CLI->run(@ARGV);
