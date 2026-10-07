use lib qw(t/lib lib);
use strict;
use warnings;
use Test::More;
use Mojo::Log;
use Mojo::Promise;

use_ok 'EduMaps::Bots::Notifier';

# --- Mocks --------------------------------------------------------------
# MockBot: classe injetada via bot_class — regista chamadas e devolve RES.
{ package MockBot;
  our @NEW;        # args completos recebidos no new
  our @SENT;       # [text, opts] de cada send_text/send_text_p
  our $RES = { ok => 1, status => 200 };

  sub new {
    my ($class, %args) = @_;
    push @NEW, \%args;
    return bless {}, $class;
  }
  sub send_text {
    my ($self, $text, $opts) = @_;
    push @SENT, [$text, $opts];
    return $RES;
  }
  sub send_text_p {
    my ($self, $text, $opts) = @_;
    push @SENT, [$text, $opts];
    return Mojo::Promise->resolve($RES);
  }
}

# MockCfg: responde bot_telegram_config com o hash injetado.
{ package MockCfg;
  sub new { my ($c, $cfg) = @_; bless { cfg => $cfg || {} }, $c }
  sub bot_telegram_config { $_[0]{cfg} }
}

sub make_notifier {
  my %args = @_;
  $MockBot::RES = $args{res} // { ok => 1, status => 200 };
  return EduMaps::Bots::Notifier->new(
    schema     => bless({}, 'MockSchema'),   # não usado: app_config injetado
    log        => Mojo::Log->new,
    app_config => MockCfg->new($args{cfg} || {}),
    bot_class  => 'MockBot',
  );
}

sub reset_bot {
  @MockBot::NEW  = ();
  @MockBot::SENT = ();
  $MockBot::RES  = { ok => 1, status => 200 };
}

my $CFG_OK = {
  enabled         => 1,
  token           => 't0k3n',
  chat_id         => '42',
  allowed_actions => [qw/system_alert ingest_done ingest_stall/],
};

subtest 'ação desconhecida morre (erro de programação)' => sub {
  reset_bot;
  my $n = make_notifier(cfg => $CFG_OK);
  eval { $n->notify('acao_inexistente', 'x') };
  like $@, qr/desconhecida/, 'croak';
  is scalar(@MockBot::SENT), 0, 'nada enviado';
};

subtest 'enabled=0 -> nada enviado' => sub {
  reset_bot;
  my $n = make_notifier(cfg => { enabled => 0, token => 't', chat_id => 'c' });
  is $n->notify('system_alert', 'x'), 0, 'retorna 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';
};

subtest 'ação fora das allowed_actions -> nada enviado' => sub {
  reset_bot;
  my $n = make_notifier(cfg => $CFG_OK);
  is $n->notify('ingest_failed', 'Job X falhou'), 0, 'retorna 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';
};

subtest 'config incompleta (sem token) -> nada enviado' => sub {
  reset_bot;
  my $n = make_notifier(cfg => {
    enabled         => 1,
    chat_id         => '42',
    allowed_actions => ['system_alert'],
  });
  is $n->notify('system_alert', 'x'), 0, 'retorna 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';
};

subtest 'ação permitida e habilitada -> envia e retorna 1' => sub {
  reset_bot;
  my $n = make_notifier(cfg => $CFG_OK);
  my $r = $n->notify('ingest_stall', 'Job IBGE parado');
  is $r, 1, 'retorna 1';
  is scalar(@MockBot::SENT), 1, '1 envio';
  is $MockBot::SENT[0][0], 'Job IBGE parado', 'texto enviado';
  is $MockBot::SENT[0][1]{action}, 'ingest_stall', 'ação passada ao envio';
  is $MockBot::NEW[0]{config}{telegram_token},   't0k3n', 'token decifrado usado';
  is $MockBot::NEW[0]{config}{telegram_chat_id}, '42',    'chat id usado';
  is $MockBot::NEW[0]{enabled}, 1, 'bot habilitado';
};

subtest 'API recusa -> retorna 0 sem morrer' => sub {
  reset_bot;
  my $n = make_notifier(cfg => $CFG_OK, res => { ok => 0, status => 503, error => 'busy' });
  is $n->notify('ingest_done', 'x'), 0, 'retorna 0';
};

subtest 'config ausente (means enabled=0) -> nada enviado' => sub {
  reset_bot;
  my $n = make_notifier(cfg => {});
  is $n->notify('ingest_done', 'x'), 0, 'retorna 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';
};

subtest 'notify_p: mesma política, resolve 1/0 via send_text_p' => sub {
  # ação desconhecida: croak SÍNCRONO (antes de qualquer promise)
  reset_bot;
  my $n = make_notifier(cfg => $CFG_OK);
  eval { $n->notify_p('acao_inexistente', 'x') };
  like $@, qr/desconhecida/, 'croak síncrono p/ ação fora da whitelist';

  # permitida + habilitada -> resolve 1
  reset_bot;
  $n = make_notifier(cfg => $CFG_OK);
  my $r;
  $n->notify_p('ingest_stall', 'Job IBGE parado')->then(sub { my ($v) = @_; $r = $v })->wait;
  is $r, 1, 'resolve 1';
  is $MockBot::SENT[0][0], 'Job IBGE parado', 'texto enviado';
  is $MockBot::SENT[0][1]{action}, 'ingest_stall', 'ação passada ao envio';

  # enabled=0 -> resolve 0, nada enviado
  reset_bot;
  $n = make_notifier(cfg => { enabled => 0, token => 't', chat_id => 'c' });
  $r = undef;
  $n->notify_p('system_alert', 'x')->then(sub { my ($v) = @_; $r = $v })->wait;
  is $r, 0, 'enabled=0 resolve 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';

  # fora das allowed_actions -> resolve 0
  reset_bot;
  $n = make_notifier(cfg => $CFG_OK);
  $r = undef;
  $n->notify_p('ingest_failed', 'x')->then(sub { my ($v) = @_; $r = $v })->wait;
  is $r, 0, 'fora das allowed resolve 0';
  is scalar(@MockBot::SENT), 0, 'nada enviado';

  # API recusa -> resolve 0 sem morrer
  reset_bot;
  $n = make_notifier(cfg => $CFG_OK, res => { ok => 0, status => 503, error => 'busy' });
  $r = undef;
  $n->notify_p('ingest_done', 'x')->then(sub { my ($v) = @_; $r = $v })->wait;
  is $r, 0, 'API recusa resolve 0';
};

done_testing;