package EduMaps::Roles::Business::Canal::Confirmacao;
use Mojo::Base -role, -signatures;
use utf8;

use Digest::SHA qw(sha256_hex);

# ============================================================================
# CONFIRMAÇÃO DE POSSE DO TELEFONE NAS LISTAS COM QR (issue #212 — Fase 1)
# ============================================================================
#
# Quando a lista exige confirmação (`canal_listas.exige_confirmacao`), cada
# inscrição de membro PENDENTE recebe uma referência pública opaca (`ref`):
#
#   - 128 bits aleatórios em 32 hex; o banco guarda SÓ o SHA-256 (ref_hash) —
#     a ref em claro vai apenas ao inscrito;
#   - validade de 24h (`confirmacao_ttl_horas`), uso único (`usada_em`);
#   - reabrir para o mesmo membro invalida as refs pendentes anteriores
#     (`invalidada_em`) — nada é apagado.
#
# Concluir a confirmação marca o membro (`confirmado_em/via`, `validado=true`,
# `telegram_chat_id` opcional) e a inscrição (`validado=true`). Número
# divergente vira `conflito=true` na inscrição, sem tocar o membro (modelo não
# destrutivo, como na Fase 0).
#
# Composta no mesmo model que `Canal::Listas` (EduMaps::Model::Canal); usa os
# helpers SQL `_rows/_row` de lá e a config dos canais do AppConfig
# (`canais_confirmacao_disponiveis`).

requires qw(schema _rows _row canais_confirmacao_disponiveis);

our @VIAS = qw(telegram whatsapp);

# Validade da ref, em horas (decisão da spec: 24h).
sub confirmacao_ttl_horas { return 24; }

# Formato da ref pública: 32 hex (128 bits).
sub ref_valida ($self, $ref) {
  return defined $ref && !ref $ref && $ref =~ /^[0-9a-fA-F]{32}\z/ ? 1 : 0;
}

sub _ref_hash ($self, $ref) { return sha256_hex(lc $ref); }

