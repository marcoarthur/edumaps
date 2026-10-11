package EduMaps::Controller::Canais;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

use Digest::SHA qw(hmac_sha256_hex);

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
    lista_nome  => $pub->{lista_nome},
    escola_nome => $pub->{escola_nome},
    canal       => $pub->{canal},
    campos      => $pub->{campos},
    expira_em   => $pub->{expira_em},
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
    consentimento => (defined $input->{consentimento} && $input->{consentimento} ? 1 : 0),
    ip_anon     => $self->_ip_anon($ip),
    user_agent  => $self->req->headers->user_agent,
  );

  return $self->_render_inscricao_error($r) unless $r->{ok};

  my $body = { ok => 1 };
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

# A `ref` é a capability (32 hex). Pendente → 200 {estado:"pendente", canais,
# expira_em}; usada → 200 {estado:"confirmado", canais:[], expira_em};
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
    canais    => $e->{estado} eq 'pendente' ? $model->canais_confirmacao(lc $ref) : [],
    expira_em => $e->{expira_em},
  });
}

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

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
  if ($reason eq 'campos') {
    return $self->render(
      json => { error => $r->{erro} // 'Informe nome e telefone válidos.' },
      status => 400,
    );
  }
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
