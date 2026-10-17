package EduMaps::Ingestion::DatasetsLock;
use Mojo::Base -base, -signatures;
use utf8;

use Digest::SHA qw(sha256_hex);
use JSON::PP ();
use Encode qw(encode);

# ============================================================================
# bin/datasets_lock.pl — manifesto de hashes dos datasets (#135)
#
# Fixa (pin) o pipeline em duas pontas, para o número publicado ser rastreável:
#
#   1. `tables` — a ENTRADA (`raw`): sha256 por arquivo bruto, gravado pelo job
#      de ingestão em `clean.import_metadata.raw_manifest` desde o #231.
#      `dataset_version` = sha256 do JSON canônico de {version, tables}.
#
#   2. `transformations` — o CÓDIGO que produz as camadas derivadas
#      (`raw`→`clean`→`analytics`) que o IVET (#137) consome: sha256 da
#      definição do objeto que materializa cada tabela (`pg_get_functiondef`
#      para funções `refresh_*`, `pg_get_viewdef` para matviews/views), mais o
#      `row_count` observado. `transform_version` = sha256 do JSON canônico de
#      {version, transformations}.
#
# Insumo + transformação pinados ⇒ saída reprodutível, sem hashear centenas de
# milhares de linhas. O `--verify` denuncia deriva de qualquer das duas pontas.
#
# Campos fora do lock, de propósito:
#   - caminho/baixado_em/reaproveitado — variam a cada execução (o caminho tem a
#     data do download); não identificam o conteúdo, só sujariam o diff.
#   - retrieved_at / import_timestamp — idem; a proveniência completa fica na
#     base (retrieved_at + source_url + sha256 respondem juntos, #135 entregável 4).
# ============================================================================

our $LOCK_VERSION = 2;

# Camadas DERIVADAS que o IVET (#137) consome. Cada passo declara qual objeto
# define a transformação que PRODUZ a tabela (`method`) e de que tipo ele é
# (`kind`): uma função `refresh_*` ou a própria matview/view. O `table_name` é a
# tabela derivada lida pelo IVET. Registry declarado de propósito (explícito)
# em vez de auto-descoberto: quem adiciona uma camada nova a regista aqui.
our @DERIVED_STEPS = (
  {
    table_name => 'clean.escola_influencia',
    method     => 'clean.refresh_escola_influencia',
    kind       => 'function',
  },
  {
    table_name => 'clean.escola_entorno_socioeconomico',
    method     => 'clean.refresh_escola_entorno_socioeconomico',
    kind       => 'function',
  },
  {
    table_name => 'clean.mv_escolas_scores',
    method     => 'clean.mv_escolas_scores',
    kind       => 'matview',
  },
);

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

