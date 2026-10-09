use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use GitHooks::PreCommit qw(docs_warning);

# Não avisa quando o commit não toca código.
ok(!defined docs_warning('docs/indice.md', 'README.md'), 'docs: sem aviso');

# Não avisa quando o commit toca código E a documentação funcional.
ok(
  !defined docs_warning('backend/lib/Foo.pm', 'docs/funcionalidades/busca/x.md'),
  'código + docs funcionais: sem aviso',
);

# Avisa quando toca código e não toca docs/funcionalidades/.
like(
  docs_warning('backend/lib/Foo.pm'),
  qr/docs\/funcionalidades\//,
  'código sem docs funcionais: aviso',
);

like(
  docs_warning('data_pipeline/deploy/x.sql', 'docs/indice.md'),
  qr/docs\/funcionalidades\//,
  'código + outra doc: aviso',
);

like(
  docs_warning('frontend/edumaps/src/app.svelte'),
  qr/docs\/funcionalidades\//,
  'frontend sem docs funcionais: aviso',
);

like(
  docs_warning('analysis/edumapsr/R/x.R'),
  qr/docs\/funcionalidades\//,
  'analysis sem docs funcionais: aviso',
);

# Um caminho que só contém "backend/" no meio não conta como área.
ok(!defined docs_warning('docs/backend/notas.md'), 'docs/backend não é área de código');

done_testing;
