package EduMaps::Controller::Chat;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use POSIX qw(strftime);

has _default_poll_time => 1;

# ---------------------------------------------------------------------------
# POST /api/chat/ask
#
# Enfileira a pergunta ao Assistente do Censo (chat NL->SQL) na fila dedicada
# 'analytics' e devolve 202 + Location para polling/SSE. A pergunta e o
# contexto (escopo do gestor) são validados aqui; o job chama o Plumber.
# ---------------------------------------------------------------------------

sub ask ($self) {
  my $is_json = ($self->req->headers->content_type // '') =~ m{^application/json};
  my $input = $is_json ? $self->req->json : $self->req->params->to_hash;
  $input ||= {};

  # O escopo (contexto do gestor) vem aninhado em `contexto`, mas aceitamos
  # também os campos na raiz por compatibilidade.
  my $ctx = ref $input->{contexto} eq 'HASH' ? $input->{contexto} : {};
  my %raw = (
    pergunta       => $input->{pergunta},
    cod_municipio  => $ctx->{cod_municipio}  // $input->{cod_municipio},
    cod_inep       => $ctx->{cod_inep}       // $input->{cod_inep},
    nome_municipio => $ctx->{nome_municipio} // $input->{nome_municipio},
    nome_escola    => $ctx->{nome_escola}    // $input->{nome_escola},
    sg_uf          => $ctx->{sg_uf}          // $input->{sg_uf},
  );

  my $v = $self->app->validator->validation;
  $v->input(\%raw);
  $v->required('pergunta', 'trim')->like(qr/^.{1,500}\z/s);
  $v->optional('cod_municipio', 'trim')->like(qr/^\d{7}$/);
  $v->optional('cod_inep',      'trim')->like(qr/^\d{8}$/);
  $v->optional('nome_municipio', 'trim');
  $v->optional('nome_escola',    'trim');
  $v->optional('sg_uf',          'trim')->like(qr/^[A-Za-z]{2}$/);

  return $self->bad_req if $v->has_error;

  my %contexto;
  $contexto{cod_municipio}  = $v->param('cod_municipio')  if $v->param('cod_municipio');
  $contexto{cod_inep}       = $v->param('cod_inep')       if $v->param('cod_inep');
  $contexto{nome_municipio} = $v->param('nome_municipio') if $v->param('nome_municipio');
  $contexto{nome_escola}    = $v->param('nome_escola')    if $v->param('nome_escola');
  $contexto{sg_uf}          = uc($v->param('sg_uf'))      if $v->param('sg_uf');

  my $args = {
    pergunta => $v->param('pergunta'),
    contexto => \%contexto,
  };

  my $job_id = $self->app->minion->enqueue(
    chat_ask => [$args] => { queue => 'analytics' }
  );

  $self->res->headers->header('Location' => "/api/chat/progress?job_id=$job_id");
  $self->render(status => 202, json => { task => 'chat', job_id => $job_id });
}

# ---------------------------------------------------------------------------
# GET /api/chat/progress
#
# Snapshot JSON (polling) ou SSE (Accept: text/event-stream), igual ao
# /api/task/progress.
# ---------------------------------------------------------------------------

sub progress ($self) {
  my $v = $self->validation;
  $v->required('job_id', 'trim')->num;

  return $self->bad_req if $self->any_error;

  my $job_id = $v->param('job_id');

  if (($self->req->headers->accept // '') !~ m{text/event-stream}i) {
    my $info = $self->minion->job($job_id);
    return $self->render(json => { error => 'job_not_found' }, status => 404) unless $info;

    my $job = $info->info;
    my %resp = (state => $job->{state});
    if ($job->{state} eq 'failed') {
      my $err = $job->{error} // $job->{result};
      $resp{error} = ref $err eq 'HASH' ? ($err->{error} // Mojo::JSON::encode_json($err)) : "$err";
    }
    elsif ($job->{state} eq 'finished') {
      $resp{result} = $job->{result};
    }
    return $self->render(json => \%resp);
  }

  $self->render_later;
  $self->monitor_chat($job_id);
}

# ---------------------------------------------------------------------------
# POST /api/chat/conversas
#
# Salva a conversa atual do gestor logado.
# Body JSON: { titulo?: string, messages: [{ role, content, meta }] }
# role: 'user' | 'assistant'
# Retorna { id, created_at }
# ---------------------------------------------------------------------------

sub save_conversa ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;
  my $input = $self->req->json // {};

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->optional('titulo', 'trim');
  $v->optional('messages');
  return $self->bad_req if $v->has_error;

  # validação manual de messages (array de objetos {role, content, meta})
  my $messages = $input->{messages};
  return $self->render(json => { error => 'messages deve ser um array' }, status => 400)
    unless ref $messages eq 'ARRAY';

  my $valid_msgs = 0;
  for my $msg (@$messages) {
    next unless ref $msg eq 'HASH';
    my $role = $msg->{role} // '';
    my $content = $msg->{content} // '';
    $valid_msgs++ if $role =~ /^(user|assistant)$/ && length($content);
  }
  return $self->render(json => { error => 'Nenhuma mensagem válida (role: user|assistant, content não vazio)' }, status => 400)
    unless $valid_msgs;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $id = $model->save_conversa($gestor->{id} + 0, $input);
  return $self->render(json => { error => 'Nenhuma mensagem para salvar' }, status => 400) unless $id;

  $self->render(status => 201, json => { id => $id });
}

# ---------------------------------------------------------------------------
# GET /api/chat/conversas
#
# Lista conversas do gestor logado (paginado).
# Query: page, per_page, from (YYYY-MM-DD), to (YYYY-MM-DD)
# ---------------------------------------------------------------------------

sub list_conversas ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;

  my $v = $self->validation;
  $v->optional('page', 'trim')->num;
  $v->optional('per_page', 'trim')->num;
  $v->optional('from', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  $v->optional('to', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  return $self->bad_req if $v->has_error;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $res = $model->list_conversas($gestor->{id} + 0, {
    page     => $v->param('page') // 1,
    per_page => $v->param('per_page') // 20,
    from     => $v->param('from'),
    to       => $v->param('to'),
  });
  $self->render(json => $res);
}

# ---------------------------------------------------------------------------
# GET /api/chat/conversas/:id
#
# Detalha uma conversa com todas as mensagens.
# ---------------------------------------------------------------------------

sub show_conversa ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;
  my $id = $self->param('id');
  return $self->bad_req unless $id =~ /^\d+$/;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $conv = $model->get_conversa($gestor->{id} + 0, $id + 0);
  return $self->render(json => { error => 'Conversa não encontrada' }, status => 404) unless $conv;

  $self->render(json => $conv);
}

# ---------------------------------------------------------------------------
# DELETE /api/chat/conversas/:id
#
# Exclui uma conversa do gestor logado.
# ---------------------------------------------------------------------------

sub delete_conversa ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;
  my $id = $self->param('id');
  return $self->bad_req unless $id =~ /^\d+$/;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $ok = eval { $model->delete_conversa($gestor->{id} + 0, $id + 0) };
  return $self->render(json => { error => 'Erro ao excluir conversa' }, status => 500) if $@;
  return $self->render(json => { error => 'Conversa não encontrada' }, status => 404) unless $ok;

  $self->rendered(204);
}

# ---------------------------------------------------------------------------
# GET /api/chat/conversas/search
#
# Busca full-text no conteúdo das mensagens.
# Query: q (termo), page, per_page
# ---------------------------------------------------------------------------

sub search_conversas ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;

  my $v = $self->validation;
  $v->required('q', 'trim')->size(1, 200);
  $v->optional('page', 'trim')->num;
  $v->optional('per_page', 'trim')->num;
  return $self->bad_req if $v->has_error;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $res = $model->search_conversas($gestor->{id} + 0, $v->param('q'), {
    page     => $v->param('page') // 1,
    per_page => $v->param('per_page') // 20,
  });
  $self->render(json => $res);
}

