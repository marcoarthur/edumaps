package EduMaps::Controller::GestorRelatorios;
use Mojo::Base 'EduMaps::Controller::Gestor', -signatures;
use utf8;
use EduMaps::Roles::Business::Gestor::Relatorios ();

# Assistente de Relatório (#219) — /api/gestor/:cod_inep/relatorios/...
# Todas as rotas exigem sessão do gestor (under gestor#_require_gestor) e a
# posse do cod_inep (_gestor_inep_ok, herdado do Controller::Gestor).
#
#   GET  .../relatorios/recorte-padrao  escola, município, UF e região
#   GET  .../relatorios/assistentes     assistentes do R com público gestor (cache)
#   GET  .../relatorios/temas?nivel=&assistente=
#                                       catálogo do R (cache)
#   POST .../relatorios                 valida e enfileira relatorio_gerar
#   GET  .../relatorios/jobs/:job_id    estado/progresso/resultado do job
#
# Fase 3 — relatórios salvos (só os do gestor da sessão):
#   POST   .../relatorios/salvos        {job_id} salva a fotografia do job
#   GET    .../relatorios/salvos        lista paginada (?page, ?per_page)
#   GET    .../relatorios/salvos/:id    resumo + relatorio (ReportResult)
#   DELETE .../relatorios/salvos/:id    exclui

use constant ERRO_R_INDISPONIVEL =>
  'O serviço de relatórios está indisponível no momento. Tente novamente em alguns minutos.';

# Plumber serializa escalares como arrays de 1 elemento quando não usa
# auto_unbox; normaliza para comparar ids.
sub _scalar ($v) {
  return $v->[0] if ref $v eq 'ARRAY' && @$v == 1;
  return $v;
}

sub recorte_padrao($self) {
  return unless $self->_gestor_inep_ok;
  my $cod_inep = $self->param('cod_inep');

  my $recorte = $self->model('Gestor')->recorte_padrao($cod_inep)
    or return $self->_render_not_found("Escola não encontrada no Censo para o INEP $cod_inep");

  $self->render(json => $recorte);
}

# Fase 4: id do assistente padrão ("Relatório por tema") e formato dos ids.
use constant ASSISTENTE_PADRAO => 'relatorio';
my $RE_ASSISTENTE = qr/^[a-z0-9_]{1,64}\z/;

# Valor de uma lista vinda do R: arrayref (normal) ou escalar (Plumber com
# auto_unbox numa lista de 1 elemento) -> lista Perl.
sub _lista ($v) {
  return @$v if ref $v eq 'ARRAY';
  return ()  if !defined $v || ref $v;
  return ($v);
}

sub assistentes($self) {
  return unless $self->_gestor_inep_ok;

  my $assistentes = $self->_assistentes
    // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);

  $self->render(json => { assistentes => $assistentes });
}

sub temas($self) {
  return unless $self->_gestor_inep_ok;

  my $assistente = $self->param('assistente');
  if (defined $assistente && length $assistente) {
    return $self->render(json => { error => 'assistente inválido' }, status => 400)
      unless $assistente =~ $RE_ASSISTENTE;
    # Só os assistentes visíveis ao gestor (o padrão dispensa a consulta).
    if ($assistente ne ASSISTENTE_PADRAO) {
      my $lista = $self->_assistentes
        // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);
      return $self->render(json => { error => "Assistente '$assistente' não está disponível." }, status => 400)
        unless _achar_assistente($lista, $assistente);
    }
  }
  else {
    $assistente = ASSISTENTE_PADRAO;
  }

  my $nivel = $self->param('nivel');
  if (defined $nivel && length $nivel) {
    return $self->render(json => { error => 'nivel inválido (use escola, municipio, uf ou regiao)' }, status => 400)
      unless grep { $_ eq $nivel } @EduMaps::Roles::Business::Gestor::Relatorios::NIVEIS;
  }
  else {
    $nivel = undef;
  }

  my $temas = $self->_temas($nivel, $assistente)
    // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);

  $self->render(json => { temas => $temas });
}

