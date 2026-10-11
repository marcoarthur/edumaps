# t/03-plugins/channel/factory.t
# Fábrica de canais: tipos conhecidos, carga sob demanda e construção a partir
# de um hashref de config (saída de AppConfig->channel_config).
use lib qw(t/lib lib);
use Imports;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel';

is(EduMaps::Channel->types, [qw(email telegram whatsapp)],
  'tipos disponíveis (ordem)');

ok(EduMaps::Channel->is_valid_type('email'), 'email válido');
ok(!EduMaps::Channel->is_valid_type('sms'),  'sms inválido');
ok(!EduMaps::Channel->is_valid_type(undef),  'undef inválido');

my $email = EduMaps::Channel->build('email', config => {});
is ref($email), 'EduMaps::Channel::Email', 'build email';
is $email->name, 'email', 'nome imposto pela fábrica';
ok $email->isa('EduMaps::Channel::Base'), 'herda da base';

my $tg = EduMaps::Channel->build('telegram', config => {});
is ref($tg), 'EduMaps::Channel::Telegram', 'build telegram';

my $ok = eval { EduMaps::Channel->build('pombo', config => {}); 1 };
ok !$ok, 'tipo desconhecido falha';
like $@, qr/Canal desconhecido/, 'mensagem de erro';

my $wa = EduMaps::Channel->build_from_config('whatsapp', { provider => 'cloud', enabled => 1 });
is ref($wa), 'EduMaps::Channel::WhatsApp', 'build_from_config';
is $wa->config->{provider}, 'cloud', 'config propagada';
is $wa->enabled, 1, 'enabled=1 respeitado';

my $wa2 = EduMaps::Channel->build_from_config('whatsapp', { provider => 'link' });
is $wa2->enabled, 1, 'enabled ausente assume habilitado';

my $wa3 = EduMaps::Channel->build_from_config('whatsapp', { enabled => 0 });
is $wa3->enabled, 0, 'enabled=0 respeitado';

done_testing;
