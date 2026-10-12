package EduMaps::Controller::Canais;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

use Digest::SHA qw(hmac_sha256_hex sha256_hex);
use Mojo::Util qw(secure_compare);
use EduMaps::Channel::WhatsApp;
use EduMaps::Channel::Email;
use EduMaps::Channel::Confirmation;
use EduMaps::Channel::Telegram::Updates;

# Face pública da autoinscrição por QR (issue #208 — Fase 0, canal telefone).
# O token na URL é a capability: não há sessão. Duas rotas, mesma rota-base
# (Plugin::API::Canais):
#
#   GET  /api/canais/inscricao/:token  → 200 {lista_nome, escola_nome, canal,
#                                          campos, expira_em} · 404/410
#   POST /api/canais/inscricao/:token  → 201 {ok:1, duplicado?, confirmacao?}
#                                          · 400/404/410/429
#   GET  /api/canais/confirmacao/:ref  → 200 {estado, canais, expira_em} · 404
#                                          (#212 — confirmação de posse)
#   POST /api/canais/confirmacao/:ref/whatsapp           → 202 {enviado, expira_em}
#                                          · 404/409/429 (#212, onda 2)
#   POST /api/canais/confirmacao/:ref/whatsapp/verificar → 200 {estado}
#                                          · 400/404/410/429 (#212, onda 2)
#   POST /api/canais/telegram/webhook  → 200 {ok:1} · 401/404 (#212, onda 2)
#
# Fase 2 (#214 — e-mail e LGPD):
#   GET  /api/canais/inscricao/:token  + campos/obrigatorios por `coleta` e
#                                        consentimento {versao, texto} vigente
#   POST /api/canais/inscricao/:token  + email, consentimento_versao (409 se ≠
#                                        vigente); 201 + exclusao_url
#   GET  /api/canais/confirmacao/:ref  estado pendente|parcial|confirmado +
#                                        contatos {telefone?, email?}
#   POST /api/canais/confirmacao/:ref/email           → 202 {enviado, expira_em}
#                                        · 404/409/429/502
#   POST /api/canais/confirmacao/:ref/email/verificar → 200 {estado, contatos}
#                                        · 400/404/410/429
#   GET  /api/canais/consentimento     → 200 {versao, texto, publicada_em}
#
# Regras: feature flag `canais.inscricao.enabled` (desligada → 404 genérico);
# resposta mínima (NUNCA PII de terceiros); honeypot `_hp` (201 falso sem
# gravar); rate limit por token+IP; consentimento obrigatório; IP anonimizado
# (HMAC + salt diário), nunca o IP puro.

# ---------------------------------------------------------------------------
# GET — formulário público (RF-003)
# ---------------------------------------------------------------------------

sub inscricao_form($self) {
  my $model = $self->_modelo_habilitado or return;

  my $pub = $model->dados_publicos_token($self->param('token'));
  # no GET o contrato é 200/404/410: "esgotado" é link indisponível (410), não
  # rate limit (429, exclusivo do POST).
  return $self->_render_token_error($pub, esgotado_410 => 1) unless $pub->{ok};

  # dados_publicos_token já devolve o envelope mínimo; redeclarado aqui para
  # deixar explícito o contrato congelado (sem PII, sem cod_inep/gestor).
  $self->render(json => {
    lista_nome    => $pub->{lista_nome},
    escola_nome   => $pub->{escola_nome},
    canal         => $pub->{canal},
    campos        => $pub->{campos},
    obrigatorios  => $pub->{obrigatorios},
    consentimento => $pub->{consentimento},
    expira_em     => $pub->{expira_em},
  });
}

# ---------------------------------------------------------------------------
# POST — registrar inscrição (RF-004/RF-005)
# ---------------------------------------------------------------------------

