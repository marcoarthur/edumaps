package EduMaps::Controller::Admin;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

# API administrativa da plataforma (/api/admin/...) — Painel de Configuração.
# Exige sessão de gestor com access_role = 'admin' (under admin#_require_admin,
# registrado no Plugin::API::Admin e reutilizando o _require_admin do
# Controller::Gestor). Exposição mínima: árvore de config, leitura/validação e
# gravação de itens — segredos nunca saem em claro (apenas { set: 0|1 }).
use EduMaps::Bots::Telegram;

# GET /api/admin/config/tree — árvore de configuração com estados.
sub config_tree ($self) {
  my $model = $self->instantiate_model(model => 'AppConfig');
  $self->render(json => $model->config_tree);
}

# GET /api/admin/config/:key — detalhe de uma folha (mascarado se segredo).
sub config_show ($self) {
  my $model = $self->instantiate_model(model => 'AppConfig');
  my $key   = $self->param('key');
  return $self->_render_not_found_config unless $model->is_config_key($key);

  my $item = $model->config_item($key);
  return $self->_render_not_found_config unless $item;
  $self->render(json => $item);
}

# PUT /api/admin/config/:key — grava o valor { value: ... }.
sub config_update ($self) {
  my $model = $self->instantiate_model(model => 'AppConfig');
  my $key   = $self->param('key');
  return $self->_render_not_found_config unless $model->is_config_key($key);

  my $input = $self->req->json;
  $input ||= {};
  return $self->render(json => { error => 'Corpo JSON inválido.' }, status => 400)
    unless ref $input eq 'HASH' && exists $input->{value};

  my $result = $model->config_validate($key, $input->{value});
  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }

  my $updated_by = $self->stash('gestor')
    ? ($self->stash('gestor')->{email} // $self->stash('gestor')->{nome} // 'admin')
    : 'admin';
  my $ok = $self->_guard_config(sub { $model->config_put($key, $input->{value}, $updated_by) });
  return if $self->stash('guard_rendered');
  return $self->render(
    json => { error => 'Não foi possível salvar a configuração.' },
    status => 500,
  ) unless $ok;

  $self->render(json => $model->config_item($key));
}

# POST /api/admin/config/:key/validate — valida um valor sem gravar.
sub config_validate ($self) {
  my $model = $self->instantiate_model(model => 'AppConfig');
  my $key   = $self->param('key');
  return $self->_render_not_found_config unless $model->is_config_key($key);

  my $input = $self->req->json;
  $input ||= {};
  my $result = ref $input eq 'HASH'
    ? $model->config_validate($key, $input->{value})
    : { error => 'Corpo JSON inválido.' };
  if ($result->{error}) {
    return $self->render(json => { error => $result->{error} }, status => 400);
  }
  $self->render(json => { ok => 1, value => $key =~ /integrations\.assistant_censo\.api_key/ ? '[validada]' : $result->{value} });
}

