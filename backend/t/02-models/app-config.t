# t/02-models/app-config.t
# Testes do modelo de configuração global (Painel de Configuração):
# árvore, leitura/gravação de itens, cifragem de segredos e helper do
# Assistente do Censo. Só roda onde app_config foi aplicada.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_table = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('app_config.items')"
);

my $model = $t->app->model('AppConfig');

my $BACKUP_KEY = $ENV{EDUMAPS_CONFIG_MASTER_KEY};

END {
  if ($has_table) {
    my $dbh = $t->app->schema->storage->dbh;
    $dbh->do('DELETE FROM app_config.items WHERE key LIKE $1', {}, 'integrations.assistant_censo.%');
  }
}

subtest 'defaults: teste marcado' => sub {
  plan skip_all => 'app_config.items ausente (migration nao aplicada)'
    unless $has_table;
  pass 'tabela presente';
};

subtest 'config_tree expõe categorias e folhas' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;

  my $tree = $model->config_tree;
  ok ref($tree->{categories}) eq 'ARRAY', 'categories';
  my @labels = map { $_->{label} } @{ $tree->{categories} };
  is(join(',', @labels), 'Sistema,Integrações,Canais de comunicação,Aparência,Comportamento,Outros',
    'categorias corretas');

  my ($canais) = grep { $_->{key} eq 'canais' } @{ $tree->{categories} };
  ok $canais, 'categoria canais';
  my ($email_grp) = grep { $_->{key} eq 'canais_email' } @{ $canais->{children} };
  ok $email_grp, 'grupo e-mail';
  my ($email_host) = grep { $_->{key} eq 'canais.email.smtp_host' } @{ $email_grp->{children} };
  ok $email_host, 'folha smtp_host';
  is $email_host->{type}, 'text', 'smtp_host é text';
  my ($wa_grp) = grep { $_->{key} eq 'canais_whatsapp' } @{ $canais->{children} };
  ok $wa_grp, 'grupo whatsapp';
  my ($provider) = grep { $_->{key} eq 'canais.whatsapp.provider' } @{ $wa_grp->{children} };
  is $provider->{type}, 'select', 'provider é select';
  is $provider->{options}, [qw(link cloud)], 'opções de provider';
  # A autoinscrição por QR está ativa (#208): as folhas são editáveis no painel,
  # não "Em breve".
  my ($insc_grp) = grep { $_->{key} eq 'canais_inscricao' } @{ $canais->{children} };
  ok $insc_grp, 'grupo autoinscrição';
  is scalar(grep { $_->{enabled} } @{ $insc_grp->{children} }), 4,
    'folhas de canais.inscricao.* habilitadas';

  my ($integ) = grep { $_->{key} eq 'integracoes' } @{ $tree->{categories} };
  ok $integ, 'categoria integracoes';
  my ($assistente) = grep { $_->{key} eq 'assistant_censo' } @{ $integ->{children} };
  ok $assistente, 'grupo assistant_censo';
  my ($chaves) = grep { $_->{key} eq 'integrations.assistant_censo.api_key' } @{ $assistente->{children} };
  ok $chaves, 'folha chaves';
  is $chaves->{type}, 'secret', 'type secret';
  ok $chaves->{sensitive}, 'sensitive';
  ok $chaves->{enabled}, 'habilitada';
  ok !$chaves->{value}{set}, 'ainda não definida';
};

subtest 'is_config_key' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;
  ok $model->is_config_key('integrations.assistant_censo.api_key'), 'api_key conhecida';
  ok !$model->is_config_key('foo.bar'), 'chave desconhecida';
};

subtest 'gravar segredo (cifrado) e ler mascarado' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  my $ok = $model->config_put('integrations.assistant_censo.api_key', 'sk-teste-1234567890', 'admin@edumaps.test');
  ok $ok, 'gravou segredo';

  my $item = $model->config_item('integrations.assistant_censo.api_key');
  is ref($item->{value}), 'HASH', 'valor é envelope';
  ok $item->{value}{set}, 'set=1';
  ok !exists $item->{value}{plaintext}, 'plaintext nunca presente';
  is $item->{updated_by}, 'admin@edumaps.test', 'auditoria updated_by';

  # no banco, o segredo está cifrado (não é o plaintext).
  my $row = $t->app->schema->storage->dbh->selectrow_hashref(
    'SELECT ENCODE(secret, \'hex\') AS secret, sensitive, secret_key_version FROM app_config.items WHERE key = ?',
    {}, 'integrations.assistant_censo.api_key',
  );
  ok defined $row->{secret} && length $row->{secret} > 0, 'secret bytea não vazio';
  ok $row->{sensitive}, 'sensitive=TRUE no banco';
  is $row->{secret_key_version}, 1, 'secret_key_version 1';
  ok index($row->{secret}, 'sk-teste-') == -1, 'ciphertext não contém o plaintext';
};

subtest 'gravar EXIGE master key' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY};
  delete $ENV{EDUMAPS_CONFIG_MASTER_KEY};

  my $died = eval {
    $model->config_put('integrations.assistant_censo.api_key', 'sk-teste-1234567890', 'a@b');
    0;
  };
  ok !defined $died, 'config_put falha (croak) sem master key';
};

subtest 'config_validate valida por tipo' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;
  is $model->config_validate('integrations.assistant_censo.api_key', 'curta')->{error},
    'A chave não pode ser vazia.', 'chave curta rejeitada';
  ok !$model->config_validate('integrations.assistant_censo.api_key', 'sk-teste-muito-longa')->{error},
    'chave válida aceita';
  is $model->config_validate('behavior.default_ano', 'abc')->{error},
    'O valor deve ser um número inteiro.', 'ano deve ser número';
  is $model->config_validate('behavior.default_ano', '2025')->{value}, 2025, 'ano numérico';
  is $model->config_validate('appearance.theme', 'neon')->{error},
    'Opção inválida para este item.', 'tema inválido';
  # Bot Telegram
  is $model->config_validate('integrations.bot_telegram.enabled', 'true')->{value}, 1, 'boolean true normalizado';
  is $model->config_validate('integrations.bot_telegram.enabled', 'false')->{value}, 0, 'boolean false normalizado';
  ok $model->config_validate('integrations.bot_telegram.allowed_actions', ['ingest_stall'])->{ok}, 'multiselect aceita ação válida';
  is $model->config_validate('integrations.bot_telegram.allowed_actions', 'bad')->{error},
    'O valor deve ser uma lista de ações.', 'multiselect rejeita string';
};

subtest 'chat_llm_config: só campos definidos' => sub {
  plan skip_all => 'app_config.items ausente' unless $has_table;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  $t->app->schema->storage->dbh->do(
    'DELETE FROM app_config.items WHERE key = ?', {}, 'integrations.assistant_censo.api_key');

  my $cfg = $model->chat_llm_config;
  ok !exists $cfg->{api_key}, 'sem api_key quando nada foi definido';

  $model->config_put('integrations.assistant_censo.api_key', 'sk-teste-1234567890', 'a@b');
  $cfg = $model->chat_llm_config;
  is $cfg->{api_key}, 'sk-teste-1234567890', 'api_key definido (descriptografado)';

  my $cfg2 = $t->app->model('AppConfig')->chat_llm_config;
  is $cfg2->{api_key}, 'sk-teste-1234567890', 'config persistida (nova instância do model)';
};

$ENV{EDUMAPS_CONFIG_MASTER_KEY} = $BACKUP_KEY if defined $BACKUP_KEY;

done_testing;