# ---------------------------------------------------------------------------
# build_transformations(\@steps) -> arrayref
#
# $steps: { table_name, method, kind, row_count, def }.
#   - `def` é o texto da definição (pg_get_functiondef / pg_get_viewdef); a
#     ausência do objeto na base é `undef`.
# Saída (ordenada por table_name): { table_name, method, kind, row_count,
# def_sha256 }. PURA (sem DB) — o núcleo testável.
# ---------------------------------------------------------------------------
sub build_transformations ($self, $steps) {
  my @out;

  for my $s (sort { ($a->{table_name} // '') cmp ($b->{table_name} // '') } @$steps) {
    my $def = $s->{def};
    push @out, {
      table_name => $s->{table_name},
      method     => $s->{method},
      kind       => $s->{kind},
      row_count  => defined $s->{row_count} ? $s->{row_count} + 0 : undef,
      def_sha256 => (defined $def && length $def) ? sha256_hex($self->_bytes($def)) : undef,
    };
  }

  return \@out;
}

# A definição vem do catálogo do Postgres; o DBD::Pg pode devolvê-la com a flag
# utf8 ligada (string "wide"), que o Digest::SHA recusa. Normaliza para BYTES
# UTF-8 antes de hashear, de forma determinística.
sub _bytes ($self, $str) {
  return utf8::is_utf8($str) ? encode('UTF-8', $str) : $str;
}

# Chave de conteúdo do conjunto de DADOS (exclui o próprio campo).
sub dataset_version ($self, $lock) {
  my $payload = { version => $lock->{version}, tables => $lock->{tables} };
  return sha256_hex($self->canonical_json($payload));
}

# Chave de conteúdo do conjunto de TRANSFORMAÇÕES (`raw`→`clean`→`analytics`).
sub transform_version ($self, $lock) {
  my $payload = {
    version         => $lock->{version},
    transformations => $lock->{transformations} // [],
  };
  return sha256_hex($self->canonical_json($payload));
}

# Monta o documento final versionado (com as chaves de conteúdo embutidas).
sub document ($self, $lock) {
  my $trans = $lock->{transformations} // [];
  return {
    version           => $lock->{version},
    dataset_version   => $self->dataset_version($lock),
    transform_version => $self->transform_version({ version => $lock->{version}, transformations => $trans }),
    tables            => $lock->{tables},
    transformations   => $trans,
  };
}

# ---------------------------------------------------------------------------
# from_db($dbh, \@steps) -> hashref { version, tables, transformations }
#
# Lê a entrada `raw` de clean.import_metadata e a definição das transformações
# do catálogo do Postgres. `@steps` default = @DERIVED_STEPS (o registry do
# IVET); pode ser sobreposto em teste.
# ---------------------------------------------------------------------------
sub from_db ($self, $dbh, $steps = \@DERIVED_STEPS) {
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

  my $lock = $self->build_lock($rows);

  my $cat = $self->_catalog($dbh);

  my @derived;
  for my $s (@$steps) {
    my $def = $s->{kind} eq 'function'
      ? $cat->{func}{ $s->{method} }
      : $cat->{rel}{ $s->{method} }{viewdef};

    # row_count exato só quando a tabela existe na base (evita morrer em base
    # sem a camada deployada — nesse caso fica `undef` e o --verify acusa).
    my $row_count;
    if ($cat->{rel}{ $s->{table_name} }) {
      ($row_count) = $dbh->selectrow_array("SELECT count(*) FROM $s->{table_name}");
    }

    push @derived, { %$s, def => $def, row_count => $row_count };
  }

  $lock->{transformations} = $self->build_transformations(\@derived);

  return $lock;
}

# ---------------------------------------------------------------------------
# _catalog($dbh) -> { func => { name => def }, rel => { name => { relkind, viewdef } } }
#
# Fotografia do catálogo do schema `clean` (uma query por tipo), para resolver
# a definição de cada passo de @DERIVED_STEPS. `name` = `schema.objeto`; funções
# por nome (não há sobrecarga em `clean`).
# ---------------------------------------------------------------------------
sub _catalog ($self, $dbh) {
  my $rels = $dbh->selectall_arrayref(
    q{SELECT n.nspname || '.' || c.relname AS name,
             c.relkind AS relkind,
             pg_get_viewdef(c.oid, true) AS viewdef
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'clean' AND c.relkind IN ('r', 'm', 'v')},
    { Slice => {} },
  );

  my $funcs = $dbh->selectall_arrayref(
    q{SELECT n.nspname || '.' || p.proname AS name,
             pg_get_functiondef(p.oid) AS def
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'clean' AND p.prokind = 'f'},
    { Slice => {} },
  );

  return {
    rel  => { map { $_->{name} => { relkind => $_->{relkind}, viewdef => $_->{viewdef} } } @$rels },
    func => { map { $_->{name} => $_->{def} } @$funcs },
  };
}

# ---------------------------------------------------------------------------
# diff($expected_doc, $lock_from_db) -> arrayref de strings (vazio = sem deriva)
#
# Compara campo a campo o documento versionado com o estado atual da base,
# apontando o que mudou — é o que o --verify reporta. Cobre as duas pontas:
# `tables` (dados) e `transformations` (código).
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

  my %exp_t = map  { $_->{table_name} => $_ } @{ $doc->{transformations} // [] };
  my %act_t = map  { $_->{table_name} => $_ } @{ $lock->{transformations} // [] };

  for my $t (sort keys %exp_t) {
    if (!exists $act_t{$t}) {
      push @drift, "$t: transformação ausente na base (existia no lockfile)";
      next;
    }
    my ($e, $a) = ($exp_t{$t}, $act_t{$t});
    push @drift, "$t: definição da transformação mudou (def_sha256)"
      if ($e->{def_sha256} // '') ne ($a->{def_sha256} // '');
    push @drift, "$t: row_count derivado mudou (lock="
               . (defined $e->{row_count} ? $e->{row_count} : 'undef') . " base="
               . (defined $a->{row_count} ? $a->{row_count} : 'undef') . ")"
      if (defined $e->{row_count} ? $e->{row_count} : '') ne (defined $a->{row_count} ? $a->{row_count} : '');
  }
  for my $t (sort keys %act_t) {
    push @drift, "$t: transformação nova na base (não está no lockfile)"
      unless exists $exp_t{$t};
  }

  return \@drift;
}

# Recalcula as chaves de conteúdo de um documento lido do disco.
sub document_version ($self, $doc) {
  return $self->dataset_version({ version => $doc->{version}, tables => $doc->{tables} });
}

sub document_transform_version ($self, $doc) {
  return $self->transform_version({
    version         => $doc->{version},
    transformations => $doc->{transformations} // [],
  });
}

1;
