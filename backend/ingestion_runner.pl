#!/usr/bin/env perl
# EduMaps Ingestion Runner
# Uso: perl -Ilib ingestion_runner.pl [--job=NOME] [--schedule=daily] [--list] [--dry-run]
#
# O código de saída é 0 apenas quando todos os jobs executados têm sucesso.

use strict;
use warnings;
use lib 'lib';

use EduMaps::Ingestion::CLI;

exit EduMaps::Ingestion::CLI->run(@ARGV);
