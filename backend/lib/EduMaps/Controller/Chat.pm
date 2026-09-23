package EduMaps::Controller::Chat;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;

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

1;
