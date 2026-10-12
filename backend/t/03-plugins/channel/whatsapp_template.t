# t/03-plugins/channel/whatsapp_template.t
# WhatsApp Cloud (#212, onda 2): código de confirmação por TEMPLATE DE
# AUTENTICAÇÃO (body + botão url "copiar código"); mensagens comuns seguem
# como texto; sem template o canal não é oferecido na confirmação das listas.
# Sem rede (FakeUA).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel::WhatsApp';

my $CFG = { provider => 'cloud', token => 'EAAG-T', phone_number_id => '1234',
            template_confirmacao => 'edumaps_codigo', template_idioma => 'pt_BR' };

subtest 'template_payload: formato da Meta (authentication + copy code)' => sub {
  my $wa = EduMaps::Channel::WhatsApp->new(config => $CFG, schema => undef);
  ok $wa->supports_template_confirm, 'confirma por template';
  is $wa->template_payload('5511944440001', '123456'), {
    messaging_product => 'whatsapp',
    to                => '5511944440001',
    type              => 'template',
    template          => {
      name       => 'edumaps_codigo',
      language   => { code => 'pt_BR' },
      components => [
        { type => 'body', parameters => [ { type => 'text', text => '123456' } ] },
        { type => 'button', sub_type => 'url', index => '0',
          parameters => [ { type => 'text', text => '123456' } ] },
      ],
    },
  }, 'payload';
};

subtest 'envio: código → template; mensagem comum → texto' => sub {
  my $ua = FakeUA->new(responder => sub { (200, { messages => [ { id => 'wamid.X' } ] }) });
  my $wa = EduMaps::Channel::WhatsApp->new(config => $CFG, schema => undef, ua => $ua);

  my $r = $wa->send_message({ to => '11944440001', operacao => 'confirmacao',
                              corpo => 'x', codigo => '654321' });
  ok $r->{ok}, 'ok';
  is $r->{provider_message_id}, 'wamid.X', 'id do provedor';
  my $c = $ua->last_call;
  like $c->{url}, qr{graph\.facebook\.com/v20\.0/1234/messages$}, 'url';
  is $c->{headers}{Authorization}, 'Bearer EAAG-T', 'bearer';
  is $c->{json}{type}, 'template', 'type template';
  is $c->{json}{to}, '5511944440001', 'telefone no formato do canal';
  is $c->{json}{template}{components}[1]{parameters}[0]{text}, '654321', 'código no botão';

  $wa->send_message({ to => '11944440001', operacao => 'aviso', corpo => 'Oi' });
  is $ua->last_call->{json}{type}, 'text', 'comum = texto';
  is $ua->last_call->{json}{text}{body}, 'Oi', 'corpo';

  my $sem = EduMaps::Channel::WhatsApp->new(
    config => { %$CFG, template_confirmacao => undef }, schema => undef, ua => $ua);
  ok !$sem->supports_template_confirm, 'sem template: não confirma por template';
  $sem->send_message({ to => '11944440001', operacao => 'confirmacao', corpo => 'c', codigo => '1' });
  is $ua->last_call->{json}{type}, 'text', 'sem template: texto';

  like $wa->_confirm_template('999888'), qr/edumaps_codigo/, 'corpo do histórico cita o template';
  unlike $wa->_confirm_template('999888'), qr/999888/, '... e não contém o código';
};

subtest 'falha da Meta → ok 0' => sub {
  my $ua = FakeUA->new(responder => sub { (400, { error => { message => 'bad' } }) });
  my $wa = EduMaps::Channel::WhatsApp->new(config => $CFG, schema => undef, ua => $ua);
  my $r = $wa->send_message({ to => '11944440001', operacao => 'confirmacao', corpo => 'x', codigo => '1' });
  ok !$r->{ok}, 'falhou';
  is $r->{status}, 400, 'status';
};

subtest 'disponibilidade: sem template o WhatsApp não é canal de confirmação' => sub {
  my $t = Test::Mojo->new('EduMaps');
  $t->app->log->level('fatal');
  my $dbh = $t->app->schema->storage->dbh;
  plan skip_all => 'app_config ausente' unless $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
  my $m = $t->app->model('Canal');
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';
  my $limpa = sub { $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.whatsapp.%'}) };
  $limpa->();
  $m->config_put('canais.whatsapp.enabled', 'true', 't');
  $m->config_put('canais.whatsapp.provider', 'cloud', 't');
  $m->config_put('canais.whatsapp.token', 'EAAG-token-teste', 't');
  $m->config_put('canais.whatsapp.phone_number_id', '1234', 't');
  ok !grep({ $_->{canal} eq 'whatsapp' } @{ $m->canais_confirmacao_disponiveis }), 'sem template: indisponível';
  $m->config_put('canais.whatsapp.template_confirmacao', 'edumaps_codigo', 't');
  ok scalar(grep { $_->{canal} eq 'whatsapp' } @{ $m->canais_confirmacao_disponiveis }), 'com template: disponível';
  $limpa->();
};

done_testing;