# expira_em em ISO 8601 (UTC), como o contrato pede.
my $ISO = q{to_char(%s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')};

# ---------------------------------------------------------------------------
# abrir / consultar
# ---------------------------------------------------------------------------

# Abre uma nova ref para o membro, ligada à inscrição que a originou. Invalida
# as refs pendentes anteriores do mesmo membro. Devolve { ref, expira_em }.
sub abrir_ref ($self, $membro_id, $inscricao_id) {
  my $ref = $self->_row(
    q{SELECT encode(gen_random_bytes(16), 'hex') AS ref}
  )->{ref};

  my $row;
  $self->schema->storage->txn_do(sub {
    $self->_rows(
      q{UPDATE clean.canal_confirmacao_refs
           SET invalidada_em = NOW()
         WHERE membro_id = ? AND usada_em IS NULL AND invalidada_em IS NULL},
      $membro_id + 0,
    );
    $row = $self->_row(
      sprintf(q{INSERT INTO clean.canal_confirmacao_refs
                  (inscricao_id, membro_id, ref_hash, expira_em)
                VALUES (?, ?, ?, NOW() + make_interval(hours => ?))
                RETURNING id, %s AS expira_em}, sprintf($ISO, 'expira_em')),
      $inscricao_id + 0, $membro_id + 0, $self->_ref_hash($ref),
      $self->confirmacao_ttl_horas + 0,
    );
  });

  return { ref => $ref, expira_em => $row->{expira_em} };
}

# Estado de uma ref (sem PII). Devolve undef para formato inválido,
# inexistente, invalidada ou expirada sem uso (o chamador responde 404
# genérico). Caso contrário:
#
#   { estado => 'pendente'|'confirmado', expira_em,
#     ref_id, membro_id, inscricao_id, lista_id, telefone_norm }
#
# Os ids e o telefone_norm são para consumo interno (bot/WhatsApp, onda 2);
# a API pública devolve só estado/canais/expira_em.
sub estado_ref ($self, $ref) {
  return unless $self->ref_valida($ref);

  my $r = $self->_row(
    sprintf(q{SELECT r.id AS ref_id, r.membro_id, r.inscricao_id,
                     r.usada_em, r.invalidada_em, r.telegram_chat_pendente,
                     r.envios_whatsapp,
                     (r.expira_em <= NOW()) AS vencida,
                     %s AS expira_em,
                     m.lista_id, m.confirmado_em,
                     i.telefone_norm
              FROM   clean.canal_confirmacao_refs r
              JOIN   clean.canal_lista_membros m ON m.id = r.membro_id
              JOIN   clean.canal_inscricoes i    ON i.id = r.inscricao_id
              WHERE  r.ref_hash = ?}, sprintf($ISO, 'r.expira_em')),
    $self->_ref_hash($ref),
  ) or return;

  my $estado;
  if    (defined $r->{usada_em})      { $estado = 'confirmado'; }
  elsif (defined $r->{invalidada_em}) { return; }
  elsif ($r->{vencida})               { return; }
  elsif (defined $r->{confirmado_em}) { $estado = 'confirmado'; } # por outro caminho
  else                                { $estado = 'pendente'; }

  return {
    estado                 => $estado,
    expira_em              => $r->{expira_em},
    ref_id                 => $r->{ref_id} + 0,
    membro_id              => $r->{membro_id} + 0,
    inscricao_id           => $r->{inscricao_id} + 0,
    lista_id               => $r->{lista_id} + 0,
    telefone_norm          => $r->{telefone_norm},
    telegram_chat_pendente => $r->{telegram_chat_pendente},
    envios_whatsapp        => $r->{envios_whatsapp} + 0,
  };
}

# Canais de confirmação disponíveis para uma ref, no formato do contrato:
# [ {canal=>'telegram', url=>'https://t.me/<bot>?start=<ref>'}, {canal=>'whatsapp'} ].
sub canais_confirmacao ($self, $ref) {
  my @out;
  for my $c (@{ $self->canais_confirmacao_disponiveis }) {
    if ($c->{canal} eq 'telegram') {
      push @out, { canal => 'telegram',
                   url   => "https://t.me/$c->{bot_username}?start=$ref" };
    }
    else {
      push @out, { canal => $c->{canal} };
    }
  }
  return \@out;
}

# Objeto `confirmacao` da resposta do POST de inscrição (lista que exige):
# membro já confirmado → { estado => 'confirmado' }; senão abre ref nova
# (invalida a anterior) → { ref, estado => 'pendente', expira_em, canais }.
sub confirmacao_da_inscricao ($self, $membro_id, $inscricao_id) {
  my $m = $self->_row(
    'SELECT confirmado_em FROM clean.canal_lista_membros WHERE id = ?',
    $membro_id + 0,
  );
  return { estado => 'confirmado' } if $m && defined $m->{confirmado_em};

  my $r = $self->abrir_ref($membro_id, $inscricao_id);
  return {
    ref       => $r->{ref},
    estado    => 'pendente',
    expira_em => $r->{expira_em},
    canais    => $self->canais_confirmacao($r->{ref}),
  };
}

# ---------------------------------------------------------------------------
# concluir / conflito
# ---------------------------------------------------------------------------

# Conclui a confirmação. Parâmetros: `ref` OU `membro_id`; `via`
# ('telegram'|'whatsapp'); `telegram_chat_id` opcional.
#
#   - por ref: a ref precisa estar pendente (não invalidada, não vencida); ref
#     já usada → idempotente ({ ok => 1, ja_confirmado => 1 });
#   - por membro: usa a ref pendente mais recente do membro, se houver (marca
#     `usada_em`), e a inscrição dela (ou a última inscrição do membro).
#
# Membro: confirmado_em/via preservados se já confirmado (idempotente);
# `validado=true`. Inscrição: `validado=true`. Devolve
# { ok => 1, estado => 'confirmado', membro_id, ja_confirmado } ou
# { ok => 0, reason => 'via'|'not_found' }.
sub concluir ($self, %p) {
  my $via = $p{via} // '';
  return { ok => 0, reason => 'via' } unless grep { $_ eq $via } @VIAS;
  my $chat_id = $p{telegram_chat_id};
  $chat_id = undef if defined $chat_id && $chat_id !~ /^-?\d+\z/;

  my ($membro_id, $ref_id, $inscricao_id);
  if (defined $p{ref}) {
    my $e = $self->estado_ref($p{ref}) or return { ok => 0, reason => 'not_found' };
    ($membro_id, $ref_id, $inscricao_id) = @$e{qw(membro_id ref_id inscricao_id)};
  }
  elsif (defined $p{membro_id} && $p{membro_id} =~ /^\d+\z/) {
    my $m = $self->_row(
      q{SELECT m.id, r.id AS ref_id,
               COALESCE(r.inscricao_id,
                        (SELECT i.id FROM clean.canal_inscricoes i
                          WHERE i.lista_id = m.lista_id AND i.contato_id = m.contato_id
                          ORDER BY i.id DESC LIMIT 1)) AS inscricao_id
        FROM   clean.canal_lista_membros m
        LEFT JOIN LATERAL (
          SELECT r.id, r.inscricao_id
          FROM   clean.canal_confirmacao_refs r
          WHERE  r.membro_id = m.id AND r.usada_em IS NULL
            AND  r.invalidada_em IS NULL AND r.expira_em > NOW()
          ORDER  BY r.id DESC LIMIT 1
        ) r ON TRUE
        WHERE  m.id = ?},
      $p{membro_id} + 0,
    ) or return { ok => 0, reason => 'not_found' };
    ($membro_id, $ref_id, $inscricao_id) = @$m{qw(id ref_id inscricao_id)};
  }
  else {
    return { ok => 0, reason => 'not_found' };
  }

  my $ja;
  $self->schema->storage->txn_do(sub {
    my $antes = $self->_row(
      'SELECT confirmado_em FROM clean.canal_lista_membros WHERE id = ? FOR UPDATE',
      $membro_id + 0,
    );
    $ja = $antes && defined $antes->{confirmado_em} ? 1 : 0;

    $self->_rows(
      q{UPDATE clean.canal_lista_membros
           SET confirmado_em    = COALESCE(confirmado_em, NOW()),
               confirmado_via   = COALESCE(confirmado_via, ?),
               telegram_chat_id = COALESCE(?::bigint, telegram_chat_id),
               validado         = true
         WHERE id = ?},
      $via, $chat_id, $membro_id + 0,
    );
    $self->_rows(
      q{UPDATE clean.canal_confirmacao_refs
           SET usada_em = COALESCE(usada_em, NOW())
         WHERE id = ?},
      $ref_id + 0,
    ) if defined $ref_id;
    $self->_rows(
      'UPDATE clean.canal_inscricoes SET validado = true WHERE id = ?',
      $inscricao_id + 0,
    ) if defined $inscricao_id;
  });

  return { ok => 1, estado => 'confirmado', membro_id => $membro_id + 0,
           ja_confirmado => $ja };
}

# Número divergente (ex.: contato do Telegram ≠ telefone inscrito): marca
# `conflito=true` na inscrição da ref, sem alterar o membro nem a ref (o
# inscrito pode tentar de novo). Só refs pendentes.
# Devolve { ok => 1, inscricao_id } ou { ok => 0, reason => 'not_found' }.
sub registrar_conflito ($self, $ref) {
  my $e = $self->estado_ref($ref);
  return { ok => 0, reason => 'not_found' }
    unless $e && $e->{estado} eq 'pendente';

  $self->_rows(
    'UPDATE clean.canal_inscricoes SET conflito = true WHERE id = ?',
    $e->{inscricao_id} + 0,
  );
  return { ok => 1, inscricao_id => $e->{inscricao_id} };
}

# ---------------------------------------------------------------------------
# bot público do Telegram (onda 2)
# ---------------------------------------------------------------------------

# `/start <ref>`: grava o chat que abriu a ref (aguardando o contato). Só ref
# pendente. Um chat aguarda UMA ref por vez: o vínculo do mesmo chat a outras
# refs pendentes é desfeito (a última aberta vale).
# Devolve { ok => 1, ref_id } ou { ok => 0, reason => 'not_found'|'confirmado' }.
sub vincular_chat_telegram ($self, $ref, $chat_id) {
  return { ok => 0, reason => 'not_found' }
    unless defined $chat_id && $chat_id =~ /^-?\d+\z/;
  my $e = $self->estado_ref($ref) or return { ok => 0, reason => 'not_found' };
  return { ok => 0, reason => 'confirmado' } unless $e->{estado} eq 'pendente';

  $self->schema->storage->txn_do(sub {
    $self->_rows(
      q{UPDATE clean.canal_confirmacao_refs
           SET telegram_chat_pendente = NULL
         WHERE telegram_chat_pendente = ?::bigint AND id <> ?},
      $chat_id, $e->{ref_id},
    );
    $self->_rows(
      q{UPDATE clean.canal_confirmacao_refs
           SET telegram_chat_pendente = ?::bigint WHERE id = ?},
      $chat_id, $e->{ref_id},
    );
  });
  return { ok => 1, ref_id => $e->{ref_id} };
}

# Ref pendente (não usada, não invalidada, não vencida, membro não
# confirmado) aguardando o contato deste chat. Devolve
# { ref_id, membro_id, inscricao_id, telefone_norm } ou undef.
sub ref_pendente_do_chat ($self, $chat_id) {
  return unless defined $chat_id && $chat_id =~ /^-?\d+\z/;
  my $r = $self->_row(
    q{SELECT r.id AS ref_id, r.membro_id, r.inscricao_id, i.telefone_norm
      FROM   clean.canal_confirmacao_refs r
      JOIN   clean.canal_lista_membros m ON m.id = r.membro_id
      JOIN   clean.canal_inscricoes i    ON i.id = r.inscricao_id
      WHERE  r.telegram_chat_pendente = ?::bigint
        AND  r.usada_em IS NULL AND r.invalidada_em IS NULL
        AND  r.expira_em > NOW() AND m.confirmado_em IS NULL
      ORDER  BY r.id DESC LIMIT 1},
    $chat_id,
  ) or return;
  $r->{$_} += 0 for qw(ref_id membro_id inscricao_id);
  return $r;
}

# Conflito pela inscrição (o bot não tem a ref em claro: acha a ref pelo chat).
sub registrar_conflito_inscricao ($self, $inscricao_id) {
  return { ok => 0, reason => 'not_found' }
    unless defined $inscricao_id && $inscricao_id =~ /^\d+\z/;
  $self->_rows(
    'UPDATE clean.canal_inscricoes SET conflito = true WHERE id = ?',
    $inscricao_id + 0,
  );
  return { ok => 1, inscricao_id => $inscricao_id + 0 };
}

# Offset do getUpdates (modo polling), por bot. 0 se nunca gravado.
sub telegram_offset ($self, $bot_username) {
  my $r = $self->_row(
    'SELECT update_offset FROM clean.canal_telegram_estado WHERE bot_username = ?',
    $bot_username,
  );
  return $r ? $r->{update_offset} + 0 : 0;
}

# Upsert do offset (= último update_id tratado + 1). Nunca retrocede.
sub salvar_telegram_offset ($self, $bot_username, $offset) {
  $self->_rows(
    q{INSERT INTO clean.canal_telegram_estado (bot_username, update_offset, updated_at)
      VALUES (?, ?, NOW())
      ON CONFLICT (bot_username) DO UPDATE
         SET update_offset = GREATEST(clean.canal_telegram_estado.update_offset,
                                      EXCLUDED.update_offset),
             updated_at    = NOW()},
    $bot_username, $offset + 0,
  );
  return $offset + 0;
}

# ---------------------------------------------------------------------------
# WhatsApp: limites de envio do código (onda 2)
# ---------------------------------------------------------------------------

# Máximo de envios do código por ref (total) e por telefone em 1h.
sub whatsapp_max_envios { return 3; }

# Conta mais um envio na ref.
sub contar_envio_whatsapp ($self, $ref_id) {
  $self->_rows(
    q{UPDATE clean.canal_confirmacao_refs
         SET envios_whatsapp = envios_whatsapp + 1 WHERE id = ?},
    $ref_id + 0,
  );
  return;
}

# Códigos de confirmação ENVIADOS (status sent) ao telefone na última hora.
sub envios_whatsapp_ultima_hora ($self, $endereco) {
  my $r = $self->_row(
    q{SELECT count(*)::int AS n
      FROM   clean.canal_mensagens
      WHERE  canal = 'whatsapp' AND operacao = 'confirmacao'
        AND  destinatario = ? AND status = 'sent'
        AND  created_at > NOW() - interval '1 hour'},
    $endereco,
  );
  return $r ? $r->{n} + 0 : 0;
}

# Validade (ISO 8601 UTC) de um pedido de código (clean.canal_confirmacoes).
sub expira_em_codigo ($self, $confirmacao_id) {
  my $r = $self->_row(
    sprintf(q{SELECT %s AS expira_em FROM clean.canal_confirmacoes WHERE id = ?},
            sprintf($ISO, 'expira_em')),
    $confirmacao_id + 0,
  );
  return $r ? $r->{expira_em} : undef;
}

1;
