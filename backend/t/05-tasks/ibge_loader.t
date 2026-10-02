use lib qw(t/lib lib);
use strict;
use warnings;
use Test::More;
use Mojo::Log;
use File::Temp qw(tempdir);

# Teste básico do job IBGE/SIDRA
my $JOB = 'EduMaps::Ingestion::Job::IBGE';
require_ok($JOB);

sub job { return $JOB->new(log => Mojo::Log->new) }

ok(defined job(), 'instancia job IBGE');
is(job()->job_name, 'IBGE', 'nome do job correto');
is(job()->tabela_pib, '5938', 'tabela SIDRA correta');

done_testing();