# POST /api/admin/bot/telegram/test — envia uma mensagem de teste real para o
# chat configurado. Usa a config da AppConfig (token decifrado em memória,
# nunca retornado). Falha alto: 400 se incompleto/desligado, 502 se a API do
# Telegram responder erro.
sub bot_telegram_test ($self) {
  my $model = $self->instantiate_model(model => 'AppConfig');
  my $cfg   = $model->bot_telegram_config;

  return $self->render(json => {
    error => 'O bot está desativado — ative "Bot ativado" antes de testar.',
  }, status => 400) unless $cfg->{enabled};

  for my $campo (qw/token chat_id/) {
    return $self->render(json => {
      error => "Configuração incompleta: falta definir "
        . ($campo eq 'token' ? 'o token do bot' : 'o chat de destino') . '.',
    }, status => 400) unless defined $cfg->{$campo} && length $cfg->{$campo};
  }

  my $bot = EduMaps::Bots::Telegram->new(
    enabled => 1,
    config  => {
      telegram_token   => $cfg->{token},
      telegram_chat_id => $cfg->{chat_id},
    },
  );

  my $quem = $self->stash('gestor')
    ? ($self->stash('gestor')->{email} // 'admin') : 'admin';
  my $res = $bot->send_text(
    "✅ EduMaps — teste do bot Telegram.\n"
    . "Enviado pelo painel de configuração por $quem."
  );

  return $self->render(json => {
    error => 'A API do Telegram recusou a mensagem: '
      . ($res->{error} // "HTTP $res->{status}"),
  }, status => 502) unless $res->{ok};

  $self->render(json => { ok => 1, status => $res->{status} });
}

# ---------------------------------------------------------------------------
# Bot PÚBLICO do Telegram — confirmação de posse nas listas com QR (#212)
# ---------------------------------------------------------------------------
# Config em canais.telegram.* (AppConfig::telegram_publico_config); o token
# sai decifrado só em memória. Independente do bot de notificações internas
# (integrations.bot_telegram, acima).

# GET /api/admin/canais/telegram/status
#   { enabled, recebimento, bot_username,
#     webhook: { url, pending_update_count, last_error_message }   (só webhook)
#     polling: { ativo, offset } }
sub telegram_publico_status ($self) {
  my $model = $self->instantiate_model(model => 'Canal');
  my $cfg   = $model->telegram_publico_config;
  my $bot   = $cfg->{bot_username};

  my $out = {
    enabled      => $cfg->{enabled} ? 1 : 0,
    recebimento  => $cfg->{recebimento},
    bot_username => $bot,
    polling      => {
      ativo  => $self->telegram_polling_ativo,
      offset => (defined $bot && length $bot ? $model->telegram_offset($bot) : 0),
    },
  };

  if ($cfg->{recebimento} eq 'webhook' && _tem($cfg->{token})) {
    my $r = $self->_telegram_publico_bot($cfg)->api_call(getWebhookInfo => {});
    my $i = $r->{ok} && ref $r->{result} eq 'HASH' ? $r->{result} : {};
    $out->{webhook} = {
      url                  => (_tem($i->{url}) ? $i->{url} : undef),
      pending_update_count => $i->{pending_update_count} // 0,
      last_error_message   => $i->{last_error_message},
    };
    $out->{webhook}{erro} = $r->{error} unless $r->{ok};
  }

  $self->render(json => $out);
}

# POST /api/admin/canais/telegram/webhook — setWebhook com secret_token e
# allowed_updates [message]. URL: <canais.inscricao.public_base_url>
# /api/canais/telegram/webhook. 409 fora do modo webhook, bot desligado ou
# sem token/public_base_url/segredo; 502 se o Telegram recusar.
sub telegram_publico_webhook_set ($self) {
  my $model = $self->instantiate_model(model => 'Canal');
  my $cfg   = $model->telegram_publico_config;

  return $self->_conflito_telegram('O modo de recebimento não é "webhook".')
    unless $cfg->{recebimento} eq 'webhook';
  return $self->_conflito_telegram('O bot público está desativado ou sem token.')
    unless $cfg->{enabled} && _tem($cfg->{token});
  return $self->_conflito_telegram('Defina o segredo do webhook (canais.telegram.webhook_secret).')
    unless _tem($cfg->{webhook_secret});

  my $base = $model->inscricao_config->{public_base_url};
  return $self->_conflito_telegram('Defina a URL pública base (canais.inscricao.public_base_url).')
    unless _tem($base);
  $base =~ s{/+$}{};
  my $url = "$base/api/canais/telegram/webhook";

  my $r = $self->_telegram_publico_bot($cfg)->api_call(setWebhook => {
    url             => $url,
    secret_token    => $cfg->{webhook_secret},
    allowed_updates => ['message'],
  });
  return $self->_telegram_recusou($r) unless $r->{ok};

  $self->render(json => { ok => 1, url => $url });
}

# DELETE /api/admin/canais/telegram/webhook — deleteWebhook. 409 sem token;
# 502 se o Telegram recusar.
sub telegram_publico_webhook_delete ($self) {
  my $cfg = $self->instantiate_model(model => 'Canal')->telegram_publico_config;
  return $self->_conflito_telegram('O bot público está sem token.')
    unless _tem($cfg->{token});

  my $r = $self->_telegram_publico_bot($cfg)->api_call(deleteWebhook => {});
  return $self->_telegram_recusou($r) unless $r->{ok};
  $self->render(json => { ok => 1 });
}

# POST /api/admin/canais/telegram/polling — chama deleteWebhook e enfileira o
# job `telegram_polling` se não houver outro: 202 {ok, job_id}; já ativo →
# 200 {ok, ja_ativo:1}; fora do modo polling ou bot desligado/incompleto → 409.
sub telegram_publico_polling ($self) {
  my $cfg = $self->instantiate_model(model => 'Canal')->telegram_publico_config;

  return $self->_conflito_telegram('O modo de recebimento não é "polling".')
    unless $cfg->{recebimento} eq 'polling';
  return $self->_conflito_telegram('O bot público está desativado ou incompleto (token e usuário do bot).')
    unless $cfg->{enabled} && _tem($cfg->{token}) && _tem($cfg->{bot_username});

  my $r = $self->telegram_polling_start(delete_webhook => 1, config => $cfg);
  return $self->render(json => { ok => 1, ja_ativo => 1 }) if $r->{ja_ativo};
  $self->render(status => 202, json => { ok => 1, job_id => $r->{job_id} });
}

sub _tem ($v) { return defined $v && !ref $v && length $v ? 1 : 0 }

sub _telegram_publico_bot ($self, $cfg) {
  return EduMaps::Bots::Telegram->new(
    enabled => 1,
    config  => { telegram_token => $cfg->{token} },
    ua      => $self->canais_ua,
  );
}

sub _conflito_telegram ($self, $msg) {
  $self->render(json => { error => $msg }, status => 409);
}

sub _telegram_recusou ($self, $r) {
  $self->render(json => {
    error => 'A API do Telegram recusou o pedido: '
      . ($r->{error} // "HTTP " . ($r->{status} // 0)),
  }, status => 502);
}

# GET /api/admin/telemetry/overview — KPIs do fluxo de acesso de sessão
# (logins, sessões, rotas, buscas, série temporal). Só agregados; nunca IP,
# User-Agent, texto digitado ou sessão individual. `window` é validado contra
# a whitelist (6h/12h/24h/hoje/7d/30d).
sub telemetry_overview ($self) {
  my $model  = $self->instantiate_model(model => 'AdminTelemetry');
  my $window = $self->param('window') // '24h';
  return $self->render(json => { error => "Janela inválida: '$window'." }, status => 400)
    unless $model->is_window($window);

  my $data = eval { $model->overview({ window => $window }) };
  unless ($data) {
    $self->app->log->error('Admin::Telemetry error: ' . ($@ || 'erro desconhecido'));
    return $self->render(json => { error => 'Não foi possível gerar a telemetria.' }, status => 500);
  }

  $self->render(json => $data);
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

sub _render_not_found_config ($self) {
  $self->render(json => { error => 'Chave de configuração não encontrada.' }, status => 404);
}

sub _guard_config ($self, $code) {
  $self->stash(guard_rendered => undef);
  my ($ok, @out) = eval { (1, $code->()) };
  unless ($ok) {
    my $err = $@ || '';
    $self->app->log->error("Admin::AppConfig error: $err");
    if ($err =~ /EDUMAPS_CONFIG_MASTER_KEY/) {
      $self->render(
        json => { error => 'A chave mestra do servidor não está configurada (EDUMAPS_CONFIG_MASTER_KEY).' },
        status => 500,
      );
      $self->stash(guard_rendered => 1);
      return;
    }
    return $self->render(json => { error => 'Chave de configuração desconhecida.' }, status => 404)
      if $err =~ /desconhecida/;
    $self->render(json => { error => 'Erro interno ao salvar a configuração.' }, status => 500);
    $self->stash(guard_rendered => 1);
    return;
  }
  return $out[0];
}

1;