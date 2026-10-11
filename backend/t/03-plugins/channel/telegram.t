# t/03-plugins/channel/telegram.t
# Canal Telegram: validação/normalização do chat_id e delegação ao bot
# existente (EduMaps::Bots::Telegram) — aqui com um bot falso injetado.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::Telegram';

{
  package TelegramTest::Bot;
  use Mojo::Base -base, -signatures;
  our $LAST;
  sub send_text ($self, $text, $opts = {}) {
    $LAST = { text => $text, opts => $opts };
    return { ok => 1, status => 200 };
  }
  sub send_text_p ($self, $text, $opts = {}) {
    $LAST = { text => $text, opts => $opts };
    return Mojo::Promise->resolve({ ok => 1, status => 200 });
  }
}

my $ch = EduMaps::Channel::Telegram->new(
  config => { token => 'TOKEN' }, schema => undef, bot_class => 'TelegramTest::Bot');

is $ch->name, 'telegram', 'nome';
is $ch->address_kind, 'chat_id', 'tipo de endereço';
ok $ch->supports_confirm, 'telegram suporta confirmação';

subtest 'validação e normalização' => sub {
  ok $ch->validate_address('-1001234567890')->{ok}, 'chat_id de grupo';
  ok $ch->validate_address('@edumaps_bot')->{ok}, '@username válido';
  is $ch->validate_address(' https://t.me/edumaps_bot ')->{normalized}, '@edumaps_bot',
    'link t.me -> @username';
  ok !$ch->validate_address('nome com espaço')->{ok}, 'inválido';
  ok !$ch->validate_address('')->{ok}, 'vazio inválido';
};

subtest 'token ausente falha de forma explícita' => sub {
  my $notoken = EduMaps::Channel::Telegram->new(
    config => {}, schema => undef, bot_class => 'TelegramTest::Bot');
  my $res = $notoken->send_message({ to => '-1001234567890', operacao => 'alerta', corpo => 'x' });
  ok !$res->{ok}, 'falha';
  is $res->{error}, 'Telegram: token ausente', 'erro explícito';
};

subtest 'delega ao bot (síncrono)' => sub {
  $TelegramTest::Bot::LAST = undef;
  my $res = $ch->send_message({
    to => '-1001234567890', operacao => 'alerta', assunto => 'Aviso', corpo => 'Ping',
  });
  ok $res->{ok}, 'envio ok';
  is $TelegramTest::Bot::LAST->{opts}{chat_id}, '-1001234567890', 'chat_id repassado';
  is $TelegramTest::Bot::LAST->{text}, "Aviso\n\nPing", 'texto = assunto + corpo';
};

subtest 'delega ao bot (assíncrono)' => sub {
  $TelegramTest::Bot::LAST = undef;
  $ch->send_message_p({ to => '-1001234567890', operacao => 'alerta', corpo => 'Async' })
    ->then(sub ($r) {
      ok $r->{ok}, 'async ok';
      is $TelegramTest::Bot::LAST->{text}, 'Async', 'texto async';
    })->catch(sub ($err) { fail "promise rejeitou: $err" })->wait;
  ok $TelegramTest::Bot::LAST, 'bot chamado';
};

done_testing;
