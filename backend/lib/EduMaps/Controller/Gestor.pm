package EduMaps::Controller::Gestor;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

use File::Path qw(make_path);

# API do painel do gestor escolar (/api/gestor/...) + módulo Reuniões e Atas
# (contatos, grupos por drag-and-drop, agendamento com atas e anexos).
# O sub-módulo de reuniões exige sessão do gestor (bearer em clean.sessoes):
#   _require_gestor injeta o gestor no stash; _gestor_inep_ok garante que a
#   rota /:cod_inep/... pertence à escola logada.

use constant EMAIL_RE => qr/^[\w.+\-]+@[\w.\-]+\.[A-Za-z]{2,}$/;
use constant QUANDO_RE => qr/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2})?$/;
use constant AVISOS => qw(whatsapp email todos);

# ---------------------------------------------------------------------------
# painel / similares (públicos)
# ---------------------------------------------------------------------------

sub panel($self) {
  my $cod_inep = $self->param('cod_inep');
  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $model->panel({ cod_inep => $cod_inep });

  unless ($result) {
    return $self->render(
      json => { error => "Escola não encontrada para o INEP $cod_inep" },
      status => 404,
    );
  }

  $self->render(json => $result);
}

sub similares($self) {
  my $cod_inep = $self->param('cod_inep');
  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $model->similar_schools({
    cod_inep => $cod_inep,
    scope    => $self->param('scope'),
    limit    => $self->param('limit'),
  });

  unless ($result) {
    return $self->render(
      json => { error => "Escola não encontrada para o INEP $cod_inep" },
      status => 404,
    );
  }

  $self->render(json => $result);
}

# ---------------------------------------------------------------------------
# autenticação (bearer)
# ---------------------------------------------------------------------------

sub me($self) {
  $self->render(json => $self->stash('gestor'));
}

sub logout($self) {
  my $model = $self->instantiate_model(model => 'Pesquisa');
  $model->logout_gestor($self->stash('gestor_token'));
  $self->render(status => 204, text => '');
}

# Gatilho dos under() autenticados: valida o Bearer token e injeta o gestor.
sub _require_gestor($self) {
  my $auth  = $self->req->headers->authorization // '';
  my ($token) = $auth =~ /^Bearer\s+(\S+)$/;

  my $gestor = $token
    ? $self->instantiate_model(model => 'Pesquisa')->sessao_valida($token)
    : undef;

  if (!$gestor) {
    $self->_render_unauthorized;
    return 0;
  }

  $self->stash(gestor => $gestor, gestor_token => $token);
  return 1;
}

# Garante que o cod_inep da rota é o da escola logada (403 caso contrário).
sub _gestor_inep_ok($self) {
  my $gestor = $self->stash('gestor');
  my $inep   = $self->param('cod_inep');
  if (($gestor->{cod_inep} || 0) . '' ne ($inep // '')) {
    $self->render(json => { error => 'Você só administra a sua própria escola.' }, status => 403);
    return 0;
  }
  return 1;
}

# ---------------------------------------------------------------------------
# contatos
# ---------------------------------------------------------------------------

sub contatos_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->list_contatos($self->param('cod_inep')));
}

