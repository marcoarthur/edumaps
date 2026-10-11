# t/03-plugins/channel/config.t
# Leitura da config dos canais (canais.*) pelo AppConfig e construção do canal
# a partir dela. Só roda onde app_config foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

use ok 'EduMaps::Channel';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('app_config.items')");
my $model = $t->app->model('AppConfig');

my $BACKUP = $ENV{EDUMAPS_CONFIG_MASTER_KEY};

END {
  return unless $has;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do("DELETE FROM app_config.items WHERE key LIKE 'canais.%'");
}

subtest 'validação das folhas novas' => sub {
  plan skip_all => 'app_config.items ausente (migration não aplicada)' unless $has;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY};

  is $model->config_validate('canais.email.smtp_port', '587')->{value}, 587, 'porta numérica';
  is $model->config_validate('canais.email.smtp_port', 'abc')->{error},
    'O valor deve ser um número inteiro.', 'porta inválida';
  is $model->config_validate('canais.whatsapp.provider', 'cloud')->{value}, 'cloud', 'provider cloud';
  is $model->config_validate('canais.whatsapp.provider', 'sms')->{error},
    'Opção inválida para este item.', 'provider inválido';
  is $model->config_validate('canais.email.enabled', 'true')->{value}, 1, 'boolean true';
  is $model->config_validate('canais.email.from', '')->{error},
    'O valor não pode ser vazio.', 'text vazio recusado';
};

subtest 'defaults sem nada definido' => sub {
  plan skip_all => 'app_config.items ausente' unless $has;

  my $email = $model->email_config;
  is $email->{enabled}, 0, 'e-mail desligado por omissão';

  my $wa = $model->whatsapp_config;
  is $wa->{provider}, 'link', 'whatsapp em modo link por omissão';
  is $wa->{enabled}, 0, 'whatsapp desligado por omissão';

  ok !defined $model->channel_config('sms'), 'canal desconhecido -> undef';
};

subtest 'gravado: lê de volta e constrói o canal' => sub {
  plan skip_all => 'app_config.items ausente' unless $has;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  $model->config_put('canais.email.smtp_host', 'smtp.exemplo.org', 'admin@edumaps.test');
  $model->config_put('canais.email.smtp_port', '587', 'admin@edumaps.test');
  $model->config_put('canais.email.from', 'nao-responda@exemplo.org', 'admin@edumaps.test');
  $model->config_put('canais.email.enabled', 'true', 'admin@edumaps.test');
  $model->config_put('canais.email.smtp_password', 'segredo-smtp-123', 'admin@edumaps.test');

  my $cfg = $model->email_config;
  is $cfg->{smtp_host}, 'smtp.exemplo.org', 'host lido';
  is $cfg->{smtp_port}, 587, 'porta como número';
  is $cfg->{enabled}, 1, 'ligado';
  is $cfg->{smtp_password}, 'segredo-smtp-123', 'senha decifrada';

  my $ch = EduMaps::Channel->build_from_config('email', $cfg, schema => $t->app->schema);
  is ref($ch), 'EduMaps::Channel::Email', 'canal construído';
  ok $ch->enabled, 'enabled propagado';
  is $ch->config->{smtp_host}, 'smtp.exemplo.org', 'config propagada';
};

subtest 'canal telegram reusa a config do bot (read-only)' => sub {
  plan skip_all => 'app_config.items ausente' unless $has;

  # Não escreve: confirma que telegram_config espelha o bot já configurado,
  # sem tocar na config real do bot.
  my $bot = $model->bot_telegram_config;
  my $cfg = $model->telegram_config;
  is $cfg->{token}, $bot->{token}, 'token vem do bot';
  is $cfg->{chat_id}, $bot->{chat_id}, 'chat_id vem do bot';
  is $cfg->{enabled}, ($bot->{enabled} // 0), 'enabled vem do bot';
  is ref($model->channel_config('telegram')), 'HASH', 'channel_config despacha telegram';
};

$ENV{EDUMAPS_CONFIG_MASTER_KEY} = $BACKUP if defined $BACKUP;

done_testing;
