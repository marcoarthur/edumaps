package EduMaps::Roles::Business::Canal::Envios;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(true false);
use Digest::SHA qw(sha256_hex hmac_sha256_hex);
use EduMaps::Channel::Email;

# ============================================================================
# ENVIO POR E-MAIL PARA LISTAS (issue #216 — Fase 3, onda 1)
# ============================================================================
#
# Ciclo do envio (clean.canal_envios):
#
#   rascunho -> agendado (agendado_para) | enviando -> concluido
#   desvios: pausado_cota (cota do dia esgotou; retoma 00:05 do dia seguinte,
#            America/Sao_Paulo), suspenso (escola suspensa), cancelado.
#
# Disparo (`envio_disparar`): valida rascunho, data, `canais.envio.enabled`,
# SMTP, suspensão e alvo → resolve os membros com e-mail (Canal::Segmentos::
# resolver_destinatarios: dedupe por e-mail, opt-out por lista) → teto e cota
# → FOTOGRAFIA: grava os destinatários (pendente; opt-out já como
# ignorado_optout; duplicados só no contador `ignorados`) e o `saida_hash` de
# cada um, numa transação → enfileira o job `canais_envio` (coderef do
# chamador) com `delay` e guarda o `minion_job_id`.
#
# Token de saída: hmac_sha256_hex("saida:<destinatario_id>", segredo do app),
# primeiros 32 hex; o banco guarda só o sha256 do token. O lote deriva o token
# de novo para o rodapé e o cabeçalho List-Unsubscribe.
#
# Lote (`envio_processar_lote`, chamado pelo job): até `ritmo_por_minuto`
# pendentes por ordem de id, parando quando o saldo da cota do dia acaba;
# destinatário sem e-mail (anonimizado no meio) → ignorado_anonimizado; envio
# via Channel::Email->send_message (histórico em canal_mensagens com
# referente envio) → enviado | falhou. Só `pendente` é processado: reprocessar
# nunca reenvia. Concluído/cancelado zera o `email` dos destinatários (fica o
# hash).
#
# Composta no model Canal; usa Canal::Listas (helpers SQL), Canal::Segmentos
# (resolução de membros, máscara) e AppConfig (envio_config, email_config,
# inscricao_config, email_confirmacao_disponivel).

requires qw(schema _rows _row envio_config email_config inscricao_config
            email_confirmacao_disponivel resolver_destinatarios mascarar_email
            segmento_validar_criterios _listas_ativas);

our @ENVIO_STATUS = qw(rascunho agendado enviando pausado_cota suspenso concluido cancelado);
our @DEST_STATUS  = qw(pendente enviado falhou cancelado ignorado_optout ignorado_anonimizado);
our @ENVIO_OPERACOES = qw(aviso informacao pedido convite lembrete alerta);
our %OPERACAO_ROTULO = (
  aviso => 'Aviso', informacao => 'Informação', pedido => 'Pedido',
  convite => 'Convite', lembrete => 'Lembrete', alerta => 'Alerta',
);
our @CANCELAVEIS = qw(agendado enviando pausado_cota suspenso);
our $TESTES_MAX     = 5;      # e-mails de teste por envio
our $AGENDA_MAX_DIAS = 90;
our $DELAY_LOTE     = 60;     # próximo lote
our $DELAY_ESPERA   = 300;    # envio desligado / SMTP indisponível
our $TZ = 'America/Sao_Paulo';