# ---------------------------------------------------------------------------
# GET /api/chat/conversas/calendar
#
# Dias com conversas no intervalo [from, to].
# Query: from (YYYY-MM-DD), to (YYYY-MM-DD)
# Retorna { "YYYY-MM-DD": count, ... }
# ---------------------------------------------------------------------------

sub calendar_conversas ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;

  my $v = $self->validation;
  $v->required('from', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  $v->required('to', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  return $self->bad_req if $v->has_error;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $cal = $model->calendar_conversas($gestor->{id} + 0, $v->param('from'), $v->param('to'));
  $self->render(json => $cal);
}

# ---------------------------------------------------------------------------
# GET /api/chat/conversas/export
#
# Exporta conversas selecionadas (ids[]) ou todas (all=1) para Markdown.
# Query: ids[]=1,2,3 ou all=1
# Retorna text/markdown com header Content-Disposition.
# ---------------------------------------------------------------------------

sub export_conversas ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;

  my $ids = $self->req->params->to_hash->{ids} // [];
  $ids = [$ids] unless ref $ids eq 'ARRAY';
  my $all = $self->req->params->to_hash->{all} // 0;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $md = $model->export_conversas($gestor->{id} + 0, { ids => $ids, all => $all });

  my $date = strftime('%Y-%m-%d', localtime);
  $self->res->headers->content_type('text/markdown; charset=utf-8');
  $self->res->headers->content_disposition("attachment; filename=\"conversas-$date.md\"");
  $self->render(text => $md);
}

1;
