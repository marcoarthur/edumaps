package EduMaps::Roles::Business::Gestor::Reunioes;
use Mojo::Base -role, -signatures;
use utf8;

# Reuniões e atas do gestor: agenda de contatos (PII — só o gestor logado da
# escola acessa), grupos organizados por drag-and-drop e reuniões agendadas
# pelo wizard (quando/quem/aviso/onde/pauta) com atas e anexos.
#
# Não recria as ferramentas profissionais de reunião (vídeo/ata ao vivo): o
# EduMaps guarda o agendamento e o método de aviso; o convite copiável
# (wa.me / e-mail) é gerado no frontend. O arquivo físico anexado fica no
# upload_dir (config), fora do banco — aqui só o registro.

requires qw(schema);

our %EXT_MIME = (
  pdf  => 'application/pdf',
  docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  png  => 'image/png',
  jpg  => 'image/jpeg',
  jpeg => 'image/jpeg',
  txt  => 'text/plain',
);

sub max_upload_bytes { return 10 * 1024 * 1024; }

sub ext_mime { return \%EXT_MIME; }

# ---------------------------------------------------------------------------
# contatos
# ---------------------------------------------------------------------------

sub list_contatos ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT c.id, c.nome, c.email, c.telefone, c.cargo,
            c.grupo_id, g.nome AS grupo_nome, c.updated_at
     FROM   clean.contatos c
     LEFT JOIN clean.contato_grupos g ON g.id = c.grupo_id
     WHERE  c.cod_inep = ?
     ORDER  BY c.nome',
    $cod_inep + 0,
  );

  my @out;
  for my $r (@$rows) {
    push @out, {
      id         => $r->{id} + 0,
      nome       => $r->{nome},
      email      => $r->{email},
      telefone   => $r->{telefone},
      cargo      => $r->{cargo},
      grupo_id   => $r->{grupo_id} ? $r->{grupo_id} + 0 : undef,
      grupo_nome => $r->{grupo_nome},
      updated_at => $r->{updated_at},
    };
  }
  return \@out;
}

sub create_contato ($self, $cod_inep, $gestor_id, $params = {}) {
  my $row = $self->_row(
    'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email, telefone, cargo, grupo_id)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     RETURNING id',
    $cod_inep + 0,
    $gestor_id + 0,
    $params->{nome},
    $params->{email}    // undef,
    $params->{telefone} // undef,
    $params->{cargo}    // undef,
    $params->{grupo_id} ? $params->{grupo_id} + 0 : undef,
  );
  return $row ? $self->_contato_detail($cod_inep, $row->{id}) : undef;
}

sub update_contato ($self, $id, $cod_inep, $params = {}) {
  my $row = $self->_row(
    'UPDATE clean.contatos
     SET    nome = ?, email = ?, telefone = ?, cargo = ?, grupo_id = ?, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $params->{nome},
    $params->{email}    // undef,
    $params->{telefone} // undef,
    $params->{cargo}    // undef,
    $params->{grupo_id} ? $params->{grupo_id} + 0 : undef,
    $id + 0,
    $cod_inep + 0,
  );
  return $row ? $self->_contato_detail($cod_inep, $row->{id}) : undef;
}

sub delete_contato ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.contatos WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

# Import em lote (colagem de texto no frontend): lista já normalizada,
# grupos inexistentes são criados no caminho — tudo numa transação.
sub import_contatos ($self, $cod_inep, $gestor_id, $contatos) {
  my ($n_inseridos, $n_pulados) = (0, 0);
  $self->schema->storage->txn_do(sub {
    for my $c (@$contatos) {
      my $grupo_id;
      if (my $g = $c->{grupo}) {
        my $grupo = $self->_row(
          'INSERT INTO clean.contato_grupos (cod_inep, gestor_id, nome)
           VALUES (?, ?, ?)
           ON CONFLICT (cod_inep, nome) DO UPDATE SET nome = EXCLUDED.nome
           RETURNING id',
          $cod_inep + 0, $gestor_id + 0, $g,
        );
        $grupo_id = $grupo->{id};
      }

      my $row = $self->_row(
        'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email, telefone, cargo, grupo_id)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT (cod_inep, lower(email)) WHERE email IS NOT NULL DO NOTHING
         RETURNING id',
        $cod_inep + 0,
        $gestor_id + 0,
        $c->{nome},
        $c->{email}    // undef,
        $c->{telefone} // undef,
        $c->{cargo}    // undef,
        $grupo_id,
      );
      $row ? $n_inseridos++ : $n_pulados++;
    }
  });

  return { n_inseridos => $n_inseridos, n_pulados => $n_pulados };
}

