# t/03-plugins/channel/whatsapp.t
# Canal WhatsApp: normalização do telefone brasileiro, provedor `link` (stub,
# sem envio) e guardas do provedor `cloud`.
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::WhatsApp';

my $link = EduMaps::Channel::WhatsApp->new(config => { provider => 'link' }, schema => undef);
is $link->name, 'whatsapp', 'nome';
is $link->address_kind, 'phone', 'tipo de endereço';

subtest 'normalização do telefone' => sub {
  is $link->validate_address('+55 (11) 99999-0001')->{normalized}, '5511999990001', 'com DDI';
  is $link->validate_address('11999990001')->{normalized}, '5511999990001', 'sem DDI: prefixa 55';
  is $link->validate_address('(11) 3333-4444')->{normalized}, '551133334444', 'telefone fixo';
  is $link->validate_address('00 55 11 99999 0001')->{normalized}, '5511999990001', 'prefixo 00 removido';
  ok !$link->validate_address('123')->{ok}, 'curto inválido';
  ok !$link->validate_address('')->{ok},    'vazio inválido';
};

subtest 'provedor link: stub com wa.me, sem confirmação' => sub {
  ok !$link->supports_confirm, 'link não confirma';

  my $res = $link->send_message({
    to => '11999990001', operacao => 'convite', assunto => 'Oi', corpo => 'Vamos!',
  });
  ok $res->{ok}, 'ok';
  ok $res->{stub}, 'marcado como stub';
  is $res->{provider}, 'link', 'provider link';
  like $res->{wa_link}, qr{^https://wa\.me/5511999990001\?}, 'wa.me do número normalizado';
  like $res->{wa_link}, qr{text=}, 'com texto na query';
};

subtest 'provedor cloud: guardas' => sub {
  my $cloud = EduMaps::Channel::WhatsApp->new(config => { provider => 'cloud' }, schema => undef);
  my $res = $cloud->send_message({ to => '11999990001', operacao => 'aviso', corpo => 'x' });
  ok !$res->{ok}, 'sem token falha';
  is $res->{error}, 'WhatsApp Cloud: token ausente', 'erro de token';

  my $cloud2 = EduMaps::Channel::WhatsApp->new(
    config => { provider => 'cloud', token => 'T', phone_number_id => '1' }, schema => undef);
  ok $cloud2->supports_confirm, 'com token/número, capacidade de confirmação';
};

done_testing;
