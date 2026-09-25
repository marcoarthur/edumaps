package EduMaps::Controller::Gestor;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

use File::Path qw(make_path);
use DateTime;

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

# Gatilho dos under() administrativos: sessão de gestor válida + papel admin
# (access_role = 'admin' em clean.gestores) — Painel de Configuração.
sub _require_admin($self) {
  my $auth  = $self->req->headers->authorization // '';
  my ($token) = $auth =~ /^Bearer\s+(\S+)$/;

  my $gestor = $token
    ? $self->instantiate_model(model => 'Pesquisa')->sessao_valida($token)
    : undef;

  if (!$gestor) {
    $self->_render_unauthorized;
    return 0;
  }

  if (($gestor->{access_role} // '') ne 'admin') {
    $self->render(
      json => { error => 'Acesso restrito a administradores da instalação.' },
      status => 403,
    );
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

# Importa os profissionais da folha de pagamento como contatos da escola
# (nome + cargo), vinculados aos grupos pré-listados da folha.
sub contatos_importar_folha($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $result = $self->_guard_api(sub {
    $model->importar_contatos_folha($self->param('cod_inep'), $self->stash('gestor')->{id});
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
  }

  my $aviso = $v->param('aviso_metodo') // 'todos';
  if (!grep { $_ eq $aviso } AVISOS) {
    $self->render(json => { error => 'Método de aviso inválido.' }, status => 400);
    return;
  }

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
# inventário escolar (recursos e serviços)
# ---------------------------------------------------------------------------

sub inventario_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $inep  = $self->param('cod_inep');
  $model->sincronizar_categorias_censo($inep);
  my $censo = $model->inventario_censo($inep, $self->param('ano'));
  $self->render(json => {
    ano          => $censo ? $censo->{ano} : ($self->param('ano') ? $self->param('ano') + 0 : 2025),
    censo        => $censo,
    categorias   => $model->list_categorias($inep),
    fornecedores => $model->list_fornecedores($inep),
    itens        => $model->list_itens($inep),
  });
}

sub inventario_itens_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->list_itens($self->param('cod_inep'), {
    tipo         => $self->param('tipo'),
    categoria_id => $self->param('categoria_id'),
    q            => $self->param('q'),
  }));
}

sub inventario_importar_censo($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $res = $self->_guard_api(sub {
    $model->importar_censo($self->param('cod_inep'), $self->stash('gestor')->{id}, $self->param('ano'));
  });
  return if $self->stash('guard_rendered');
  $self->render(json => $res);
}

# --- categorias ------------------------------------------------------------

sub inventario_categoria_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_categoria_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $cat = $self->_guard_api(sub {
    $model->create_categoria($self->param('cod_inep'), $self->stash('gestor')->{id}, {
      tipo => $v->param('tipo'), nome => $v->param('nome'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não pôde ser criada') unless $cat;
  $self->render(status => 201, json => $cat);
}

sub inventario_categoria_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_categoria_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $cat = $self->_guard_api(sub {
    $model->update_categoria($self->param('id'), $self->param('cod_inep'), {
      tipo => $v->param('tipo'), nome => $v->param('nome'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não encontrada') unless $cat;
  $self->render(json => $cat);
}

sub inventario_categoria_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $ok = $self->_guard_api(sub {
    $model->delete_categoria($self->param('id'), $self->param('cod_inep'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não encontrada') unless $ok;
  $self->render(status => 204, text => '');
}

# --- fornecedores ----------------------------------------------------------

sub inventario_fornecedor_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_fornecedor_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $f = $self->_guard_api(sub {
    $model->create_fornecedor($self->param('cod_inep'), $self->stash('gestor')->{id},
      $self->_fornecedor_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Fornecedor não pôde ser criado') unless $f;
  $self->render(status => 201, json => $f);
}

sub inventario_fornecedor_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_fornecedor_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $f = $self->_guard_api(sub {
    $model->update_fornecedor($self->param('id'), $self->param('cod_inep'),
      $self->_fornecedor_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Fornecedor não encontrado') unless $f;
  $self->render(json => $f);
}

sub inventario_fornecedor_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $ok = $self->_guard_api(sub {
    $model->delete_fornecedor($self->param('id'), $self->param('cod_inep'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Fornecedor não encontrado') unless $ok;
  $self->render(status => 204, text => '');
}

# --- itens -----------------------------------------------------------------

sub inventario_item_show($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $item = $model->item_detail($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Item não encontrado') unless $item;
  $self->render(json => $item);
}

sub inventario_item_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_item_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $item = $self->_guard_api(sub {
    $model->create_item($self->param('cod_inep'), $self->stash('gestor')->{id},
      $self->_item_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Item não pôde ser criado') unless $item;
  $self->render(status => 201, json => $item);
}

sub inventario_item_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_item_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $item = $self->_guard_api(sub {
    $model->update_item($self->param('id'), $self->param('cod_inep'),
      $self->_item_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Item não encontrado') unless $item;
  $self->render(json => $item);
}

sub inventario_item_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  my $caminhos = $model->item_anexos_caminhos($id, $cod_inep);

  my $ok = $self->_guard_api(sub { $model->delete_item($id, $cod_inep) });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Item não encontrado') unless $ok;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  unlink "$base/$_->{caminho}" for @$caminhos;
  $self->render(status => 204, text => '');
}

# --- anexos ----------------------------------------------------------------

sub inventario_anexo_create($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Item não encontrado') unless $model->item_state($id, $cod_inep);

  my $upload = $self->req->upload('arquivo');
  return $self->render(json => { error => 'O anexo é obrigatório (campo "arquivo").' }, status => 400)
    unless $upload && $upload->size;

  return $self->render(json => { error => 'O arquivo não pode passar de 10 MB.' }, status => 400)
    if $upload->size > $model->max_upload_bytes;

  my ($nome, $dot, $ext) = $upload->filename =~ /^(.*)(\.)([^.\/]+)$/;
  $ext = lc($ext // '');
  my $mime = $model->ext_mime->{$ext};
  return $self->render(
    json => { error => 'Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT.' },
    status => 400,
  ) unless $mime;

  my $uuid = Mojo::Util::sha1_hex(join('|', time, $$, rand, $upload->filename, $id));
  my $rel  = qq{$cod_inep/inventario/$id/$uuid.$ext};
  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$rel";

  eval { make_path("$base/$cod_inep/inventario/$id"); 1 }
    or return $self->render(json => { error => 'Não foi possível preparar o armazenamento.' }, status => 500);

  $upload->move_to($abs)
    or return $self->render(json => { error => 'Não foi possível salvar o arquivo.' }, status => 500);

  my $res = $model->registrar_anexo_item($id, $cod_inep, {
    nome_original => $upload->filename,
    caminho       => $rel,
    mime          => $mime,
    tamanho       => $upload->size,
  });
  if (!$res) {
    unlink $abs;
    return $self->_render_conflict('Item inexistente — anexo descartado');
  }
  $self->render(status => 201, json => $res);
}

sub inventario_anexo_get($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->anexo_item_row($self->param('id'), $self->param('cod_inep'), $self->param('anexo_id'));
  return $self->_render_not_found('Anexo não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  return $self->_render_not_found('Arquivo não encontrado no servidor') unless -f $abs;

  $self->reply->file($abs, { filename => $row->{nome_original} });
}

sub inventario_anexo_delete($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->delete_anexo_item($self->param('id'), $self->param('cod_inep'), $self->param('anexo_id'));
  return $self->_render_not_found('Anexo não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  unlink $abs if -f $abs;
  $self->render(status => 204, text => '');
}

# --- validação do inventário ----------------------------------------------

sub _categoria_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('tipo', 'trim')->like(qr/^(?:recurso|servico)$/);
  $v->required('nome', 'trim')->size(1, 80);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $v;
}

sub _fornecedor_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 120);
  $v->optional('tipo_servico', 'trim')->size(1, 60);
  $v->optional('email', 'trim')->like(EMAIL_RE);
  $v->optional('telefone', 'trim')->size(8, 20);
  $v->optional('site', 'trim')->size(1, 300);
  $v->optional('documento', 'trim')->size(1, 40);
  $v->optional('observacoes', 'trim')->size(0, 2000);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $self->_check_atributos($input) ? $v : undef;
}

sub _item_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('categoria_id', 'trim')->num;
  $v->required('nome', 'trim')->size(1, 120);
  $v->optional('fornecedor_id', 'trim')->num;
  $v->optional('descricao', 'trim')->size(0, 2000);
  $v->optional('quantidade', 'trim')->like(qr/^\d+(?:[.,]\d{1,3})?$/);
  $v->optional('unidade', 'trim')->size(1, 30);
  $v->optional('estado', 'trim')->size(1, 40);
  $v->optional('identificador', 'trim')->size(1, 120);
  $v->optional('periodicidade', 'trim')->size(1, 40);
  $v->optional('valor', 'trim')->like(qr/^\d+(?:[.,]\d{1,2})?$/);
  $v->optional('data_aquisicao', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $self->_check_atributos($input) ? $v : undef;
}

sub _check_atributos($self, $input) {
  my $atributos = $input->{atributos};
  return 1 if !defined $atributos;
  if (ref $atributos ne 'HASH') {
    $self->render(json => { error => 'O campo atributos deve ser um objeto.' }, status => 400);
    return 0;
  }
  return 1;
}

sub _fornecedor_params($self, $v, $input) {
  return {
    nome         => $v->param('nome'),
    tipo_servico => $self->_blank($v->param('tipo_servico')),
    email        => $self->_blank($v->param('email')),
    telefone     => $self->_blank($v->param('telefone')),
    site         => $self->_blank($v->param('site')),
    documento    => $self->_blank($v->param('documento')),
    observacoes  => $self->_blank($v->param('observacoes')),
    atributos    => $input->{atributos},
  };
}

sub _item_params($self, $v, $input) {
  return {
    categoria_id   => $v->param('categoria_id'),
    fornecedor_id  => $self->_blank($v->param('fornecedor_id')),
    nome           => $v->param('nome'),
    descricao      => $self->_blank($v->param('descricao')),
    quantidade     => $self->_dec($v->param('quantidade')),
    unidade        => $self->_blank($v->param('unidade')),
    estado         => $self->_blank($v->param('estado')),
    identificador  => $self->_blank($v->param('identificador')),
    periodicidade  => $self->_blank($v->param('periodicidade')),
    valor          => $self->_dec($v->param('valor')),
    data_aquisicao => $self->_blank($v->param('data_aquisicao')),
    atributos      => $input->{atributos},
  };
}

sub _blank($self, $value) {
  return undef if !defined $value || $value eq '';
  return $value;
}

# Normaliza decimal digitado com vírgula (pt-BR) para o ponto do Postgres.
sub _dec($self, $value) {
  my $v = $self->_blank($value);
  return undef unless defined $v;
  $v =~ s/,/./;
  return $v;
}

# ---------------------------------------------------------------------------
# relações institucionais (entidades externas + relações)
# ---------------------------------------------------------------------------

sub relacoes_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $inep  = $self->param('cod_inep');
  $model->sincronizar_categorias_padrao($inep);
  $self->render(json => {
    categorias => $model->list_relacoes_categorias($inep),
    entidades  => $model->list_entidades($inep),
    relacoes   => $model->list_relacoes($inep, {
      entidade_id => $self->param('entidade_id'),
      finalidade  => $self->param('finalidade'),
      status      => $self->param('status'),
      prioridade  => $self->param('prioridade'),
      vencidas    => $self->param('vencidas'),
      q           => $self->param('q'),
    }),
  });
}

# --- categorias ------------------------------------------------------------

sub relacoes_categoria_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_relacao_categoria_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $cat = $self->_guard_api(sub {
    $model->create_relacoes_categoria($self->param('cod_inep'), $self->stash('gestor')->{id}, {
      eixo => $v->param('eixo'), nome => $v->param('nome'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não pôde ser criada') unless $cat;
  $self->render(status => 201, json => $cat);
}

sub relacoes_categoria_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_relacao_categoria_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $cat = $self->_guard_api(sub {
    $model->update_relacoes_categoria($self->param('id'), $self->param('cod_inep'), {
      eixo => $v->param('eixo'), nome => $v->param('nome'),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não encontrada') unless $cat;
  $self->render(json => $cat);
}

sub relacoes_categoria_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $ok = $self->_guard_api(sub {
    $model->delete_relacoes_categoria($self->param('id'), $self->param('cod_inep'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Categoria não encontrada') unless $ok;
  $self->render(status => 204, text => '');
}

# --- entidades externas ----------------------------------------------------

sub relacoes_entidade_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->list_entidades($self->param('cod_inep'), {
    tipo => $self->param('tipo'),
    q    => $self->param('q'),
  }));
}

sub relacoes_entidade_show($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $ent = $model->entidade_detail($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Entidade não encontrada') unless $ent;
  $self->render(json => $ent);
}

sub relacoes_entidade_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_entidade_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $ent = $self->_guard_api(sub {
    $model->create_entidade($self->param('cod_inep'), $self->stash('gestor')->{id},
      $self->_entidade_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Entidade não pôde ser criada') unless $ent;
  $self->render(status => 201, json => $ent);
}

sub relacoes_entidade_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_entidade_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $ent = $self->_guard_api(sub {
    $model->update_entidade($self->param('id'), $self->param('cod_inep'),
      $self->_entidade_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Entidade não encontrada') unless $ent;
  $self->render(json => $ent);
}

sub relacoes_entidade_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $ok = $self->_guard_api(sub {
    $model->delete_entidade($self->param('id'), $self->param('cod_inep'));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Entidade não encontrada') unless $ok;
  $self->render(status => 204, text => '');
}

# --- relações --------------------------------------------------------------

sub relacoes_agenda($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->agenda_relacoes($self->param('cod_inep'), {
    de                 => $self->param('de'),
    ate                => $self->param('ate'),
    incluir_encerradas => $self->param('incluir_encerradas'),
  }));
}

sub relacoes_show($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $rel = $model->relacao_detail($self->param('id'), $self->param('cod_inep'));
  return $self->_render_not_found('Relação não encontrada') unless $rel;
  $self->render(json => $rel);
}

sub relacoes_create($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_relacao_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Entidade não encontrada para esta escola')
    unless $model->entidade_state($v->param('entidade_id'), $self->param('cod_inep'));

  my $rel = $self->_guard_api(sub {
    $model->create_relacao($self->param('cod_inep'), $self->stash('gestor')->{id},
      $self->_relacao_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Relação não pôde ser criada') unless $rel;
  $self->render(status => 201, json => $rel);
}

sub relacoes_update($self) {
  return unless $self->_gestor_inep_ok;
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_relacao_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Entidade não encontrada para esta escola')
    unless $model->entidade_state($v->param('entidade_id'), $self->param('cod_inep'));

  my $rel = $self->_guard_api(sub {
    $model->update_relacao($self->param('id'), $self->param('cod_inep'),
      $self->_relacao_params($v, $input));
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Relação não encontrada') unless $rel;
  $self->render(json => $rel);
}

sub relacoes_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  my $caminhos = $model->documentos_relacao_caminhos($id, $cod_inep);
  return $self->_render_not_found('Relação não encontrada')
    unless $model->delete_relacao($id, $cod_inep);
  my $base = $self->app->config->{upload_dir} // './var/uploads';
  unlink "$base/$_->{caminho}" for @$caminhos;
  $self->render(status => 204, text => '');
}

# --- interações (timeline da relação) --------------------------------------

sub relacoes_interacao_create($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Relação não encontrada') unless $model->relacao_state($id, $cod_inep);

  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_interacao_validation($input) or return;

  my $inter = $self->_guard_api(sub {
    $model->create_interacao_relacao($id, $cod_inep, $self->stash('gestor')->{id}, {
      data         => $self->_blank($v->param('data')),
      canal        => $self->_blank($v->param('canal')),
      participante => $self->_blank($v->param('participante')),
      assunto      => $v->param('assunto'),
      descricao    => $self->_blank($v->param('descricao')),
      resultado    => $self->_blank($v->param('resultado')),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Interação não pôde ser criada') unless $inter;
  $self->render(status => 201, json => $inter);
}

sub relacoes_interacao_update($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $iid) = ($self->param('cod_inep'), $self->param('id'), $self->param('interacao_id'));
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_interacao_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $inter = $self->_guard_api(sub {
    $model->update_interacao_relacao($iid, $id, $cod_inep, {
      data         => $self->_blank($v->param('data')),
      canal        => $self->_blank($v->param('canal')),
      participante => $self->_blank($v->param('participante')),
      assunto      => $v->param('assunto'),
      descricao    => $self->_blank($v->param('descricao')),
      resultado    => $self->_blank($v->param('resultado')),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Interação não encontrada') unless $inter;
  $self->render(json => $inter);
}

sub relacoes_interacao_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $iid) = ($self->param('cod_inep'), $self->param('id'), $self->param('interacao_id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Interação não encontrada')
    unless $model->delete_interacao_relacao($iid, $id, $cod_inep);
  $self->render(status => 204, text => '');
}

# --- documentos (anexos da relação) ----------------------------------------

sub relacoes_documento_create($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Relação não encontrada') unless $model->relacao_state($id, $cod_inep);

  my $upload = $self->req->upload('arquivo');
  return $self->render(json => { error => 'O documento é obrigatório (campo "arquivo").' }, status => 400)
    unless $upload && $upload->size;

  return $self->render(json => { error => 'O arquivo não pode passar de 10 MB.' }, status => 400)
    if $upload->size > $model->max_upload_bytes;

  my ($nome, $dot, $ext) = $upload->filename =~ /^(.*)(\.)([^.\/]+)$/;
  $ext = lc($ext // '');
  my $mime = $model->ext_mime->{$ext};
  return $self->render(
    json => { error => 'Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT.' },
    status => 400,
  ) unless $mime;

  my $uuid = Mojo::Util::sha1_hex(join('|', time, $$, rand, $upload->filename, $id));
  my $rel  = qq{$cod_inep/relacoes/$id/$uuid.$ext};
  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$rel";

  eval { make_path("$base/$cod_inep/relacoes/$id"); 1 }
    or return $self->render(json => { error => 'Não foi possível preparar o armazenamento.' }, status => 500);

  $upload->move_to($abs)
    or return $self->render(json => { error => 'Não foi possível salvar o arquivo.' }, status => 500);

  my $res = $model->registrar_documento_relacao($id, $cod_inep, $self->stash('gestor')->{id}, {
    tipo          => $self->_blank($self->param('tipo')),
    data          => $self->_blank($self->param('data')),
    referencia    => $self->_blank($self->param('referencia')),
    nome_original => $upload->filename,
    caminho       => $rel,
    mime          => $mime,
    tamanho       => $upload->size,
  });
  if (!$res) {
    unlink $abs;
    return $self->_render_conflict('Relação inexistente — documento descartado');
  }
  $self->render(status => 201, json => $res);
}

sub relacoes_documento_get($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->documento_relacao_row(
    $self->param('id'), $self->param('cod_inep'), $self->param('documento_id'));
  return $self->_render_not_found('Documento não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  return $self->_render_not_found('Arquivo não encontrado no servidor') unless -f $abs;

  $self->reply->file($abs, { filename => $row->{nome_original} });
}

sub relacoes_documento_delete($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->delete_documento_relacao(
    $self->param('id'), $self->param('cod_inep'), $self->param('documento_id'));
  return $self->_render_not_found('Documento não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  unlink $abs if -f $abs;
  $self->render(status => 204, text => '');
}

# --- tarefas (checklist) ---------------------------------------------------

sub relacoes_tarefa_create($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id) = ($self->param('cod_inep'), $self->param('id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Relação não encontrada') unless $model->relacao_state($id, $cod_inep);

  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_tarefa_validation($input) or return;

  my $tarefa = $self->_guard_api(sub {
    $model->create_tarefa_relacao($id, $cod_inep, $self->stash('gestor')->{id}, {
      descricao   => $v->param('descricao'),
      responsavel => $self->_blank($v->param('responsavel')),
      prazo       => $self->_blank($v->param('prazo')),
      status      => $self->_blank($v->param('status')),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Tarefa não pôde ser criada') unless $tarefa;
  $self->render(status => 201, json => $tarefa);
}

sub relacoes_tarefa_update($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $tid) = ($self->param('cod_inep'), $self->param('id'), $self->param('tarefa_id'));
  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->_tarefa_validation($input) or return;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $tarefa = $self->_guard_api(sub {
    $model->update_tarefa_relacao($tid, $id, $cod_inep, {
      descricao   => $v->param('descricao'),
      responsavel => $self->_blank($v->param('responsavel')),
      prazo       => $self->_blank($v->param('prazo')),
      status      => $self->_blank($v->param('status')),
    });
  });
  return if $self->stash('guard_rendered');
  return $self->_render_not_found('Tarefa não encontrada') unless $tarefa;
  $self->render(json => $tarefa);
}

sub relacoes_tarefa_destroy($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $tid) = ($self->param('cod_inep'), $self->param('id'), $self->param('tarefa_id'));
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Tarefa não encontrada')
    unless $model->delete_tarefa_relacao($tid, $id, $cod_inep);
  $self->render(status => 204, text => '');
}

# --- indicadores (visão gerencial derivada) --------------------------------

sub relacoes_indicadores($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->indicadores_relacoes($self->param('cod_inep')));
}

# --- validação das relações ------------------------------------------------

sub _tarefa_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('descricao', 'trim')->size(1, 300);
  $v->optional('responsavel', 'trim')->size(1, 120);
  $v->optional('prazo', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  $v->optional('status', 'trim')->like(qr/^(?:pendente|concluida)$/);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $v;
}

sub _interacao_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('assunto', 'trim')->size(1, 160);
  $v->optional('data', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  $v->optional('canal', 'trim')->size(1, 40);
  $v->optional('participante', 'trim')->size(1, 120);
  $v->optional('descricao', 'trim')->size(0, 2000);
  $v->optional('resultado', 'trim')->size(0, 2000);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $v;
}

sub _relacao_categoria_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('eixo', 'trim')->like(qr/^(?:entidade|finalidade)$/);
  $v->required('nome', 'trim')->size(1, 80);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $v;
}

sub _entidade_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 120);
  $v->optional('tipo', 'trim')->size(1, 60);
  $v->optional('identificador', 'trim')->size(1, 40);
  $v->optional('responsavel_externo', 'trim')->size(1, 120);
  $v->optional('email', 'trim')->like(EMAIL_RE);
  $v->optional('telefone', 'trim')->size(8, 20);
  $v->optional('site', 'trim')->size(1, 300);
  $v->optional('endereco', 'trim')->size(0, 200);
  $v->optional('observacoes', 'trim')->size(0, 2000);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $self->_check_atributos($input) ? $v : undef;
}

sub _relacao_validation($self, $input) {
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('entidade_id', 'trim')->num;
  $v->required('assunto', 'trim')->size(1, 160);
  $v->optional('finalidade', 'trim')->size(1, 60);
  $v->optional('descricao', 'trim')->size(0, 2000);
  $v->optional('status', 'trim')->like(qr/^(?:aberta|em_andamento|aguardando|concluida|cancelada)$/);
  $v->optional('prioridade', 'trim')->like(qr/^(?:baixa|media|alta|urgente)$/);
  $v->optional('responsavel_interno', 'trim')->size(1, 120);
  $v->optional('inicio', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  $v->optional('proxima_acao', 'trim')->size(0, 300);
  $v->optional('prazo', 'trim')->like(qr/^\d{4}-\d{2}-\d{2}$/);
  if ($v->has_error) {
    $self->_render_validation($v);
    return;
  }
  return $self->_check_atributos($input) ? $v : undef;
}

sub _entidade_params($self, $v, $input) {
  return {
    tipo                => $self->_blank($v->param('tipo')),
    nome                => $v->param('nome'),
    identificador       => $self->_blank($v->param('identificador')),
    responsavel_externo => $self->_blank($v->param('responsavel_externo')),
    email               => $self->_blank($v->param('email')),
    telefone            => $self->_blank($v->param('telefone')),
    site                => $self->_blank($v->param('site')),
    endereco            => $self->_blank($v->param('endereco')),
    observacoes         => $self->_blank($v->param('observacoes')),
    atributos           => $input->{atributos},
  };
}

sub _relacao_params($self, $v, $input) {
  return {
    entidade_id         => $v->param('entidade_id'),
    finalidade          => $self->_blank($v->param('finalidade')),
    assunto             => $v->param('assunto'),
    descricao           => $self->_blank($v->param('descricao')),
    status              => $self->_blank($v->param('status')) // 'aberta',
    prioridade          => $self->_blank($v->param('prioridade')) // 'media',
    responsavel_interno => $self->_blank($v->param('responsavel_interno')),
    inicio              => $self->_blank($v->param('inicio')),
    proxima_acao        => $self->_blank($v->param('proxima_acao')),
    prazo               => $self->_blank($v->param('prazo')),
    atributos           => $input->{atributos},
  };
}

# ---------------------------------------------------------------------------
# financeiro — busca assíncrona dos dados do SIOPE (remuneração municipal)
# ---------------------------------------------------------------------------

sub finance_siope($self) {
  return unless $self->_gestor_inep_ok;
  my $cod_inep = $self->param('cod_inep');

  my $input = $self->_input or return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('ano', 'trim')->in(2020 .. DateTime->now->year);
  return $self->_render_validation($v) if $v->has_error;

  my $ano   = $v->param('ano');
  my $model = $self->instantiate_model(model => 'School');
  my $st    = $model->siope_disponivel($cod_inep, $ano);

  if ($st->{error}) {
    return $self->_render_not_found('Escola não encontrada para este INEP')
      if $st->{error} eq 'escola_inexistente';
    return $self->render(json => { error => 'O SIOPE só possui dados da rede municipal.' }, status => 422)
      if $st->{error} eq 'nao_municipal';
    return $self->_render_conflict('Os dados do SIOPE para este ano já foram baixados.')
      if $st->{error} eq 'ano_existente';
  }

  my $job_id = $self->get_siope($st->{cod_municipio}, $ano);
  $self->res->headers->header('Location' => "/api/task/progress?job_id=$job_id");
  $self->render(status => 202, json => { task => 'query_siope', job_id => $job_id, ano => $ano + 0 });
}

# ---------------------------------------------------------------------------
# documentos e planos escolares (pastas, versões, tags, auditoria)
# ---------------------------------------------------------------------------

sub documentos_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  $self->render(json => $model->doc_arvore($self->param('cod_inep') + 0));
}

sub documentos_auditoria_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $limite = $self->param('limite') // 30;
  $limite = 100 if $limite > 100;
  my $rows = $model->auditoria_recente($self->param('cod_inep') + 0, $limite + 0);
  $self->render(json => { auditoria => $rows });
}

sub documentos_pasta_create($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $input) = ($self->param('cod_inep') + 0, $self->_input);

  my $v = $self->app->validator->validation;
  $v->input($input);
  $v->required('nome', 'trim')->size(1, 200);
  # '' (string vazia) = raiz; optional só ignora undef
  $v->optional('pasta_pai_id')->like(qr/^\d*$/);
  return $self->_render_validation($v) if $v->has_error;

  my $pai = (($input->{pasta_pai_id} // '') =~ /^\d+$/) ? $input->{pasta_pai_id} + 0 : undef;
  my $model = $self->instantiate_model(model => 'Gestor');
  return $self->_render_not_found('Pasta pai não encontrada')
    if defined $pai && !$model->pasta_existe($cod_inep, $pai);

  my $res;
  my $ok = eval { $res = $model->criar_pasta($cod_inep, $self->stash('gestor')->{id}, $input->{nome}, $pai); 1 };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  $self->render(status => 201, json => $res);
}

sub documentos_pasta_update($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $id, $input) = ($self->param('cod_inep') + 0, $self->param('id'), $self->_input);

  my $nome = $input->{nome};
  if (defined $nome) {
    (my $clean = $nome) =~ s/^\s+|\s+$//g;
    return $self->render(json => { error => 'O nome da pasta deve ter de 1 a 200 caracteres.' }, status => 400)
      if !length $clean || length($clean) > 200;
    $nome = $clean;
  }

  my $novo_pai = undef;
  if (exists $input->{pasta_pai_id}) {
    my $v = $input->{pasta_pai_id};
    if (defined $v && length $v) {
      return $self->render(json => { error => 'A pasta de destino é inválida.' }, status => 400)
        unless $v =~ /^\d+$/;
      $novo_pai = $v + 0;
    }
  }

  my $model = $self->instantiate_model(model => 'Gestor');
  my $res;
  my $ok = eval {
    $res = $model->atualizar_pasta($cod_inep, $self->stash('gestor')->{id}, $id, {
      nome         => $nome,
      pasta_pai_id => $novo_pai,
    });
    1;
  };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  return $self->_render_not_found('Pasta não encontrada') unless $res;
  return $self->_render_conflict('A pasta não pode ser movida para dentro dela mesma.')
    if $res->{erro} && $res->{erro} eq 'ciclo';
  return $self->_render_not_found('Pasta pai não encontrada.')
    if $res->{erro} && $res->{erro} eq 'pasta_nao_encontrada';
  $self->render(json => $res);
}

sub documentos_pasta_delete($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $res;
  my $ok = eval {
    $res = $model->excluir_pasta(
      $self->param('cod_inep') + 0, $self->stash('gestor')->{id}, $self->param('id'));
    1;
  };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  return $self->_render_not_found('Pasta não encontrada') unless $res;
  return $self->_render_conflict('A pasta não está vazia. Remova os arquivos e subpastas antes de excluí-la.')
    if $res->{erro} && $res->{erro} eq 'pasta_nao_vazia';
  $self->render(status => 204, text => '');
}

sub documentos_upload($self) {
  return unless $self->_gestor_inep_ok;
  my $cod_inep = $self->param('cod_inep') + 0;
  my $model = $self->instantiate_model(model => 'Gestor');

  my $upload = $self->req->upload('arquivo');
  return $self->render(json => { error => 'O arquivo é obrigatório (campo "arquivo").' }, status => 400)
    unless $upload && $upload->size;
  return $self->render(json => { error => 'O arquivo não pode passar de 10 MB.' }, status => 400)
    if $upload->size > $model->max_upload_bytes;

  my ($nome, $dot, $ext) = $upload->filename =~ /^(.*)(\.)([^.\/]+)$/;
  $ext = lc($ext // '');
  my $mime = $model->ext_mime->{$ext};
  return $self->render(
    json => { error => 'Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT.' },
    status => 400,
  ) unless $mime;

  my $pasta_raw = $self->param('pasta_id');
  my $pasta_id  = (defined $pasta_raw && $pasta_raw =~ /^\d+$/) ? $pasta_raw + 0 : undef;
  return $self->_render_not_found('Pasta não encontrada')
    if defined $pasta_id && !$model->pasta_existe($cod_inep, $pasta_id);

  my @tags = $model->normalize_tags($self->req->params->every_param('tags'));

  my $arquivo = $upload->filename;
  my $uuid = Mojo::Util::sha1_hex(join('|', time, $$, rand, $arquivo, $pasta_id // ''));
  my $rel  = qq{$cod_inep/documentos/$uuid.$ext};
  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$rel";

  eval { make_path("$base/$cod_inep/documentos"); 1 }
    or return $self->render(json => { error => 'Não foi possível preparar o armazenamento.' }, status => 500);

  my $sha1 = Mojo::Util::sha1_hex($upload->asset->slurp);

  $upload->move_to($abs)
    or return $self->render(json => { error => 'Não foi possível salvar o arquivo.' }, status => 500);

  my $res;
  my $ok = eval {
    $res = $model->subir_documento($cod_inep, $self->stash('gestor')->{id}, {
      pasta_id      => $pasta_id,
      nome          => $arquivo,
      caminho       => $rel,
      nome_original => $arquivo,
      mime          => $mime,
      tamanho       => $upload->size,
      sha1          => $sha1,
    });
    1;
  };
  if (!$ok) {
    unlink $abs;
    $self->_render_db_error($@ || '');
    return;
  }
  $res->{tags} = @tags ? $model->setar_tags($cod_inep, $self->stash('gestor')->{id}, $res->{documento_id}, \@tags) : [];

  $self->render(status => 201, json => $res);
}

sub documentos_update($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $input) = ($self->param('cod_inep') + 0, $self->_input);

  my $nome = $input->{nome};
  if (defined $nome) {
    (my $clean = $nome) =~ s/^\s+|\s+$//g;
    return $self->render(json => { error => 'O nome do documento deve ter de 1 a 200 caracteres.' }, status => 400)
      if !length $clean || length($clean) > 200;
    $nome = $clean;
  }

  my $novo_pai = undef;
  if (exists $input->{pasta_id}) {
    my $v = $input->{pasta_id};
    if (defined $v && length $v) {
      return $self->render(json => { error => 'A pasta de destino é inválida.' }, status => 400)
        unless $v =~ /^\d+$/;
      $novo_pai = $v + 0;
    }
  }

  my $model = $self->instantiate_model(model => 'Gestor');
  my $res;
  my $ok = eval {
    $res = $model->atualizar_documento($cod_inep, $self->stash('gestor')->{id}, $self->param('id'), {
      nome     => $nome,
      pasta_id => $novo_pai,
    });
    1;
  };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  return $self->_render_not_found('Documento não encontrado') unless $res;
  return $self->_render_not_found('Pasta não encontrada.')
    if $res->{erro} && $res->{erro} eq 'pasta_nao_encontrada';
  $self->render(json => $res);
}

sub documentos_tags_update($self) {
  return unless $self->_gestor_inep_ok;
  my ($cod_inep, $input) = ($self->param('cod_inep') + 0, $self->_input);

  my $tags = $input->{tags};
  return $self->render(json => { error => 'O campo tags é obrigatório.' }, status => 400)
    unless ref $tags eq 'ARRAY';

  my @tags;
  for my $t (@$tags) {
    next unless defined $t;
    (my $clean = $t) =~ s/^\s+|\s+$//g;
    return $self->render(json => { error => 'Cada tag tem no máximo 40 caracteres.' }, status => 400)
      if length($clean) > 40;
    push @tags, $clean if length $clean;
  }
  return $self->render(json => { error => 'Limite de 20 tags por documento.' }, status => 400)
    if @tags > 20;

  my $model = $self->instantiate_model(model => 'Gestor');
  my $res;
  my $ok = eval {
    $res = $model->setar_tags($cod_inep, $self->stash('gestor')->{id}, $self->param('id'), \@tags);
    1;
  };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  return $self->_render_not_found('Documento não encontrado') unless $res;
  $self->render(json => { tags => $res });
}

sub documentos_versoes_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $versoes = $model->doc_versoes($self->param('cod_inep') + 0, $self->param('id'));
  $self->render(json => { versoes => $versoes });
}

sub documentos_historico_index($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $historico = $model->doc_auditoria($self->param('cod_inep') + 0, $self->param('id'));
  $self->render(json => { historico => $historico });
}

sub documentos_download($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $row = $model->doc_download_row(
    $self->param('cod_inep') + 0, $self->param('id'), $self->param('versao'));
  return $self->_render_not_found('Documento não encontrado') unless $row;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  my $abs  = "$base/$row->{caminho}";
  return $self->_render_not_found('Arquivo não encontrado no servidor') unless -f $abs;

  $self->reply->file($abs, { filename => $row->{nome_original} });
}

sub documentos_delete($self) {
  return unless $self->_gestor_inep_ok;
  my $model = $self->instantiate_model(model => 'Gestor');
  my $res;
  my $ok = eval {
    $res = $model->excluir_documento(
      $self->param('cod_inep') + 0, $self->stash('gestor')->{id}, $self->param('id'));
    1;
  };
  if (!$ok) { $self->_render_db_error($@ || ''); return; }
  return $self->_render_not_found('Documento não encontrado') unless $res;

  my $base = $self->app->config->{upload_dir} // './var/uploads';
  unlink "$base/$_" for @{ $res->{caminhos} };
  $self->render(status => 204, text => '');
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
  if ($err =~ /uq_inventario_categorias_inep_tipo_nome/) {
    return $self->render(json => { error => 'Já existe uma categoria com este nome para este tipo.' }, status => 409);
  }
  if ($err =~ /uq_inventario_fornecedores_inep_nome/) {
    return $self->render(json => { error => 'Já existe um fornecedor com este nome nesta escola.' }, status => 409);
  }
  if ($err =~ /inventario_itens_categoria_id_fkey/) {
    return $self->render(json => { error => 'Não é possível excluir: a categoria tem itens no inventário.' }, status => 409);
  }
  if ($err =~ /inventario_itens_fornecedor_id_fkey/) {
    return $self->render(json => { error => 'Fornecedor não pertence a esta escola.' }, status => 400);
  }
  if ($err =~ /(?:invalid input syntax for type numeric)/) {
    return $self->render(json => { error => 'Quantidade ou valor inválido.' }, status => 400);
  }
  if ($err =~ /uq_relacoes_categorias_inep_eixo_nome/) {
    return $self->render(json => { error => 'Já existe uma categoria com este nome para este eixo.' }, status => 409);
  }
  if ($err =~ /uq_relacoes_entidades_inep_nome/) {
    return $self->render(json => { error => 'Já existe uma entidade com este nome nesta escola.' }, status => 409);
  }
  if ($err =~ /relacoes_entidade_id_fkey/) {
    return $self->render(json => { error => 'Não é possível excluir: a entidade tem relações registradas.' }, status => 409);
  }
  if ($err =~ /uq_pastas_escolares_inep_pai_nome/) {
    return $self->render(json => { error => 'Já existe uma pasta com este nome neste local.' }, status => 409);
  }
  if ($err =~ /uq_escola_documentos_inep_pasta_nome/) {
    return $self->render(json => { error => 'Já existe um documento com este nome nesta pasta.' }, status => 409);
  }
  if ($err =~ /(?:invalid input syntax for type date)/) {
    return $self->render(json => { error => 'Data inválida.' }, status => 400);
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
  pasta_pai_id => 'pasta',
  pasta_id     => 'pasta',
  tags         => 'tags',
  versao       => 'versão',
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