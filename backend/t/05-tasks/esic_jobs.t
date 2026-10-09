use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use Mojo::Log;

use_ok('EduMaps::Ingestion::Runner');

# #172: os 4 jobs com e-SIC pendente têm de FALHAR com motivo — um stub que
# devolve sucesso é indistinguível de um job que correu e a fonte não tinha
# nada. O CensoEscolar (caminho morto) foi removido e não pode reaparecer na
# lista de jobs (derivada do diretório).
#
# #171 (decisão C) e #170: INMET (API retirada) e MapBiomas (e-SIC para
# token; loader antigo baixava geometria do IBGE) seguem a mesma regra —
# falham alto com o motivo, sem sucesso silencioso.

{ package EsicTesteDBH;     sub selectall_arrayref { $_[0]{rows} } }
{ package EsicTesteStorage; sub dbh     { $_[0]{dbh} } }
{ package EsicTesteSchema;  sub storage { $_[0]{storage} } }
{ package EsicTesteApp;     sub schema  { $_[0]{schema} } }
sub mock_app {
  my $dbh    = bless { rows => [] }, 'EsicTesteDBH';
  my $store  = bless { dbh => $dbh },   'EsicTesteStorage';
  my $schema = bless { storage => $store }, 'EsicTesteSchema';
  bless { schema => $schema }, 'EsicTesteApp';
}

{ package EsicMockNotifier;
  sub new    { bless { calls => [] }, $_[0] }
  sub notify { my ($self, $action, $text) = @_; push @{$self->{calls}}, [$action, $text]; return 1 }
}

my @ESIC_JOBS = qw(FNDE MedidorConectada SecretariasMunicipais INEP);

subtest 'jobs com e-SIC pendente falham com motivo (sem sucesso silencioso)' => sub {
  my $runner = EduMaps::Ingestion::Runner->new(
    app           => mock_app(),
    log           => Mojo::Log->new,
    notifier      => EsicMockNotifier->new,
    stall_timeout => 0,
  );
  $runner->load_jobs(\@ESIC_JOBS);
  for my $name (@ESIC_JOBS) {
    my $r = $runner->run_job($name);
    is $r->{success}, 0, "$name: success=0 (falha explícita)";
    like $r->{error}, qr/e-SIC|e-SICs|secretarias/i, "$name: motivo citado";
    like $r->{error}, qr/docs\/admin\/esic-requests\.md/, "$name: aponta o tracker de e-SIC";
  }
};

subtest 'INMET (decisão #171 C) e MapBiomas (#170) falham com motivo honesto' => sub {
  my $runner = EduMaps::Ingestion::Runner->new(
    app           => mock_app(),
    log           => Mojo::Log->new,
    notifier      => EsicMockNotifier->new,
    stall_timeout => 0,
  );
  $runner->load_jobs([qw(INMET MapBiomas)]);

  my $r = $runner->run_job('INMET');
  is $r->{success}, 0, 'INMET: success=0 (decisão C registrada)';
  like $r->{error}, qr/#171/, 'INMET: cita a decisão';
  like $r->{error}, qr/NÃO CONSTRUÍD[AA]/, 'INMET: declara as tabelas não construídas';
  like $r->{error}, qr/retirada/, 'INMET: motivo = API retirada';

  $r = $runner->run_job('MapBiomas');
  is $r->{success}, 0, 'MapBiomas: success=0 (e-SIC pendente)';
  like $r->{error}, qr/#170/, 'MapBiomas: cita a issue';
  like $r->{error}, qr/e-SIC/, 'MapBiomas: motivo = e-SIC para token';
  like $r->{error}, qr/IBGE/, 'MapBiomas: explica o defeito do loader antigo';
};

subtest 'CensoEscolar removido (caminho morto) e INEP permanece' => sub {
  my @nomes = EduMaps::Ingestion::Runner->job_names;
  ok !(grep { $_ eq 'CensoEscolar' } @nomes), 'CensoEscolar fora da lista (auto-descoberta do diretório)';
  ok  (grep { $_ eq 'INEP' } @nomes), 'INEP segue presente';
};

done_testing;