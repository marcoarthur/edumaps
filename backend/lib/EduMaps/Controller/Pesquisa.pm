package EduMaps::Controller::Pesquisa;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

# Rotas de pesquisas do gestor.
#   /perfil: cadastro anônimo — só CRIA conta, nunca altera uma existente.
#   CRUD de pesquisas: exige a sessão do gestor; a escola vem da sessão.

use EduMaps::Util::ClientIP qw(client_ip);

use constant EMAIL_RE => qr/^[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}$/;

# Limites de tentativa (#335): janela deslizante em segundos. Sobrescrevíveis
# no config (`auth_limite => { login_email => { max => .., janela => .. }, … }`).
#   login_email: falhas de login por e-mail (exista a conta ou não);
#   login_ip:    falhas de login por IP (folgado: escola atrás de um IP só);
#   cadastro_ip: tentativas de cadastro por IP (o 409 revela e-mail existente).
my %LIMITE_PADRAO = (
  login_email => { max => 10, janela => 900 },
  login_ip    => { max => 50, janela => 900 },
  cadastro_ip => { max => 20, janela => 3600 },
  # esqueci minha senha (#336): pedidos por e-mail e por IP; o IP também conta
  # tokens inválidos em /senha/redefinir.
  reset_email => { max => 3,  janela => 3600 },
  reset_ip    => { max => 10, janela => 3600 },
);

