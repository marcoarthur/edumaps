package EduMaps::Ingestion::DatasetsLock;
use Mojo::Base -base, -signatures;

use Digest::SHA qw(sha256_hex);
use JSON::PP ();

# ============================================================================
# Manifesto de hashes dos datasets do pipeline (#135).
#
# O #135 pedia versionamento de datasets (título: DVC). A decisão (2026-10-15)
# foi o caminho MÍNIMO: um lockfile de hashes versionado no git, sem dependência
# nova. Justifica-se porque a peça difícil já existe desde o #231 — o job de
# ingestão grava, por tabela, o sha256 e os bytes de cada arquivo bruto em
# `clean.import_metadata.raw_manifest`.
#
# Este módulo transforma `clean.import_metadata` num pin determinístico:
#
#   { version, dataset_version, tables: [ { table_name, source_url,
#     source_license, row_count_loaded, raw: [ {url, sha256, bytes} ] } ] }
#
# `dataset_version` = sha256 do JSON canônico de {version, tables} — a "chave de
# conteúdo" do conjunto de dados. Responde "de qual versão dos dados veio este
# número?" comparando o lockfile versionado com a base.
#
# Campos fora do lock, de propósito:
#   - caminho/baixado_em/reaproveitado — variam a cada execução (o caminho tem a
#     data do download); não identificam o conteúdo, só sujariam o diff.
#   - retrieved_at / import_timestamp — idem; a proveniência completa fica na
#     base (retrieved_at + source_url + sha256 respondem juntos, #135 entregável 4).
# ============================================================================

our $LOCK_VERSION = 1;

# Ordem canônica e chave de conteúdo -------------------------------------------------

# JSON canônico (chaves ordenadas) em BYTES UTF-8 — base da chave de conteúdo
# e dos diffs. Precisa ser bytes (não caracteres) porque Digest::SHA recusa
# strings com caracteres largos ("Wide character in subroutine entry").
# JSON::PP (não Mojo) porque o encode_json do Mojo não ordena chaves; a forma
# canônica precisa ser estável entre execuções/máquinas (mesma escolha de
# EduMaps::Analytics::Client e Controller::Base).
sub canonical_json ($self, $data) {
  return JSON::PP->new->canonical->utf8->allow_nonref->encode($data);
}

# JSON legível (para o arquivo versionado; o diff fica revisável).
sub pretty_json ($self, $data) {
  return JSON::PP->new->canonical->pretty->allow_nonref->encode($data);
}

# ---------------------------------------------------------------------------
# build_lock(\@rows) -> hashref { version, tables }
#
# $rows vêm de clean.import_metadata (Slice => {}). Cada linha:
#   table_name, source_url, source_license, row_count_loaded, raw_manifest
# `raw_manifest` é arrayref (já decodificado) de { url, sha256, bytes, ... }.
# Função PURA (sem DB) — o núcleo testável.
# ---------------------------------------------------------------------------
sub build_lock ($self, $rows) {
  my @tabelas;

  for my $r (sort { ($a->{table_name} // '') cmp ($b->{table_name} // '') } @$rows) {
    my @raw =
      sort { ($a->{url} // '') cmp ($b->{url} // '')
             or ($a->{sha256} // '') cmp ($b->{sha256} // '') }
      map  {
        {
          url    => $_->{url}    // '',
          sha256 => $_->{sha256} // '',
          bytes  => defined $_->{bytes} ? $_->{bytes} + 0 : 0,
        }
      }
      grep { defined $_ && defined $_->{sha256} }
      @{ $r->{raw_manifest} // [] };

    push @tabelas, {
      table_name       => $r->{table_name},
      source_url       => $r->{source_url},
      source_license   => $r->{source_license},
      row_count_loaded => defined $r->{row_count_loaded} ? $r->{row_count_loaded} + 0 : undef,
      raw              => \@raw,
    };
  }

  return { version => $LOCK_VERSION, tables => \@tabelas };
}

# Chave de conteúdo do conjunto (exclui, claro, o próprio campo).
sub dataset_version ($self, $lock) {
  my $payload = { version => $lock->{version}, tables => $lock->{tables} };
  return sha256_hex($self->canonical_json($payload));
}

# Monta o documento final versionado (com a chave de conteúdo embutida).
sub document ($self, $lock) {
  return {
    version         => $lock->{version},
    dataset_version => $self->dataset_version($lock),
    tables          => $lock->{tables},
  };
}

# ---------------------------------------------------------------------------
# from_db($dbh) -> hashref { version, tables } (mesmo shape de build_lock)
# ---------------------------------------------------------------------------
sub from_db ($self, $dbh) {
  my $rows = $dbh->selectall_arrayref(
    q{SELECT table_name, source_url, source_license, row_count_loaded, raw_manifest
        FROM clean.import_metadata
       ORDER BY table_name},
    { Slice => {} },
  );

  for my $r (@$rows) {
    my $m = $r->{raw_manifest};
    $r->{raw_manifest} = ref $m eq 'ARRAY' ? $m
                       : (defined $m && length $m) ? JSON::PP->new->decode($m)
                       : [];
  }

  return $self->build_lock($rows);
}

# ---------------------------------------------------------------------------
# diff($expected_doc, $lock_from_db) -> arrayref de strings (vazio = sem deriva)
#
# Compara campo a campo o documento versionado com o estado atual da base,
# apontando o que mudou — é o que o --verify reporta.
# ---------------------------------------------------------------------------
sub diff ($self, $doc, $lock) {
  my @drift;

  my $exp_h = $doc->{tables};
  my $act_h = $lock->{tables};

  my %exp = map  { $_->{table_name} => $_ } @{ $exp_h // [] };
  my %act = map  { $_->{table_name} => $_ } @{ $act_h // [] };

  for my $t (sort keys %exp) {
    if (!exists $act{$t}) {
      push @drift, "$t: ausente na base (existia no lockfile)";
      next;
    }
    my ($e, $a) = ($exp{$t}, $act{$t});
    for my $campo (qw(source_url source_license row_count_loaded)) {
      my ($ev, $av) = (defined $e->{$campo} ? "$e->{$campo}" : undef,
                       defined $a->{$campo} ? "$a->{$campo}" : undef);
      push @drift, "$t: $campo mudou (lock=" . ($ev // '∅') . ", base=" . ($av // '∅') . ")"
        if ($ev // '') ne ($av // '');
    }
    my $er = join ',', map { "$_->{url}#$_->{sha256}" } @{ $e->{raw} // [] };
    my $ar = join ',', map { "$_->{url}#$_->{sha256}" } @{ $a->{raw} // [] };
    push @drift, "$t: conjunto de hashes raw mudou" if $er ne $ar;
  }

  for my $t (sort keys %act) {
    push @drift, "$t: nova na base (não está no lockfile)" unless exists $exp{$t};
  }

  return \@drift;
}

# Recalcula a chave de conteúdo de um documento lido do disco.
sub document_version ($self, $doc) {
  return $self->dataset_version({ version => $doc->{version}, tables => $doc->{tables} });
}

1;
