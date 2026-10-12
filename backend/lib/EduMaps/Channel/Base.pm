package EduMaps::Channel::Base;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use utf8;

use Mojo::Promise;
use EduMaps::Channel::Operacoes;
use EduMaps::Channel::History;
use EduMaps::Channel::Confirmation;

# ============================================================================
# CLASSE BASE DOS CANAIS DE COMUNICAÇÃO (Mojo::EventEmitter)
# ============================================================================
#
# Um "canal" é o transporte para alcançar UM destinatário (e-mail, WhatsApp,
# Telegram). A classe base concentra o que é comum a todos os canais (DRY) no
# método-template `send_message`: valida o endereço, normaliza, grava o
# histórico (`queued`), delega a entrega à subclasse (`_deliver`), atualiza o
# histórico (`sent`/`failed`) e emite eventos. Cada subclasse só especializa o
# que difere: `_address_regex`, `_normalize_address`, `_deliver`/`_deliver_p`,
# as capacidades (`address_kind`, `supports_confirm`, `max_len`) e o texto de
# confirmação.
#
# Eventos emitidos (Mojo::EventEmitter):
#   message.invalid, message.queued, message.sent, message.failed,
#   confirm.requested, confirm.verified, confirm.failed
#
# Mensagem (hashref): { to, operacao, assunto, corpo, referente => {tipo,id},
#   contato_id, cod_inep, meta, headers (e-mail: cabeçalhos extras, #216) }.
# O resultado de `send_message` traz `mensagem_id` (id no histórico).

has name    => 'base';
has enabled => 1;
has config  => sub { {} };
has log     => sub { Mojo::Log->new };
has schema  => undef;
has ua      => sub { Mojo::UserAgent->new(timeout => 10) };

# Colaboradores de persistência (injáveis em teste). Sem schema ficam inertes.
has history => sub ($self) {
  EduMaps::Channel::History->new(schema => $self->schema, log => $self->log);
};
has confirmation => sub ($self) {
  EduMaps::Channel::Confirmation->new(schema => $self->schema, log => $self->log);
};

# --- capacidades declarativas (subclasse sobrescreve) -----------------------

sub address_kind     { 'text' }   # email | phone | chat_id | text
sub supports_confirm { 0 }
sub supports_receive { 0 }
sub max_len          { 0 }        # 0 = sem limite

sub can_send ($self) { $self->enabled ? 1 : 0 }

sub can_confirm ($self) {
  return 0 unless $self->enabled && $self->supports_confirm;
  return $self->schema ? 1 : 0;
}

# --- validação de endereço (template, subclasse fornece as regras) ----------

sub _normalize_address ($self, $addr) { return $addr }
sub _address_regex     ($self) { return qr/\S/ }

# Devolve { ok, normalized } ou { ok => 0, reason }.
sub validate_address ($self, $addr) {
  $addr = '' unless defined $addr;
  $addr =~ s/^\s+|\s+$//g;
  return { ok => 0, reason => 'endereço vazio' } unless length $addr;

  my $normalized = $self->_normalize_address($addr);
  return { ok => 0, reason => 'endereço inválido' }
    unless defined $normalized && length $normalized;
  return { ok => 0, reason => 'endereço inválido' }
    unless $normalized =~ $self->_address_regex;
  return { ok => 0, reason => 'endereço muito longo' }
    if $self->max_len && length($normalized) > $self->max_len;

  return { ok => 1, normalized => $normalized };
}

# --- envio ------------------------------------------------------------------

sub _deliver ($self, $msg) {
  die 'canal ' . $self->name . " não implementa _deliver\n";
}

# Fallback assíncrono: subclasse com transporte nativo sobrescreve `_deliver_p`.
sub _deliver_p ($self, $msg) {
  my $res = eval { $self->_deliver($msg) };
  $res = { ok => 0, error => ("$@" || 'falha desconhecida') } unless ref $res eq 'HASH';
  return Mojo::Promise->resolve($res);
}

# Envia uma mensagem. Síncrono.
sub send_message ($self, $msg) {
  my $v = $self->validate_address($msg->{to});
  unless ($v->{ok}) {
    $self->emit('message.invalid',
      { channel => $self->name, to => $msg->{to}, reason => $v->{reason} });
    return { ok => 0, error => $v->{reason} };
  }

  my $operacao = $msg->{operacao} // 'informacao';
  unless (EduMaps::Channel::Operacoes->is_valid($operacao)) {
    return { ok => 0, error => "operação inválida: $operacao" };
  }

  my $m = { %$msg, canal => $self->name, to => $v->{normalized}, operacao => $operacao };

  my $id = $self->_history_queued($m);
  $self->emit('message.queued',
    { channel => $self->name, to => $m->{to}, operacao => $operacao });

  my $res = eval { $self->_deliver($m) };
  $res = { ok => 0, error => ("$@" || 'falha desconhecida') } unless ref $res eq 'HASH';

  $self->_finish($id, $m, $res);
  # `mensagem_id` (#216): linha do histórico (canal_mensagens), undef sem schema.
  return { %$res, canal => $self->name, to => $m->{to}, operacao => $operacao,
           mensagem_id => $id };
}

