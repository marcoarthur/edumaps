package EduMaps::Channel::History;
use Mojo::Base -base, -signatures;
use utf8;

# ============================================================================
# HISTÓRICO DE MENSAGENS DE CANAL — INSTRUMENTAÇÃO
# ============================================================================
#
# Recorder único (um só para todos os canais, DRY) que persiste o ciclo de vida
# de cada mensagem em clean.canal_mensagens: `queued` no enfileiramento,
# `sent`/`failed` depois da entrega. Guarda o canal, a operação (motivo), o
# destino, o texto e a que entidade a mensagem se refere — para responder
# "qual mensagem foi enviada, por qual canal e a que operação se refere".
#
# O destinatário e o corpo são PII: a leitura (`list`) pode mascará-los com
# `mask => 1`; a coluna crua é de acesso restrito, como clean.contatos.

has schema => undef;
has log    => sub { Mojo::Log->new };

# Registra a mensagem como enfileirada. Devolve o id da linha criada.
sub queued ($self, $msg) {
  my $ref = $msg->{referente} // {};
  my $row = $self->_row(
    q{INSERT INTO clean.canal_mensagens
        (canal, operacao, destinatario, assunto, corpo,
         referente_tipo, referente_id, contato_id, cod_inep, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'queued')
      RETURNING id},
    $msg->{canal},
    $msg->{operacao},
    $msg->{to},
    $msg->{assunto},
    # `corpo_historico` (opcional): versão do corpo para o histórico — ex.:
    # código de confirmação mascarado (#214). Senão, o corpo enviado.
    $msg->{corpo_historico} // $msg->{corpo},
    $ref->{tipo},
    (defined $ref->{id} ? $ref->{id} + 0 : undef),
    (defined $msg->{contato_id} ? $msg->{contato_id} + 0 : undef),
    (defined $msg->{cod_inep}   ? $msg->{cod_inep} + 0   : undef),
  );
  return $row->{id};
}

sub sent ($self, $id, $res = {}) {
  return unless $id;
  $self->_rows(
    q{UPDATE clean.canal_mensagens
         SET status = 'sent',
             provider_message_id = ?,
             tentativas = tentativas + 1,
             erro = NULL,
             sent_at = NOW()
       WHERE id = ?},
    $res->{provider_message_id},
    $id + 0,
  );
  return 1;
}

sub failed ($self, $id, $res = {}) {
  return unless $id;
  $self->_rows(
    q{UPDATE clean.canal_mensagens
         SET status = 'failed',
             erro = ?,
             tentativas = tentativas + 1
       WHERE id = ?},
    $res->{error},
    $id + 0,
  );
  return 1;
}

# Lista o histórico (mais recente primeiro). Filtros: canal, operacao, status,
# contato_id, cod_inep, limite. Com `mask => 1`, destinatário e corpo são
# mascarados na leitura (para exposição por API).
sub list ($self, $filter = {}) {
  my (@where, @binds);
  for my $f (qw(canal operacao status)) {
    if (defined $filter->{$f} && length $filter->{$f}) {
      push @where, "$f = ?";
      push @binds, $filter->{$f};
    }
  }
  for my $f (qw(contato_id cod_inep)) {
    if (defined $filter->{$f}) {
      push @where, "$f = ?";
      push @binds, $filter->{$f} + 0;
    }
  }
  my $where = @where ? 'WHERE ' . join(' AND ', @where) : '';
  my $limit = (defined $filter->{limite} && $filter->{limite} =~ /^\d+$/)
    ? $filter->{limite} + 0
    : 100;
  $limit = 1000 if $limit > 1000;

  my $rows = $self->_rows(
    qq{SELECT id, canal, operacao, destinatario, assunto, corpo,
              referente_tipo, referente_id, contato_id, cod_inep,
              status, erro, provider_message_id, tentativas, created_at, sent_at
         FROM clean.canal_mensagens
         $where
        ORDER BY id DESC
        LIMIT $limit},
    @binds,
  );

  if ($filter->{mask}) {
    for my $r (@$rows) {
      $r->{destinatario} = $self->mask_address($r->{destinatario});
      $r->{corpo}        = '[conteúdo restrito]' if defined $r->{corpo};
    }
  }
  return $rows;
}

# Mascara um endereço para leitura: e-mail mantém as 2 primeiras letras da
# parte local; telefone/chat_id mantém os 4 últimos dígitos.
sub mask_address ($self, $addr) {
  return '' unless defined $addr && length $addr;
  if ($addr =~ /\@/) {
    my ($user, $dom) = split /\@/, $addr, 2;
    my $head = substr($user, 0, 2);
    my $stars = length($user) > 2 ? '*' x (length($user) - 2) : '';
    return "$head$stars\@$dom";
  }
  return $addr if length($addr) <= 4;
  return ('*' x (length($addr) - 4)) . substr($addr, -4);
}

# --- helpers SQL (padrão das roles de negócio) -----------------------------

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0] // {};
}

1;
