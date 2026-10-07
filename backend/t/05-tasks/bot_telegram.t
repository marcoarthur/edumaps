use Mojo::Base -base;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mojo::Promise;

require_ok 'EduMaps::Bots::Base';
require_ok 'EduMaps::Bots::Role::Sender';
require_ok 'EduMaps::Config::Bot';
require_ok 'EduMaps::Bots::Policy::Actions';
require_ok 'EduMaps::Bots::Telegram';

subtest 'Base: can_send/can_receive' => sub {
  my $b = EduMaps::Bots::Base->new;
  is $b->can_send, 0, 'disabled by default';
  is $b->can_receive, 0, 'fase 1: receive disabled';
  $b->enabled(1);
  is $b->can_send, 1, 'enabled';
};

subtest 'Config::Bot: ação permitida' => sub {
  my $cfg = EduMaps::Config::Bot->new(allowed_actions => ['system_alert', 'ingest_done']);
  ok $cfg->is_action_allowed('system_alert');
  ok !$cfg->is_action_allowed('other');
  my $empty = EduMaps::Config::Bot->new;
  ok !$empty->is_action_allowed('system_alert'), 'sem lista = nada permitido';
};

subtest 'Policy::Actions: lista e validação' => sub {
  my $avail = EduMaps::Bots::Policy::Actions->available;
  ok ref $avail eq 'ARRAY' && @$avail > 0, 'lista disponível';
  ok EduMaps::Bots::Policy::Actions->is_valid('ingest_stall');
  ok !EduMaps::Bots::Policy::Actions->is_valid('nonsense');
  # Ações da categoria system.bot.* (issue #188)
  for my $a (qw/system_bot_info system_bot_warn system_bot_error system_bot_trace/) {
    ok EduMaps::Bots::Policy::Actions->is_valid($a), "$a válida na whitelist";
    ok scalar(grep { $_ eq $a } @$avail), "$a disponível no multiselect";
  }
};

subtest 'Telegram: falha sem token/chat_id, sem enviar' => sub {
  my $tg = EduMaps::Bots::Telegram->new(config => {});
  eval { $tg->send_text('x') };
  like $@, qr/token/, 'token em falta';
  $tg->config({telegram_token => 'fake', telegram_chat_id => ''});
  eval { $tg->send_text('x') };
  like $@, qr/chat_id/, 'chat_id em falta';
};

subtest 'Telegram: can_receive falso (fase 1)' => sub {
  my $tg = EduMaps::Bots::Telegram->new;
  ok !$tg->can_receive;
};

{ package TesteResErro;
  # is_success falso sem resposta HTTP (falha de conexão: code/message undef)
  sub new { bless {}, $_[0] }
  sub is_success { 0 }
  sub code    { undef }
  sub message { undef }
}
{ package TesteTxErro;
  sub new { my ($c, $r) = @_; bless { res => $r, error => { message => 'Connect timeout' } }, $c }
  sub res { $_[0]{res} }
  sub error { $_[0]{error} }
}
{ package TesteUAErro;
  sub new { bless {}, $_[0] }
  sub post { TesteTxErro->new(TesteResErro->new) }
}

subtest 'Telegram: erro de conexão reporta causa (não perde diagnóstico)' => sub {
  my $tg = EduMaps::Bots::Telegram->new(
    ua     => TesteUAErro->new,
    config => { telegram_token => 't', telegram_chat_id => 'c' },
  );
  my $res = $tg->send_text('x');
  is $res->{ok}, 0, 'não ok';
  is $res->{status}, 0, 'status 0 (sem resposta HTTP)';
  like $res->{error}, qr/Connect timeout/, 'causa presente';
};

# --- send_text_p (assíncrono via post_p + Mojo::Promise) ------------------

{ package TesteResOk;
  sub new { bless {}, $_[0] }
  sub is_success { 1 }
  sub code    { 200 }
  sub message { 'OK' }
}
{ package TesteTxOk;
  sub new { my ($c, $r) = @_; bless { res => $r }, $c }
  sub res { $_[0]{res} }
  sub error { undef }
}
{ package TesteResRecusa;
  sub new { bless {}, $_[0] }
  sub is_success { 0 }
  sub code    { 503 }
  sub message { 'busy' }
}
{ package TesteTxRecusa;
  sub new { my ($c, $r) = @_; bless { res => $r }, $c }
  sub res { $_[0]{res} }
  sub error { undef }
}
{ package TesteUAP;
  our $TX;
  sub new { bless {}, $_[0] }
  sub post_p { Mojo::Promise->resolve($TX) }
}
{ package TesteUAPRejeita;
  sub new { bless {}, $_[0] }
  sub post_p { Mojo::Promise->reject('dns fail') }
}

subtest 'Telegram: send_text_p assíncrono mapeia resposta (promise)' => sub {
  my $res;
  my $tg = sub {
    EduMaps::Bots::Telegram->new(
      ua     => TesteUAP->new,
      config => { telegram_token => 't', telegram_chat_id => 'c' },
    );
  };

  # sucesso
  $TesteUAP::TX = TesteTxOk->new(TesteResOk->new);
  $tg->()->send_text_p('x')->then(sub { my ($r) = @_; $res = $r })->wait;
  is $res->{ok}, 1, 'sucesso ok';
  is $res->{status}, 200, 'status 200';

  # recusa HTTP
  $TesteUAP::TX = TesteTxRecusa->new(TesteResRecusa->new);
  $tg->()->send_text_p('x')->then(sub { my ($r) = @_; $res = $r })->wait;
  is $res->{ok}, 0, 'recusa HTTP -> não ok';
  is $res->{status}, 503, 'status 503';
  like $res->{error}, qr/busy/, 'mensagem HTTP presente';

  # erro de conexão (post_p resolve com TX; causa em $tx->error)
  $TesteUAP::TX = TesteTxErro->new(TesteResErro->new);
  $tg->()->send_text_p('x')->then(sub { my ($r) = @_; $res = $r })->wait;
  is $res->{ok}, 0, 'erro de conexão -> não ok';
  is $res->{status}, 0, 'status 0';
  like $res->{error}, qr/Connect timeout/, 'causa real presente';

  # post_p rejeita (hard failure) -> resolve {ok=>0} sem rejeitar
  my $tg2 = EduMaps::Bots::Telegram->new(
    ua     => TesteUAPRejeita->new,
    config => { telegram_token => 't', telegram_chat_id => 'c' },
  );
  $tg2->send_text_p('x')->then(sub { my ($r) = @_; $res = $r })->wait;
  is $res->{ok}, 0, 'rejeição do post_p vira não ok';
  is $res->{status}, 0, 'status 0';
  like $res->{error}, qr/dns fail/, 'causa da rejeição';
};

done_testing;
