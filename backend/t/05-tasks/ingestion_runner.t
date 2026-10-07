use lib qw(t/lib lib);
use strict;
use warnings;
use Test::More;
use Mojo::Home;
use Mojo::File;
use Mojo::Log;
use Mojo::File qw(path);
use File::Temp qw(tempdir);
use Cwd qw(getcwd);

use_ok('EduMaps::Ingestion::Runner');
use_ok('EduMaps::Ingestion::CLI');

my $IBGE = 'EduMaps::Ingestion::Job::IBGE';

{
  package TesteDBH;
  sub selectall_arrayref { $_[0]{rows} }
  sub do  { die "ESCREVEU NA BD EM DRY-RUN\n" }
  sub txn_do { die "ESCREVEU NA BD EM DRY-RUN\n" }
}
{ package TesteStorage; sub dbh { $_[0]{dbh} } }
{ package TesteSchema;  sub storage { $_[0]{storage} } }
{ package TesteApp;     sub schema  { $_[0]{schema} } }

sub mock_app {
  my ($rows) = @_;
  my $dbh    = bless { rows => $rows }, 'TesteDBH';
  my $store  = bless { dbh => $dbh },   'TesteStorage';
  my $schema = bless { storage => $store }, 'TesteSchema';
  bless { schema => $schema }, 'TesteApp';
}

my $JSON_SIDRA = [
  [ { id => 'header' } ],
  { D3C => 2022, D2C => 37, V => '1000', MN => 'R$ milhoes' },
  { D3C => 2021, D2C => 37, V => '900',  MN => 'R$ milhoes' },
];

{ package TesteRes; sub new { bless { json => $_[1] }, $_[0] } sub code { 200 } sub json { $_[0]{json} } }
{ package TesteTx;  sub new { bless { json => $_[1] }, $_[0] } sub res  { TesteRes->new($_[0]{json}) } }
{ package TesteUA;  sub new { bless {}, $_[0] } sub get { TesteTx->new($JSON_SIDRA) } }

my @MUNICIPIOS = (
  { codigo_ibge => '3550308', sigla_uf => 'SP', nome_municipio => 'Sao Paulo' },
  { codigo_ibge => '3304557', sigla_uf => 'RJ', nome_municipio => 'Rio de Janeiro' },
);

subtest '1. Runner passa app ao job' => sub {
  my $app = mock_app(\@MUNICIPIOS);
  my $runner = EduMaps::Ingestion::Runner->new(app => $app, log => Mojo::Log->new);
  $runner->load_jobs(['IBGE']);
  my $job = $runner->jobs->{IBGE};
  isa_ok $job, $IBGE;
  my $r = eval { $job->app };
  is $@, '', 'app acessível';
  is $r, $app, 'app passado';
};

