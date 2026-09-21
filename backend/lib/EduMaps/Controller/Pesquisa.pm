package EduMaps::Controller::Pesquisa;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

# Rotas de pesquisas do gestor (fase 1: cadastro do gestor + CRUD de pesquisas).
# Sem autenticação — o e-mail do gestor é a identidade da sessão (upsert).

use constant EMAIL_RE => qr/^[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}$/;

sub perfil($self) {
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

  my $model   = $self->instantiate_model(model => 'Pesquisa');

  # Escola precisa existir no cadastro (censo ou tabela curada).
  return $self->_render_not_found('Escola não encontrada para este INEP')
    unless $model->escola_existe($v->param('cod_inep'));

  # Se o e-mail é novo (não existe na base) e a escola já tem um gestor
  # responsável pela agenda (reunião criada), bloqueia o cadastro.
  if (!$model->gestor_email_existe(lc $v->param('email'))
      && $model->escola_tem_agenda($v->param('cod_inep'))) {
    return $self->render(
      json => { error => 'Esta escola já tem um gestor responsável pela agenda das reuniões. Use o e-mail já cadastrado ou peça a quem gerencia a agenda para transferir o acesso.' },
      status => 409,
    );
  }

  my $gestor  = $model->upsert_gestor({
    cod_inep => $v->param('cod_inep'),
    nome     => $v->param('nome'),
    email    => $v->param('email'),
    telefone => $v->param('telefone'),
    cargo    => $v->param('cargo'),
    cpf      => $v->param('cpf'),
    senha    => $v->param('senha'),
  });

  return $self->_render_not_found("Gestor não pôde ser salvo") unless $gestor;
  $self->render(json => $gestor);
}

sub index($self) {
  my $v = $self->app->validator->validation;
  $v->input($self->req->params->to_hash || {});
  $v->required('inep', 'trim');
  return $self->_render_validation($v) if $v->has_error;

  # Formato inválido segue o padrão do projeto p/ codigo_ibge: 404 (não 400).
  my $inep = $v->param('inep');
  return $self->_render_not_found('Escola não encontrada para este INEP')
    unless $inep =~ /^\d{8}$/;

  my $model = $self->instantiate_model(model => 'Pesquisa');
  $self->render(json => $model->list_surveys($inep));
}

sub create($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('gestor_id', 'trim')->num;
  $v->required('titulo',    'trim')->size(3, 120);
  $v->optional('descricao', 'trim')->size(0, 500);
  return $self->_render_validation($v) if $v->has_error;

  my $payload = $self->_survey_payload($input);
  return $self->render(json => {error => $payload->{error}}, status => 400) if $payload->{error};

  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $survey = $model->create_survey({
    gestor_id  => $v->param('gestor_id'),
    titulo     => $v->param('titulo'),
    descricao  => $v->param('descricao'),
    perguntas  => $payload->{perguntas},
  });

  return $self->_render_not_found('Gestor não encontrado para gestor_id') unless $survey;
  $self->render(status => 201, json => $survey);
}

sub show($self) {
  my $model  = $self->instantiate_model(model => 'Pesquisa');
  my $survey = $model->survey_detail($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $survey;
  $self->render(json => $survey);
}

sub update($self) {
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $state = $model->survey_state($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $state;
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
  my $state = $model->survey_state($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $state;
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
  my $state = $model->survey_state($self->param('id'));
  return $self->_render_not_found('Pesquisa não encontrada') unless $state;
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

  my $model = $self->instantiate_model(model => 'Pesquisa');
  my $sessao = $model->login_gestor($v->param('email'), $v->param('senha'));
  return $self->render(json => { error => 'E-mail ou senha inválidos' }, status => 401) unless $sessao;
  $self->render(json => $sessao);
}

sub me($self) {
  $self->render(json => $self->stash('gestor'));
}

sub logout($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  $model->logout_gestor($self->stash('gestor_token'));
  $self->render(status => 204, text => '');
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