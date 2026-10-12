package EduMaps::Roles::Business::Canal::Consentimento;
use Mojo::Base -role, -signatures;
use utf8;

# ============================================================================
# CONSENTIMENTO VERSIONADO DA AUTOINSCRIÇÃO (issue #214 — Fase 2, RF-208)
# ============================================================================
#
# Versões do texto de consentimento em clean.consentimento_versoes, da
# INSTALAÇÃO (não por escola). Ciclo:
#
#   rascunho  — criado pela administração; editável (texto_hash recalculado);
#   vigente   — publicada; a exibida na página pública; no máximo UMA
#               (índice único parcial uq_consentimento_vigente);
#   arquivada — substituída por outra publicação.
#
# Publicada (vigente/arquivada) é IMUTÁVEL. A inscrição grava a `versao` e o
# `texto_hash` (SHA-256 hex do texto em UTF-8, calculado no banco com
# pgcrypto) — prova do texto aceito.
#
# Composta no model Canal (e usada pelo Controller::Admin); usa os helpers SQL
# `_rows/_row` de Canal::Listas.

requires qw(schema _rows _row);

# Fallback quando a tabela não tem versão vigente (banco sem seed): a versão
# histórica da Fase 0/1 (constante de Canal::Listas), sem texto nem hash.
sub _consentimento_versao_fallback ($self) {
  no warnings 'once';
  return $EduMaps::Roles::Business::Canal::Listas::CONSENTIMENTO_VERSAO // '1.0';
}