subtest '2. lista de jobs derivada do directório' => sub {
  my @nomes = EduMaps::Ingestion::Runner->job_names;
  ok((grep { $_ eq 'IBGE' } @nomes), 'IBGE presente');
  ok(!(grep { $_ eq 'Base' } @nomes), 'Base ausente');
  opendir my $dh, 'lib/EduMaps/Ingestion/Job' or die $!;
  my @esperados = sort map { s/\.pm\z//r } grep { $_ ne 'Base.pm' && /\.pm\z/ } readdir $dh;
  closedir $dh;
  is_deeply \@nomes, \@esperados, 'lista bate com diretório';
};

subtest '3. print_results retorna nº de falhas' => sub {
  is(EduMaps::Ingestion::CLI->print_results([{job=>'A',success=>0,duration=>1,error=>'boom'}]), 1, '1 falha => 1');
  is(EduMaps::Ingestion::CLI->print_results([{job=>'B',success=>1,duration=>1},{job=>'C',success=>1,duration=>1}]), 0, '2 OK => 0');
  is(EduMaps::Ingestion::CLI->print_results([{job=>'D',success=>1,duration=>1},{job=>'E',success=>0,duration=>1,error=>'boom'}]), 1, 'misto => 1');
};

subtest '4. --config carregado e propagado' => sub {
  is_deeply(EduMaps::Ingestion::CLI->load_config(''), {}, 'vazio');
  my $tmpc = tempdir;
  my $f = path($tmpc, 'c.pl'); $f->spurt("return { dir_trabalho => '/tmp/x' };\n");
  my $c = EduMaps::Ingestion::CLI->load_config("$f");
  is $c->{dir_trabalho}, '/tmp/x', 'carrega';
  eval { EduMaps::Ingestion::CLI->load_config('/nao/existe.conf') };
  like $@, qr/encontrado|exist/, 'morre alto';
  my $runner = EduMaps::Ingestion::Runner->new(
    app    => mock_app([]),
    config => { dir_trabalho => '/tmp/chegou' },
    log    => Mojo::Log->new,
  );
  $runner->load_jobs(['IBGE']);
  is $runner->jobs->{IBGE}->config->{dir_trabalho}, '/tmp/chegou',
    'propaga';
};

subtest '5. dry-run IBGE corre cadeia sem escrever na BD' => sub {
  my $tmp = tempdir(CLEANUP=>1);
  my $job = $IBGE->new(log=>Mojo::Log->new,dry_run=>1,app=>mock_app(\@MUNICIPIOS),ua=>bless({},'TesteUA'),config=>{dir_trabalho=>$tmp});
  my $rc; my $morreu = !eval { $rc = $job->run; 1 };
  ok !$morreu, 'não morre' or diag $@;
  ok -f "$tmp/municipios.csv", 'municipios.csv';
  ok -f "$tmp/dados_ibge.csv", 'dados_ibge.csv';
  ok -f "$tmp/ibge_agregados.csv", 'ibge_agregados.csv';
  is $rc, 8, 'contagem 8';
};

subtest '6. exit code != 0 quando job falha' => sub {
  my $tmp = tempdir;
  my $mod = path($tmp, 'EduMaps', 'Ingestion', 'Job');
  $mod->make_path;
  $mod->child('ZZTesteFalha.pm')->spurt(<<'PM');
package EduMaps::Ingestion::Job::ZZTesteFalha;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
has job_name => 'ZZTesteFalha';
has description => 'falha';
has schedule => 'manual';
sub run ($self, $args = {}) { die "falha deliberada\n" }
1;
PM
  my $cwd = getcwd();
  my $chdir_ok = chdir 'backend';
  my $saida = `$^X -I$tmp -Ilib ingestion_runner.pl --job=ZZTesteFalha 2>&1`;
  my $exit = $? >> 8;
  chdir $cwd if $chdir_ok;
  isnt $exit, 0, "exit != 0 (foi $exit)";
  like $saida, qr/falha(s)?/, 'reporta falhas';
};


subtest '7. Detecta stall (sem progresso) e aborta com exit != 0' => sub {
  my $tmp = tempdir;
  my $mod = path($tmp, 'EduMaps', 'Ingestion', 'Job');
  $mod->make_path;
  $mod->child('ZZStall.pm')->spurt(<<'PM');
package EduMaps::Ingestion::Job::ZZStall;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
has job_name     => 'ZZStall';
has description  => 'stall';
has schedule     => 'manual';
sub run ($self, $args = {}) { sleep 3; return 1 }
1;
PM
  my $cwd = getcwd();
  my $chdir_ok = chdir 'backend';
  my $saida = `$^X -I$tmp -Ilib ingestion_runner.pl --job=ZZStall --stall-timeout=1 --stall-check-interval=1 2>&1`;
  my $exit = $? >> 8;
  chdir $cwd if $chdir_ok;
  isnt $exit, 0, "exit != 0 (foi $exit)";
  like $saida, qr/\[STALL\]/, 'mensagem de stall emitida';
};

{ package ZZJobOK;
  sub new { bless {}, $_[0] }
  sub run { return 1 }
}
{ package ZZJobFalha;
  sub new { bless {}, $_[0] }
  sub run { die "falha deliberada\n" }
}
{ package ZZJobStall;
  sub new { bless {}, $_[0] }
  sub run { die "[STALL] Sem progresso há 601s (timeout 600s). dir=data/ingestao sig=abc\n" }
}
{ package MockNotifier;
  sub new { bless { calls => [] }, $_[0] }
  sub notify { my ($self, $action, $text) = @_; push @{$self->{calls}}, [$action, $text]; return 1 }
}

subtest '8. run_job notifica ingest_done no sucesso' => sub {
  my $notifier = MockNotifier->new;
  my $runner = EduMaps::Ingestion::Runner->new(
    app       => mock_app([]),
    log       => Mojo::Log->new,
    notifier  => $notifier,
    stall_timeout => 0,
  );
  $runner->jobs->{ZZOK} = ZZJobOK->new;
  my $r = $runner->run_job('ZZOK');
  is $r->{success}, 1, 'job OK';
  is scalar(@{$notifier->{calls}}), 1, '1 notificação';
  is $notifier->{calls}[0][0], 'ingest_done', 'ação ingest_done';
  like $notifier->{calls}[0][1], qr/ZZOK/, 'texto cita o job';
};

subtest '9. run_job notifica ingest_failed na falha' => sub {
  my $notifier = MockNotifier->new;
  my $runner = EduMaps::Ingestion::Runner->new(
    app       => mock_app([]),
    log       => Mojo::Log->new,
    notifier  => $notifier,
    stall_timeout => 0,
  );
  $runner->jobs->{ZZFalha} = ZZJobFalha->new;
  my $r = $runner->run_job('ZZFalha');
  is $r->{success}, 0, 'job falhou';
  is scalar(@{$notifier->{calls}}), 1, '1 notificação';
  is $notifier->{calls}[0][0], 'ingest_failed', 'ação ingest_failed';
  like $notifier->{calls}[0][1], qr/falha deliberada/, 'texto cita o erro';
};

subtest '10. run_job notifica ingest_stall quando erro tem [STALL]' => sub {
  my $notifier = MockNotifier->new;
  my $runner = EduMaps::Ingestion::Runner->new(
    app       => mock_app([]),
    log       => Mojo::Log->new,
    notifier  => $notifier,
    stall_timeout => 0,
  );
  $runner->jobs->{ZZStall2} = ZZJobStall->new;
  my $r = $runner->run_job('ZZStall2');
  is $r->{success}, 0, 'job falhou';
  is scalar(@{$notifier->{calls}}), 1, '1 notificação';
  is $notifier->{calls}[0][0], 'ingest_stall', 'ação ingest_stall';
  like $notifier->{calls}[0][1], qr/\[STALL\]/, 'texto cita stall';
};

done_testing();