sub criar($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor   = $self->stash('gestor');
  my $cod_inep = '' . $self->param('cod_inep');

  my $input = $self->_input;
  return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400)
    unless ref $input eq 'HASH';

  my ($geotag, $erro) = $self->model('Gestor')->geotag_valido($input->{geotag}, $gestor->{cod_inep});
  return $self->render(json => { error => $erro }, status => 400) unless $geotag;

  # Fase 4: assistente opcional (padrão: Relatório por tema).
  my $assistente = $input->{assistente} // ASSISTENTE_PADRAO;
  return $self->render(json => { error => 'assistente inválido' }, status => 400)
    unless !ref $assistente && $assistente =~ $RE_ASSISTENTE;

  my $opcoes = $input->{opcoes} // {};
  return $self->render(json => { error => 'opcoes deve ser um objeto' }, status => 400)
    unless ref $opcoes eq 'HASH';

  # O assistente precisa estar na lista do R visível ao gestor (cache).
  my $lista = $self->_assistentes
    // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);
  my $def = _achar_assistente($lista, $assistente)
    or return $self->render(json => { error => "Assistente '$assistente' não está disponível." }, status => 400);

  my $nivel = $geotag->{nivel};
  return $self->render(
    json   => { error => "O assistente '$assistente' não está disponível para o nível $nivel." },
    status => 400,
  ) unless grep { defined $_ && !ref $_ && $_ eq $nivel } _lista($def->{niveis});

  my $modo = _scalar($def->{modo}) // 'tema';
  my %job = (
    gestor_id  => $gestor->{id},
    cod_inep   => $cod_inep,
    geotag     => $geotag,
    assistente => $assistente,
    opcoes     => $opcoes,
  );

  # No `composto` os capítulos são fixos: o tema é opcional e ignorado.
  if ($modo ne 'composto') {
    my $tema = $input->{tema};
    return $self->render(json => { error => 'tema é obrigatório' }, status => 400)
      unless defined $tema && !ref $tema && length $tema;

    # O tema precisa existir no catálogo do assistente no nível (R, cache).
    my $temas = $self->_temas($nivel, $assistente)
      // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);
    return $self->render(
      json   => { error => "Tema '$tema' não está disponível para o nível $nivel." },
      status => 400,
    ) unless grep { ref $_ eq 'HASH' && (_scalar($_->{id}) // '') eq $tema } @$temas;
    $job{tema} = $tema;
  }

  my $job_id = $self->gerar_relatorio(\%job);

  $self->res->headers->header(
    Location => "/api/gestor/$cod_inep/relatorios/jobs/$job_id"
  );
  $self->render(status => 202, json => { job_id => $job_id });
}

sub job($self) {
  return unless $self->_gestor_inep_ok;

  my $info = $self->_job_do_gestor($self->param('job_id'))
    or return $self->_render_not_found('Relatório não encontrado.');

  my %resp = (state => $info->{state});

  if (my $p = ($info->{notes} // {})->{progress}) {
    $resp{progress} = { percent => $p->{percent}, message => $p->{message} };
  }

  if ($info->{state} eq 'failed') {
    my $err = $info->{result};
    $resp{error} = ref $err eq 'HASH' && defined $err->{error} && !ref $err->{error}
      ? $err->{error}
      : 'Não foi possível gerar o relatório.';
  }
  elsif ($info->{state} eq 'finished') {
    $resp{result} = $info->{result};
  }

  $self->render(json => \%resp);
}

# --- relatórios salvos (Fase 3) ---------------------------------------------

sub salvos_criar($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor   = $self->stash('gestor');
  my $cod_inep = '' . $self->param('cod_inep');

  my $input = $self->_input;
  return $self->render(json => { error => 'Corpo JSON inválido' }, status => 400)
    unless ref $input eq 'HASH';
  my $job_id = $input->{job_id};
  return $self->render(json => { error => 'job_id é obrigatório (inteiro)' }, status => 400)
    unless defined $job_id && !ref $job_id && $job_id =~ /^\d{1,18}\z/;

  # Mesma checagem da rota do job: inexistente, de outra task ou alheio -> 404.
  my $info = $self->_job_do_gestor($job_id)
    or return $self->_render_not_found('Relatório não encontrado.');

  return $self->render(
    json   => { error => 'O relatório ainda não terminou ou falhou; só relatórios gerados com sucesso podem ser salvos.' },
    status => 409,
  ) unless $info->{state} eq 'finished';

  # O conteúdo vem do resultado do job no servidor; o corpo só dá o job_id.
  my ($salvo, $novo) = $self->model('Gestor')
    ->salvar_relatorio($gestor->{id}, $cod_inep, $job_id, $info);
  return $self->render(
    json   => { error => 'O resultado deste relatório não pode ser salvo.' },
    status => 409,
  ) unless $salvo;

  $self->res->headers->header(
    Location => "/api/gestor/$cod_inep/relatorios/salvos/$salvo->{id}"
  );
  $self->render(status => ($novo ? 201 : 200), json => $salvo);
}

sub salvos_listar($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor = $self->stash('gestor');

  my $page     = $self->param('page')     // 1;
  my $per_page = $self->param('per_page') // 20;
  $page     = 1  unless $page =~ /^\d{1,9}\z/ && $page >= 1;
  $per_page = 20 unless $per_page =~ /^\d{1,9}\z/ && $per_page >= 1;
  $per_page = 100 if $per_page > 100;

  $self->render(json => $self->model('Gestor')
    ->listar_relatorios_salvos($gestor->{id}, $page + 0, $per_page + 0));
}

sub salvos_detalhe($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor = $self->stash('gestor');

  my $salvo = $self->model('Gestor')->relatorio_salvo($gestor->{id}, $self->param('id'))
    or return $self->_render_not_found('Relatório salvo não encontrado.');
  $self->render(json => $salvo);
}

sub salvos_excluir($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor = $self->stash('gestor');

  $self->model('Gestor')->excluir_relatorio_salvo($gestor->{id}, $self->param('id'))
    or return $self->_render_not_found('Relatório salvo não encontrado.');
  $self->render(json => { ok => 1 });
}

# info do job relatorio_gerar se ele é do gestor da sessão e do cod_inep da
# rota; undef para job inexistente, de outra task ou de outro gestor/escola —
# sem distinguir os casos (não vaza a existência de jobs alheios).
sub _job_do_gestor($self, $job_id) {
  my $gestor   = $self->stash('gestor');
  my $cod_inep = '' . $self->param('cod_inep');

  my $job  = $self->minion->job($job_id);
  my $info = $job ? $job->info : undef;
  my $args = $info && ref $info->{args} eq 'ARRAY' ? $info->{args}[0] : undef;

  return undef
    unless $info
        && $info->{task} eq 'relatorio_gerar'
        && ref $args eq 'HASH'
        && ($args->{gestor_id} // '') eq ($gestor->{id} // '')
        && ($args->{cod_inep}  // '') eq $cod_inep;
  return $info;
}

# Assistentes do R visíveis ao gestor (`publico` contém `gestor`), como
# arrayref, ou undef se o R falhar.
sub _assistentes($self) {
  my $res = eval { $self->analytics->run_report_assistentes };
  if (my $err = $@) {
    $self->app->log->error("Assistente de Relatório: /report/assistentes falhou: $err");
    return undef;
  }
  my $lista = ref $res eq 'HASH' ? $res->{assistentes} : undef;
  unless (ref $lista eq 'ARRAY') {
    $self->app->log->error('Assistente de Relatório: /report/assistentes sem lista de assistentes');
    return undef;
  }
  return [
    grep {
      my $def = $_;
      ref $def eq 'HASH'
        && grep { defined $_ && !ref $_ && $_ eq 'gestor' } _lista($def->{publico})
    } @$lista
  ];
}

# Definição do assistente $id na lista (hashref) ou undef.
sub _achar_assistente ($lista, $id) {
  for my $def (@$lista) {
    return $def if (_scalar($def->{id}) // '') eq $id;
  }
  return undef;
}

# Catálogo de temas do nível e assistente (arrayref) ou undef se o R falhar.
sub _temas($self, $nivel, $assistente = ASSISTENTE_PADRAO) {
  my $res = eval { $self->analytics->run_report_temas($nivel, $assistente) };
  if (my $err = $@) {
    $self->app->log->error("Assistente de Relatório: /report/temas falhou: $err");
    return undef;
  }
  my $temas = ref $res eq 'HASH' ? $res->{temas} : undef;
  unless (ref $temas eq 'ARRAY') {
    $self->app->log->error('Assistente de Relatório: /report/temas sem lista de temas');
    return undef;
  }
  return $temas;
}

1;
