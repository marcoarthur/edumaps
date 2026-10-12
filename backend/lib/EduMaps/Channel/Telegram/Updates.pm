package EduMaps::Channel::Telegram::Updates;
use Mojo::Base -base, -signatures;
use utf8;

use Mojo::JSON qw(true);
use EduMaps::Channel::Telegram;

# ============================================================================
# BOT PÚBLICO DO TELEGRAM — TRATAMENTO DE UPDATES (issue #212, Fase 1)
# ============================================================================
#
# Confirmação de posse do telefone nas listas com QR. `handle($update)` é
# puro em relação à ORIGEM do update: o webhook (POST
# /api/canais/telegram/webhook) e o job de polling (Task::TelegramPolling)
# chamam o mesmo método.
#
# Fluxo (contrato da onda 2, "Comportamento do bot"):
#   /start <ref> (ref pendente) → grava `telegram_chat_pendente` e responde com
#       o teclado "Compartilhar meu número" (request_contact, one_time);
#   contact com contact.user_id == from.id → acha a ref pendente pelo chat →
#       número igual ao telefone inscrito (tolerância ao 55) → concluir
#       (via telegram, telegram_chat_id) e remove o teclado; diferente →
#       conflito + "número não confere";
#   contato de terceiro → recusa; /start sem ref válida ou qualquer outra
#       mensagem → resposta fixa curta.
#
# Só conversa privada (o request_contact só existe lá); updates de grupos,
# canais, edições etc. são ignorados sem resposta. Rate limit simples por
# chat_id (em memória, por processo). Toda resposta sai pelo bot PÚBLICO
# (canais.telegram.token) via Channel::Telegram, que registra cada envio em
# clean.canal_mensagens (operação `confirmacao`).

# Modelo com Canal::Confirmacao + Canal::Listas (EduMaps::Model::Canal).
has model  => undef;
# Config do bot público (AppConfig::telegram_publico_config).
has config => sub { {} };
has log    => sub { Mojo::Log->new };
has ua     => undef;   # UA injetável (teste); undef = o padrão do canal

