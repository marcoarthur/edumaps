# t/03-plugins/channel/confirmation.t
# Confirmação de posse de endereço: `start` gera e guarda apenas o hash do
# código; `verify` confere com limite de tentativas, validade e invalidação do
# pedido anterior. Só roda onde a migration canal_confirmacoes foi aplicada.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Schema;
use EduMaps::Channel::Confirmation;

my $schema = eval { EduMaps::Schema->go };
plan skip_all => 'base indisponível: ' . ($@ // '?') unless $schema;

my $dbh = $schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacoes')");
plan skip_all => 'clean.canal_confirmacoes ausente (migration não aplicada)' unless $has;

my $conf = EduMaps::Channel::Confirmation->new(
  schema => $schema, ttl_seconds => 600, max_attempts => 3);
my $END_PREFIX = 'conf.test.';

END {
  return unless $schema && $has;
  my $dbh = $schema->storage->dbh;
  local $dbh->{RaiseError} = 0;
  $dbh->do('DELETE FROM clean.canal_confirmacoes WHERE endereco LIKE ?', {}, $END_PREFIX . '%');
}

my $end    = $END_PREFIX . $$;
my $wrong  = sub ($codigo) { $codigo eq '000000' ? '111111' : '000000' };

subtest 'start guarda só o hash e devolve o código' => sub {
  my $r = $conf->start(canal => 'email', endereco => $end);
  ok $r->{ok}, 'start ok';
  ok $r->{id} > 0, 'id devolvido';
  like $r->{codigo}, qr/^\d{6}$/, 'código de 6 dígitos';

  my $row = $dbh->selectrow_hashref(
    'SELECT codigo_hash, salt, confirmado_em, tentativas FROM clean.canal_confirmacoes WHERE id = ?',
    {}, $r->{id});
  isnt $row->{codigo_hash}, $r->{codigo}, 'não guarda o código em claro';
  ok length($row->{salt}) > 0, 'salt presente';
  ok !defined $row->{confirmado_em}, 'pendente';
  is $row->{tentativas}, 0, 'sem tentativas';
};

subtest 'verify aceita o código correto e consome o pedido' => sub {
  my $r = $conf->start(canal => 'email', endereco => $end);
  my $v = $conf->verify(canal => 'email', endereco => $end, codigo => $r->{codigo});
  ok $v->{ok}, 'verificado';
  is $v->{confirmacao_id}, $r->{id}, 'id devolvido';

  my $v2 = $conf->verify(canal => 'email', endereco => $end, codigo => $r->{codigo});
  ok !$v2->{ok}, 'já não há pendente';
  is $v2->{reason}, 'sem pedido pendente', 'motivo';
};

subtest 'verify recusa código errado' => sub {
  my $r = $conf->start(canal => 'email', endereco => $end);
  my $v = $conf->verify(canal => 'email', endereco => $end, codigo => $wrong->($r->{codigo}));
  ok !$v->{ok}, 'recusado';
  is $v->{reason}, 'código inválido', 'motivo';
};

subtest 'bloqueia após max_attempts' => sub {
  my $r = $conf->start(canal => 'email', endereco => $end);
  my $w = $wrong->($r->{codigo});
  $conf->verify(canal => 'email', endereco => $end, codigo => $w) for 1 .. 3;
  my $v = $conf->verify(canal => 'email', endereco => $end, codigo => $r->{codigo});
  ok !$v->{ok}, 'código correto já não passa';
  is $v->{reason}, 'tentativas excedidas', 'motivo';
};

subtest 'novo pedido invalida o pedido pendente anterior' => sub {
  my $r1 = $conf->start(canal => 'whatsapp', endereco => $end);
  my $r2 = $conf->start(canal => 'whatsapp', endereco => $end);

  my $row1 = $dbh->selectrow_hashref(
    'SELECT (expira_em <= NOW()) AS expired FROM clean.canal_confirmacoes WHERE id = ?',
    {}, $r1->{id});
  ok $row1->{expired}, 'pedido anterior expirado';

  my $v = $conf->verify(canal => 'whatsapp', endereco => $end, codigo => $r2->{codigo});
  ok $v->{ok}, 'novo pedido verifica';
};

subtest 'pedido expirado não verifica' => sub {
  my $r = $conf->start(canal => 'telegram', endereco => $end);
  $dbh->do(
    q{UPDATE clean.canal_confirmacoes SET expira_em = NOW() - interval '1 second' WHERE id = ?},
    {}, $r->{id});
  my $v = $conf->verify(canal => 'telegram', endereco => $end, codigo => $r->{codigo});
  ok !$v->{ok}, 'expirado recusado';
  is $v->{reason}, 'sem pedido pendente', 'motivo';
};

done_testing;
