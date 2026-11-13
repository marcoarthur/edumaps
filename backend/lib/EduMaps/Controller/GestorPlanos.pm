package EduMaps::Controller::GestorPlanos;
use Mojo::Base 'EduMaps::Controller::Gestor', -signatures;
use utf8;
use Scalar::Util qw(blessed looks_like_number);
use Time::Piece ();
use EduMaps::Roles::Business::Gestor::Planos ();

# Planos de gestão da escola (#369, épico #368) — /api/gestor/:cod_inep/planos
# Sessão do gestor (under gestor#_require_gestor) + posse do cod_inep
# (_gestor_inep_ok, herdado): outra escola recebe 403 em todas as rotas.
#
#   GET    .../planos                         lista (?arquivados=1 inclui arquivados)
#   POST   .../planos                         cria
#   GET    .../planos/:id                     plano com objetivos, metas, ações e resumo
#   PUT    .../planos/:id                     atualiza (parcial); encerrado só reabre
#   DELETE .../planos/:id                     arquiva (não apaga)
#   GET    .../planos/:id/auditoria           histórico do plano
#   POST   .../planos/:id/objetivos           | PUT/DELETE .../objetivos/:oid
#   POST   .../planos/:id/metas               | PUT/DELETE .../metas/:mid
#   POST   .../planos/:id/acoes               | PUT/DELETE .../acoes/:aid
#   GET    .../planos/indicadores             catálogo de indicadores oficiais
#                                             com o último valor da escola (#370)
#   POST   .../planos/:id/metas/:mid/medicoes            medição manual (#370)
#   DELETE .../planos/:id/metas/:mid/medicoes/:medid     só manual
#   GET    .../planos/evidencias/origens       reuniões e versões de documento
#                                             da escola que podem virar evidência (#372)
#   POST   .../planos/:id/evidencias          | DELETE .../evidencias/:eid
#   GET    .../planos/:id/relatorio           dados do relatório de acompanhamento (#374)
#
# PUT é PARCIAL: só os campos enviados mudam; um campo enviado como null (ou
# texto vazio) limpa o valor.

my $P = 'EduMaps::Roles::Business::Gestor::Planos';

my %CAMPOS = (
  plano => {
    tipo           => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::TIPOS, obrigatorio => 1 ],
    titulo         => [ texto => 200, obrigatorio => 1 ],
    descricao      => [ texto => 4000 ],
    inicio         => [ 'data' ],
    fim            => [ 'data' ],
    situacao       => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::SITUACOES ],
    documento_id   => [ 'inteiro' ],
    alertas_ativos => [ 'booleano' ],
  },
  objetivo => {
    titulo    => [ texto => 300, obrigatorio => 1 ],
    descricao => [ texto => 4000 ],
    ordem     => [ 'inteiro' ],
  },
  meta => {
    objetivo_id => [ 'inteiro', obrigatorio => 1 ],
    descricao   => [ texto => 500, obrigatorio => 1 ],
    unidade     => [ texto => 40 ],
    sentido     => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::SENTIDOS ],
    indicador_codigo => [ texto => 40 ],
    linha_base  => [ 'numero' ],
    alvo        => [ 'numero' ],
    prazo       => [ 'data' ],
  },
  medicao => {
    data_ref => [ 'data', obrigatorio => 1 ],
    valor    => [ 'numero', obrigatorio => 1 ],
    nota     => [ texto => 500 ],
  },
  evidencia => {
    acao_id             => [ 'inteiro' ],
    meta_id             => [ 'inteiro' ],
    tipo                => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::TIPOS_EVIDENCIA, obrigatorio => 1 ],
    reuniao_id          => [ 'inteiro' ],
    documento_versao_id => [ 'inteiro' ],
    texto               => [ texto => 2000 ],
  },
  acao => {
    objetivo_id    => [ 'inteiro', obrigatorio => 1 ],
    meta_id        => [ 'inteiro' ],
    descricao      => [ texto => 500, obrigatorio => 1 ],
    responsavel    => [ texto => 120 ],
    inicio         => [ 'data' ],
    prazo          => [ 'data' ],
    situacao       => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::SITUACOES_ACAO ],
    custo_previsto => [ 'numero_nao_negativo' ],
    custo_executado => [ 'numero_nao_negativo' ],
    executado_em   => [ 'data' ],
    fonte_recurso  => [ enum => \@EduMaps::Roles::Business::Gestor::Planos::FONTES_RECURSO ],
  },
);

