package GitHooks::PreCommit;

# Avisos de pré-commit (nunca bloqueia). Só core Perl.
#
# O aviso de documentação funcional é a única regra de negócio aqui; os linters
# (perlcritic/lintr) são ligados condicionalmente pelo CLI
# (`pre-commit.pl`), apenas se estiverem instalados.

use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(docs_warning);

my @CODE_AREAS = qw(backend/ frontend/ analysis/ data_pipeline/);
my $DOCS_AREA  = 'docs/funcionalidades/';

# Recebe a lista de caminhos staged e devolve a mensagem de aviso (ou undef)
# quando o commit toca código e não toca docs/funcionalidades/ — passo 3 do
# Workflow do AGENTS.md.
sub docs_warning {
  my (@files) = @_;

  my $touch_code = 0;
  my $touch_docs = 0;
  for my $file (@files) {
    $touch_docs = 1 if index($file, $DOCS_AREA) == 0;
    for my $area (@CODE_AREAS) {
      if (index($file, $area) == 0) {
        $touch_code = 1;
        last;
      }
    }
  }

  return undef unless $touch_code && !$touch_docs;
  return 'este commit toca código e não atualiza docs/funcionalidades/ '
    . '(passo 3 do Workflow do AGENTS.md)';
}

1;