my $ISO = q{to_char(%s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')};
my $SQL_INICIO_HOJE = qq{(date_trunc('day', NOW() AT TIME ZONE '$TZ') AT TIME ZONE '$TZ')};

# ---------------------------------------------------------------------------
# limites, cota e suspensão
# ---------------------------------------------------------------------------

# E-mails efetivamente enviados hoje (America/Sao_Paulo) pela escola.
sub envio_enviados_hoje ($self, $cod_inep) {
  my $r = $self->_row(
    qq{SELECT count(*)::int AS n
       FROM   clean.canal_envio_destinatarios d
       JOIN   clean.canal_envios e ON e.id = d.envio_id
       WHERE  e.cod_inep = ? AND d.status = 'enviado'
         AND  d.processado_em >= $SQL_INICIO_HOJE},
    $cod_inep + 0,
  );
  return $r ? $r->{n} + 0 : 0;
}

sub envio_saldo_hoje ($self, $cod_inep, $cfg = undef) {
  $cfg //= $self->envio_config;
  my $s = $cfg->{cota_diaria_escola} - $self->envio_enviados_hoje($cod_inep);
  return $s > 0 ? $s : 0;
}

# Suspensão ativa da escola: { motivo, suspenso_em } ou undef.
sub envio_suspensao ($self, $cod_inep) {
  return $self->_row(
    sprintf(q{SELECT motivo, %s AS suspenso_em
              FROM   clean.canal_envio_suspensoes
              WHERE  cod_inep = ? AND reativado_em IS NULL
              ORDER  BY id DESC LIMIT 1}, sprintf($ISO, 'suspenso_em')),
    $cod_inep + 0,
  );
}

# GET /envios/limites.
sub envio_limites ($self, $cod_inep) {
  my $cfg = $self->envio_config;
  my $hoje = $self->envio_enviados_hoje($cod_inep);
  my $saldo = $cfg->{cota_diaria_escola} - $hoje;
  return {
    enabled           => $cfg->{enabled} ? true : false,
    smtp_disponivel   => $self->email_confirmacao_disponivel ? true : false,
    ritmo_por_minuto  => $cfg->{ritmo_por_minuto} + 0,
    cota_diaria       => $cfg->{cota_diaria_escola} + 0,
    max_destinatarios => $cfg->{max_destinatarios} + 0,
    enviados_hoje     => $hoje,
    saldo_hoje        => $saldo > 0 ? $saldo : 0,
    suspensao         => $self->envio_suspensao($cod_inep),
  };
}

# ---------------------------------------------------------------------------
# rascunho: listar / criar / detalhe / editar / apagar
# ---------------------------------------------------------------------------

# { items, total, page, per_page } (mais recentes primeiro, sem `corpo`) ou
# { error } (status inválido).
sub envio_listar ($self, $cod_inep, %f) {
  my ($page, $per) = $self->_paginacao($f{page}, $f{per_page});
  my @where = ('e.cod_inep = ?');
  my @binds = ($cod_inep + 0);
  if (defined $f{status} && length $f{status}) {
    return { error => 'status inválido.' }
      unless !ref $f{status} && grep { $_ eq $f{status} } @ENVIO_STATUS;
    push @where, 'e.status = ?';
    push @binds, $f{status};
  }
  my $w = join ' AND ', @where;
  my $total = $self->_row("SELECT count(*)::int AS n FROM clean.canal_envios e WHERE $w", @binds)->{n};
  my $rows = $self->_rows(
    $self->_sql_envio("WHERE $w ORDER BY e.created_at DESC, e.id DESC LIMIT ? OFFSET ?"),
    @binds, $per, ($page - 1) * $per,
  );
  return {
    items    => [ map { $self->_envio_publico($_, sem_corpo => 1) } @$rows ],
    total    => $total + 0,
    page     => $page,
    per_page => $per,
  };
}

sub envio_detalhe ($self, $cod_inep, $id) {
  return unless defined $id && $id =~ /^\d+\z/;
  my $r = $self->_row($self->_sql_envio('WHERE e.id = ? AND e.cod_inep = ?'), $id + 0, $cod_inep + 0)
    or return;
  return $self->_envio_publico($r);
}

# Cria um rascunho. %p: cod_inep, gestor_id, alvo_tipo, alvo_id, operacao,
# assunto, corpo. Devolve o envio ou { error, status => 400|404 }.
sub envio_criar ($self, %p) {
  my $v = $self->_envio_campos($p{cod_inep}, \%p, undef);
  return $v if $v->{error};
  my $c = $v->{campos};
  my $row = $self->_row(
    q{INSERT INTO clean.canal_envios
        (cod_inep, gestor_id, alvo_tipo, alvo_id, alvo_nome, operacao, assunto, corpo)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      RETURNING id},
    $p{cod_inep} + 0, $p{gestor_id} + 0,
    @$c{qw(alvo_tipo alvo_id alvo_nome operacao assunto corpo)},
  );
  return $self->envio_detalhe($p{cod_inep}, $row->{id});
}

# PATCH de um rascunho (qualquer campo do POST). Devolve o envio, undef (não é
# da escola) ou { error, status => 400|404|409 }.
sub envio_atualizar ($self, $cod_inep, $id, %campos) {
  my $atual = $self->_envio_base($cod_inep, $id) or return;
  return { error => 'Só é possível editar um envio em rascunho.', status => 409, motivo => 'status' }
    unless $atual->{status} eq 'rascunho';
  return { error => 'Nada a alterar.', status => 400 }
    unless grep { exists $campos{$_} } qw(alvo_tipo alvo_id operacao assunto corpo);

  my $v = $self->_envio_campos($cod_inep, \%campos, $atual);
  return $v if $v->{error};
  my $c = $v->{campos};
  $self->_rows(
    q{UPDATE clean.canal_envios
         SET alvo_tipo = ?, alvo_id = ?, alvo_nome = ?, operacao = ?, assunto = ?,
             corpo = ?, updated_at = NOW()
       WHERE id = ? AND cod_inep = ? AND status = 'rascunho'},
    @$c{qw(alvo_tipo alvo_id alvo_nome operacao assunto corpo)}, $id + 0, $cod_inep + 0,
  );
  return $self->envio_detalhe($cod_inep, $id);
}

# Apaga um rascunho. { ok => 1 } · undef (não é da escola) · { error,
# status => 409 } (não é rascunho).
sub envio_apagar ($self, $cod_inep, $id) {
  my $atual = $self->_envio_base($cod_inep, $id) or return;
  return { error => 'Só é possível apagar um envio em rascunho.', status => 409, motivo => 'status' }
    unless $atual->{status} eq 'rascunho';
  my $r = $self->_row(
    q{DELETE FROM clean.canal_envios
       WHERE id = ? AND cod_inep = ? AND status = 'rascunho' RETURNING id},
    $id + 0, $cod_inep + 0,
  );
  return { error => 'Só é possível apagar um envio em rascunho.', status => 409, motivo => 'status' }
    unless $r;
  return { ok => 1 };
}

# ---------------------------------------------------------------------------
# prévia e teste
# ---------------------------------------------------------------------------

# { assunto, texto (corpo + rodapé, link de saída EXEMPLO), estimativa:
# {destinatarios, ignorados_optout, ignorados_duplicado} } ou undef.
sub envio_previa ($self, $cod_inep, $id) {
  my $e = $self->_envio_base($cod_inep, $id) or return;
  my $alvo = $self->_alvo_resolvido($cod_inep, $e->{alvo_tipo}, $e->{alvo_id});
  my ($n, $opt, $dup) = (0, 0, 0);
  if ($alvo) {
    my $r = $self->resolver_destinatarios($cod_inep, $alvo->{listas}, $alvo->{filtro});
    $opt = grep { $_->{optout} } @{ $r->{itens} };
    $n   = @{ $r->{itens} } - $opt;
    $dup = $r->{duplicados};
  }
  my $base = $self->_base_url;
  return {
    assunto    => $e->{assunto},
    texto      => $self->envio_texto(
      corpo      => $e->{corpo},
      lista_nome => ($alvo ? $alvo->{nome} : $e->{alvo_nome}),
      escola     => $self->_escola_nome($cod_inep),
      operacao   => $e->{operacao},
      link_saida => "$base/privacidade/sair/EXEMPLO",
    ),
    estimativa => {
      destinatarios       => $n + 0,
      ignorados_optout    => $opt + 0,
      ignorados_duplicado => $dup + 0,
    },
  };
}

# E-mail de teste para o próprio gestor (não conta na cota; histórico com
# referente envio_teste). %p: cod_inep, id, gestor_id, smtp_transport, log.
# Devolve undef (não é da escola), { enviado => 1, para } ou { error, status
# => 409 (motivo smtp_indisponivel|sem_email_gestor) | 429 | 502 }.
sub envio_teste ($self, %p) {
  my $e = $self->_envio_base($p{cod_inep}, $p{id}) or return;
  return { error => 'O envio de e-mail não está configurado.', status => 409,
           motivo => 'smtp_indisponivel' }
    unless $self->email_confirmacao_disponivel;

  my $g = $self->_row('SELECT email FROM clean.gestores WHERE id = ?', ($p{gestor_id} // 0) + 0);
  my $para = $g && defined $g->{email} ? lc($g->{email} =~ s/^\s+|\s+$//gr) : '';
  return { error => 'Seu cadastro não tem e-mail.', status => 409, motivo => 'sem_email_gestor' }
    unless length $para;

  my $n = $self->_row(
    q{SELECT count(*)::int AS n FROM clean.canal_mensagens
       WHERE referente_tipo = 'envio_teste' AND referente_id = ?},
    $e->{id} + 0,
  )->{n};
  return { error => "Limite de $TESTES_MAX e-mails de teste por envio atingido.", status => 429 }
    if $n >= $TESTES_MAX;

  my $alvo = $self->_alvo_resolvido($p{cod_inep}, $e->{alvo_tipo}, $e->{alvo_id});
  my $base = $self->_base_url;
  my $link = "$base/privacidade/sair/EXEMPLO";
  my $res = $self->_canal_email(%p)->send_message({
    to        => $para,
    operacao  => $e->{operacao},
    assunto   => "[Teste] $e->{assunto}",
    corpo     => $self->envio_texto(
      corpo      => $e->{corpo},
      lista_nome => ($alvo ? $alvo->{nome} : $e->{alvo_nome}),
      escola     => $self->_escola_nome($p{cod_inep}),
      operacao   => $e->{operacao},
      link_saida => $link,
    ),
    headers   => $self->_cabecalhos_lista($link),
    referente => { tipo => 'envio_teste', id => $e->{id} + 0 },
    cod_inep  => $p{cod_inep} + 0,
  });
  return { error => 'Não foi possível enviar o e-mail de teste agora.', status => 502,
           detalhe => $res->{error} }
    unless $res->{ok};
  return { enviado => 1, para => $self->mascarar_email($para) };
}

# Texto final: corpo + rodapé do contrato.
sub envio_texto ($self, %p) {
  my $base = $self->_base_url;
  my $lista = $p{lista_nome} // '';
  my $escola = $p{escola} // '';
  my $rotulo = $OPERACAO_ROTULO{ $p{operacao} // '' } // ($p{operacao} // '');
  my $corpo = $p{corpo} // '';
  $corpo =~ s/\s+\z//;
  return join "\n",
    $corpo,
    '',
    '--',
    qq{Você recebe este e-mail porque se inscreveu na lista "$lista" da escola $escola.},
    "Motivo: $rotulo.",
    "Não quer mais receber mensagens desta lista? $p{link_saida}",
    "Privacidade e remoção dos seus dados: $base/privacidade";
}

# ---------------------------------------------------------------------------
# disparo e cancelamento
# ---------------------------------------------------------------------------

# Token de saída do destinatário (32 hex) e o hash gravado.
sub envio_token_saida ($self, $destinatario_id, $secret) {
  die "envio_token_saida: segredo do app ausente\n" unless defined $secret && length $secret;
  return substr(hmac_sha256_hex("saida:$destinatario_id", $secret), 0, 32);
}

# Dispara. %p: cod_inep, id, agendado_para (opcional), secret (segredo do
# app), enqueue (coderef ($envio_id, $delay) -> job id). Devolve o envio,
# undef (não é da escola) ou { error, status => 400|409, motivo, saldo?,
# teto? }.
sub envio_disparar ($self, %p) {
  my ($cod_inep, $id) = @p{qw(cod_inep id)};
  my $e = $self->_envio_base($cod_inep, $id) or return;
  my $conf = sub ($motivo, $msg, %x) { +{ error => $msg, status => 409, motivo => $motivo, %x } };

  return $conf->('status', 'Este envio já foi disparado.') unless $e->{status} eq 'rascunho';

  my $agenda = $p{agendado_para};
  $agenda = undef if defined $agenda && !ref $agenda && $agenda !~ /\S/;
  my $delay = 0;
  if (defined $agenda) {
    my $a = $self->_valida_agendamento($agenda);
    return { error => $a->{error}, status => 400 } if $a->{error};
    ($agenda, $delay) = @$a{qw(valor delay)};
  }

  my $cfg = $self->envio_config;
  return $conf->('envio_desligado', 'O envio para listas está desligado pela administração.')
    unless $cfg->{enabled};
  return $conf->('smtp_indisponivel', 'O envio de e-mail não está configurado.')
    unless $self->email_confirmacao_disponivel;
  return $conf->('escola_suspensa', 'O envio desta escola está suspenso pela administração.')
    if $self->envio_suspensao($cod_inep);

  my $alvo = $self->_alvo_resolvido($cod_inep, $e->{alvo_tipo}, $e->{alvo_id});
  return $conf->('alvo_inexistente', 'A lista de destino não existe mais.') unless $alvo;

  my $r = $self->resolver_destinatarios($cod_inep, $alvo->{listas}, $alvo->{filtro});
  my @itens = @{ $r->{itens} };
  my $optouts = grep { $_->{optout} } @itens;
  my $n = @itens - $optouts;
  return $conf->('sem_destinatarios', 'Nenhum destinatário com e-mail.') unless $n;
  return $conf->('acima_do_teto', "O envio passa do máximo de $cfg->{max_destinatarios} destinatários.",
                 teto => $cfg->{max_destinatarios} + 0)
    if $n > $cfg->{max_destinatarios};
  my $saldo = defined $agenda ? $cfg->{cota_diaria_escola} + 0
                              : $self->envio_saldo_hoje($cod_inep, $cfg);
  return $conf->('cota_insuficiente', 'A cota diária de e-mails não comporta este envio.',
                 saldo => $saldo)
    if $n > $saldo;

  my $secret = $p{secret};
  die "envio_disparar: segredo do app ausente\n" unless defined $secret && length $secret;

  my $ok;
  $self->schema->storage->txn_do(sub {
    my $u = $self->_row(
      q{UPDATE clean.canal_envios
           SET status = ?, alvo_nome = ?, agendado_para = ?::timestamptz,
               iniciado_em = CASE WHEN ? THEN NULL ELSE NOW() END,
               destinatarios = ?, ignorados = ?, updated_at = NOW()
         WHERE id = ? AND cod_inep = ? AND status = 'rascunho'
         RETURNING id},
      (defined $agenda ? 'agendado' : 'enviando'), $alvo->{nome}, $agenda,
      (defined $agenda ? 1 : 0),
      scalar(@itens), $r->{duplicados} + $optouts, $id + 0, $cod_inep + 0,
    ) or return;

    my (@c, @l, @em, @h, @st);
    for my $i (@itens) {
      push @c,  $i->{contato_id};
      push @l,  $i->{lista_id};
      push @em, $i->{optout} ? undef : $i->{email};
      push @h,  $i->{email_hash};
      push @st, $i->{optout} ? 'ignorado_optout' : 'pendente';
    }
    my $ins = $self->_rows(
      q{INSERT INTO clean.canal_envio_destinatarios
          (envio_id, contato_id, lista_id, email, email_hash, status, processado_em)
        SELECT ?, u.c, u.l, u.e, u.h, u.s,
               CASE WHEN u.s = 'pendente' THEN NULL ELSE NOW() END
        FROM   unnest(?::bigint[], ?::bigint[], ?::text[], ?::text[], ?::text[])
                 WITH ORDINALITY AS u(c, l, e, h, s, ord)
        ORDER  BY u.ord
        RETURNING id, status},
      $id + 0, \@c, \@l, \@em, \@h, \@st,
    );
    my @pend = grep { $_->{status} eq 'pendente' } @$ins;
    $self->_rows(
      q{UPDATE clean.canal_envio_destinatarios d SET saida_hash = u.h
        FROM   unnest(?::bigint[], ?::text[]) AS u(id, h)
        WHERE  d.id = u.id},
      [ map { $_->{id} + 0 } @pend ],
      [ map { sha256_hex($self->envio_token_saida($_->{id}, $secret)) } @pend ],
    ) if @pend;
    $ok = 1;
  });
  return $conf->('status', 'Este envio já foi disparado.') unless $ok;

  if (my $enq = $p{enqueue}) {
    my $job = $enq->($id + 0, $delay);
    $self->_rows('UPDATE clean.canal_envios SET minion_job_id = ? WHERE id = ?', $job + 0, $id + 0)
      if defined $job;
  }
  return $self->envio_detalhe($cod_inep, $id);
}

# Cancela (agendado|enviando|pausado_cota|suspenso): pendentes → cancelado;
# e-mails em claro zerados. Devolve o envio, undef ou { error, status => 409 }.
sub envio_cancelar ($self, $cod_inep, $id) {
  my $e = $self->_envio_base($cod_inep, $id) or return;
  my $ok;
  $self->schema->storage->txn_do(sub {
    $self->_row(
      q{UPDATE clean.canal_envios
           SET status = 'cancelado', cancelado_em = NOW(), updated_at = NOW()
         WHERE id = ? AND cod_inep = ? AND status = ANY(?::text[])
         RETURNING id},
      $id + 0, $cod_inep + 0, \@CANCELAVEIS,
    ) or return;
    $self->_rows(
      q{UPDATE clean.canal_envio_destinatarios
           SET status = 'cancelado', processado_em = NOW()
         WHERE envio_id = ? AND status = 'pendente'},
      $id + 0,
    );
    $self->_rows(
      'UPDATE clean.canal_envio_destinatarios SET email = NULL WHERE envio_id = ? AND email IS NOT NULL',
      $id + 0,
    );
    $ok = 1;
  });
  return { error => 'Este envio não pode ser cancelado no estado atual.', status => 409,
           motivo => 'status' }
    unless $ok;
  return $self->envio_detalhe($cod_inep, $id);
}

# Destinatários (paginado, e-mail mascarado). Devolve { items, total, page,
# per_page }, undef (envio não é da escola) ou { error } (status inválido).
sub envio_destinatarios ($self, $cod_inep, $id, %f) {
  my $e = $self->_envio_base($cod_inep, $id) or return;
  my ($page, $per) = $self->_paginacao($f{page}, $f{per_page});
  my @where = ('d.envio_id = ?');
  my @binds = ($id + 0);
  if (defined $f{status} && length $f{status}) {
    return { error => 'status inválido.' }
      unless !ref $f{status} && grep { $_ eq $f{status} } @DEST_STATUS;
    push @where, 'd.status = ?';
    push @binds, $f{status};
  }
  my $w = join ' AND ', @where;
  my $total = $self->_row(
    "SELECT count(*)::int AS n FROM clean.canal_envio_destinatarios d WHERE $w", @binds,
  )->{n};
  my $rows = $self->_rows(
    sprintf(qq{SELECT d.id, d.lista_id, d.status, d.erro, c.nome,
                      COALESCE(d.email, lower(trim(c.email))) AS email,
                      %s AS processado_em
               FROM   clean.canal_envio_destinatarios d
               LEFT JOIN clean.contatos c ON c.id = d.contato_id
               WHERE  $w
               ORDER  BY d.id
               LIMIT ? OFFSET ?}, sprintf($ISO, 'd.processado_em')),
    @binds, $per, ($page - 1) * $per,
  );
  return {
    items => [ map { +{
      id            => $_->{id} + 0,
      nome          => $_->{nome},
      email         => $self->mascarar_email($_->{email}),
      lista_id      => defined $_->{lista_id} ? $_->{lista_id} + 0 : undef,
      status        => $_->{status},
      erro          => $_->{erro},
      processado_em => $_->{processado_em},
    } } @$rows ],
    total    => $total + 0,
    page     => $page,
    per_page => $per,
  };
}

# ---------------------------------------------------------------------------
# lote (job canais_envio)
# ---------------------------------------------------------------------------

# Processa um lote do envio. %o: secret (segredo do app), smtp_transport
# (coderef injetável), log. Devolve:
#
#   { fim => 'inexistente'|'rascunho'|'cancelado'|'concluido' }   sai
#   { fim => 'suspenso' }                                         escola suspensa
#   { reagendar => 300, motivo => 'envio_desligado'|'smtp_indisponivel' }
#   { reagendar => <s>, motivo => 'agendado' }                    ainda não é hora
#   { reagendar => <s até 00:05>, status => 'pausado_cota', processados }
#   { reagendar => 60, processados }                              há pendentes
#   { fim => 'concluido', processados }                           acabou
sub envio_processar_lote ($self, $id, %o) {
  my $e = $self->_row(
    q{SELECT id, cod_inep, status, alvo_nome, operacao, assunto, corpo,
             GREATEST(0, CEIL(EXTRACT(EPOCH FROM (agendado_para - NOW()))))::int AS falta
      FROM   clean.canal_envios WHERE id = ?},
    $id + 0,
  ) or return { fim => 'inexistente' };
  return { fim => $e->{status} } if grep { $e->{status} eq $_ } qw(rascunho cancelado concluido);

  my $cod_inep = $e->{cod_inep} + 0;
  if ($self->envio_suspensao($cod_inep)) {
    $self->_rows(
      q{UPDATE clean.canal_envios SET status = 'suspenso', updated_at = NOW()
         WHERE id = ? AND status <> 'suspenso'},
      $id + 0,
    );
    return { fim => 'suspenso' };
  }

  my $cfg = $self->envio_config;
  return { reagendar => $DELAY_ESPERA, motivo => 'envio_desligado' } unless $cfg->{enabled};
  return { reagendar => $DELAY_ESPERA, motivo => 'smtp_indisponivel' }
    unless $self->email_confirmacao_disponivel;
  return { reagendar => $e->{falta} + 0, motivo => 'agendado' }
    if $e->{status} eq 'agendado' && $e->{falta} > 0;

  # agendado → enviando (+ iniciado_em); pausado_cota/suspenso (reativada) → enviando
  $self->_rows(
    q{UPDATE clean.canal_envios
         SET status = 'enviando', iniciado_em = COALESCE(iniciado_em, NOW()), updated_at = NOW()
       WHERE id = ? AND status IN ('agendado', 'pausado_cota', 'suspenso')},
    $id + 0,
  );

  my $secret = $o{secret};
  die "envio_processar_lote: segredo do app ausente\n" unless defined $secret && length $secret;

  my $saldo = $self->envio_saldo_hoje($cod_inep, $cfg);
  my $escola = $self->_escola_nome($cod_inep);
  my $base   = $self->_base_url;
  my $canal  = $self->_canal_email(%o);
  my %listas;

  my $pend = $self->_rows(
    q{SELECT d.id, d.contato_id, d.lista_id, d.email, l.nome AS lista_nome
      FROM   clean.canal_envio_destinatarios d
      LEFT JOIN clean.canal_listas l ON l.id = d.lista_id
      WHERE  d.envio_id = ? AND d.status = 'pendente'
      ORDER  BY d.id LIMIT ?},
    $id + 0, $cfg->{ritmo_por_minuto} + 0,
  );

  my $n = 0;
  for my $d (@$pend) {
    # cancelado no meio do lote: a linha já não está pendente
    my $ainda = $self->_row(
      q{SELECT status, email FROM clean.canal_envio_destinatarios WHERE id = ?}, $d->{id} + 0);
    next unless $ainda && $ainda->{status} eq 'pendente';

    unless (defined $ainda->{email} && length $ainda->{email}) {
      $self->_rows(
        q{UPDATE clean.canal_envio_destinatarios
             SET status = 'ignorado_anonimizado', processado_em = NOW()
           WHERE id = ? AND status = 'pendente'},
        $d->{id} + 0,
      );
      $self->_contar($id, ignorados => 1);
      $n++;
      next;
    }
    last if $saldo <= 0;

    my $token = $self->envio_token_saida($d->{id}, $secret);
    my $link  = "$base/privacidade/sair/$token";
    my $res = $canal->send_message({
      to        => $ainda->{email},
      operacao  => $e->{operacao},
      assunto   => $e->{assunto},
      corpo     => $self->envio_texto(
        corpo      => $e->{corpo},
        lista_nome => $d->{lista_nome} // $e->{alvo_nome},
        escola     => $escola,
        operacao   => $e->{operacao},
        link_saida => $link,
      ),
      headers    => $self->_cabecalhos_lista($link),
      referente  => { tipo => 'envio', id => $id + 0 },
      contato_id => $d->{contato_id},
      cod_inep   => $cod_inep,
    });
    my $mid = $res->{mensagem_id};
    if ($res->{ok}) {
      $self->_rows(
        q{UPDATE clean.canal_envio_destinatarios
             SET status = 'enviado', erro = NULL, mensagem_id = ?, processado_em = NOW()
           WHERE id = ? AND status = 'pendente'},
        $mid, $d->{id} + 0,
      );
      $self->_contar($id, enviados => 1);
      $saldo--;
    }
    else {
      my $erro = $res->{error} // 'falha desconhecida';
      $self->_rows(
        q{UPDATE clean.canal_envio_destinatarios
             SET status = 'falhou', erro = ?, mensagem_id = ?, processado_em = NOW()
           WHERE id = ? AND status = 'pendente'},
        substr($erro, 0, 500), $mid, $d->{id} + 0,
      );
      $self->_contar($id, falhas => 1);
    }
    $n++;
  }

  # cancelado durante o lote: o cancelamento já fechou tudo
  my $st = $self->_row('SELECT status FROM clean.canal_envios WHERE id = ?', $id + 0);
  return { fim => $st->{status}, processados => $n } if $st && $st->{status} ne 'enviando';

  my $resta = $self->_row(
    q{SELECT count(*)::int AS n FROM clean.canal_envio_destinatarios
       WHERE envio_id = ? AND status = 'pendente'},
    $id + 0,
  )->{n};

  unless ($resta) {
    $self->schema->storage->txn_do(sub {
      $self->_rows(
        q{UPDATE clean.canal_envios
             SET status = 'concluido', concluido_em = NOW(), updated_at = NOW()
           WHERE id = ? AND status = 'enviando'},
        $id + 0,
      );
      $self->_rows(
        'UPDATE clean.canal_envio_destinatarios SET email = NULL WHERE envio_id = ? AND email IS NOT NULL',
        $id + 0,
      );
    });
    return { fim => 'concluido', processados => $n };
  }

  if ($saldo <= 0) {
    $self->_rows(
      q{UPDATE clean.canal_envios SET status = 'pausado_cota', updated_at = NOW()
         WHERE id = ? AND status = 'enviando'},
      $id + 0,
    );
    return { reagendar => $self->envio_segundos_ate_retomada, status => 'pausado_cota',
             processados => $n };
  }
  return { reagendar => $DELAY_LOTE, processados => $n };
}

# Segundos até 00:05 do dia seguinte (America/Sao_Paulo).
sub envio_segundos_ate_retomada ($self) {
  my $r = $self->_row(
    qq{SELECT CEIL(EXTRACT(EPOCH FROM (
              ((date_trunc('day', NOW() AT TIME ZONE '$TZ') + interval '1 day 5 minutes')
                 AT TIME ZONE '$TZ') - NOW())))::int AS s},
  );
  return $r->{s} > 0 ? $r->{s} + 0 : 1;
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _contar ($self, $id, %inc) {
  $self->_rows(
    q{UPDATE clean.canal_envios
         SET enviados = enviados + ?, falhas = falhas + ?, ignorados = ignorados + ?,
             updated_at = NOW()
       WHERE id = ?},
    ($inc{enviados} // 0), ($inc{falhas} // 0), ($inc{ignorados} // 0), $id + 0,
  );
}

sub _cabecalhos_lista ($self, $link) {
  return [
    [ 'List-Unsubscribe'      => "<$link>" ],
    [ 'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click' ],
    [ 'Precedence'            => 'bulk' ],
  ];
}

sub _canal_email ($self, %o) {
  my $cfg = $self->email_config;
  return EduMaps::Channel::Email->new(
    config         => $cfg,
    enabled        => ($cfg->{enabled} ? 1 : 0),
    schema         => $self->schema,
    ($o{log} ? (log => $o{log}) : ()),
    smtp_transport => $o{smtp_transport},
  );
}

sub _base_url ($self) {
  my $b = $self->inscricao_config->{public_base_url} // '';
  $b =~ s{/+$}{};
  return $b;
}

sub _escola_nome ($self, $cod_inep) {
  my $r = $self->_row('SELECT escola FROM clean.escolas WHERE codigo_inep = ?', $cod_inep + 0);
  return $r && defined $r->{escola} ? $r->{escola} : '';
}

sub _paginacao ($self, $page, $per) {
  $page = (defined $page && !ref $page && $page =~ /^\d{1,6}\z/ && $page >= 1) ? $page + 0 : 1;
  $per  = (defined $per && !ref $per && $per =~ /^\d{1,6}\z/ && $per >= 1) ? $per + 0 : 20;
  $per  = 100 if $per > 100;
  return ($page, $per);
}

# Alvo resolvido para a resolução de membros: { nome, listas => [ids ativos],
# filtro } ou undef (alvo inexistente na escola / sem listas ativas para lista).
sub _alvo_resolvido ($self, $cod_inep, $tipo, $alvo_id) {
  if ($tipo eq 'lista') {
    my $l = $self->_row(
      'SELECT id, nome FROM clean.canal_listas WHERE id = ? AND cod_inep = ? AND ativo',
      $alvo_id + 0, $cod_inep + 0,
    ) or return;
    return { nome => $l->{nome}, listas => [ $l->{id} + 0 ], filtro => undef };
  }
  my $s = $self->_row(
    'SELECT id, nome, criterios::text AS criterios FROM clean.canal_segmentos WHERE id = ? AND cod_inep = ?',
    $alvo_id + 0, $cod_inep + 0,
  ) or return;
  my $c = Mojo::JSON::decode_json($s->{criterios});
  return {
    nome   => $s->{nome},
    listas => $self->_listas_ativas($cod_inep, $c->{listas} // []),
    filtro => $c,
  };
}

# Nome atual do alvo (lista ativa ou segmento da escola) ou undef.
sub _alvo_nome_atual ($self, $cod_inep, $tipo, $alvo_id) {
  my $sql = $tipo eq 'lista'
    ? 'SELECT nome FROM clean.canal_listas WHERE id = ? AND cod_inep = ? AND ativo'
    : 'SELECT nome FROM clean.canal_segmentos WHERE id = ? AND cod_inep = ?';
  my $r = $self->_row($sql, $alvo_id + 0, $cod_inep + 0);
  return $r ? $r->{nome} : undef;
}

# Valida os campos do POST/PATCH (no PATCH, `$atual` dá os ausentes). Devolve
# { campos => {...} } ou { error, status => 400|404 }.
sub _envio_campos ($self, $cod_inep, $in, $atual) {
  my %c;
  my $tem = sub ($k) { exists $in->{$k} || !$atual };
  my $bad = sub ($m) { +{ error => $m, status => 400 } };

  $c{alvo_tipo} = $tem->('alvo_tipo') ? $in->{alvo_tipo} : $atual->{alvo_tipo};
  return $bad->('alvo_tipo inválido (lista ou segmento).')
    unless defined $c{alvo_tipo} && !ref $c{alvo_tipo} && $c{alvo_tipo} =~ /^(?:lista|segmento)\z/;
  $c{alvo_id} = $tem->('alvo_id') ? $in->{alvo_id} : $atual->{alvo_id};
  return $bad->('alvo_id inválido.')
    unless defined $c{alvo_id} && !ref $c{alvo_id} && $c{alvo_id} =~ /^\d{1,18}\z/;
  $c{alvo_id} += 0;

  $c{operacao} = $tem->('operacao') ? $in->{operacao} : $atual->{operacao};
  return $bad->('operacao inválida (aviso, informacao, pedido, convite, lembrete ou alerta).')
    unless defined $c{operacao} && !ref $c{operacao} && grep { $_ eq $c{operacao} } @ENVIO_OPERACOES;

  for my $k ([assunto => 200], [corpo => 20000]) {
    my ($campo, $max) = @$k;
    my $v = $tem->($campo) ? $in->{$campo} : $atual->{$campo};
    $v = '' unless defined $v && !ref $v;
    $v =~ s/^\s+|\s+$//g if $campo eq 'assunto';
    $v =~ s/\s+\z// if $campo eq 'corpo';
    return $bad->("$campo é obrigatório (1..$max caracteres).")
      unless length $v >= 1 && length $v <= $max && $v =~ /\S/;
    $c{$campo} = $v;
  }

  # alvo da escola (lista ativa ou segmento); só é checado quando muda
  my $muda = !$atual || $c{alvo_tipo} ne $atual->{alvo_tipo} || $c{alvo_id} != $atual->{alvo_id};
  my $nome = $self->_alvo_nome_atual($cod_inep, $c{alvo_tipo}, $c{alvo_id});
  return { error => 'Lista de destino não encontrada nesta escola.', status => 404 }
    if $muda && !defined $nome;
  $c{alvo_nome} = $nome // $atual->{alvo_nome};
  return { campos => \%c };
}

sub _valida_agendamento ($self, $v) {
  my $msg = 'agendado_para deve ser uma data/hora ISO 8601 no futuro (até 90 dias).';
  return { error => $msg } if ref $v;
  $v =~ s/^\s+|\s+$//g;
  return { error => $msg } unless $v =~ /^\d{4}-\d\d-\d\d
                                        [T\x20]\d\d:\d\d(?::\d\d(?:\.\d{1,6})?)?
                                        (?:Z|[+-]\d\d(?::?\d\d)?)?\z/xi;
  my $r = eval {
    $self->_row(
      sprintf(q{SELECT (?::timestamptz > NOW()) AS futura,
                       (?::timestamptz <= NOW() + make_interval(days => ?)) AS dentro,
                       CEIL(EXTRACT(EPOCH FROM (?::timestamptz - NOW())))::int AS delay,
                       %s AS valor}, sprintf($ISO, '?::timestamptz')),
      $v, $v, $AGENDA_MAX_DIAS, $v, $v,
    );
  };
  return { error => $msg } unless $r && $r->{futura} && $r->{dentro};
  return { valor => $r->{valor}, delay => ($r->{delay} > 0 ? $r->{delay} + 0 : 0) };
}

sub _envio_base ($self, $cod_inep, $id) {
  return unless defined $id && $id =~ /^\d+\z/ && defined $cod_inep;
  return $self->_row(
    q{SELECT id, cod_inep, status, alvo_tipo, alvo_id, alvo_nome, operacao, assunto, corpo
      FROM   clean.canal_envios WHERE id = ? AND cod_inep = ?},
    $id + 0, $cod_inep + 0,
  );
}

sub _sql_envio ($self, $resto) {
  return sprintf(q{
    SELECT e.*, g.nome AS autor_nome,
           %s AS agendado_para_iso, %s AS iniciado_em_iso, %s AS concluido_em_iso,
           %s AS cancelado_em_iso, %s AS created_at_iso, %s AS updated_at_iso,
           CASE WHEN e.alvo_tipo = 'lista'
                THEN (SELECT nome FROM clean.canal_listas l
                       WHERE l.id = e.alvo_id AND l.cod_inep = e.cod_inep AND l.ativo)
                ELSE (SELECT nome FROM clean.canal_segmentos s
                       WHERE s.id = e.alvo_id AND s.cod_inep = e.cod_inep) END AS alvo_atual,
           (SELECT count(*)::int FROM clean.canal_envio_destinatarios d
             WHERE d.envio_id = e.id AND d.status = 'pendente') AS n_pendentes,
           (SELECT count(*)::int FROM clean.canal_envio_destinatarios d
             WHERE d.envio_id = e.id AND d.status = 'cancelado') AS n_cancelados,
           (SELECT count(*)::int FROM clean.canal_optouts o
             WHERE o.envio_id = e.id) AS n_optouts
    FROM   clean.canal_envios e
    LEFT JOIN clean.gestores g ON g.id = e.gestor_id
    %s},
    (map { sprintf($ISO, "e.$_") } qw(agendado_para iniciado_em concluido_em cancelado_em
                                      created_at updated_at)),
    $resto);
}

sub _envio_publico ($self, $r, %o) {
  my %e = (
    id       => $r->{id} + 0,
    cod_inep => $r->{cod_inep} + 0,
    alvo     => {
      tipo => $r->{alvo_tipo},
      id   => $r->{alvo_id} + 0,
      nome => $r->{status} eq 'rascunho' ? $r->{alvo_atual} : $r->{alvo_nome},
    },
    canal         => $r->{canal},
    operacao      => $r->{operacao},
    assunto       => $r->{assunto},
    corpo         => $r->{corpo},
    status        => $r->{status},
    agendado_para => $r->{agendado_para_iso},
    iniciado_em   => $r->{iniciado_em_iso},
    concluido_em  => $r->{concluido_em_iso},
    cancelado_em  => $r->{cancelado_em_iso},
    contadores    => {
      destinatarios => $r->{destinatarios} + 0,
      enviados      => $r->{enviados} + 0,
      falhas        => $r->{falhas} + 0,
      ignorados     => $r->{ignorados} + 0,
      pendentes     => $r->{n_pendentes} + 0,
      cancelados    => $r->{n_cancelados} + 0,
      optouts       => $r->{n_optouts} + 0,
    },
    autor => defined $r->{gestor_id}
      ? { id => $r->{gestor_id} + 0, nome => $r->{autor_nome} } : undef,
    created_at => $r->{created_at_iso},
    updated_at => $r->{updated_at_iso},
  );
  delete $e{corpo} if $o{sem_corpo};
  return \%e;
}

1;