# Campos que, quando enviados, não podem ficar vazios.
my %NAO_ANULAVEL = map { $_ => 1 } qw(situacao sentido alertas_ativos);

# ---------------------------------------------------------------------------
# planos
# ---------------------------------------------------------------------------

sub index($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) {
    { planos => $m->planos_listar($self->param('cod_inep'), { arquivados => scalar $self->param('arquivados') }) }
  });
}

sub show($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) { $m->plano_detalhe($self->param('cod_inep'), $self->param('id')) });
}

sub create($self) {
  return unless $self->_gestor_inep_ok;
  my $p = $self->_campos('plano', 1) // return;
  $self->_executar(sub ($m) { $m->plano_criar($self->param('cod_inep'), $self->_gid, $p) }, 201);
}

sub update($self) {
  return unless $self->_gestor_inep_ok;
  my $p = $self->_campos('plano', 0) // return;
  $self->_executar(sub ($m) { $m->plano_atualizar($self->param('cod_inep'), $self->_gid, $self->param('id'), $p) });
}

sub destroy($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) {
    $m->plano_arquivar($self->param('cod_inep'), $self->_gid, $self->param('id'));
    { arquivado => Mojo::JSON::true };
  });
}

sub indicadores($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) { { indicadores => $m->indicadores_catalogo($self->param('cod_inep')) } });
}

sub medicao_create($self) {
  return unless $self->_gestor_inep_ok;
  my $p = $self->_campos('medicao', 1) // return;
  $self->_executar(sub ($m) {
    $m->medicao_criar($self->param('cod_inep'), $self->_gid, $self->param('id'), $self->param('mid'), $p);
  }, 201);
}

sub medicao_destroy($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) {
    $m->medicao_excluir($self->param('cod_inep'), $self->_gid, $self->param('id'),
      $self->param('mid'), $self->param('medid'));
    { excluido => Mojo::JSON::true };
  });
}

sub evidencia_origens($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) { $m->evidencia_origens($self->param('cod_inep')) });
}

sub evidencia_create($self) { $self->_filho_create('evidencia') }
sub evidencia_destroy($self) { $self->_filho_destroy('evidencia', 'eid') }

sub relatorio($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) { $m->plano_relatorio($self->param('cod_inep'), $self->param('id'), $self->_gid,
    { exercicio => $self->param('exercicio') }) });
}

sub auditoria($self) {
  return unless $self->_gestor_inep_ok;
  $self->_executar(sub ($m) { { auditoria => $m->plano_auditoria($self->param('cod_inep'), $self->param('id')) } });
}

# ---------------------------------------------------------------------------
# objetivos, metas, ações
# ---------------------------------------------------------------------------

sub objetivo_create($self) { $self->_filho_create('objetivo') }
sub objetivo_update($self) { $self->_filho_update('objetivo', 'oid') }
sub objetivo_destroy($self) { $self->_filho_destroy('objetivo', 'oid') }
sub meta_create($self)     { $self->_filho_create('meta') }
sub meta_update($self)     { $self->_filho_update('meta', 'mid') }
sub meta_destroy($self)    { $self->_filho_destroy('meta', 'mid') }
sub acao_create($self)     { $self->_filho_create('acao') }
sub acao_update($self)     { $self->_filho_update('acao', 'aid') }
sub acao_destroy($self)    { $self->_filho_destroy('acao', 'aid') }

sub _filho_create($self, $entidade) {
  return unless $self->_gestor_inep_ok;
  my $p = $self->_campos($entidade, 1) // return;
  my $metodo = "${entidade}_criar";
  $self->_executar(sub ($m) {
    $m->$metodo($self->param('cod_inep'), $self->_gid, $self->param('id'), $p);
  }, 201);
}

sub _filho_update($self, $entidade, $param) {
  return unless $self->_gestor_inep_ok;
  my $p = $self->_campos($entidade, 0) // return;
  my $metodo = "${entidade}_atualizar";
  $self->_executar(sub ($m) {
    $m->$metodo($self->param('cod_inep'), $self->_gid, $self->param('id'), $self->param($param), $p);
  });
}

sub _filho_destroy($self, $entidade, $param) {
  return unless $self->_gestor_inep_ok;
  my $metodo = "${entidade}_excluir";
  $self->_executar(sub ($m) {
    $m->$metodo($self->param('cod_inep'), $self->_gid, $self->param('id'), $self->param($param));
    { excluido => Mojo::JSON::true };
  });
}

# ---------------------------------------------------------------------------
# execução e erros
# ---------------------------------------------------------------------------