# Envia uma mensagem. Assíncrono (Mojo::Promise — nunca rejeita).
sub send_message_p ($self, $msg) {
  my $v = $self->validate_address($msg->{to});
  unless ($v->{ok}) {
    $self->emit('message.invalid',
      { channel => $self->name, to => $msg->{to}, reason => $v->{reason} });
    return Mojo::Promise->resolve({ ok => 0, error => $v->{reason} });
  }

  my $operacao = $msg->{operacao} // 'informacao';
  unless (EduMaps::Channel::Operacoes->is_valid($operacao)) {
    return Mojo::Promise->resolve({ ok => 0, error => "operação inválida: $operacao" });
  }

  my $m = { %$msg, canal => $self->name, to => $v->{normalized}, operacao => $operacao };
  my $id = $self->_history_queued($m);
  $self->emit('message.queued',
    { channel => $self->name, to => $m->{to}, operacao => $operacao });

  return $self->_deliver_p($m)->then(sub ($res) {
    $res = { ok => 0, error => 'resposta inválida do transporte' }
      unless ref $res eq 'HASH';
    $self->_finish($id, $m, $res);
    return { %$res, canal => $self->name, to => $m->{to}, operacao => $operacao };
  });
}

# --- confirmação de posse ---------------------------------------------------

sub _confirm_template ($self, $codigo, %ctx) {
  return "EduMaps — seu código de confirmação é $codigo.";
}

# Envia o código de confirmação ao endereço. Devolve { ok, confirmacao_id }.
sub confirm_start ($self, $addr, %ctx) {
  return { ok => 0, error => 'canal não suporta confirmação' } unless $self->can_confirm;

  my $v = $self->validate_address($addr);
  return { ok => 0, error => $v->{reason} } unless $v->{ok};

  my $started = $self->confirmation->start(
    canal    => $self->name,
    endereco => $v->{normalized},
    %ctx,
  );
  return { ok => 0, error => $started->{error} } unless $started->{ok};

  my $corpo = $self->_confirm_template($started->{codigo}, %ctx);
  my $res = $self->send_message({
    to        => $v->{normalized},
    operacao  => 'confirmacao',
    assunto   => 'Confirmação de contato',
    corpo     => $corpo,
    # o histórico (canal_mensagens) NUNCA grava o código em claro (#214,
    # RNF-205): corpo com o código mascarado.
    corpo_historico => ($corpo =~ s/\Q$started->{codigo}\E/******/gr),
    referente => { tipo => 'confirmacao', id => $started->{id} },
    contato_id => $ctx{contato_id},
    cod_inep   => $ctx{cod_inep},
    # o código em claro segue SÓ em memória para o transporte que o envia
    # como parâmetro (ex.: template de autenticação do WhatsApp, #212); o
    # histórico não grava esta chave.
    codigo     => $started->{codigo},
  });
  return { ok => 0, error => 'falha ao enviar o código de confirmação' }
    unless $res->{ok};

  $self->emit('confirm.requested',
    { channel => $self->name, to => $v->{normalized}, confirmacao_id => $started->{id} });
  return { ok => 1, confirmacao_id => $started->{id} };
}

# Confere o código recebido. Devolve { ok => 1 } ou { ok => 0, reason }.
sub confirm_check ($self, $addr, $codigo) {
  return { ok => 0, reason => 'canal não suporta confirmação' } unless $self->can_confirm;

  my $v = $self->validate_address($addr);
  return { ok => 0, reason => $v->{reason} } unless $v->{ok};

  my $res = $self->confirmation->verify(
    canal    => $self->name,
    endereco => $v->{normalized},
    codigo   => $codigo,
  );

  if ($res->{ok}) {
    $self->emit('confirm.verified', { channel => $self->name, to => $v->{normalized} });
  }
  else {
    $self->emit('confirm.failed',
      { channel => $self->name, to => $v->{normalized}, reason => $res->{reason} });
  }
  return $res;
}

# --- internos ---------------------------------------------------------------

sub _history_queued ($self, $m) {
  return undef unless $self->schema;
  return $self->history->queued($m);
}

sub _finish ($self, $id, $m, $res) {
  if ($res->{ok}) {
    $self->history->sent($id, $res) if $id;
    $self->emit('message.sent', {
      channel             => $self->name,
      to                  => $m->{to},
      operacao            => $m->{operacao},
      provider_message_id => $res->{provider_message_id},
    });
  }
  else {
    $self->history->failed($id, $res) if $id;
    $self->emit('message.failed', {
      channel  => $self->name,
      to       => $m->{to},
      operacao => $m->{operacao},
      error    => $res->{error},
    });
  }
  return;
}

1;
