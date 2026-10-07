use Mojo::Base -base;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

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

done_testing;
