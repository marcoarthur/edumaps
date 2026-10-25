package GitHooks::PreCommit;

use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(docs_warning);

sub docs_warning {
  my (@staged) = @_;

  return undef unless @staged;

  my @code = grep { m{^(?:backend|frontend|analysis|data_pipeline|db)/} } @staged;
  return undef unless @code;

  my @docs_func = grep { m{^docs/funcionalidades/} } @staged;
  my @docs_ajuda = grep { m{^docs/ajuda/} } @staged;

  if (@docs_func || @docs_ajuda) {
    return undef;
  }

  return
    "este commit toca código e não atualiza docs/funcionalidades/ nem docs/ajuda/ (passo 3 do Workflow). "
    . "Crie/atualize a página de ajuda em docs/ajuda/<perfil>/ com funcionalidade: apontando para docs/funcionalidades/... "
    . "ou justifique com [ajuda: não se aplica] na mensagem do commit.";
}

1;