# expira/publicada em ISO 8601 (UTC).
my $ISO = q{to_char(%s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')};

my $COLS = sprintf(
  q{id, versao, texto, texto_hash, status, %s AS publicada_em, %s AS created_at},
  sprintf($ISO, 'publicada_em'), sprintf($ISO, 'created_at'),
);

sub _consentimento_publico ($self, $r) {
  return {
    id           => $r->{id} + 0,
    versao       => $r->{versao},
    texto        => $r->{texto},
    texto_hash   => $r->{texto_hash},
    status       => $r->{status},
    publicada_em => $r->{publicada_em},
    created_at   => $r->{created_at},
  };
}

# Versão vigente: { id, versao, texto, texto_hash, status, publicada_em,
# created_at }. Sem vigente na tabela → fallback { versao => '1.0', texto =>
# undef, texto_hash => undef, fallback => 1 }.
sub consentimento_vigente ($self) {
  my $r = $self->_row(
    "SELECT $COLS FROM clean.consentimento_versoes WHERE status = 'vigente'"
  );
  return $self->_consentimento_publico($r) if $r;
  return {
    versao       => $self->_consentimento_versao_fallback,
    texto        => undef,
    texto_hash   => undef,
    publicada_em => undef,
    fallback     => 1,
  };
}

# Todas as versões, mais recente primeiro.
sub consentimento_listar ($self) {
  my $rows = $self->_rows(
    "SELECT $COLS FROM clean.consentimento_versoes ORDER BY id DESC"
  );
  return [ map { $self->_consentimento_publico($_) } @$rows ];
}

sub consentimento_por_id ($self, $id) {
  return unless defined $id && !ref $id && $id =~ /^\d+\z/;
  my $r = $self->_row(
    "SELECT $COLS FROM clean.consentimento_versoes WHERE id = ?", $id + 0,
  ) or return;
  return $self->_consentimento_publico($r);
}

# Validação de entrada (versao: 1..20, letras/dígitos/._-; texto: 1..20000).
# Devolve a mensagem de erro ou undef.
sub _consentimento_valida_versao ($self, $versao) {
  return 'versao é obrigatória (1..20 caracteres: letras, dígitos, ".", "_" ou "-").'
    unless defined $versao && !ref $versao
        && $versao =~ /^[0-9A-Za-z._-]{1,20}\z/;
  return;
}

sub _consentimento_valida_texto ($self, $texto) {
  return 'texto é obrigatório (1..20000 caracteres).'
    unless defined $texto && !ref $texto
        && $texto =~ /\S/ && length $texto <= 20000;
  return;
}

# Cria um rascunho. Devolve a versão criada ou { error, status => 400|409 }.
sub consentimento_criar_rascunho ($self, %p) {
  my $versao = $p{versao};
  $versao =~ s/^\s+|\s+$//g if defined $versao && !ref $versao;
  my $texto = $p{texto};

  if (my $e = $self->_consentimento_valida_versao($versao)) {
    return { error => $e, status => 400 };
  }
  if (my $e = $self->_consentimento_valida_texto($texto)) {
    return { error => $e, status => 400 };
  }

  my $row = $self->_row(
    q{INSERT INTO clean.consentimento_versoes (versao, texto, texto_hash, criado_por)
      VALUES (?, ?, encode(digest(?::text, 'sha256'), 'hex'), ?)
      ON CONFLICT (versao) DO NOTHING
      RETURNING id},
    $versao, $texto, $texto,
    (defined $p{criado_por} && $p{criado_por} =~ /^\d+\z/ ? $p{criado_por} + 0 : undef),
  );
  return { error => 'Já existe uma versão com este rótulo.', status => 409 } unless $row;
  return $self->consentimento_por_id($row->{id});
}

# Edita um rascunho (`versao` e/ou `texto`). texto_hash recalculado.
# Devolve a versão; undef se não existe; { error, status => 400|409 }.
sub consentimento_editar_rascunho ($self, $id, %campos) {
  my $atual = $self->consentimento_por_id($id) or return;
  return { error => 'Só rascunhos podem ser editados (versão publicada é imutável).', status => 409 }
    unless $atual->{status} eq 'rascunho';

  my (@set, @binds);
  if (exists $campos{versao}) {
    my $versao = $campos{versao};
    $versao =~ s/^\s+|\s+$//g if defined $versao && !ref $versao;
    if (my $e = $self->_consentimento_valida_versao($versao)) {
      return { error => $e, status => 400 };
    }
    push @set, 'versao = ?';
    push @binds, $versao;
  }
  if (exists $campos{texto}) {
    my $texto = $campos{texto};
    if (my $e = $self->_consentimento_valida_texto($texto)) {
      return { error => $e, status => 400 };
    }
    push @set, 'texto = ?', q{texto_hash = encode(digest(?::text, 'sha256'), 'hex')};
    push @binds, $texto, $texto;
  }
  return { error => 'Nada a alterar (versao ou texto).', status => 400 } unless @set;

  my $ok = eval {
    $self->_rows(
      'UPDATE clean.consentimento_versoes SET ' . join(', ', @set)
        . q{ WHERE id = ? AND status = 'rascunho'},
      @binds, $id + 0,
    );
    1;
  };
  unless ($ok) {
    return { error => 'Já existe uma versão com este rótulo.', status => 409 }
      if ($@ // '') =~ /consentimento_versoes_versao_key/;
    die $@;
  }
  return $self->consentimento_por_id($id);
}

# Publica um rascunho numa transação: a vigente atual vira arquivada e o
# rascunho vira vigente (publicada_em = NOW()). Devolve a versão publicada;
# undef se não existe; { error, status => 409 } se não é rascunho.
sub consentimento_publicar ($self, $id) {
  return unless defined $id && !ref $id && $id =~ /^\d+\z/;
  my $res;
  $self->schema->storage->txn_do(sub {
    my $r = $self->_row(
      'SELECT id, status FROM clean.consentimento_versoes WHERE id = ? FOR UPDATE',
      $id + 0,
    );
    unless ($r) { $res = undef; return; }
    unless ($r->{status} eq 'rascunho') {
      $res = { error => 'Só rascunhos podem ser publicados.', status => 409 };
      return;
    }
    $self->_rows(
      q{UPDATE clean.consentimento_versoes SET status = 'arquivada'
         WHERE status = 'vigente'},
    );
    $self->_rows(
      q{UPDATE clean.consentimento_versoes
           SET status = 'vigente', publicada_em = NOW()
         WHERE id = ?},
      $id + 0,
    );
    $res = { ok => 1 };
  });
  return $res unless $res && $res->{ok};
  return $self->consentimento_por_id($id);
}

1;