sub contatos_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->_contato_validation($input);
  return unless $v;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $contato = $self->_guard_api(sub {
    $model->create_contato($self->param('cod_inep'), $self->stash('gestor')->{id}, {
      nome      => $v->param('nome'),
      email     => $v->param('email'),
      telefone  => $v->param('telefone'),
      cargo     => $v->param('cargo'),
      grupo_id  => $v->param('grupo_id'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Contato não pôde ser salvo') unless $contato;
  $self->render(status => 201, json => $contato);
}

sub contatos_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->_contato_validation($input);
  return unless $v;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $contato = $self->_guard_api(sub {
    $model->update_contato($self->param('id'), $self->param('cod_inep'), {
      nome      => $v->param('nome'),
      email     => $v->param('email'),
      telefone  => $v->param('telefone'),
      cargo     => $v->param('cargo'),
      grupo_id  => $v->param('grupo_id'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Contato não encontrado') unless $contato;
  $self->render(json => $contato);
}

sub contatos_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Contato não encontrado')
    unless $model->delete_contato($self->param('id'), $self->param('cod_inep'));
  $self->render(status => 204, text => '');
}

# Import em lote: colagem de texto normalizada no frontend -> [{nome,email,
# telefone,cargo,grupo}]. Grupos inexistentes são criados.
sub contatos_import($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $contatos = $input->{contatos};
  return $self->render(json => { error => 'contatos deve ser uma lista' }, status => 400)
    unless ref $contatos eq 'ARRAY' && @$contatos;

  return $self->render(json => { error => 'O import aceita no máximo 200 contatos por vez' }, status => 400)
    if @$contatos > 200;

  my $nome = 1;
  for my $c (@$contatos) {
    return $self->render(json => { error => "Contato #$nome deve ser um objeto" }, status => 400)
      unless ref $c eq 'HASH';
    $c->{nome} = '' unless defined $c->{nome};
    $c->{nome} =~ s/^\s+|\s+$//g;
    return $self->render(json => { error => "Contato #$nome: nome vazio (use \"nome;email;telefone;grupo\")" }, status => 400)
      unless length($c->{nome}) >= 1 && length($c->{nome}) <= 80;
    if (defined $c->{email} && length $c->{email}) {
      $c->{email} =~ s/^\s+|\s+$//g;
      $c->{email} = lc $c->{email};
      return $self->render(json => { error => "Contato #$nome: e-mail inválido" }, status => 400)
        unless $c->{email} =~ EMAIL_RE;
    } else {
      $c->{email} = undef;
    }
    if (defined $c->{telefone} && length $c->{telefone}) {
      $c->{telefone} =~ s/^\s+|\s+$//g;
      $c->{telefone} =~ s/[^\d+]//g;
      return $self->render(json => { error => "Contato #$nome: telefone muito curto" }, status => 400)
        if length($c->{telefone}) < 8;
      $c->{telefone} = undef if length($c->{telefone}) > 20;
    } else {
      $c->{telefone} = undef;
    }
    if (defined $c->{grupo} && length $c->{grupo}) {
      $c->{grupo} =~ s/^\s+|\s+$//g;
      return $self->render(json => { error => "Contato #$nome: grupo com mais de 60 caracteres" }, status => 400)
        if length($c->{grupo}) > 60;
    } else {
      $c->{grupo} = undef;
    }
    $c->{cargo} = undef unless defined $c->{cargo} && length $c->{cargo};
    $nome++;
  }

  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $self->_guard_api(sub {
    $model->import_contatos($self->param('cod_inep'), $self->stash('gestor')->{id}, $contatos);
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Nenhum contato importado') unless $result;
  $self->render(status => 201, json => $result);
}

sub _contato_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 80);
  $v->optional('email', 'trim')->like(EMAIL_RE);
  $v->optional('telefone', 'trim')->size(8, 20);
  $v->optional('cargo', 'trim')->size(3, 60);
  $v->optional('grupo_id', 'trim')->num;
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $v;
}

# ---------------------------------------------------------------------------
# grupos
# ---------------------------------------------------------------------------

sub grupos_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  # Grupos pré-listados da folha de pagamento (idempotente; custo O(1) quando já existem).
  $model->sincronizar_grupos_folha($self->param('cod_inep'));
  $self->render(json => $model->list_grupos($self->param('cod_inep')));
}

sub grupos_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 60);
  return $self->_render_validation($v) if $v->has_error;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $grupo = $self->_guard_api(sub {
    $model->create_grupo($self->param('cod_inep'), $self->stash('gestor')->{id}, $v->param('nome'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Grupo não pôde ser criado') unless $grupo;
  $self->render(status => 201, json => $grupo);
}

sub grupos_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 60);
  return $self->_render_validation($v) if $v->has_error;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $grupo = $self->_guard_api(sub {
    $model->update_grupo($self->param('id'), $self->param('cod_inep'), $v->param('nome'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Grupo não encontrado') unless $grupo;
  $self->render(json => $grupo);
}

sub grupos_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Grupo não encontrado')
    unless $model->delete_grupo($self->param('id'), $self->param('cod_inep'));
  $self->render(status => 204, text => '');
}

# ---------------------------------------------------------------------------
# gestor responsável pela agenda
# ---------------------------------------------------------------------------

sub escola_perfil($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->perfil_escola($self->param('cod_inep')));
}

sub agenda_transferir($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('novo_gestor_id', 'trim')->num;
  return $self->_render_validation($v) if $v->has_error;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $res = $model->transferir_agenda(
    $self->param('cod_inep'),
    $self->stash('gestor')->{id},
    $v->param('novo_gestor_id'),
  );

  if ($res->{error}) {
    return $self->_render_not_found('O gestor de destino não pertence a esta escola.')
      if $res->{error} eq 'novo_gestor';
    return $self->render(json => { error => 'Só o gestor responsável pela agenda pode transferir o vínculo.' }, status => 403);
  }

  $self->render(json => $res);
}

# ---------------------------------------------------------------------------
# reuniões
# ---------------------------------------------------------------------------

sub reunioes_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $filtros = {
    q      => $self->param('q'),
    status => $self->param('status'),
    de     => $self->param('de'),
    ate    => $self->param('ate'),
  };
  $self->render(json => $model->list_reunioes($self->param('cod_inep'), $filtros));
}

sub reunioes_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->_reuniao_validation($input) or return;
  my $ids = $self->_participant_ids($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $reuniao = $self->_guard_api(sub {
    $model->agendar_reuniao({
      cod_inep      => $self->param('cod_inep'),
      gestor_id     => $self->stash('gestor')->{id},
      titulo        => $v->param('titulo'),
      quando        => $v->param('quando'),
      duracao_min   => $v->param('duracao_min'),
      onde_label    => $v->param('onde_label'),
      onde_link     => $v->param('onde_link'),
      aviso_metodo  => $v->param('aviso_metodo'),
      pauta_texto   => $v->param('pauta_texto'),
      contato_ids   => $ids->{contato_ids},
      grupo_ids     => $ids->{grupo_ids},
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Reunião não pôde ser agendada') unless $reuniao;
  $self->render(status => 201, json => $reuniao);
}

sub reunioes_show($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $reuniao = $model->detalhe_reuniao($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Reunião não encontrada') unless $reuniao;
  $self->render(json => $reuniao);
}

sub reunioes_update($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $state = $model->reuniao_state($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Reunião não encontrada') unless $state;
  return $self->_render_conflict('Só é possível editar reuniões ainda agendadas')
    if $state->{status} ne 'agendada';

  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->_reuniao_validation($input) or return;
  my $ids = $self->_participant_ids($input) or return;

  my $reuniao = $self->_guard_api(sub {
    $model->update_reuniao($self->param('id'), $self->param('cod_inep'), {
      titulo        => $v->param('titulo'),
      quando        => $v->param('quando'),
      duracao_min   => $v->param('duracao_min'),
      onde_label    => $v->param('onde_label'),
      onde_link     => $v->param('onde_link'),
      aviso_metodo  => $v->param('aviso_metodo'),
      pauta_texto   => $v->param('pauta_texto'),
      contato_ids   => $ids->{contato_ids},
      grupo_ids     => $ids->{grupo_ids},
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Reunião não encontrada') unless $reuniao;
  $self->render(json => $reuniao);
}

sub reunioes_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $state = $model->reuniao_state($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Reunião não encontrada') unless $state;
  return $self->_render_conflict('Reunião realizada não pode ser excluída')
    if $state->{status} eq 'realizada';
  $model->excluir_reuniao($self->param('id'), $self->param('cod_inep'));
  $self->render(status => 204, text => '');
}

sub reunioes_salvar_ata($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => {error => 'Corpo JSON inválido'}, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('ata_texto', 'trim')->size(0, 20000);
  return $self->_render_validation($v) if $v->has_error;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $state = $model->reuniao_state($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Reunião não encontrada') unless $state;
  return $self->_render_conflict('Reunião cancelada não recebe ata')
    if $state->{status} eq 'cancelada';

  my $reuniao = $model->salvar_ata($self->param('id'), $self->param('cod_inep'), $v->param('ata_texto'));
  return $self->_render_not_found('Reunião não encontrada') unless $reuniao;
  $self->render(json => $reuniao);
}

sub reunioes_marcar_realizada($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $reuniao = $model->marcar_realizada($self->param('id'), $self->param('cod_inep'));
  return $self->_render_conflict('Só reuniões agendadas podem ser marcadas como realizadas')
    unless $reuniao;
  $self->render(json => $reuniao);
}

sub reunioes_cancelar($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $reuniao = $model->cancelar_reuniao($self->param('id'), $self->param('cod_inep'));
  return $self->_render_conflict('Só reuniões agendadas podem ser canceladas')
    unless $reuniao;
  $self->render(json => $reuniao);
}

# POST multipart: campo "arquivo" + tipo (pauta|ata, da rota).
sub reunioes_anexos($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $tipo) = ($self->param('cod_inep'), $self->param('id'), $self->param('tipo'));
  my $model = $self->instantiate_model(model => 'Gestor');
  my $state = $model->reuniao_state($id, $cod_inep);
  return $self->_render_not_found('Reunião não encontrada') unless $state;

  my $upload = $self->req->upload('arquivo');
  return $self->render(json => { error => 'O anexo é obrigatório (campo "arquivo").' }, status => 400)
    unless $upload && $upload->size;

  return $self->render(json => { error => 'O arquivo não pode passar de 10 MB.' }, status => 400)
    if $upload->size > $model->max_upload_bytes;

  my ($nome, $dot, $ext) = $upload->filename =~ /^(.*)(\.)([^.\/]+)$/;
  $ext = lc($ext // '');
  my $mime = $model->ext_mime->{$ext};
  $self->app->log->debug(sprintf 'anexo upload: filename=[%s] ext=[%s] mime=[%s]', $upload->filename, $ext, $mime // '');
  return $self->render(
    json => { error => 'Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT.' },
    status => 400,
  ) unless $mime;

  my $uuid = Mojo::Util::sha1_hex(join('|', time, $$, rand, $upload->filename, $tipo));
  my $rel  = qq{$cod_inep/$id/$uuid.$ext};
  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$rel";

  eval { make_path("$base/$cod_inep/$id"); 1 }
    or return $self->render(json => { error => 'Não foi possível preparar o armazenamento.' }, status => 500);

  $upload->move_to($abs)
    or return $self->render(json => { error => 'Não foi possível salvar o arquivo.' }, status => 500);

  my $reuniao = $model->registrar_anexo($id, $cod_inep, $tipo, {
    nome_original => $upload->filename,
    caminho       => $rel,
    mime          => $mime,
    tamanho       => $upload->size,
  });

  if (!$reuniao) {
    unlink $abs;
    return $self->_render_conflict('Reunião inexistente — anexo descartado');
  }
  $self->render(status => 201, json => $reuniao);
}

sub reunioes_anexo_get($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $tipo) = ($self->param('cod_inep'), $self->param('id'), $self->param('tipo'));
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->anexo_row($id, $cod_inep, $tipo);
  return $self->_render_not_found('Anexo não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  return $self->_render_not_found('Arquivo não encontrado no servidor') unless -f $abs;

  $self->reply->file($abs, { filename => $row->{nome_original} });
}

sub _reuniao_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('titulo', 'trim')->size(3, 120);
  $v->required('quando', 'trim')->like(QUANDO_RE);
  $v->optional('duracao_min', 'trim');
  $v->optional('onde_label', 'trim')->size(1, 120);
  $v->optional('onde_link', 'trim')->size(1, 500);
  $v->optional('pauta_texto', 'trim')->size(0, 5000);
  $v->optional('aviso_metodo', 'trim');
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }

  my $duracao = $v->param('duracao_min');
  if (defined $duracao && length $duracao) {
    if ($duracao !~ /^\d+$/ || $duracao < 15 || $duracao > 480) {
      $self->render(json => { error => 'A duração deve ser de 15 a 480 minutos.' }, status => 400);
      return;
    }
  } else {
    $duracao = 60;
  }

  my $aviso = $v->param('aviso_metodo') // 'todos';
  if (!grep { $_ eq $aviso } AVISOS) {
    $self->render(json => { error => 'Método de aviso inválido.' }, status => 400);
    return;
  }

  $input->{__duracao} = $duracao;
  $input->{__aviso}   = $aviso;
  return $v;
}

sub _participant_ids($self, $input) {
  my @contato_ids = ();
  if (my $ids = $input->{contato_ids}) {
    if (ref $ids ne 'ARRAY') {
      $self->render(json => { error => 'contato_ids deve ser uma lista' }, status => 400);
      return;
    }
    for my $id (@$ids) {
      next unless defined $id;
      push @contato_ids, $id + 0 if $id =~ /^\d+$/;
    }
  }
  my @grupo_ids = ();
  if (my $ids = $input->{grupo_ids}) {
    if (ref $ids ne 'ARRAY') {
      $self->render(json => { error => 'grupo_ids deve ser uma lista' }, status => 400);
      return;
    }
    for my $id (@$ids) {
      next unless defined $id;
      push @grupo_ids, $id + 0 if $id =~ /^\d+$/;
    }
  }

  if (!@contato_ids && !@grupo_ids) {
    $self->render(json => { error => 'Selecione ao menos uma pessoa ou grupo.' }, status => 400);
    return;
  }

  return { contato_ids => \@contato_ids, grupo_ids => \@grupo_ids };
}

# ---------------------------------------------------------------------------
# helpers de renderização / guarda de erros de banco
# ---------------------------------------------------------------------------

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

# Executa uma chamada de modelo e traduz erros de banco conhecidos em respostas
# HTTP amigáveis (email/grupo duplicado, timestamp inválido). Se um erro de
# banco disparar render(), marca guard_rendered para o action não render de novo.
sub _guard_api($self, $code) {
  $self->stash(guard_rendered => undef);
  my ($ok, @out) = eval { (1, $code->()) };
  unless ($ok) {
    $self->_render_db_error($@ || '');
    $self->stash(guard_rendered => 1);
    return;
  }
  return $out[0];
}

sub _render_db_error($self, $err) {
  $self->app->log->error("Gestor::Reunioes db error: $err");
  if ($err =~ /duplicate key value violates unique constraint "uq_contatos_inep_email"/) {
    return $self->render(json => { error => 'Já existe um contato com este e-mail para esta escola.' }, status => 409);
  }
  if ($err =~ /contato_grupos_cod_inep_nome_key/) {
    return $self->render(json => { error => 'Já existe um grupo com este nome nesta escola.' }, status => 409);
  }
  if ($err =~ /(?:invalid input syntax for type timestamp|date\/time field value out of range)/) {
    return $self->render(json => { error => 'A data e a hora da reunião são inválidas.' }, status => 400);
  }
  $self->render(status => 500, json => { error => 'Erro interno ao salvar.' });
}

sub _render_validation($self, $v) {
  my @failed = $v->failed->@*;
  $self->app->log->debug('Gestor validation errors: ' . join(', ', map { "$_: " . join(', ', @{$v->error($_)}) } @failed));
  $self->render(json => { error => $self->_validation_message($v, $failed[0]) }, status => 400);
}

# Rótulos amigáveis por campo (o nome do check sozinho — ex.: "like" — não
# diz nada ao usuário).
my %CAMPO_LABEL = (
  titulo       => 'título',
  quando       => 'data e hora',
  nome         => 'nome',
  email        => 'e-mail',
  telefone     => 'telefone',
  cargo        => 'cargo',
  grupo_id     => 'grupo',
  duracao_min  => 'duração',
  onde_label   => 'local',
  onde_link    => 'link',
  pauta_texto  => 'pauta',
  ata_texto    => 'ata',
  aviso_metodo => 'método de aviso',
);

sub _validation_message($self, $v, $field) {
  my ($check) = @{ $v->error($field) // [] };
  my $label = $CAMPO_LABEL{$field} // $field;
  return 'Campo obrigatório.' if ($check // '') eq 'required';
  return "O campo $label está inválido." if ($check // '') eq 'like';
  return "O campo $label está fora do tamanho permitido." if ($check // '') eq 'size';
  return "O campo $label deve ser numérico." if ($check // '') eq 'num';
  return "O campo $label é inválido.";
}

sub _render_not_found($self, $msg) {
  $self->render(json => { error => $msg }, status => 404);
}

sub _render_conflict($self, $msg) {
  $self->render(json => { error => $msg }, status => 409);
}

sub _render_unauthorized($self) {
  $self->render(json => { error => 'Faça login como gestor.' }, status => 401);
}

1;

=head1 NAME

EduMaps::Controller::Gestor - API do painel do gestor escolar

=head1 DESCRIPTION

Raio-x de uma escola para o gestor (painel, similares) a partir do Censo
Escolar, além do módulo Reuniões e Atas: contatos e grupos (agenda PII do
gestor), agendamento de reuniões com método de aviso (convite copiável —
sem envio real), atas e anexos em upload_dir.

=cut