sub inscricao_create($self) {
  my $model = $self->_modelo_habilitado or return;

  my $token = $self->param('token');
  my $v = $model->validar_token($token);
  return $self->_render_token_error($v) unless $v->{ok};

  my $input = $self->_input;

  # Honeypot: campo escondido preenchido = bot. Responde 201 como sucesso sem
  # gravar nada (não ensina o atacante).
  if (defined $input->{_hp} && $input->{_hp} ne '' && $input->{_hp} ne '0') {
    return $self->render(status => 201, json => { ok => 1 });
  }

  # Rate limit por token + IP (antiabuso, RNF-003). Nunca 500 por abuso.
  my $ip = $self->tx->remote_address;
  my $rl = $model->rate_limit_check(token => $token, ip => $ip);
  return $self->_render_too_many('Muitas inscrições por este link. Tente novamente em instantes.')
    unless $rl->{ok};

  my $r = $model->registrar_inscricao(
    token       => $token,
    nome        => $input->{nome},
    telefone    => $input->{telefone},
    email       => $input->{email},
    consentimento => (defined $input->{consentimento} && $input->{consentimento} ? 1 : 0),
    consentimento_versao => $input->{consentimento_versao},
    ip_anon     => $self->_ip_anon($ip),
    user_agent  => $self->req->headers->user_agent,
  );

  return $self->_render_inscricao_error($r) unless $r->{ok};

  my $body = { ok => 1, exclusao_url => $r->{exclusao_url} };
  $body->{duplicado} = 1 if $r->{duplicado};
  # Lista que exige confirmação de posse (#212): `confirmacao` com a ref e os
  # canais disponíveis (ou {estado:"confirmado"}). Sem exigência, a resposta é
  # idêntica à da Fase 0 (sem a chave).
  $body->{confirmacao} = $r->{confirmacao} if $r->{confirmacao};
  $self->render(status => 201, json => $body);
}

# ---------------------------------------------------------------------------
# GET — estado da confirmação de posse (#212, RF-105)
# ---------------------------------------------------------------------------

# A `ref` é a capability (32 hex). Pendente/parcial → 200 {estado, canais (dos
# contatos pendentes), expira_em, contatos}; usada → 200 {estado:"confirmado",
# canais:[], expira_em, contatos};
# formato inválido, inexistente, expirada sem uso ou invalidada → 404 genérico.
# Sem PII. A página pública consulta este GET periodicamente (polling), por
# isso o rate limit tem orçamento próprio, maior que o do POST.
sub confirmacao_show($self) {
  my $model = $self->_modelo_habilitado or return;

  my $ref = $self->param('ref');
  return $self->_render_confirmacao_not_found unless $model->ref_valida($ref);

  my $rl = $model->rate_limit_check(
    token => 'confirmacao:' . lc $ref,
    ip    => $self->tx->remote_address,
    max   => $model->inscricao_config->{rate_max} * 6,
  );
  return $self->_render_too_many('Muitas consultas. Tente novamente em instantes.')
    unless $rl->{ok};

  my $e = $model->estado_ref($ref)
    or return $self->_render_confirmacao_not_found;

  $self->render(json => {
    estado    => $e->{estado},
    canais    => $e->{estado} ne 'confirmado' ? $model->canais_confirmacao(lc $ref, $e) : [],
    expira_em => $e->{expira_em},
    contatos  => $e->{contatos},
  });
}

# ---------------------------------------------------------------------------
# POST — código de confirmação pelo WhatsApp (#212, RF-104, onda 2)
# ---------------------------------------------------------------------------