# Redes de onde se aceita o X-Real-IP (o nginx). Config opcional
# `auth_limite => { proxies_confiaveis => ['127.0.0.1/32'] }`; sem ela, o
# padrão de EduMaps::Util::ClientIP (loopback + redes privadas). Onde a API
# também escuta direto numa rede privada (LXC), restrinja ao IP do nginx.
sub _ip($self) {
  my $redes = ($self->app->config->{auth_limite} // {})->{proxies_confiaveis};
  return client_ip($self, ref $redes eq 'ARRAY' ? $redes : undef) // '';
}

# EDUMAPS_AUTH_LIMITE_OFF=1 desliga os limites — SÓ para a suíte de testes
# (t/lib/Imports.pm liga), onde dezenas de cadastros saem do mesmo 127.0.0.1.
# t/04-api/gestor/login_limite.t a remove para testar os limites de verdade.
sub _limites_off { $ENV{EDUMAPS_AUTH_LIMITE_OFF} ? 1 : 0 }

sub _limite($self, $nome) {
  my $cfg = ($self->app->config->{auth_limite} // {})->{$nome} // {};
  return { %{ $LIMITE_PADRAO{$nome} }, %$cfg };
}

# Maior espera (s) entre os escopos [escopo, chave, limite]; 0 = liberado.
sub _espera($self, $model, @escopos) {
  return 0 if _limites_off();
  my $espera = 0;
  for my $e (@escopos) {
    my ($escopo, $chave, $lim) = @$e;
    my $s = $model->auth_retry_after($escopo, $chave, $lim->{max}, $lim->{janela});
    $espera = $s if $s > $espera;
  }
  return $espera;
}

sub _render_muitas_tentativas($self, $espera, $escopo) {
  # Log sem e-mail, senha nem IP: só o escopo que estourou.
  $self->app->log->warn("auth: bloqueado por limite de tentativas (escopo=$escopo)");
  my $min = int(($espera + 59) / 60) || 1;
  $self->res->headers->header('Retry-After' => $espera);
  $self->render(
    json   => { error => "Muitas tentativas. Tente de novo em $min minuto" . ($min == 1 ? '' : 's') . '.' },
    status => 429,
  );
}

sub perfil($self) {
  # Limite por IP antes de tudo: cada tentativa de cadastro conta.
  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $secret = $self->app->secrets->[0];
  my $ip     = $self->_ip;
  my $ip_key = $model->auth_chave($secret, $ip);
  my $lim    = $self->_limite('cadastro_ip');
  if (my $espera = $self->_espera($model, ['cadastro_ip', $ip_key, $lim])) {
    return $self->_render_muitas_tentativas($espera, 'cadastro_ip');
  }
  $model->auth_registrar('cadastro_ip', $ip_key) unless _limites_off();

  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  # CPF aceita pontuação e é normalizado antes da validação (só dígitos).
  $input->{cpf} =~ s/\D//g if defined $input->{cpf};

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('cod_inep', 'trim')->like(qr/^\d{8}$/);
  $v->required('nome',     'trim')->size(2, 80);
  $v->required('email',    'trim')->like(EMAIL_RE);
  $v->optional('telefone', 'trim')->size(8, 20);
  $v->optional('cargo',    'trim')->size(3, 60);
  $v->optional('cpf',      'trim')->size(11, 11)->like(qr/^\d{11}$/);
  $v->required('senha',    'trim')->size(6, 64);
  return $self->_render_validation($v) if $v->has_error;

  # Rota anônima: e-mail já cadastrado nunca é alterado por aqui (seria trocar
  # a senha de outra pessoa). Quem já tem conta entra pelo login.
  return $self->render(
    json   => { error => 'Este e-mail já tem conta. Entre com sua senha.' },
    status => 409,
  ) if $model->gestor_email_existe($v->param('email'));

  # Escola precisa existir no cadastro (censo ou tabela curada).
  return $self->_render_not_found('Escola não encontrada para este INEP')
    unless $model->escola_existe($v->param('cod_inep'));

  # E-mail novo (o existente já saiu acima) em escola que já tem um gestor
  # responsável pela agenda (reunião criada), bloqueia o cadastro.
  if ($model->escola_tem_agenda($v->param('cod_inep'))) {
    return $self->render(
      json => { error => 'Esta escola já tem um gestor responsável pela agenda das reuniões. Use o e-mail já cadastrado ou peça a quem gerencia a agenda para transferir o acesso.' },
      status => 409,
    );
  }

  my $gestor  = $model->cadastrar_gestor({
    cod_inep => $v->param('cod_inep'),
    nome     => $v->param('nome'),
    email    => $v->param('email'),
    telefone => $v->param('telefone'),
    cargo    => $v->param('cargo'),
    cpf      => $v->param('cpf'),
    senha    => $v->param('senha'),
  });

  # Corrida (mesmo e-mail entre a checagem e o INSERT) ou CPF já cadastrado
  return $self->render(
    json   => { error => 'Já existe uma conta com este e-mail ou CPF. Entre com sua senha.' },
    status => 409,
  ) unless $gestor;
  $self->render(json => $gestor);
}

# Lista as pesquisas da escola da sessão. `?inep=` é aceito por compatibilidade,
# mas só a própria escola: outra escola é 403 (como os resultados).
sub index($self) {
  my $escola = $self->_escola_da_sessao;
  my $inep   = $self->param('inep');
  return $self->render(json => { error => 'Só o gestor da escola vê as pesquisas dela.' }, status => 403)
    if defined $inep && length $inep && $inep ne $escola;

  my $model = $self->instantiate_model(model => 'Pesquisa');
  $self->render(json => $model->list_surveys($escola));
}

sub create($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('titulo',    'trim')->size(3, 120);
  $v->optional('descricao', 'trim')->size(0, 500);
  return $self->_render_validation($v) if $v->has_error;

  my $payload = $self->_survey_payload($input);
  return $self->render(json => {error => $payload->{error}}, status => 400) if $payload->{error};

  my $model  = $self->instantiate_model(model => 'Pesquisa');
  # Autor = gestor da sessão; um gestor_id no corpo é ignorado.
  my $survey = $model->create_survey({
    gestor_id  => $self->stash('gestor')->{id},
    titulo     => $v->param('titulo'),
    descricao  => $v->param('descricao'),
    perguntas  => $payload->{perguntas},
  });

  return $self->_render_not_found('Gestor não encontrado para gestor_id') unless $survey;
  $self->render(status => 201, json => $survey);
}

sub show($self) {
  $self->_pesquisa_da_escola or return;
  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $survey = $model->survey_detail($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $survey;
  $self->render(json => $survey);
}

sub update($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $state = $self->_pesquisa_da_escola or return;
  return $self->_render_conflict('Pesquisa publicada não pode ser editada') if $state->{status} ne 'rascunho';

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('titulo',    'trim')->size(3, 120);
  $v->optional('descricao', 'trim')->size(0, 500);
  return $self->_render_validation($v) if $v->has_error;

  my $payload = $self->_survey_payload($input);
  return $self->render(json => {error => $payload->{error}}, status => 400) if $payload->{error};

  my $survey = $model->update_survey($self->param('id'), {
    titulo    => $v->param('titulo'),
    descricao => $v->param('descricao'),
    perguntas => $payload->{perguntas},
  });
  return $self->_render_not_found('Pesquisa não encontrada') unless $survey;
  $self->render(json => $survey);
}

sub finalize($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $state = $self->_pesquisa_da_escola or return;
  return $self->_render_conflict('Pesquisa já está publicada') if $state->{status} ne 'rascunho';

  my $detail = $model->survey_detail($self->param('id'));
  return $self->render(json => {error => 'A pesquisa precisa de pelo menos uma pergunta'}, status => 400)
    unless @{$detail->{perguntas}};

  my $survey = $model->finalize_survey($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $survey;
  $self->render(json => $survey);
}

sub destroy($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $state = $self->_pesquisa_da_escola or return;
  return $self->_render_conflict('Pesquisa publicada não pode ser excluída') if $state->{status} ne 'rascunho';

  $model->delete_survey($self->param('id'));
  $self->render(status => 204, text => '');
}

# ---------------------------------------------------------------
# fase 2 — autenticação do gestor
# ---------------------------------------------------------------

sub login($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('email', 'trim')->like(EMAIL_RE);
  $v->required('senha', 'trim')->size(6, 64);
  return $self->_render_validation($v) if $v->has_error;

  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $secret = $self->app->secrets->[0];
  my @escopos = (
    ['email', $model->auth_chave($secret, $v->param('email')), $self->_limite('login_email')],
    ['ip',    $model->auth_chave($secret, $self->_ip), $self->_limite('login_ip')],
  );

  # Bloqueado responde 429 ANTES de olhar a senha — senão a senha certa
  # passaria pelo bloqueio. Mesma resposta exista a conta ou não.
  for my $e (@escopos) {
    my $espera = $self->_espera($model, $e) or next;
    return $self->_render_muitas_tentativas($espera, $e->[0]);
  }

  my $sessao = $model->login_gestor($v->param('email'), $v->param('senha'));

  # PROVISÓRIO — admin de instalação em texto plano no edu_maps.conf (bloco
  # `admin`), p/ bootstrap do operador no deploy. Conferência falha rápido e
  # só bate se BOTH email+senha conferirem; as credenciais NUNCA são logadas.
  unless ($sessao) {
    my $admin = $self->app->config->{admin} || {};
    if (lc($admin->{email} // '') eq lc $v->param('email')
      && ($admin->{senha} // '') eq $v->param('senha')) {
      $sessao = $model->login_admin_config($v->param('email'), $v->param('senha'));
    }
  }

  unless ($sessao) {
    unless (_limites_off()) { $model->auth_registrar($_->[0], $_->[1]) for @escopos }
    return $self->render(json => { error => 'E-mail ou senha inválidos' }, status => 401);
  }

  # Acertou: zera as falhas do e-mail (as do IP seguem: outros e-mails ali).
  $model->auth_limpar('email', $escopos[0][1]);
  $self->render(json => $sessao);
}

# ---------------------------------------------------------------
# esqueci minha senha (#336)
# ---------------------------------------------------------------

# E-mail habilitado e URL pública configurada? Sem isso a tela esconde o link.
sub _senha_disponivel($self) {
  my $cfg = $self->instantiate_model(model => 'Canal')->email_config;
  return ($cfg->{enabled} && $cfg->{smtp_host} && $cfg->{from}
          && ($cfg->{public_base_url} // '') =~ m{^https?://}) ? 1 : 0;
}

sub senha_disponivel($self) {
  $self->render(json => { disponivel => $self->_senha_disponivel });
}

# Pedido de link. Responde SEMPRE a mesma coisa (202), exista a conta ou não;
# o envio vai para um job (mesmo tempo nos dois casos).
sub senha_esqueci($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('email', 'trim')->like(EMAIL_RE);
  return $self->_render_validation($v) if $v->has_error;

  return $self->render(json => { error => 'Redefinição de senha por e-mail indisponível.' }, status => 409)
    unless $self->_senha_disponivel;

  my $model   = $self->instantiate_model(model => 'Pesquisa');
  my $secret  = $self->app->secrets->[0];
  my @escopos = (
    ['reset_email', $model->auth_chave($secret, $v->param('email')), $self->_limite('reset_email')],
    ['reset_ip',    $model->auth_chave($secret, $self->_ip),         $self->_limite('reset_ip')],
  );
  for my $e (@escopos) {
    my $espera = $self->_espera($model, $e) or next;
    return $self->_render_muitas_tentativas($espera, $e->[0]);
  }
  unless (_limites_off()) { $model->auth_registrar($_->[0], $_->[1]) for @escopos }

  if (my $g = $model->gestor_por_email($v->param('email'))) {
    $self->gestor_senha_enfileirar($g->{id});
  }
  $self->render(status => 202, json => {
    ok       => 1,
    mensagem => 'Se houver uma conta com esse e-mail, enviamos um link para criar uma senha nova. Confira a caixa de entrada e o spam.',
  });
}

# Usa o link: senha nova, sessões encerradas. Token inválido, vencido ou já
# usado recebem a mesma resposta.
sub senha_redefinir($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('token', 'trim')->like(qr/^[A-Za-z0-9_-]{43}$/);
  $v->required('senha')->size(6, 64);
  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $secret = $self->app->secrets->[0];
  my $ip_e   = ['reset_ip', $model->auth_chave($secret, $self->_ip), $self->_limite('reset_ip')];
  if (my $espera = $self->_espera($model, $ip_e)) {
    return $self->_render_muitas_tentativas($espera, 'reset_ip');
  }
  my $invalido = sub {
    $model->auth_registrar($ip_e->[0], $ip_e->[1]) unless _limites_off();
    $self->render(json => { error => 'Este link não vale mais (vencido ou já usado). Peça um novo em “Esqueci minha senha”.' }, status => 400);
  };
  if ($v->has_error) {
    return $invalido->() if $v->has_error('token');
    return $self->_render_validation($v);
  }

  my $g = $model->redefinicao_usar($v->param('token'), $v->param('senha')) or return $invalido->();
  # senha nova: zera as falhas de login do e-mail
  $model->auth_limpar('email', $model->auth_chave($secret, $g->{email}));
  $self->render(json => { ok => 1 });
}

sub me($self) {
  $self->render(json => $self->stash('gestor'));
}

sub logout($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  $model->logout_gestor($self->stash('gestor_token'));
  $self->render(status => 204, text => '');
}

sub _escola_da_sessao($self) {
  return sprintf '%08d', $self->stash('gestor')->{cod_inep} || 0;
}

# Pesquisa do :id, se for da escola da sessão. Outra escola responde 404, como
# se não existisse (não revela pesquisas alheias). Devolve o estado ou undef
# (resposta já renderizada).
sub _pesquisa_da_escola($self) {
  my $state = $self->instantiate_model(model => 'Pesquisa')->survey_state($self->param('id'));
  unless ($state && $state->{cod_inep} == ($self->stash('gestor')->{cod_inep} || 0)) {
    $self->_render_not_found('Pesquisa não encontrada');
    return;
  }
  return $state;
}

# Gatilho dos under() autenticados: valida o Bearer token e injeta o gestor no stash.
sub _require_gestor($self) {
  my $auth  = $self->req->headers->authorization // '';
  my ($token) = $auth =~ /^Bearer\s+(\S+)$/;

  my $gestor = $token
    ? $self->instantiate_model(model => 'Pesquisa')->sessao_valida($token)
    : undef;

  if (!$gestor) {
    $self->_render_unauthorized;
    return 0;   # render já feito — quebra a cadeia do under
  }

  $self->stash(gestor => $gestor, gestor_token => $token);
  return 1;
}

# ---------------------------------------------------------------
# fase 2 — link público de resposta
# ---------------------------------------------------------------

sub publica_form($self) {
  return $self->_render_not_found('Pesquisa não encontrada ou não publicada')
    unless my $token = $self->_valid_public_token;
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $survey = $model->survey_for_public($token);
  return $self->_render_not_found('Pesquisa não encontrada ou não publicada') unless $survey;
  $self->render(json => $survey);
}

sub publica_resposta($self) {
  return $self->_render_not_found('Pesquisa não encontrada ou não publicada')
    unless my $token = $self->_valid_public_token;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('identificador_dispositivo', 'trim')->like(qr/^[0-9a-fA-F-]{32,36}$/);
  return $self->_render_validation($v) if $v->has_error;

  my $respostas = $input->{respostas};
  return $self->render(json => { error => 'respostas deve ser uma lista' }, status => 400)
    unless ref $respostas eq 'ARRAY' && @$respostas >= 0;

  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $result = $model->register_answer(
    $token,
    $v->param('identificador_dispositivo'),
    $respostas,
  );

  return $self->render(status => 201, json => { ok => 1, id => $result->{id} }) if $result->{ok};

  if ($result->{error} eq 'already_answered') {
    return $self->render(json => { error => 'Você já respondeu esta pesquisa neste dispositivo.' }, status => 409);
  }
  if ($result->{error} eq 'validation') {
    return $self->render(json => { error => $result->{detalhe} || 'Resposta inválida' }, status => 400);
  }
  return $self->_render_not_found('Pesquisa não encontrada ou não está mais aberta');
}

# ---------------------------------------------------------------
# fase 2 — resultados (exige sessão do gestor da escola)
# ---------------------------------------------------------------

sub resultados($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $state = $model->survey_state($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $state;

  my $gestor = $self->stash('gestor');
  return $self->render(json => { error => 'Só o gestor da escola vê os resultados.' }, status => 403)
    unless ($gestor->{cod_inep} || 0) == $state->{cod_inep};

  $self->render(json => $model->survey_results($self->param('id')));
}

# ---------------------------------------------------------------
# helpers
# ---------------------------------------------------------------

sub _input ($self) {
  my $is_json = ($self->req->headers->content_type // '') =~ m{^application/json};
  my $input;
  if ($is_json) {
    $input = eval { $self->req->json };
  } else {
    $input = $self->req->params->to_hash;
  }
  return $input || {};
}

# Participant token: plain 36-char UUID. O placeholder da rota aceita
# segmento vazio (Mojolicious injeta o próprio qr de requirements como
# capture), o que quebraria a query com "Cannot bind a reference".
sub _valid_public_token ($self) {
  my $token = $self->param('token');
  return unless defined $token && !ref $token && $token =~ /^[0-9a-fA-F-]{36}$/;
  return $token;
}

sub _render_validation ($self, $v) {
  my @failed = $v->failed->@*;
  $self->app->log->debug('Pesquisa validation errors: ' . join(', ', map { "$_: " . join(', ', @{$v->error($_)}) } @failed));
  $self->render(json => { error => $self->_validation_message($v, $failed[0]) }, status => 400);
}

# Rótulos amigáveis por campo (o nome do check sozinho — ex.: "like" — não
# diz nada ao usuário).
my %CAMPO_LABEL = (
  cod_inep   => 'código INEP',
  inep       => 'código INEP',
  nome       => 'nome',
  email      => 'e-mail',
  telefone   => 'telefone',
  cargo      => 'cargo',
  cpf        => 'CPF',
  senha      => 'senha',
  gestor_id  => 'gestor',
  titulo     => 'título',
  descricao  => 'descrição',
  identificador_dispositivo => 'identificador do dispositivo',
);

sub _validation_message ($self, $v, $field) {
  my ($check) = @{ $v->error($field) // [] };
  my $label = $CAMPO_LABEL{$field} // $field;
  return 'Campo obrigatório.' if ($check // '') eq 'required';
  return "O campo $label está inválido." if ($check // '') eq 'like';
  return "O campo $label está fora do tamanho permitido." if ($check // '') eq 'size';
  return "O campo $label deve ser numérico." if ($check // '') eq 'num';
  return "O campo $label é inválido.";
}

sub _render_not_found ($self, $msg) {
  $self->render(json => { error => $msg }, status => 404);
}

sub _render_conflict ($self, $msg) {
  $self->render(json => { error => $msg }, status => 409);
}

sub _render_unauthorized ($self) {
  $self->render(json => { error => 'Faça login como gestor.' }, status => 401);
}

# Valida e normaliza o array de perguntas. Retorna {error => msg} ou
# {perguntas => [...]} com texto/opções/ordem já prontos para persistir.
sub _survey_payload ($self, $input) {
  my $perguntas = $input->{perguntas};
  return { error => 'perguntas deve ser uma lista' } unless ref $perguntas eq 'ARRAY';

  my $n = @$perguntas;
  # Rascunho pode nascer sem perguntas (autosave ao digitar o título);
  # a obrigatoriedade de ter pergunta vale só na finalização.
  return { error => 'A pesquisa pode ter no máximo 30 perguntas' } if $n > 30;

  my @out;
  for my $i (0 .. $n - 1) {
    my $p = $perguntas->[$i];
    return { error => "pergunta #" . ($i + 1) . ' deve ser um objeto' } unless ref $p eq 'HASH';

    my $texto = $p->{texto};
    $texto = '' unless defined $texto;
    $texto =~ s/^\s+|\s+$//g;
    return { error => "pergunta #" . ($i + 1) . ' sem texto' } unless length($texto) >= 1 && length($texto) <= 500;

    my $tipo = $p->{tipo} // '';
    my @tipos_validos = qw(unica multipla dropdown texto);
    return { error => "pergunta #" . ($i + 1) . ' com tipo de resposta inválido' }
      unless grep { $_ eq $tipo } @tipos_validos;

    my $obrigatoria = $p->{obrigatoria} ? 1 : 0;

    my $opcoes;
    if ($tipo ne 'texto') {
      my $ops = $p->{opcoes};
      return { error => "pergunta #" . ($i + 1) . ' precisa de opções' } unless ref $ops eq 'ARRAY';
      my $m = @$ops;
      return { error => "pergunta #" . ($i + 1) . ' precisa de 2 a 12 opções' } if $m < 2 || $m > 12;

      my (@norm, %seen);
      for my $j (0 .. $m - 1) {
        my $op    = $ops->[$j];
        my $label = ref $op eq 'HASH' ? $op->{label} : $op;
        $label = '' unless defined $label;
        $label =~ s/^\s+|\s+$//g;
        return { error => "pergunta #" . ($i + 1) . ", opção #" . ($j + 1) . ' sem rótulo' }
          unless length($label) >= 1 && length($label) <= 120;
        return { error => "pergunta #" . ($i + 1) . ' tem opções repetidas' } if $seen{$label}++;
        my $oid = (ref $op eq 'HASH' && defined $op->{id} && length $op->{id}) ? "$op->{id}" : ($j + 1);
        push @norm, { id => $oid, label => $label };
      }
      $opcoes = \@norm;
    }

    push @out, { texto => $texto, tipo => $tipo, obrigatoria => $obrigatoria, opcoes => $opcoes };
  }

  return { perguntas => \@out };
}

1;