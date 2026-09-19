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
  return $self->_render_validation($v) if $v->has_error;

  my $model   = $self->instantiate_model(model => 'Pesquisa');
  my $gestor  = $model->upsert_gestor({
    cod_inep => $v->param('cod_inep'),
    nome     => $v->param('nome'),
    email    => $v->param('email'),
    telefone => $v->param('telefone'),
    cargo    => $v->param('cargo'),
    cpf      => $v->param('cpf'),
  });

  return $self->_render_not_found("Gestor não pôde ser salvo") unless $gestor;
  $self->render(json => $gestor);
}

sub index($self) {
  my $v = $self->app->validator->validation;
  $v->input($self->req->params->to_hash || {});
  $v->required('inep', 'trim')->like(qr/^\d{8}$/);
  return $self->_render_validation($v) if $v->has_error;

  my $model = $self->instantiate_model(model => 'Pesquisa');
  $self->render(json => $model->list_surveys($v->param('inep')));
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

sub _render_validation ($self, $v) {
  my @failed = $v->failed->@*;
  $self->app->log->debug('Pesquisa validation errors: ' . join(', ', map { "$_: " . join(', ', @{$v->error($_)}) } @failed));
  $self->render(json => { error => $v->error($failed[0])->[0] || 'Parâmetros inválidos' }, status => 400);
}

sub _render_not_found ($self, $msg) {
  $self->render(json => { error => $msg }, status => 404);
}

sub _render_conflict ($self, $msg) {
  $self->render(json => { error => $msg }, status => 409);
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