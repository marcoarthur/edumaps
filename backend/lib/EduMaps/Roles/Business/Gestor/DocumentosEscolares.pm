package EduMaps::Roles::Business::Gestor::DocumentosEscolares;
use Mojo::Base -role, -signatures;
use Mojo::JSON ();
use utf8;

# Documentos e planos escolares: pasta de documentos pedagógicos da escola
# (PPP, projetos, planejamentos) com metáfora de sistema de arquivos
# (pastas/subpastas + documentos), tags livres e versionamento auditado.
#
# FASE 1 — sem ACL: o escopo é a escola do gestor logado (cod_inep em toda
# linha). Controle de acesso por papel de usuário é etapa futura.
#
# O arquivo físico é imutável e vive fora do banco (<upload_dir>/<cod_inep>/
# documentos/<uuid>.<ext>); o banco guarda a referência (caminho) por versão.
# Um documento é a identidade estável: re-upload com o MESMO nome na MESMA
# pasta gera NOVA versão (sobrescrita auditada) e mantém as anteriores.

requires qw(schema);

use constant MAX_TAGS     => 20;
use constant MAX_TAG_LEN  => 40;

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
# visão geral
# ---------------------------------------------------------------------------

sub doc_arvore ($self, $cod_inep) {
  return {
    pastas     => $self->_pastas($cod_inep),
    documentos => $self->_documentos($cod_inep),
    tags       => $self->_escola_tags($cod_inep),
  };
}

sub pasta_existe ($self, $cod_inep, $pasta_id) {
  return !!$self->_row(
    'SELECT 1 FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?',
    $pasta_id + 0, $cod_inep + 0,
  );
}

# ---------------------------------------------------------------------------
# pastas
# ---------------------------------------------------------------------------

sub criar_pasta ($self, $cod_inep, $gestor_id, $nome, $pasta_pai_id = undef) {
  my $row = $self->_row(
    'INSERT INTO clean.pastas_escolares (cod_inep, gestor_id, pasta_pai_id, nome)
     VALUES (?, ?, ?, ?) RETURNING id, nome, pasta_pai_id',
    $cod_inep + 0, $gestor_id + 0, $pasta_pai_id, $nome,
  );
  return 0 unless $row;

  $self->_auditar($cod_inep, $gestor_id, 'pasta', $row->{id} + 0, 'criado', {
    nome         => $nome,
    pasta_pai_id => $pasta_pai_id ? $pasta_pai_id + 0 : undef,
  });

  return {
    id           => $row->{id} + 0,
    nome         => $nome,
    pasta_pai_id => $pasta_pai_id ? $pasta_pai_id + 0 : undef,
  };
}