sub _contato_detail ($self, $cod_inep, $id) {
  my $r = $self->_row(
    'SELECT c.id, c.nome, c.email, c.telefone, c.cargo,
            c.grupo_id, g.nome AS grupo_nome, c.created_at, c.updated_at
     FROM   clean.contatos c
     LEFT JOIN clean.contato_grupos g ON g.id = c.grupo_id
     WHERE  c.id = ? AND c.cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return;
  return {
    id         => $r->{id} + 0,
    nome       => $r->{nome},
    email      => $r->{email},
    telefone   => $r->{telefone},
    cargo      => $r->{cargo},
    grupo_id   => $r->{grupo_id} ? $r->{grupo_id} + 0 : undef,
    grupo_nome => $r->{grupo_nome},
    created_at => $r->{created_at},
    updated_at => $r->{updated_at},
  };
}

# ---------------------------------------------------------------------------
# grupos (organizados por drag-and-drop no painel)
# ---------------------------------------------------------------------------

sub list_grupos ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT g.id, g.nome, g.origem,
            (SELECT COUNT(*) FROM clean.contatos c WHERE c.grupo_id = g.id) AS n_contatos
     FROM   clean.contato_grupos g
     WHERE  g.cod_inep = ?
     ORDER  BY (g.origem = \'folha\') DESC, g.nome',
    $cod_inep + 0,
  );

  my @out;
  for my $r (@$rows) {
    push @out, {
      id         => $r->{id} + 0,
      nome       => $r->{nome},
      origem     => $r->{origem} // 'manual',
      n_contatos => $r->{n_contatos} + 0,
    };
  }
  return \@out;
}