# Envia o código de 6 dígitos ao telefone da inscrição por template de
# autenticação (Channel::WhatsApp + Channel::Confirmation: só hash, TTL 10 min,
# 5 tentativas). 202 {enviado:1, expira_em do CÓDIGO}; ref inválida/confirmada
# → 404; WhatsApp indisponível, inscrição sem telefone ou telefone já
# confirmado (#214) → 409; limite de envios (3 por ref;
# 3 por telefone/hora) ou rate limit por IP → 429; falha do provedor → 502
# (registrada em canal_mensagens).
sub confirmacao_whatsapp($self) {
  my $model = $self->_modelo_habilitado or return;

  my $ref = $self->param('ref');
  return $self->_render_confirmacao_not_found unless $model->ref_valida($ref);
  $ref = lc $ref;

  my $rl = $model->rate_limit_check(
    token => "whatsapp:$ref", ip => $self->tx->remote_address);
  return $self->_render_too_many('Muitas tentativas. Tente novamente em instantes.')
    unless $rl->{ok};

  my $e = $model->estado_ref($ref);
  return $self->_render_confirmacao_not_found
    unless $e && $e->{estado} ne 'confirmado';

  return $self->_render_whatsapp_indisponivel
    unless $model->contato_pendente($e, 'telefone')
        && grep { $_->{canal} eq 'whatsapp' } @{ $model->canais_confirmacao_disponiveis };

  my $wa = $self->_whatsapp($model);
  my $v  = $wa->validate_address($e->{telefone_norm});
  return $self->_render_whatsapp_indisponivel unless $v->{ok};

  my $max = $model->whatsapp_max_envios;
  return $self->_render_too_many('Limite de envios do código atingido. Tente mais tarde.')
    if $e->{envios_whatsapp} >= $max
    || $model->envios_whatsapp_ultima_hora($v->{normalized}) >= $max;

  my $r = $wa->confirm_start($v->{normalized});
  unless ($r->{ok}) {
    $self->app->log->warn('WhatsApp: falha ao enviar código: ' . ($r->{error} // '?'));
    return $self->render(
      json   => { error => 'Não foi possível enviar o código agora. Tente novamente em instantes.' },
      status => 502,
    );
  }
  $model->contar_envio_whatsapp($e->{ref_id});

  $self->render(status => 202, json => {
    enviado   => 1,
    expira_em => $model->expira_em_codigo($r->{confirmacao_id}),
  });
}

# Confere o código. 200 {estado, contatos} — estado GERAL (#214: pode ficar
# `parcial` se falta o e-mail); também se o telefone/ref já estava confirmado
# (idempotente); código mal formado ou errado → 400; expirado, tentativas
# excedidas ou sem pedido → 410; ref inválida → 404.
sub confirmacao_whatsapp_verificar($self) {
  my $model = $self->_modelo_habilitado or return;

  my $ref = $self->param('ref');
  return $self->_render_confirmacao_not_found unless $model->ref_valida($ref);
  $ref = lc $ref;

  my $rl = $model->rate_limit_check(
    token => "whatsapp_verificar:$ref", ip => $self->tx->remote_address);
  return $self->_render_too_many('Muitas tentativas. Tente novamente em instantes.')
    unless $rl->{ok};

  my $e = $model->estado_ref($ref) or return $self->_render_confirmacao_not_found;
  return $self->_render_estado_ref($e)
    if $e->{estado} eq 'confirmado' || !$model->contato_pendente($e, 'telefone');

  my $codigo = $self->_codigo_entrada;
  return $self->render(json => { error => 'Código inválido.' }, status => 400)
    unless defined $codigo;

  my $v = $self->_whatsapp($model)->validate_address($e->{telefone_norm});
  return $self->_render_codigo_expirado unless $v->{ok};

  my $res = EduMaps::Channel::Confirmation->new(
    schema => $model->schema, log => $self->app->log,
  )->verify(canal => 'whatsapp', endereco => $v->{normalized}, codigo => $codigo);

  unless ($res->{ok}) {
    return $self->render(json => { error => 'Código inválido.' }, status => 400)
      if ($res->{reason} // '') eq 'código inválido';
    return $self->_render_codigo_expirado;
  }

  my $c = $model->concluir(ref => $ref, via => 'whatsapp');
  return $self->_render_confirmacao_not_found unless $c->{ok};
  $self->render(json => { estado => $c->{estado}, contatos => $c->{contatos} });
}

# ---------------------------------------------------------------------------
# POST — código de confirmação por e-mail (#214, RF-203)
# ---------------------------------------------------------------------------

# Envia o código de 6 dígitos ao e-mail da inscrição (Channel::Email +
# Channel::Confirmation: só hash, TTL 10 min, 5 tentativas). 202 {enviado:1,
# expira_em do CÓDIGO}; ref inválida/confirmada → 404; e-mail indisponível,
# inscrição sem e-mail ou e-mail já confirmado → 409; limite de envios (3 por
# ref; 3 por e-mail/hora) ou rate limit por IP → 429; falha do SMTP → 502
# (registrada em canal_mensagens, corpo sem o código).
sub confirmacao_email($self) {
  my $model = $self->_modelo_habilitado or return;

  my $ref = $self->param('ref');
  return $self->_render_confirmacao_not_found unless $model->ref_valida($ref);
  $ref = lc $ref;

  my $rl = $model->rate_limit_check(
    token => "email:$ref", ip => $self->tx->remote_address);
  return $self->_render_too_many('Muitas tentativas. Tente novamente em instantes.')
    unless $rl->{ok};

  my $e = $model->estado_ref($ref);
  return $self->_render_confirmacao_not_found
    unless $e && $e->{estado} ne 'confirmado';

  return $self->_render_email_indisponivel
    unless $model->contato_pendente($e, 'email') && $model->email_confirmacao_disponivel;

  my $mail = $self->_email($model);
  my $v    = $mail->validate_address($e->{email_norm});
  return $self->_render_email_indisponivel unless $v->{ok};

  my $max = $model->email_max_envios;
  return $self->_render_too_many('Limite de envios do código atingido. Tente mais tarde.')
    if $e->{envios_email} >= $max
    || $model->envios_email_ultima_hora($v->{normalized}) >= $max;

  my $r = $mail->confirm_start($v->{normalized},
    contato_id    => $e->{contato_id},
    cod_inep      => $e->{cod_inep},
    lista_nome    => $e->{lista_nome},
    escola_nome   => $e->{escola_nome},
    # o token de exclusão só existe em claro na resposta da inscrição (o
    # banco guarda o hash): o e-mail orienta onde encontrá-lo.
    exclusao_info => 'Para remover seus dados, use o link "Remover meus dados" '
                   . 'exibido ao concluir a inscrição, ou peça à escola.',
  );
  unless ($r->{ok}) {
    $self->app->log->warn('E-mail: falha ao enviar código: ' . ($r->{error} // '?'));
    return $self->render(
      json   => { error => 'Não foi possível enviar o código agora. Tente novamente em instantes.' },
      status => 502,
    );
  }
  $model->contar_envio_email($e->{ref_id});

  $self->render(status => 202, json => {
    enviado   => 1,
    expira_em => $model->expira_em_codigo($r->{confirmacao_id}),
  });
}

# Confere o código do e-mail. 200 {estado, contatos} (estado GERAL, pode ser
# `parcial`; idempotente se o e-mail/ref já está confirmado); código mal
# formado ou errado → 400; expirado, tentativas excedidas ou sem pedido →
# 410; ref inválida → 404.
sub confirmacao_email_verificar($self) {
  my $model = $self->_modelo_habilitado or return;

  my $ref = $self->param('ref');
  return $self->_render_confirmacao_not_found unless $model->ref_valida($ref);
  $ref = lc $ref;

  my $rl = $model->rate_limit_check(
    token => "email_verificar:$ref", ip => $self->tx->remote_address);
  return $self->_render_too_many('Muitas tentativas. Tente novamente em instantes.')
    unless $rl->{ok};

  my $e = $model->estado_ref($ref) or return $self->_render_confirmacao_not_found;
  return $self->_render_estado_ref($e)
    if $e->{estado} eq 'confirmado' || !$model->contato_pendente($e, 'email');

  my $codigo = $self->_codigo_entrada;
  return $self->render(json => { error => 'Código inválido.' }, status => 400)
    unless defined $codigo;

  my $v = $self->_email($model)->validate_address($e->{email_norm});
  return $self->_render_codigo_expirado unless $v->{ok};

  my $res = EduMaps::Channel::Confirmation->new(
    schema => $model->schema, log => $self->app->log,
  )->verify(canal => 'email', endereco => $v->{normalized}, codigo => $codigo);

  unless ($res->{ok}) {
    return $self->render(json => { error => 'Código inválido.' }, status => 400)
      if ($res->{reason} // '') eq 'código inválido';
    return $self->_render_codigo_expirado;
  }

  my $c = $model->concluir(ref => $ref, via => 'email');
  return $self->_render_confirmacao_not_found unless $c->{ok};
  $self->render(json => { estado => $c->{estado}, contatos => $c->{contatos} });
}

# ---------------------------------------------------------------------------
# GET — texto de consentimento vigente (#214, RF-208)
# ---------------------------------------------------------------------------

# Público (para a página /privacidade). Não depende de canais.inscricao.enabled
# (o texto da política é público). 200 {versao, texto, publicada_em}.
sub consentimento_show($self) {
  my $model = $self->instantiate_model(model => 'Canal');
  my $vig   = $model->consentimento_vigente;
  $self->render(json => {
    versao       => $vig->{versao},
    texto        => $vig->{texto},
    publicada_em => $vig->{publicada_em},
  });
}

# ---------------------------------------------------------------------------
# POST — webhook do bot público do Telegram (#212, RF-107, onda 2)
# ---------------------------------------------------------------------------

# Só no modo webhook com o bot público ligado (senão 404). Header
# X-Telegram-Bot-Api-Secret-Token comparado em tempo constante com
# canais.telegram.webhook_secret (ausente/errado, ou segredo não configurado →
# 401). Update válido → sempre 200 {ok:1}, mesmo ignorado ou com erro interno
# (o Telegram não deve reenviar).
sub telegram_webhook($self) {
  my $model = $self->instantiate_model(model => 'Canal');
  my $cfg   = $model->telegram_publico_config;

  return $self->render(json => { error => 'Não encontrado.' }, status => 404)
    unless $cfg->{enabled} && defined $cfg->{token} && length $cfg->{token}
        && ($cfg->{recebimento} // '') eq 'webhook';

  my $secret = $cfg->{webhook_secret};
  my $header = $self->req->headers->header('X-Telegram-Bot-Api-Secret-Token');
  # sha256 dos dois lados: comprimento igual, comparação em tempo constante
  return $self->render(json => { error => 'Não autorizado.' }, status => 401)
    unless defined $secret && length $secret && defined $header && length $header
        && secure_compare(sha256_hex($header), sha256_hex($secret));

  my $update = eval { $self->req->json };
  if (ref $update eq 'HASH') {
    my $ok = eval {
      EduMaps::Channel::Telegram::Updates->new(
        model => $model, config => $cfg, log => $self->app->log,
        ua    => $self->canais_ua,
      )->handle($update);
      1;
    };
    $self->app->log->error("Telegram webhook: $@") unless $ok;
  }
  $self->render(json => { ok => 1 });
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# Canal WhatsApp com a config efetiva (token decifrado em memória) e o UA dos
# canais (injetável em teste).
sub _whatsapp($self, $model) {
  my $cfg = $model->whatsapp_config;
  return EduMaps::Channel::WhatsApp->new(
    config  => $cfg,
    enabled => ($cfg->{enabled} ? 1 : 0),
    schema  => $model->schema,
    log     => $self->app->log,
    ua      => $self->canais_ua,
  );
}

# Canal e-mail com a config efetiva (senha SMTP decifrada em memória) e o
# transporte SMTP do helper `canais_smtp` (injetável em teste).
sub _email($self, $model) {
  my $cfg = $model->email_config;
  return EduMaps::Channel::Email->new(
    config         => $cfg,
    enabled        => ($cfg->{enabled} ? 1 : 0),
    schema         => $model->schema,
    log            => $self->app->log,
    smtp_transport => $self->canais_smtp,
  );
}

sub _render_email_indisponivel($self) {
  $self->render(json => { error => 'Confirmação por e-mail indisponível.' }, status => 409);
}

# Estado da ref (já confirmada ou contato já confirmado): 200 {estado, contatos}.
sub _render_estado_ref($self, $e) {
  $self->render(json => { estado => $e->{estado}, contatos => $e->{contatos} });
}

# Código de 6 dígitos do corpo (espaços ignorados); undef se mal formado.
sub _codigo_entrada($self) {
  my $codigo = $self->_input->{codigo};
  $codigo = '' unless defined $codigo && !ref $codigo;
  $codigo =~ s/\s+//g;
  return $codigo =~ /^\d{6}\z/ ? $codigo : undef;
}

sub _render_whatsapp_indisponivel($self) {
  $self->render(json => { error => 'Confirmação pelo WhatsApp indisponível.' }, status => 409);
}

sub _render_codigo_expirado($self) {
  $self->render(
    json   => { error => 'Código expirado ou tentativas esgotadas. Peça um novo código.' },
    status => 410,
  );
}

# Com a flag desligada o endpoint inteiro é inexistente (404 genérico) — não
# revela que existe uma lista/token. Devolve o modelo ou undef (já renderizado).
sub _modelo_habilitado($self) {
  my $model = $self->instantiate_model(model => 'Canal');
  return $model if $model->inscricao_config->{enabled};
  $self->_render_not_found;
  return;
}

# Traduz o motivo de validar_token/dados_publicos_token para HTTP, sem
# distinguir existência: not_found → 404; revogado/expirado/lista_inativa → 410;
# esgotado → 429 (POST) ou 410 (GET, via `esgotado_410`).
sub _render_token_error($self, $v, %opt) {
  my $reason = $v->{reason} // 'not_found';
  if ($reason eq 'esgotado') {
    return $opt{esgotado_410}
      ? $self->_render_gone
      : $self->_render_too_many('Este link atingiu o limite de inscrições.');
  }
  return $self->_render_gone
    if $reason =~ /^(?:revogado|expirado|lista_inativa)$/;
  return $self->_render_not_found;
}

# Erros de registrar_inscricao: validação/consentimento → 400; token → 404/410;
# esgotado/rate_limited → 429; resto → 500 (mensagem genérica).
sub _render_inscricao_error($self, $r) {
  my $reason = $r->{reason} // '';
  return $self->_render_too_many('Este link atingiu o limite de inscrições.')
    if $reason eq 'esgotado' || $reason eq 'rate_limited';
  return $self->_render_gone
    if $reason =~ /^(?:revogado|expirado|lista_inativa)$/;
  return $self->_render_not_found if $reason eq 'not_found';

  if ($reason eq 'consentimento') {
    return $self->render(
      json => { error => 'É necessário consentir com o uso dos dados.' },
      status => 400,
    );
  }
  if ($reason eq 'consentimento_versao') {
    return $self->render(
      json => {
        error => 'O texto de consentimento foi atualizado. Leia a versão vigente e envie novamente.',
        consentimento => $r->{consentimento},
      },
      status => 409,
    );
  }
  if ($reason eq 'campos') {
    return $self->render(
      json => { error => $r->{erro} // 'Informe nome e telefone válidos.' },
      status => 400,
    );
  }
  $self->app->log->error('Inscrição: erro interno: ' . ($r->{detalhe} // '?'))
    if $reason eq 'erro_interno';
  return $self->render(json => { error => 'Erro interno.' }, status => 500);
}

sub _render_not_found($self) {
  $self->render(json => { error => 'Link inválido ou expirado.' }, status => 404);
}

sub _render_confirmacao_not_found($self) {
  $self->render(json => { error => 'Confirmação não encontrada.' }, status => 404);
}

sub _render_gone($self) {
  $self->render(json => { error => 'Link expirado ou revogado.' }, status => 410);
}

sub _render_too_many($self, $msg) {
  $self->render(json => { error => $msg }, status => 429);
}

# Corpo JSON (ou params), como nos demais controllers. Nunca deixa explodir.
sub _input($self) {
  my $is_json = ($self->req->headers->content_type // '') =~ m{^application/json};
  my $input;
  if ($is_json) {
    $input = eval { $self->req->json };
  } else {
    $input = $self->req->params->to_hash;
  }
  return $input || {};
}

# IP anonimizado: HMAC-SHA256(IP, salt + dia), nunca o IP puro (RNF-002).
sub _ip_anon($self, $ip) {
  return undef unless defined $ip && length $ip;
  my $conf = $self->app->config // {};
  my $salt = $conf->{privacy}{anon_salt} // 'edumaps-dev-salt';
  my @g    = gmtime;
  my $day  = sprintf('%04d-%02d-%02d', $g[5] + 1900, $g[4] + 1, $g[3]);
  return hmac_sha256_hex($ip, "${salt}::$day");
}

1;
