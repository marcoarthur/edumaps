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