sub create_grupo ($self, $cod_inep, $gestor_id, $nome) {
  my $row = $self->_row(
    'INSERT INTO clean.contato_grupos (cod_inep, gestor_id, nome, origem)
     VALUES (?, ?, ?, \'manual\')
     RETURNING id',
    $cod_inep + 0, $gestor_id + 0, $nome,
  ) or return;
  return { id => $row->{id} + 0, nome => $nome, origem => 'manual', n_contatos => 0 };
}

# ---------------------------------------------------------------------------
# grupos pré-listados pela folha de pagamento (remuneracao_municipal)
# ---------------------------------------------------------------------------

# Regra padrão categoria/tipo -> grupo. Ajustável em um único lugar; os grupos
# são criados uma única vez por escola (UNIQUE cod_inep, nome), então múltiplas
# rodadas do backfill são idempotentes.
sub _grupo_para_categoria ($self, $tipo, $categoria) {
  my $t = lc($tipo // '');
  my $c = lc($categoria // '');

  # Professores: todo o magistério (docentes, coord e apoio pedagógico).
  return 'Professores'
    if $t =~ /magist|docente|professor/
    || $c =~ /docente|magist|docencia|professor/;

  # Administrativos: funções de secretaria, alimentação, multimeios e
  # manutenção/infraestrutura da escola.
  return 'Administrativos'
    if $c =~ /secretaria|alimenta|multimeios|manuten|infraestrutura/;

  # Demais categorias profissionais (psicologia, serviço social, auxiliares...).
  return 'Outros';
}

# Grupos 'folha' que a escola deveria ter, pelas categorias presentes na folha.
sub _grupos_folha_para_escola ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT DISTINCT tipo, categoria
     FROM   clean.remuneracao_municipal
     WHERE  cod_inep = ?',
    $cod_inep + 0,
  );
  my %nomes;
  for my $r (@$rows) {
    $nomes{ $self->_grupo_para_categoria($r->{tipo}, $r->{categoria}) } = 1;
  }
  # Ordem canônica: Professores, Administrativos, Outros.
  return grep { $nomes{$_} } qw(Professores Administrativos Outros);
}

# Assegura os grupos pré-listados da folha para a escola (idempotente).
# Retorna os nomes criados agora; [] se nada a fazer.
sub sincronizar_grupos_folha ($self, $cod_inep) {
  my $ja_tem = $self->_row(
    'SELECT 1 FROM clean.contato_grupos
     WHERE  cod_inep = ? AND origem = \'folha\'
     LIMIT  1',
    $cod_inep + 0,
  );
  return [] if $ja_tem;

  my @nomes = $self->_grupos_folha_para_escola($cod_inep);
  return [] unless @nomes;

  $self->_txn(sub {
    for my $nome (@nomes) {
      $self->_row(
        'INSERT INTO clean.contato_grupos (cod_inep, gestor_id, nome, origem)
         VALUES (?, NULL, ?, \'folha\')
         ON CONFLICT (cod_inep, nome) DO NOTHING',
        $cod_inep + 0, $nome,
      );
    }
  });

  return \@nomes;
}

sub update_grupo ($self, $id, $cod_inep, $nome) {
  my $row = $self->_row(
    'UPDATE clean.contato_grupos SET nome = ?
     WHERE  id = ? AND cod_inep = ?
     RETURNING id',
    $nome, $id + 0, $cod_inep + 0,
  );
  return $row ? { id => $row->{id} + 0, nome => $nome } : undef;
}

# Apagar um grupo não remove os contatos (FK SET NULL).
sub delete_grupo ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.contato_grupos WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

# ---------------------------------------------------------------------------
# gestor responsável pela agenda da escola
# ---------------------------------------------------------------------------

# Gestores da escola + quem é o responsável pela agenda (criador da 1ª reunião).
sub perfil_escola ($self, $cod_inep) {
  my $gestores = $self->_rows(
    'SELECT id, nome, email, cargo
     FROM   clean.gestores
     WHERE  cod_inep = ?
     ORDER  BY id',
    $cod_inep + 0,
  );

  my @out;
  for my $g (@$gestores) {
    push @out, {
      id    => $g->{id} + 0,
      nome  => $g->{nome},
      email => $g->{email},
      cargo => $g->{cargo},
    };
  }

  my $resp = $self->_row(
    'SELECT g.id, g.nome, g.email, g.cargo
     FROM   clean.gestores g
     WHERE  g.id = (
       SELECT gestor_id FROM clean.reunioes WHERE cod_inep = ? ORDER BY id LIMIT 1
     )',
    $cod_inep + 0,
  );

  return {
    gestores    => \@out,
    responsavel => $resp
      ? { id => $resp->{id} + 0, nome => $resp->{nome}, email => $resp->{email}, cargo => $resp->{cargo} }
      : undef,
  };
}

# Transfere o vínculo da agenda (reuniões, contatos e grupos manuais) para
# outro gestor da MESMA escola. Só o responsável pela agenda transfere; sem
# reuniões ainda, qualquer gestor da escola pode. Grupos da folha ficam sem
# dono (gestor_id NULL). Retorna {error => $codigo} em falhas.
sub transferir_agenda ($self, $cod_inep, $atual_gestor_id, $novo_gestor_id) {
  return { error => 'novo_gestor' } unless $self->_row(
    'SELECT 1 FROM clean.gestores WHERE id = ? AND cod_inep = ?',
    $novo_gestor_id + 0, $cod_inep + 0,
  );

  my $resp = $self->_row(
    'SELECT gestor_id FROM clean.reunioes WHERE cod_inep = ? ORDER BY id LIMIT 1',
    $cod_inep + 0,
  );
  if ($resp && ($resp->{gestor_id} || 0) != ($atual_gestor_id || 0)) {
    return { error => 'nao_responsavel' };
  }

  $self->_txn(sub {
    $self->_rows(
      'UPDATE clean.reunioes SET gestor_id = ? WHERE cod_inep = ?',
      $novo_gestor_id + 0, $cod_inep + 0,
    );
    $self->_rows(
      'UPDATE clean.contatos SET gestor_id = ? WHERE cod_inep = ?',
      $novo_gestor_id + 0, $cod_inep + 0,
    );
    $self->_rows(
      'UPDATE clean.contato_grupos SET gestor_id = ? WHERE cod_inep = ? AND gestor_id IS NOT NULL',
      $novo_gestor_id + 0, $cod_inep + 0,
    );
  });

  return { ok => 1, gestor_id => $novo_gestor_id + 0 };
}

# ---------------------------------------------------------------------------
# reuniões
# ---------------------------------------------------------------------------

sub agendar_reuniao ($self, $params = {}) {
  my $cod_inep  = $params->{cod_inep};
  my $gestor_id = $params->{gestor_id};

  my $reuniao_id;
  $self->_txn(sub {
    my $row = $self->_row(
      'INSERT INTO clean.reunioes
         (cod_inep, gestor_id, titulo, quando, duracao_min,
          onde_label, onde_link, aviso_metodo, pauta_texto)
       VALUES (?, ?, ?, ?::timestamptz, ?, ?, ?, ?, ?)
       RETURNING id',
      $cod_inep + 0,
      $gestor_id + 0,
      $params->{titulo},
      $params->{quando},
      ($params->{duracao_min} // 60) + 0,
      $params->{onde_label}  // undef,
      $params->{onde_link}   // undef,
      $params->{aviso_metodo} // 'todos',
      $params->{pauta_texto} // undef,
    ) or return;
    $reuniao_id = $row->{id};
    $self->_add_participantes($reuniao_id, $cod_inep,
      $params->{contato_ids} // [], $params->{grupo_ids} // []);
  }) or return;

  return $self->detalhe_reuniao($reuniao_id, $cod_inep);
}

sub update_reuniao ($self, $id, $cod_inep, $params = {}) {
  my $found;
  $self->_txn(sub {
    my $row = $self->_row(
      'UPDATE clean.reunioes
       SET    titulo = ?, quando = ?::timestamptz, duracao_min = ?,
              onde_label = ?, onde_link = ?, aviso_metodo = ?, pauta_texto = ?,
              updated_at = NOW()
       WHERE  id = ? AND cod_inep = ? AND status = \'agendada\'
       RETURNING id',
      $params->{titulo},
      $params->{quando},
      ($params->{duracao_min} // 60) + 0,
      $params->{onde_label}  // undef,
      $params->{onde_link}   // undef,
      $params->{aviso_metodo} // 'todos',
      $params->{pauta_texto} // undef,
      $id + 0,
      $cod_inep + 0,
    ) or return;
    $found = $row;
    $self->_rows(
      'DELETE FROM clean.reunioes_participantes WHERE reuniao_id = ?',
      $id + 0,
    );
    $self->_add_participantes($id + 0, $cod_inep,
      $params->{contato_ids} // [], $params->{grupo_ids} // []);
  }) or return;

  return $found ? $self->detalhe_reuniao($id + 0, $cod_inep) : undef;
}

sub list_reunioes ($self, $cod_inep, $filtros = {}) {
  my @where = ('r.cod_inep = ?');
  my @binds = ($cod_inep + 0);

  if (my $q = $filtros->{q}) {
    $q =~ s/%/\\%/g;
    push @where, 'r.titulo ILIKE ? ESCAPE \'\\\'';
    push @binds, '%' . $q . '%';
  }
  if (my $status = $filtros->{status}) {
    push @where, 'r.status = ?';
    push @binds, $status;
  }
  if (my $de = $filtros->{de}) {
    push @where, 'r.quando >= ?::timestamptz';
    push @binds, $de;
  }
  if (my $ate = $filtros->{ate}) {
    push @where, 'r.quando < (?::timestamptz + interval \'1 day\')';
    push @binds, $ate;
  }

  my $sql = 'SELECT r.id, r.titulo, r.quando, r.duracao_min, r.aviso_metodo, r.status,
                    r.pauta_texto,
                    (SELECT COUNT(*) FROM clean.reunioes_participantes p
                      WHERE p.reuniao_id = r.id) AS n_participantes,
                    (SELECT COUNT(*) FROM clean.reuniao_anexos a
                      WHERE a.reuniao_id = r.id AND a.tipo = \'ata\') AS tem_ata
             FROM   clean.reunioes r
             WHERE  ' . join(' AND ', @where) . '
             ORDER  BY r.quando DESC
             LIMIT  200';

  my $rows = $self->_rows($sql, @binds);
  my @out;
  for my $r (@$rows) {
    push @out, {
      id              => $r->{id} + 0,
      titulo          => $r->{titulo},
      quando          => $r->{quando},
      duracao_min     => $r->{duracao_min} + 0,
      aviso_metodo    => $r->{aviso_metodo},
      status          => $r->{status},
      n_participantes => $r->{n_participantes} + 0,
      tem_ata         => $r->{tem_ata} ? 1 : 0,
    };
  }
  return \@out;
}

sub detalhe_reuniao ($self, $id, $cod_inep) {
  my $r = $self->_row(
    'SELECT r.id, r.cod_inep, r.gestor_id, r.titulo, r.quando, r.duracao_min,
            r.onde_label, r.onde_link, r.aviso_metodo, r.status,
            r.pauta_texto, r.ata_texto, r.created_at, r.updated_at,
            g.nome AS gestor_nome
     FROM   clean.reunioes r
     JOIN   clean.gestores g ON g.id = r.gestor_id
     WHERE  r.id = ? AND r.cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return;

  $r->{id}          += 0;
  $r->{cod_inep}    += 0;
  $r->{gestor_id}   += 0;
  $r->{duracao_min} += 0;
  $r->{participantes} = $self->_participantes($id + 0);
  $r->{anexos}        = $self->_anexos($id + 0);
  $r->{gestor} = { nome => delete $r->{gestor_nome} };
  return $r;
}

sub salvar_ata ($self, $id, $cod_inep, $ata_texto) {
  my $row = $self->_row(
    'UPDATE clean.reunioes
     SET    ata_texto = ?, updated_at = NOW()
     WHERE  id = ? AND cod_inep = ? AND status IN (\'agendada\', \'realizada\')
     RETURNING id',
    $ata_texto, $id + 0, $cod_inep + 0,
  );
  return $row ? $self->detalhe_reuniao($id + 0, $cod_inep) : undef;
}

sub marcar_realizada ($self, $id, $cod_inep) {
  my $row = $self->_row(
    'UPDATE clean.reunioes
     SET    status = \'realizada\', updated_at = NOW()
     WHERE  id = ? AND cod_inep = ? AND status = \'agendada\'
     RETURNING id',
    $id + 0, $cod_inep + 0,
  );
  return $row ? $self->detalhe_reuniao($id + 0, $cod_inep) : undef;
}

sub cancelar_reuniao ($self, $id, $cod_inep) {
  my $row = $self->_row(
    'UPDATE clean.reunioes
     SET    status = \'cancelada\', updated_at = NOW()
     WHERE  id = ? AND cod_inep = ? AND status = \'agendada\'
     RETURNING id',
    $id + 0, $cod_inep + 0,
  );
  return $row ? $self->detalhe_reuniao($id + 0, $cod_inep) : undef;
}

# Reunião realizada (com ata) não pode ser apagada — protege o registro.
sub excluir_reuniao ($self, $id, $cod_inep) {
  return $self->_row(
    'DELETE FROM clean.reunioes
     WHERE  id = ? AND cod_inep = ? AND status IN (\'agendada\', \'cancelada\')
     RETURNING id',
    $id + 0, $cod_inep + 0,
  ) ? 1 : undef;
}

sub reuniao_state ($self, $id, $cod_inep) {
  return $self->_row(
    'SELECT id, cod_inep, status FROM clean.reunioes WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# anexos (pauta/ata) — só o registro; o arquivo físico fica no upload_dir
# ---------------------------------------------------------------------------

sub registrar_anexo ($self, $reuniao_id, $cod_inep, $tipo, $info = {}) {
  return unless $self->_row(
    'SELECT 1 FROM clean.reunioes WHERE id = ? AND cod_inep = ?',
    $reuniao_id + 0, $cod_inep + 0,
  );

  my $row;
  $self->_txn(sub {
    $self->_rows(
      'DELETE FROM clean.reuniao_anexos WHERE reuniao_id = ? AND tipo = ?',
      $reuniao_id + 0, $tipo,
    );
    $row = $self->_row(
      'INSERT INTO clean.reuniao_anexos
         (reuniao_id, tipo, nome_original, caminho, mime, tamanho)
       VALUES (?, ?, ?, ?, ?, ?)
       RETURNING id',
      $reuniao_id + 0,
      $tipo,
      $info->{nome_original},
      $info->{caminho},
      $info->{mime},
      $info->{tamanho} + 0,
    );
  }) or return;

  return $self->detalhe_reuniao($reuniao_id + 0, $cod_inep);
}

sub anexo_row ($self, $reuniao_id, $cod_inep, $tipo) {
  return $self->_row(
    'SELECT a.tipo, a.nome_original, a.caminho, a.mime, a.tamanho, r.cod_inep
     FROM   clean.reuniao_anexos a
     JOIN   clean.reunioes r ON r.id = a.reuniao_id
     WHERE  a.reuniao_id = ? AND a.tipo = ? AND r.cod_inep = ?',
    $reuniao_id + 0, $tipo, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _add_participantes ($self, $reuniao_id, $cod_inep, $contato_ids, $grupo_ids) {
  my @cids = grep { /^\d+$/ } @$contato_ids;
  if (@cids) {
    my $ph = join ', ', ('?') x @cids;
    $self->_rows(
      "INSERT INTO clean.reunioes_participantes (reuniao_id, contato_id)
       SELECT ?, c.id
       FROM   clean.contatos c
       WHERE  c.id IN ($ph) AND c.cod_inep = ?
       ON CONFLICT DO NOTHING",
      $reuniao_id + 0, @cids, $cod_inep + 0,
    );
  }

  my @gids = grep { /^\d+$/ } @$grupo_ids;
  if (@gids) {
    my $ph = join ', ', ('?') x @gids;
    $self->_rows(
      "INSERT INTO clean.reunioes_participantes (reuniao_id, contato_id, via_grupo_id)
       SELECT ?, c.id, g.id
       FROM   clean.contatos c
       JOIN   clean.contato_grupos g ON g.id = c.grupo_id
       WHERE  g.id IN ($ph) AND g.cod_inep = ?
       ON CONFLICT DO NOTHING",
      $reuniao_id + 0, @gids, $cod_inep + 0,
    );
  }
}

sub _participantes ($self, $reuniao_id) {
  my $rows = $self->_rows(
    'SELECT c.id, c.nome, c.email, c.telefone, c.cargo,
            p.via_grupo_id, g.nome AS grupo_nome
     FROM   clean.reunioes_participantes p
     JOIN   clean.contatos c ON c.id = p.contato_id
     LEFT JOIN clean.contato_grupos g ON g.id = p.via_grupo_id
     WHERE  p.reuniao_id = ?
     ORDER  BY c.nome',
    $reuniao_id + 0,
  );

  my @out;
  for my $r (@$rows) {
    push @out, {
      id         => $r->{id} + 0,
      nome       => $r->{nome},
      email      => $r->{email},
      telefone   => $r->{telefone},
      cargo      => $r->{cargo},
      via_grupo_id => $r->{via_grupo_id} ? $r->{via_grupo_id} + 0 : undef,
      via_grupo_nome => $r->{grupo_nome},
    };
  }
  return \@out;
}

sub _anexos ($self, $reuniao_id) {
  my $rows = $self->_rows(
    'SELECT id, tipo, nome_original, mime, tamanho, criado_em
     FROM   clean.reuniao_anexos
     WHERE  reuniao_id = ?
     ORDER  BY tipo',
    $reuniao_id + 0,
  );

  my @out;
  for my $r (@$rows) {
    push @out, {
      id            => $r->{id} + 0,
      tipo          => $r->{tipo},
      nome_original => $r->{nome_original},
      mime          => $r->{mime},
      tamanho       => $r->{tamanho} + 0,
      criado_em     => $r->{criado_em},
    };
  }
  return \@out;
}

sub _txn ($self, $code) {
  my $ok = eval { $self->schema->storage->txn_do(sub { $code->() }); 1 };
  return 1 if $ok;
  die $@ || 'Erro de transação';
}

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;