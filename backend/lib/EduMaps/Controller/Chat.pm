package EduMaps::Controller::Chat;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;
use Mojo::JSON ();
use POSIX qw(strftime);

has _default_poll_time => 1;

# ---------------------------------------------------------------------------
# POST /api/chat/ask
#
# Enfileira a pergunta ao Assistente do Censo (chat NL->SQL) na fila dedicada
# 'analytics' e devolve 202 + Location para polling/SSE. Exige gestor logado
# (#224): o escopo (escola, município, UF) vem SEMPRE da sessão — qualquer
# `contexto` enviado pelo cliente é ignorado. Só a `pergunta` é validada.
# ---------------------------------------------------------------------------

sub ask ($self) {
  my $gestor = $self->stash('gestor') or return $self->unauthorized;

  my $is_json = ($self->req->headers->content_type // '') =~ m{^application/json};
  my $input = $is_json ? $self->req->json : $self->req->params->to_hash;
  $input = {} unless ref $input eq 'HASH';

  my $v = $self->app->validator->validation;
  $v->input({ pergunta => $input->{pergunta} });
  $v->required('pergunta', 'trim')->like(qr/^.{1,500}\z/s);
  return $self->bad_req if $v->has_error;

  my $cod_inep = '' . ($gestor->{cod_inep} // '');
  my $args = {
    pergunta  => $v->param('pergunta'),
    contexto  => $self->_contexto_da_sessao($cod_inep),
    gestor_id => '' . $gestor->{id},
    cod_inep  => $cod_inep,
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
# /api/task/progress. Só devolve jobs `chat_ask` do gestor da sessão; job
# inexistente, de outra task ou de outro gestor -> 404 (sem distinguir).
# ---------------------------------------------------------------------------

sub progress ($self) {
  my $v = $self->validation;
  $v->required('job_id', 'trim')->num;

  return $self->bad_req if $self->any_error;

  my $job_id = $v->param('job_id');
  my $job = $self->_job_do_gestor($job_id)
    or return $self->render(json => { error => 'job_not_found' }, status => 404);

  # SSE só para job em andamento; em estado terminal o monitor não teria o que
  # transmitir (e a requisição ficaria pendurada) — devolve o snapshot.
  if (($self->req->headers->accept // '') =~ m{text/event-stream}i
      && $job->{state} !~ /^(?:finished|failed)$/) {
    $self->render_later;
    return $self->monitor_chat($job_id);
  }

  my %resp = (state => $job->{state});
  if ($job->{state} eq 'failed') {
    my $err = $job->{error} // $job->{result};
    $resp{error} = ref $err eq 'HASH' ? ($err->{error} // Mojo::JSON::encode_json($err)) : "$err";
  }
  elsif ($job->{state} eq 'finished') {
    $resp{result} = $job->{result};
  }
  $self->render(json => \%resp);
}

# Contexto (escopo) do Assistente montado a partir da escola do gestor da
# sessão: escola, município e UF da edição mais recente do Censo
# (clean.censo_escolas). Escola fora do Censo: só o cod_inep.
sub _contexto_da_sessao ($self, $cod_inep) {
  return {} unless $cod_inep =~ /^\d{8}$/;

  my $recorte = eval { $self->model('Gestor')->recorte_padrao($cod_inep) };
  $self->app->log->warn("Assistente do Censo: recorte da escola $cod_inep falhou: $@") if $@;
  return { cod_inep => $cod_inep } unless $recorte;

  my %ctx = (cod_inep => $cod_inep);
  $ctx{nome_escola}    = $recorte->{escola}{nome}       if defined $recorte->{escola}{nome};
  $ctx{cod_municipio}  = $recorte->{municipio}{codigo}  if defined $recorte->{municipio}{codigo};
  $ctx{nome_municipio} = $recorte->{municipio}{nome}    if defined $recorte->{municipio}{nome};
  $ctx{sg_uf}          = $recorte->{uf}{codigo}         if defined $recorte->{uf}{codigo};
  return \%ctx;
}

# info do job chat_ask se ele é do gestor da sessão; undef para job
# inexistente, de outra task ou de outro gestor (não vaza a existência de
# jobs alheios). Mesmo padrão de GestorRelatorios::_job_do_gestor.
sub _job_do_gestor ($self, $job_id) {
  my $gestor = $self->stash('gestor') // {};

  my $job  = $self->minion->job($job_id);
  my $info = $job ? $job->info : undef;
  my $args = $info && ref $info->{args} eq 'ARRAY' ? $info->{args}[0] : undef;

  return undef
    unless $info
        && $info->{task} eq 'chat_ask'
        && ref $args eq 'HASH'
        && defined $args->{gestor_id}
        && $args->{gestor_id} eq ('' . ($gestor->{id} // ''));
  return $info;
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

    # `meta` é um objeto livre (o frontend envia {timestamp, sql, resultado,
    # origem}). Texto solto, array ou número não têm onde ser gravados: o
    # Postgres recusaria com "invalid input syntax for type json" e a
    # requisição estoura em 500 com a página de erro em HTML.
    my $meta = $msg->{meta};
    return $self->render(json => { error => 'meta deve ser um objeto JSON' }, status => 400)
      if defined $meta && ref $meta ne 'HASH';

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

  # O `to_hash` do Mojolicious NÃO converte a notação `ids[]`: o nome da
  # chave fica literalmente `ids[]`. Com isso, um cliente que mandasse
  # `?ids[]=1&ids[]=2` caía no `@ids` vazio e o export saía com **todas**
  # as conversas do gestor, em silêncio. A forma que o backend de fato lê
  # é `?ids=1&ids=2`, mas aceitamos as duas — e cada valor pode chegar
  # como string (uma ocorrência) ou arrayref (várias), daí o `_lista`.
  my $lista = sub {
    my $v = shift;
    return () unless defined $v;
    return ref $v eq 'ARRAY' ? @$v : ($v);
  };

  my $hash = $self->req->params->to_hash;
  my @raw  = ($lista->($hash->{ids}), $lista->($hash->{'ids[]'}));
  my $ids  = [grep { /^\d+$/ } @raw];
  my $all  = $hash->{all} // 0;

  my $model = $self->instantiate_model(model => 'Chat::Conversas');
  my $md = $model->export_conversas($gestor->{id} + 0, { ids => $ids, all => $all });

  my $date = strftime('%Y-%m-%d', localtime);
  $self->res->headers->content_type('text/markdown; charset=utf-8');
  $self->res->headers->content_disposition("attachment; filename=\"conversas-$date.md\"");
  $self->render(text => $md);
}

1;
