package EduMaps::Controller::GestorRelatorios;
use Mojo::Base 'EduMaps::Controller::Gestor', -signatures;
use utf8;
use EduMaps::Roles::Business::Gestor::Relatorios ();

# Assistente de Relatório (#219) — /api/gestor/:cod_inep/relatorios/...
# Todas as rotas exigem sessão do gestor (under gestor#_require_gestor) e a
# posse do cod_inep (_gestor_inep_ok, herdado do Controller::Gestor).
#
#   GET  .../relatorios/recorte-padrao  escola, município, UF e região
#   GET  .../relatorios/temas?nivel=    catálogo do R (cache)
#   POST .../relatorios                 valida e enfileira relatorio_gerar
#   GET  .../relatorios/jobs/:job_id    estado/progresso/resultado do job

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

sub temas($self) {
  return unless $self->_gestor_inep_ok;

  my $nivel = $self->param('nivel');
  if (defined $nivel && length $nivel) {
    return $self->render(json => { error => 'nivel inválido (use escola, municipio, uf ou regiao)' }, status => 400)
      unless grep { $_ eq $nivel } @EduMaps::Roles::Business::Gestor::Relatorios::NIVEIS;
  }
  else {
    $nivel = undef;
  }

  my $temas = $self->_temas($nivel)
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

  my $tema = $input->{tema};
  return $self->render(json => { error => 'tema é obrigatório' }, status => 400)
    unless defined $tema && !ref $tema && length $tema;

  my $opcoes = $input->{opcoes} // {};
  return $self->render(json => { error => 'opcoes deve ser um objeto' }, status => 400)
    unless ref $opcoes eq 'HASH';

  # O tema precisa existir no catálogo do nível (catálogo vem do R, cache).
  my $temas = $self->_temas($geotag->{nivel})
    // return $self->render(json => { error => ERRO_R_INDISPONIVEL }, status => 502);
  return $self->render(
    json   => { error => "Tema '$tema' não está disponível para o nível $geotag->{nivel}." },
    status => 400,
  ) unless grep { ref $_ eq 'HASH' && (_scalar($_->{id}) // '') eq $tema } @$temas;

  my $job_id = $self->gerar_relatorio({
    gestor_id => $gestor->{id},
    cod_inep  => $cod_inep,
    geotag    => $geotag,
    tema      => $tema,
    opcoes    => $opcoes,
  });

  $self->res->headers->header(
    Location => "/api/gestor/$cod_inep/relatorios/jobs/$job_id"
  );
  $self->render(status => 202, json => { job_id => $job_id });
}

sub job($self) {
  return unless $self->_gestor_inep_ok;
  my $gestor   = $self->stash('gestor');
  my $cod_inep = '' . $self->param('cod_inep');

  my $job  = $self->minion->job($self->param('job_id'));
  my $info = $job ? $job->info : undef;
  my $args = $info && ref $info->{args} eq 'ARRAY' ? $info->{args}[0] : undef;

  # 404 para job inexistente, de outra task ou de outro gestor/escola — sem
  # distinguir os casos (não vaza a existência de jobs alheios).
  return $self->_render_not_found('Relatório não encontrado.')
    unless $info
        && $info->{task} eq 'relatorio_gerar'
        && ref $args eq 'HASH'
        && ($args->{gestor_id} // '') eq ($gestor->{id} // '')
        && ($args->{cod_inep}  // '') eq $cod_inep;

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

# Catálogo de temas do nível (arrayref) ou undef se o R falhar.
sub _temas($self, $nivel) {
  my $res = eval { $self->analytics->run_report_temas($nivel) };
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
