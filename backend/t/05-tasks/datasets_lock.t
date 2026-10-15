use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use JSON::PP ();

# =====================================================================
# #135 — manifesto de hashes dos datasets (lockfile versionado)
#
# O #231 já grava sha256/bytes por arquivo bruto em
# clean.import_metadata.raw_manifest. O #135 fixa isso num lockfile
# determinístico, versionado no git. Este teste cobre o núcleo puro
# (sem banco): ordenação canônica, exclusão dos campos voláteis,
# chave de conteúdo estável e detecção de deriva.
# =====================================================================

use_ok('EduMaps::Ingestion::DatasetsLock');

my $m = EduMaps::Ingestion::DatasetsLock->new;

# --- fixture -----------------------------------------------------------
my @rows = (
  {
    table_name       => 'clean.rede_escolas',
    source_url       => 'https://exemplo/rede.csv',
    source_license   => 'CC-BY-4.0',
    row_count_loaded => 10,
    raw_manifest     => [
      { url => 'https://exemplo/b.csv', sha256 => 'bbb', bytes => 2,  caminho => '/raw/b', baixado_em => 'x', reaproveitado => 0 },
      { url => 'https://exemplo/a.csv', sha256 => 'aaa', bytes => 1,  caminho => '/raw/a', baixado_em => 'y', reaproveitado => 1 },
    ],
  },
  {
    table_name       => 'clean.censo',
    source_url       => 'https://exemplo/censo.zip',
    source_license   => 'ODbL-1.0',
    row_count_loaded => 5,
    raw_manifest     => [
      { url => 'https://exemplo/c.zip', sha256 => 'ccc', bytes => 3, caminho => '/raw/c', baixado_em => 'z' },
    ],
  },
);

# --- build_lock: ordenação e exclusão de campos voláteis ---------------
my $lock = $m->build_lock([ reverse @rows ]);   # ordem de entrada invertida
is_deeply [ map { $_->{table_name} } @{ $lock->{tables} } ],
  ['clean.censo', 'clean.rede_escolas'], 'tabelas ordenadas por nome';

my $rede = (grep { $_->{table_name} eq 'clean.rede_escolas' } @{ $lock->{tables} })[0];
is_deeply [ map { $_->{url} } @{ $rede->{raw} } ],
  ['https://exemplo/a.csv', 'https://exemplo/b.csv'], 'raw ordenado por url';

is_deeply $rede->{raw}[0], { url => 'https://exemplo/a.csv', sha256 => 'aaa', bytes => 1 },
  'entry raw carrega só url/sha256/bytes (sem caminho/baixado_em/reaproveitado)';

# --- dataset_version: estável e sensível ao conteúdo -------------------
my $dv = $m->dataset_version($lock);
is $m->dataset_version($m->build_lock([ @rows ])), $dv,
  'dataset_version não muda com a ordem de entrada';

my $lock2 = $m->build_lock([ @rows ]);
$lock2->{tables}[0]{raw}[0]{sha256} = 'MUDOU';
isnt $m->dataset_version($lock2), $dv, 'sha256 diferente -> chave diferente';

my $lock3 = $m->build_lock([ @rows ]);
$lock3->{tables}[0]{row_count_loaded} = 999;
isnt $m->dataset_version($lock3), $dv, 'row_count diferente -> chave diferente';

# --- document: embute a chave de conteúdo ------------------------------
my $doc = $m->document($lock);
is $doc->{dataset_version}, $dv, 'document() embute a mesma chave';
is $m->document_version($doc), $dv, 'document_version() recalcula a chave do documento';

# --- canonical: determinístico entre execuções -------------------------
is $m->canonical_json($lock), $m->canonical_json($m->build_lock([ reverse @rows ])),
  'JSON canônico independe da ordem de entrada';

# --- não-ASCII: a chave de conteúdo é calculada sobre bytes UTF-8 -------
# (Digest::SHA recusa caracteres largos: sem ->utf8 no canonical_json isto
#  morre com "Wide character in subroutine entry".)
my @acento = (
  { table_name => 'clean.acento', source_url => 'https://exemplo/múltiplas-fontes—ção',
    source_license => 'CC-BY-4.0', row_count_loaded => 1, raw_manifest => [] },
);
my $lk_ac = eval { $m->document($m->build_lock(\@acento)) };
ok $lk_ac, 'dataset_version funciona com acentos (UTF-8)';
is $m->dataset_version($m->build_lock(\@acento)), $m->dataset_version($m->build_lock(\@acento)),
  'chave de conteúdo estável com acentos';
isnt $m->dataset_version($m->build_lock(\@acento)), $dv, 'acento muda a chave (não é colisão trivial)';

# --- diff: sem deriva vs. cada tipo de deriva --------------------------
is_deeply $m->diff($doc, $lock), [], 'sem deriva -> diff vazio';

my $drift_rc = $m->build_lock([ @rows ]);
$drift_rc->{tables}[0]{row_count_loaded} = 7;
like join("\n", @{ $m->diff($doc, $drift_rc) }), qr/row_count_loaded mudou/,
  'diff acusa row_count alterado';

my $drift_src = $m->build_lock([ @rows ]);
$drift_src->{tables}[0]{source_url} = 'https://outro';
like join("\n", @{ $m->diff($doc, $drift_src) }), qr/source_url mudou/,
  'diff acusa source_url alterada';

my $drift_raw = $m->build_lock([ @rows ]);
$drift_raw->{tables}[1]{raw} = [];
like join("\n", @{ $m->diff($doc, $drift_raw) }), qr/conjunto de hashes raw mudou/,
  'diff acusa conjunto de hashes raw alterado';

my $drift_falta = $m->build_lock([ $rows[0] ]);   # tabela a menos
like join("\n", @{ $m->diff($doc, $drift_falta) }), qr/ausente na base/,
  'diff acusa tabela do lockfile ausente na base';

my $drift_nova = $m->build_lock([ @rows,
  { table_name => 'clean.nova', raw_manifest => [] } ]);
like join("\n", @{ $m->diff($doc, $drift_nova) }), qr/nova na base/,
  'diff acusa tabela nova na base';

# --- from_db: decodifica raw_manifest (texto JSON e arrayref) ----------
{
  package FakeDBH;
  sub new { bless { rows => $_[1] }, $_[0] }
  sub selectall_arrayref { $_[0]{rows} }
}
my $fake = FakeDBH->new([
  { table_name => 'clean.a', source_url => 'u1', source_license => 'CC0-1.0', row_count_loaded => 1,
    raw_manifest => JSON::PP->new->encode([ { url => 'u', sha256 => 'h', bytes => 4, caminho => '/x' } ]) },
  { table_name => 'clean.b', row_count_loaded => 2, raw_manifest => [ { url => 'v', sha256 => 'i', bytes => 5 } ] },
  { table_name => 'clean.c', row_count_loaded => 3, raw_manifest => undef },
]);
my $db_lock = $m->from_db($fake);
is scalar @{ $db_lock->{tables} }, 3, 'from_db lê as 3 tabelas';
is $db_lock->{tables}[0]{raw}[0]{sha256}, 'h', 'from_db decodifica raw_manifest em texto JSON';
is scalar @{ $db_lock->{tables}[1]{raw} }, 1, 'from_db aceita raw_manifest já como arrayref';
is_deeply $db_lock->{tables}[2]{raw}, [], 'from_db trata raw_manifest NULL como vazio';

done_testing;
