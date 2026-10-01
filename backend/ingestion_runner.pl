#!/usr/bin/env perl
# EduMaps Ingestion Runner
# Uso: perl -Ilib ingestion_runner.pl [--job=NOME] [--schedule=daily] [--list] [--dry-run]

use strict;
use warnings;
use lib 'lib';

use EduMaps::Ingestion::CLI;

EduMaps::Ingestion::CLI->run(@ARGV);