# Renomeia e/ou move uma pasta. Retorna a linha atualizada; {erro => 'ciclo'}
# se mover a pasta para si mesma ou para dentro de um descendente;
# {erro => 'pasta_nao_encontrada'} se a pasta de destino não pertence à escola.
sub atualizar_pasta ($self, $cod_inep, $gestor_id, $id, $input = {}) {
  my $old = $self->_row(
    'SELECT id, nome, pasta_pai_id FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return undef;

  my $novo_nome = $input->{nome};
  my $move      = exists $input->{pasta_pai_id};
  my $novo_pai  = undef;
  if ($move) {
    $novo_pai = ($input->{pasta_pai_id} // '') =~ /^\d+$/ ? $input->{pasta_pai_id} + 0 : undef;
    return { erro => 'pasta_nao_encontrada' }
      unless !defined $novo_pai || $self->pasta_existe($cod_inep, $novo_pai);
    return { erro => 'ciclo' } if $self->_pasta_em_cadeia($cod_inep, $novo_pai, $id);
  }

  $self->_txn(sub {
    if (defined $novo_nome && length $novo_nome) {
      $self->_rows(
        'UPDATE clean.pastas_escolares SET nome = ?, updated_at = NOW() WHERE id = ? AND cod_inep = ?',
        $novo_nome, $id + 0, $cod_inep + 0,
      );
      $self->_auditar($cod_inep, $gestor_id, 'pasta', $id + 0, 'renomeado', {
        de => $old->{nome}, para => $novo_nome,
      });
    }
    if ($move) {
      $self->_rows(
        'UPDATE clean.pastas_escolares SET pasta_pai_id = ?, updated_at = NOW() WHERE id = ? AND cod_inep = ?',
        $novo_pai, $id + 0, $cod_inep + 0,
      );
      $self->_auditar($cod_inep, $gestor_id, 'pasta', $id + 0, 'movido', {
        de   => $old->{pasta_pai_id} ? $old->{pasta_pai_id} + 0 : undef,
        para => $novo_pai          ? $novo_pai + 0          : undef,
      });
    }
  });

  return $self->_row(
    'SELECT id, nome, pasta_pai_id, updated_at FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

# Exclusão bloqueada se a pasta tiver conteúdo (filhas ou documentos).
sub excluir_pasta ($self, $cod_inep, $gestor_id, $id) {
  my $p = $self->_row(
    'SELECT id, nome FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return undef;

  my $total = $self->_row(
    'SELECT
       (SELECT count(*) FROM clean.pastas_escolares WHERE cod_inep = ? AND pasta_pai_id = ?) +
       (SELECT count(*) FROM clean.escola_documentos WHERE cod_inep = ? AND pasta_id = ?) AS n',
    $cod_inep + 0, $id + 0, $cod_inep + 0, $id + 0,
  );
  return { erro => 'pasta_nao_vazia' } if $total->{n} + 0 > 0;

  $self->_txn(sub {
    $self->_rows(
      'DELETE FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?',
      $id + 0, $cod_inep + 0,
    );
    $self->_auditar($cod_inep, $gestor_id, 'pasta', $id + 0, 'excluido', { nome => $p->{nome} });
  });

  return { nome => $p->{nome} };
}

# ---------------------------------------------------------------------------
# documentos (upload com versionamento)
# ---------------------------------------------------------------------------

# Grava um upload: cria o documento (v1) ou, se já existe um com o mesmo nome
# na mesma pasta, grava uma NOVA VERSÃO (sobrescrita auditada). O nome/nome_do
# arquivo enviado define o documento; conteúdo novo = versão nova.
sub subir_documento ($self, $cod_inep, $gestor_id, $info = {}) {
  my ($pasta_id, $nome) = ($info->{pasta_id}, $info->{nome});
  my $res;

  $self->_txn(sub {
    my $existente = $self->_row(
      'SELECT id FROM clean.escola_documentos
       WHERE cod_inep = ? AND COALESCE(pasta_id, 0) = ? AND nome = ?
       FOR UPDATE',
      $cod_inep + 0, $pasta_id || 0, $nome,
    );

    if ($existente) {
      my $doc_id = $existente->{id} + 0;
      my $ver = $self->_row(
        'SELECT COALESCE(MAX(versao), 0) + 1 AS v FROM clean.escola_documentos_versoes WHERE documento_id = ?',
        $doc_id,
      );
      my $versao = $ver->{v} + 0;
      $self->_rows(
        'INSERT INTO clean.escola_documentos_versoes
           (documento_id, versao, caminho, nome_original, mime, tamanho, sha1, gestor_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        $doc_id, $versao,
        $info->{caminho}, $info->{nome_original}, $info->{mime},
        $info->{tamanho} + 0, $info->{sha1}, $gestor_id + 0,
      );
      $self->_rows('UPDATE clean.escola_documentos SET updated_at = NOW() WHERE id = ?', $doc_id);
      $self->_auditar($cod_inep, $gestor_id, 'documento', $doc_id, 'sobrescrito', {
        versao => $versao, nome_original => $info->{nome_original},
        tamanho => $info->{tamanho} + 0, sha1 => $info->{sha1},
      });
      $res = { documento_id => $doc_id, versao => $versao, novo => 0, nome => $nome, pasta_id => $pasta_id };
    }
    else {
      my $novo = $self->_row(
        'INSERT INTO clean.escola_documentos (cod_inep, pasta_id, gestor_id, nome)
         VALUES (?, ?, ?, ?) RETURNING id',
        $cod_inep + 0, $pasta_id, $gestor_id + 0, $nome,
      );
      my $doc_id = $novo->{id} + 0;
      $self->_rows(
        'INSERT INTO clean.escola_documentos_versoes
           (documento_id, versao, caminho, nome_original, mime, tamanho, sha1, gestor_id)
         VALUES (?, 1, ?, ?, ?, ?, ?, ?)',
        $doc_id,
        $info->{caminho}, $info->{nome_original}, $info->{mime},
        $info->{tamanho} + 0, $info->{sha1}, $gestor_id + 0,
      );
      $self->_auditar($cod_inep, $gestor_id, 'documento', $doc_id, 'criado', {
        nome => $nome, versao => 1, tamanho => $info->{tamanho} + 0, sha1 => $info->{sha1},
      });
      $res = { documento_id => $doc_id, versao => 1, novo => 1, nome => $nome, pasta_id => $pasta_id };
    }
  });

  return $res;
}

# Renomeia e/ou move um documento (metáfora de sistema de arquivos).
sub atualizar_documento ($self, $cod_inep, $gestor_id, $id, $input = {}) {
  my $old = $self->_row(
    'SELECT id, nome, pasta_id FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return undef;

  my $novo_nome = $input->{nome};
  my $move      = exists $input->{pasta_id};
  my $novo_pai  = undef;
  if ($move) {
    $novo_pai = ($input->{pasta_id} // '') =~ /^\d+$/ ? $input->{pasta_id} + 0 : undef;
    return { erro => 'pasta_nao_encontrada' }
      unless !defined $novo_pai || $self->pasta_existe($cod_inep, $novo_pai);
  }

  $self->_txn(sub {
    if (defined $novo_nome && length $novo_nome) {
      $self->_rows(
        'UPDATE clean.escola_documentos SET nome = ?, updated_at = NOW() WHERE id = ? AND cod_inep = ?',
        $novo_nome, $id + 0, $cod_inep + 0,
      );
      $self->_auditar($cod_inep, $gestor_id, 'documento', $id + 0, 'renomeado', {
        de => $old->{nome}, para => $novo_nome,
      });
    }
    if ($move) {
      $self->_rows(
        'UPDATE clean.escola_documentos SET pasta_id = ?, updated_at = NOW() WHERE id = ? AND cod_inep = ?',
        $novo_pai, $id + 0, $cod_inep + 0,
      );
      $self->_auditar($cod_inep, $gestor_id, 'documento', $id + 0, 'movido', {
        de   => $old->{pasta_id} ? $old->{pasta_id} + 0 : undef,
        para => $novo_pai      ? $novo_pai + 0      : undef,
      });
    }
  });

  return $self->_row(
    'SELECT id, nome, pasta_id FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  );
}

# Substitui as tags do documento (livres, normalizadas) e audita o diff.
sub setar_tags ($self, $cod_inep, $gestor_id, $id, $tags) {
  my @tags = $self->normalize_tags($tags);

  my $doc = $self->_row(
    'SELECT id, nome FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return undef;

  my $atual = $self->_row(
    'SELECT array_to_json(tags) AS tags FROM clean.escola_documentos WHERE id = ?',
    $id + 0,
  );
  my @atuais = @{ $self->_decode_tags($atual->{tags}) };

  my %tem_atual = map { $_ => 1 } @atuais;
  my @added   = grep { !$tem_atual{$_} } @tags;
  my %tem_novo = map { $_ => 1 } @tags;
  my @removed = grep { !$tem_novo{$_} } @atuais;

  $self->_txn(sub {
    $self->_rows(
      'UPDATE clean.escola_documentos SET tags = ?::text[], updated_at = NOW() WHERE id = ? AND cod_inep = ?',
      $self->_pgarray(@tags), $id + 0, $cod_inep + 0,
    );
    if (@added || @removed) {
      $self->_auditar($cod_inep, $gestor_id, 'documento', $id + 0, 'tags', {
        adicionadas => \@added,
        removidas   => \@removed,
      });
    }
  });

  return \@tags;
}

sub excluir_documento ($self, $cod_inep, $gestor_id, $id) {
  my $doc = $self->_row(
    'SELECT id, nome FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
    $id + 0, $cod_inep + 0,
  ) or return undef;

  my $caminhos;
  $self->_txn(sub {
    $caminhos = $self->_rows(
      'SELECT caminho FROM clean.escola_documentos_versoes WHERE documento_id = ?',
      $id + 0,
    );
    $self->_rows(
      'DELETE FROM clean.escola_documentos WHERE id = ? AND cod_inep = ?',
      $id + 0, $cod_inep + 0,
    );
    $self->_auditar($cod_inep, $gestor_id, 'documento', $id + 0, 'excluido', { nome => $doc->{nome} });
  });

  return {
    nome     => $doc->{nome},
    caminhos => [ map { $_->{caminho} } @$caminhos ],
  };
}

# ---------------------------------------------------------------------------
# leituras: versões, download, auditoria
# ---------------------------------------------------------------------------

sub doc_versoes ($self, $cod_inep, $id) {
  my $rows = $self->_rows(
    'SELECT v.versao, v.nome_original, v.mime, v.tamanho, v.sha1, v.criado_em,
            g.nome AS gestor
     FROM   clean.escola_documentos_versoes v
     JOIN   clean.escola_documentos d ON d.id = v.documento_id
     LEFT JOIN clean.gestores g ON g.id = v.gestor_id
     WHERE  v.documento_id = ? AND d.cod_inep = ?
     ORDER  BY v.versao DESC',
    $id + 0, $cod_inep + 0,
  );
  my @out;
  for my $r (@$rows) {
    push @out, {
      versao        => $r->{versao} + 0,
      nome_original => $r->{nome_original},
      mime          => $r->{mime},
      tamanho       => $r->{tamanho} + 0,
      sha1          => $r->{sha1},
      criado_em     => $r->{criado_em},
      gestor        => $r->{gestor},
    };
  }
  return \@out;
}

sub doc_download_row ($self, $cod_inep, $id, $versao) {
  my ($where, @bind) = ('v.documento_id = ? AND d.cod_inep = ?', $id + 0, $cod_inep + 0);
  if (defined $versao && length $versao) {
    $where .= ' AND v.versao = ?';
    push @bind, $versao + 0;
  }
  my $r = $self->_row(
    "SELECT v.versao, v.caminho, v.nome_original, v.mime, v.tamanho
     FROM   clean.escola_documentos_versoes v
     JOIN   clean.escola_documentos d ON d.id = v.documento_id
     WHERE  $where
     ORDER  BY v.versao DESC LIMIT 1",
    @bind,
  ) or return undef;
  return {
    versao        => $r->{versao} + 0,
    caminho       => $r->{caminho},
    nome_original => $r->{nome_original},
    mime          => $r->{mime},
    tamanho       => $r->{tamanho} + 0,
  };
}

sub doc_auditoria ($self, $cod_inep, $id) {
  my $rows = $self->_rows(
    'SELECT a.id, a.entidade, a.entidade_id, a.acao, a.detalhes, a.criado_em, g.nome AS gestor
     FROM   clean.escola_documentos_auditoria a
     LEFT JOIN clean.gestores g ON g.id = a.gestor_id
     WHERE  a.cod_inep = ? AND a.entidade = ? AND a.entidade_id = ?
     ORDER  BY a.criado_em DESC, a.id DESC',
    $cod_inep + 0, 'documento', $id + 0,
  );
  return [ map { $self->_audit_row($_) } @$rows ];
}

# Feed de atividade da escola (histórico de todas as entidades, recente 1º).
sub auditoria_recente ($self, $cod_inep, $limite = 30) {
  my $rows = $self->_rows(
    "SELECT a.id, a.entidade, a.entidade_id, a.acao, a.detalhes, a.criado_em, g.nome AS gestor,
            COALESCE(p.nome, d.nome) AS nome
     FROM   clean.escola_documentos_auditoria a
     LEFT JOIN clean.gestores g ON g.id = a.gestor_id
     LEFT JOIN clean.pastas_escolares p
            ON a.entidade = 'pasta' AND p.id = a.entidade_id AND p.cod_inep = a.cod_inep
     LEFT JOIN clean.escola_documentos d
            ON a.entidade = 'documento' AND d.id = a.entidade_id AND d.cod_inep = a.cod_inep
     WHERE  a.cod_inep = ?
     ORDER  BY a.criado_em DESC, a.id DESC
     LIMIT  ?",
    $cod_inep + 0, $limite + 0,
  );
  my @out;
  for my $r (@$rows) {
    push @out, $self->_audit_row($r);
  }
  return \@out;
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _pastas ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT id, pasta_pai_id, gestor_id, nome, created_at, updated_at
     FROM   clean.pastas_escolares
     WHERE  cod_inep = ?
     ORDER  BY nome',
    $cod_inep + 0,
  );
  my @out;
  for my $r (@$rows) {
    push @out, {
      id           => $r->{id} + 0,
      pasta_pai_id => $r->{pasta_pai_id} ? $r->{pasta_pai_id} + 0 : undef,
      gestor_id    => $r->{gestor_id} ? $r->{gestor_id} + 0 : undef,
      nome         => $r->{nome},
      created_at   => $r->{created_at},
      updated_at   => $r->{updated_at},
    };
  }
  return \@out;
}

sub _documentos ($self, $cod_inep) {
  my $rows = $self->_rows(
    "SELECT d.id, d.pasta_id, d.gestor_id, d.nome, array_to_json(d.tags) AS tags,
            d.created_at, d.updated_at,
            v.versao AS versao_atual, v.tamanho, v.mime, v.atualizado_por
     FROM   clean.escola_documentos d
     LEFT JOIN LATERAL (
       SELECT v.versao, v.tamanho, v.mime, g.nome AS atualizado_por
       FROM   clean.escola_documentos_versoes v
       LEFT JOIN clean.gestores g ON g.id = v.gestor_id
       WHERE  v.documento_id = d.id
       ORDER  BY v.versao DESC LIMIT 1
     ) v ON true
     WHERE  d.cod_inep = ?
     ORDER  BY d.nome",
    $cod_inep + 0,
  );
  my @out;
  for my $r (@$rows) {
    push @out, {
      id            => $r->{id} + 0,
      pasta_id      => $r->{pasta_id} ? $r->{pasta_id} + 0 : undef,
      gestor_id     => $r->{gestor_id} ? $r->{gestor_id} + 0 : undef,
      nome          => $r->{nome},
      tags          => $self->_decode_tags($r->{tags}),
      criado_em     => $r->{created_at},
      atualizado_em => $r->{updated_at},
      versao_atual  => $r->{versao_atual} ? $r->{versao_atual} + 0 : undef,
      tamanho       => $r->{tamanho} ? $r->{tamanho} + 0 : 0,
      mime          => $r->{mime},
      atualizado_por => $r->{atualizado_por},
    };
  }
  return \@out;
}

sub _escola_tags ($self, $cod_inep) {
  my $rows = $self->_rows(
    'SELECT DISTINCT unnest(tags) AS tag FROM clean.escola_documentos
     WHERE cod_inep = ? ORDER BY tag',
    $cod_inep + 0,
  );
  return [ map { $_->{tag} } @$rows ];
}

# Verdadeiro se a cadeia de pais de $pasta_id alcança $id (mover para si ou
# para um descendente criaria um ciclo).
sub _pasta_em_cadeia ($self, $cod_inep, $pasta_id, $id) {
  return 0 unless defined $pasta_id;
  return !!$self->_row(
    'WITH RECURSIVE asc_chain AS (
       SELECT id, pasta_pai_id FROM clean.pastas_escolares WHERE id = ? AND cod_inep = ?
       UNION ALL
       SELECT p.id, p.pasta_pai_id FROM clean.pastas_escolares p
       JOIN asc_chain a ON p.id = a.pasta_pai_id
     ) SELECT 1 FROM asc_chain WHERE id = ?',
    $pasta_id + 0, $cod_inep + 0, $id + 0,
  );
}

sub normalize_tags ($self, $tags) {
  my %seen;
  my @out;
  for my $t (ref $tags eq 'ARRAY' ? @$tags : ($tags)) {
    next unless defined $t;
    $t =~ s/^\s+|\s+$//g;
    next if !length $t || $seen{$t}++;
    next if length($t) > MAX_TAG_LEN;
    push @out, $t;
  }
  @out = @out[0 .. (MAX_TAGS - 1)] if @out > MAX_TAGS;
  return @out;
}

sub _pgarray ($self, @items) {
  return '{}' unless @items;
  return '{' . join(',', map { qq{"$_"} } @items) . '}';
}

sub _decode_tags ($self, $json) {
  return [] unless defined $json && length $json;
  my $arr = eval { Mojo::JSON::decode_json($json) };
  return ref $arr eq 'ARRAY' ? $arr : [];
}

sub _decode_json ($self, $json) {
  return {} unless defined $json && length $json;
  my $h = eval { Mojo::JSON::decode_json($json) };
  return ref $h eq 'HASH' ? $h : {};
}

sub _audit_row ($self, $r) {
  return {
    id         => $r->{id} + 0,
    entidade   => $r->{entidade},
    entidade_id => $r->{entidade_id} + 0,
    acao       => $r->{acao},
    nome       => $r->{nome},
    detalhes   => $self->_decode_json($r->{detalhes}),
    criado_em  => $r->{criado_em},
    gestor     => $r->{gestor},
  };
}

sub _auditar ($self, $cod_inep, $gestor_id, $entidade, $entidade_id, $acao, $detalhes) {
  $self->_rows(
    'INSERT INTO clean.escola_documentos_auditoria
       (cod_inep, gestor_id, entidade, entidade_id, acao, detalhes)
     VALUES (?, ?, ?, ?, ?, ?::jsonb)',
    $cod_inep + 0, $gestor_id + 0, $entidade, $entidade_id + 0, $acao,
    Mojo::JSON::encode_json($detalhes),
  );
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