sub _gid($self) { $self->stash('gestor')->{id} }

sub _executar($self, $code, $status = 200) {
  my $model = $self->model('Gestor');
  my $out = eval { $code->($model) };
  if (my $err = $@) {
    if (blessed $err && $err->isa("${P}::Erro")) {
      return $self->render(json => { error => $err->mensagem }, status => $err->status);
    }
    $self->app->log->error("GestorPlanos: $err");
    return $self->render(json => { error => 'Não foi possível salvar o plano. Tente novamente.' }, status => 500);
  }
  $self->render(json => $out, status => $status);
}

# ---------------------------------------------------------------------------
# validação: só os campos conhecidos; presença distingue "não mudar" de "limpar"
# ---------------------------------------------------------------------------

sub _campos($self, $entidade, $criando) {
  my $input = $self->_input;
  unless (ref $input eq 'HASH') {
    $self->render(json => { error => 'Corpo JSON inválido' }, status => 400);
    return undef;
  }
  my $spec = $CAMPOS{$entidade};
  my (%out, %erros);

  if (my @desconhecidos = grep { !exists $spec->{$_} } sort keys %$input) {
    $erros{$_} = 'campo desconhecido' for @desconhecidos;
  }

  for my $campo (sort keys %$spec) {
    my ($tipo, @resto) = @{ $spec->{$campo} };
    my $limite = (@resto % 2) ? shift @resto : undef;
    my %opt = @resto;

    unless (exists $input->{$campo}) {
      $erros{$campo} = 'obrigatório' if $criando && $opt{obrigatorio};
      next;
    }
    my $v = $input->{$campo};
    $v = undef if defined $v && !ref $v && $v =~ /^\s*$/;
    if (!defined $v) {
      if ($opt{obrigatorio} || $NAO_ANULAVEL{$campo}) { $erros{$campo} = 'não pode ficar vazio' }
      else                                           { $out{$campo} = undef }
      next;
    }
    my ($ok, $valor) = $self->_valor($tipo, $limite, $v);
    if ($ok) { $out{$campo} = $valor } else { $erros{$campo} = $valor }
  }

  if (%erros) {
    $self->render(json => { error => 'Dados inválidos', campos => \%erros }, status => 400);
    return undef;
  }
  if (!$criando && !%out) {
    $self->render(json => { error => 'Nada para alterar' }, status => 400);
    return undef;
  }
  return \%out;
}

# (1, valor normalizado) ou (0, motivo)
sub _valor($self, $tipo, $limite, $v) {
  my $bool_json = ref $v eq 'JSON::PP::Boolean';    # true/false do Mojo::JSON
  return (0, 'formato inválido') if ref $v && !($tipo eq 'booleano' && $bool_json);
  if ($tipo eq 'texto') {
    (my $t = $v) =~ s/^\s+|\s+$//g;
    return (0, "até $limite caracteres") if length $t > $limite;
    return (1, $t);
  }
  if ($tipo eq 'enum') {
    return (1, $v) if grep { $_ eq $v } @$limite;
    return (0, 'use: ' . join(', ', @$limite));
  }
  if ($tipo eq 'inteiro') {
    return (1, 0 + $v) if $v =~ /^\d{1,18}$/;
    return (0, 'número inteiro');
  }
  if ($tipo eq 'numero' || $tipo eq 'numero_nao_negativo') {
    my $n = $v;
    $n =~ s/\.//g, $n =~ s/,/./ if $n =~ /,/;    # pt-BR: 1.234,5
    return (0, 'número') unless looks_like_number($n) && $n !~ /(?:inf|nan)/i;
    return (0, 'não pode ser negativo') if $tipo eq 'numero_nao_negativo' && $n < 0;
    return (1, 0 + $n);
  }
  if ($tipo eq 'data') {
    return (0, 'data AAAA-MM-DD') unless $v =~ /^\d{4}-\d{2}-\d{2}$/;
    my $tp = eval { Time::Piece->strptime($v, '%Y-%m-%d') };
    return (0, 'data inexistente') unless $tp && $tp->ymd eq $v;
    return (1, $v);
  }
  if ($tipo eq 'booleano') {
    return (1, $v ? 1 : 0) if $bool_json || $v =~ /^[01]$/;
    return (1, $v eq 'true' ? 1 : 0) if $v =~ /^(?:true|false)$/;
    return (0, 'verdadeiro ou falso');
  }
  return (0, 'tipo não suportado');
}

1;
