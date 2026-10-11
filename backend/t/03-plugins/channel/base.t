# t/03-plugins/channel/base.t
# Template method da classe base dos canais: validação/normalização de endereço,
# orquestração do envio (queued -> sent/failed), eventos e confirmação. Sem
# banco: `schema => undef` torna histórico e confirmação inertes.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::Base';

# Subclasse de teste: valida [a-z0-9]+ e sempre entrega com sucesso.
{
  package ChannelTest::Echo;
  use Mojo::Base 'EduMaps::Channel::Base', -signatures;
  sub name             { 'echo' }
  sub address_kind     { 'text' }
  sub _address_regex   ($self) { qr/^[a-z0-9]+$/ }
  sub _normalize_address ($self, $a) { lc $a }
  sub _deliver ($self, $m) { { ok => 1, provider_message_id => 'echo-' . $m->{to} } }
}

# Transporte que devolve falha explícita.
{
  package ChannelTest::Boom;
  use Mojo::Base 'EduMaps::Channel::Base', -signatures;
  sub name             { 'boom' }
  sub _address_regex   ($self) { qr/^[a-z0-9]+$/ }
  sub _normalize_address ($self, $a) { lc $a }
  sub _deliver ($self, $m) { { ok => 0, error => 'quebrou' } }
}

# Transporte que morre (deve virar falha, nunca propagar a exceção).
{
  package ChannelTest::Die;
  use Mojo::Base 'EduMaps::Channel::Base', -signatures;
  sub name             { 'die' }
  sub _address_regex   ($self) { qr/^[a-z0-9]+$/ }
  sub _normalize_address ($self, $a) { lc $a }
  sub _deliver ($self, $m) { die "explosao\n" }
}

subtest 'validação e normalização de endereço' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  ok $ch->validate_address('ABC')->{ok}, 'válido';
  is $ch->validate_address('ABC')->{normalized}, 'abc', 'normaliza minúsculas';
  is $ch->validate_address('  x1  ')->{normalized}, 'x1', 'trim';
  ok !$ch->validate_address('a b')->{ok}, 'espaço inválido';
  ok !$ch->validate_address('')->{ok},    'vazio inválido';
  ok !$ch->validate_address(undef)->{ok}, 'undef inválido';
};

subtest 'send_message: sucesso, eventos e resultado' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  my @events;
  for my $name (qw(message.invalid message.queued message.sent message.failed)) {
    $ch->on($name => sub { my ($em, $payload) = @_; push @events, [$name => $payload] });
  }

  my $res = $ch->send_message({ to => 'ABC', operacao => 'aviso', assunto => 'x', corpo => 'y' });
  ok $res->{ok}, 'envio ok';
  is $res->{canal}, 'echo', 'canal no resultado';
  is $res->{to}, 'abc', 'destino normalizado';
  is $res->{operacao}, 'aviso', 'operação';
  is $res->{provider_message_id}, 'echo-abc', 'resposta do transporte';
  is [map { $_->[0] } @events], [qw(message.queued message.sent)], 'eventos na ordem';
};

subtest 'send_message: endereço inválido emite message.invalid' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  my @events;
  for my $name (qw(message.invalid message.queued)) {
    $ch->on($name => sub { push @events, $name });
  }
  my $res = $ch->send_message({ to => '!!!', operacao => 'aviso' });
  ok !$res->{ok}, 'falha';
  is $res->{error}, 'endereço inválido', 'motivo';
  is \@events, ['message.invalid'], 'só invalid';
};

subtest 'send_message: operação inválida e default' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  my $res = $ch->send_message({ to => 'abc', operacao => 'zzz' });
  ok !$res->{ok}, 'operação inválida falha';
  like $res->{error}, qr/operação inválida/, 'mensagem';

  $res = $ch->send_message({ to => 'abc', corpo => 'x' });
  is $res->{operacao}, 'informacao', 'default informacao';
};

subtest 'send_message: falha do transporte' => sub {
  my $ch = ChannelTest::Boom->new(schema => undef);
  my @events;
  for my $name (qw(message.queued message.failed)) {
    $ch->on($name => sub { push @events, $name });
  }
  my $res = $ch->send_message({ to => 'abc', operacao => 'alerta' });
  ok !$res->{ok}, 'transporte falhou';
  is $res->{error}, 'quebrou', 'erro propagado';
  is \@events, [qw(message.queued message.failed)], 'eventos failed';
};

subtest 'send_message: exceção no transporte vira falha' => sub {
  my $ch = ChannelTest::Die->new(schema => undef);
  my $res = $ch->send_message({ to => 'abc', operacao => 'alerta' });
  ok !$res->{ok}, 'die vira falha';
  like $res->{error}, qr/explosao/, 'mensagem do die';
};

subtest 'send_message_p: caminho assíncrono' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  my $done;
  $ch->send_message_p({ to => 'ABC', operacao => 'aviso' })
    ->then(sub ($r) {
      $done = $r;
      ok $r->{ok}, 'async ok';
      is $r->{to}, 'abc', 'async normaliza';
      is $r->{operacao}, 'aviso', 'async operacao';
    })->catch(sub ($err) { fail "promise rejeitou: $err" })->wait;
  ok $done, 'promise resolvida';
};

subtest 'capacidades e confirmação sem banco' => sub {
  my $ch = ChannelTest::Echo->new(schema => undef);
  ok $ch->can_send, 'can_send com enabled';
  ok !$ch->can_confirm, 'sem schema não confirma';
  my $r = $ch->confirm_start('abc');
  ok !$r->{ok}, 'confirm_start recusa';
  $r = $ch->confirm_check('abc', '123456');
  ok !$r->{ok}, 'confirm_check recusa';

  my $off = ChannelTest::Echo->new(enabled => 0, schema => undef);
  ok !$off->can_send, 'can_send=0 quando desabilitado';
};

done_testing;