# Canal de envio: Channel::Telegram com o token do bot PÚBLICO.
has channel => sub ($self) {
  EduMaps::Channel::Telegram->new(
    config => { token => $self->config->{token} // '' },
    schema => ($self->model ? $self->model->schema : undef),
    log    => $self->log,
    ($self->ua ? (ua => $self->ua) : ()),
  );
};

# Rate limit por chat: no máximo RATE_MAX updates por RATE_WINDOW segundos.
our $RATE_MAX    = 20;
our $RATE_WINDOW = 60;
my %RATE;   # chat_id => { tick, n } (por processo)

# --- textos provisórios (PT-BR) ---------------------------------------------

our %TEXTO = (
  pedir_contato => "Olá! Para confirmar o telefone da sua inscrição, toque no "
                 . "botão \"Compartilhar meu número\" abaixo.\n\n"
                 . "O número da sua conta do Telegram será usado só para "
                 . "conferir com o número informado na inscrição.",
  confirmado    => "Telefone confirmado! Obrigado. Você já pode voltar à "
                 . "página de inscrição.",
  nao_confere   => "O número desta conta do Telegram não confere com o número "
                 . "informado na inscrição, por isso não foi possível confirmar. "
                 . "Se houve erro de digitação, faça a inscrição de novo com o "
                 . "número correto.",
  terceiro      => "Por segurança, só é possível confirmar com o SEU número. "
                 . "Use o botão \"Compartilhar meu número\".",
  sem_ref       => "Este link de confirmação é inválido ou expirou. Volte à "
                 . "página de inscrição e toque de novo em \"Confirmar pelo "
                 . "Telegram\".",
  padrao        => "Este bot serve apenas para confirmar o telefone das "
                 . "inscrições nas listas da escola. Use o botão \"Confirmar "
                 . "pelo Telegram\" na página de inscrição.",
);

sub teclado_contato {
  return {
    keyboard => [ [ { text => 'Compartilhar meu número', request_contact => true } ] ],
    one_time_keyboard => true,
    resize_keyboard   => true,
  };
}

sub teclado_remover { return { remove_keyboard => true } }

# --- normalização do telefone (tolerância ao 55) ----------------------------

# Forma canônica para comparar: só dígitos, sem 00 internacional, sem o código
# do Brasil (55) quando presente num número completo (12+ dígitos), sem zero
# de tronco à esquerda.
sub telefone_canonico ($self, $tel) {
  my $d = $self->model && $self->model->can('normalize_phone')
    ? $self->model->normalize_phone($tel)
    : (defined $tel ? $tel =~ s/\D//gr : '');
  $d =~ s/^00//;
  $d = substr($d, 2) if length($d) >= 12 && $d =~ /^55/;
  $d =~ s/^0+//;
  return $d;
}

sub telefones_conferem ($self, $a, $b) {
  my ($x, $y) = ($self->telefone_canonico($a), $self->telefone_canonico($b));
  return (length $x && $x eq $y) ? 1 : 0;
}

# --- entrada ----------------------------------------------------------------

# Trata um update do Telegram (hashref já decodificado). Nunca morre por dado
# do usuário. Devolve { acao => ... } para diagnóstico/teste:
#   ignorado | rate_limited | start_ok | start_invalido | confirmado |
#   conflito | terceiro | sem_ref | padrao
sub handle ($self, $update) {
  return { acao => 'ignorado' } unless ref $update eq 'HASH';
  my $msg = $update->{message};
  return { acao => 'ignorado' } unless ref $msg eq 'HASH' && ref $msg->{chat} eq 'HASH';

  my $chat    = $msg->{chat};
  my $chat_id = $chat->{id};
  return { acao => 'ignorado' }
    unless defined $chat_id && $chat_id =~ /^-?\d+\z/;
  return { acao => 'ignorado' } unless ($chat->{type} // 'private') eq 'private';
  return { acao => 'rate_limited' } unless $self->_rate_ok($chat_id);

  my $from_id = ref $msg->{from} eq 'HASH' ? $msg->{from}{id} : undef;

  if (ref $msg->{contact} eq 'HASH') {
    return $self->_contato($chat_id, $from_id, $msg->{contact});
  }

  my $text = $msg->{text} // '';
  if ($text =~ m{^/start(?:@\w+)?(?:\s+(\S+))?\s*\z}) {
    return $self->_start($chat_id, $1);
  }

  $self->_responder($chat_id, $TEXTO{padrao});
  return { acao => 'padrao' };
}

# --- fluxos -----------------------------------------------------------------

sub _start ($self, $chat_id, $ref) {
  my $model = $self->model;
  if (defined $ref && $model->ref_valida($ref)) {
    my $v = $model->vincular_chat_telegram(lc $ref, $chat_id);
    if ($v->{ok}) {
      $self->_responder($chat_id, $TEXTO{pedir_contato},
        reply_markup => $self->teclado_contato, ref_id => $v->{ref_id});
      return { acao => 'start_ok', ref_id => $v->{ref_id} };
    }
  }
  $self->_responder($chat_id, $TEXTO{sem_ref});
  return { acao => 'start_invalido' };
}

sub _contato ($self, $chat_id, $from_id, $contact) {
  my $model = $self->model;
  my $p = $model->ref_pendente_do_chat($chat_id);

  # Contato de terceiro: user_id ausente ou diferente do remetente.
  my $proprio = defined $contact->{user_id} && defined $from_id
    && "$contact->{user_id}" eq "$from_id";
  unless ($proprio) {
    $self->_responder($chat_id, $TEXTO{terceiro},
      ($p ? (reply_markup => $self->teclado_contato, ref_id => $p->{ref_id}) : ()));
    return { acao => 'terceiro' };
  }

  unless ($p) {
    $self->_responder($chat_id, $TEXTO{sem_ref}, reply_markup => $self->teclado_remover);
    return { acao => 'sem_ref' };
  }

  if ($self->telefones_conferem($contact->{phone_number}, $p->{telefone_norm})) {
    my $r = $model->concluir(
      membro_id        => $p->{membro_id},
      via              => 'telegram',
      telegram_chat_id => $chat_id,
    );
    if ($r->{ok}) {
      $self->_responder($chat_id, $TEXTO{confirmado},
        reply_markup => $self->teclado_remover, ref_id => $p->{ref_id});
      return { acao => 'confirmado', membro_id => $r->{membro_id} };
    }
    $self->_responder($chat_id, $TEXTO{sem_ref}, reply_markup => $self->teclado_remover);
    return { acao => 'sem_ref' };
  }

  $model->registrar_conflito_inscricao($p->{inscricao_id});
  $self->_responder($chat_id, $TEXTO{nao_confere},
    reply_markup => $self->teclado_remover, ref_id => $p->{ref_id});
  return { acao => 'conflito', inscricao_id => $p->{inscricao_id} };
}

# --- envio ------------------------------------------------------------------

# Responde pelo bot público. Falha de envio é registrada (canal_mensagens via
# Channel::History) e logada, nunca propagada.
sub _responder ($self, $chat_id, $texto, %o) {
  my $res = eval {
    $self->channel->send_message({
      to        => "$chat_id",
      operacao  => 'confirmacao',
      corpo     => $texto,
      (ref $o{reply_markup} ? (reply_markup => $o{reply_markup}) : ()),
      (defined $o{ref_id}
        ? (referente => { tipo => 'confirmacao_ref', id => $o{ref_id} }) : ()),
    });
  };
  unless ($res && $res->{ok}) {
    my $err = $res ? ($res->{error} // 'falha') : ($@ || 'falha');
    $self->log->warn("Telegram público: falha ao responder: $err");
  }
  return $res;
}

sub _rate_ok ($self, $chat_id) {
  my $tick = int(time / $RATE_WINDOW);
  if (keys %RATE > 10_000) {   # limpeza barata
    delete $RATE{$_} for grep { $RATE{$_}{tick} < $tick } keys %RATE;
  }
  my $b = $RATE{$chat_id} //= { tick => $tick, n => 0 };
  if ($b->{tick} != $tick) { $b->{tick} = $tick; $b->{n} = 0; }
  return 0 if $b->{n} >= $RATE_MAX;
  $b->{n}++;
  return 1;
}

# Zera o rate limit (testes).
sub reset_rate_limit { %RATE = (); return; }

1;
