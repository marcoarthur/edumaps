#!/usr/bin/env perl

# Hook pre-commit do EduMaps. **Nunca bloqueia** (sempre exit 0): apenas avisa.
#
#   1. Lembra o passo 3 do Workflow (docs/funcionalidades/) quando o commit
#      toca código e não toca a documentação funcional.
#   2. Corre perlcritic (Perl) e lintr (R) *se* estiverem instalados e houver
#      ficheiros staged da área. Sem as ferramentas, salta em silêncio.
#
# Ver tools/git-hooks/README.md.

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";

use GitHooks::PreCommit qw(docs_warning);
use IPC::Cmd qw(can_run);

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my @staged = grep { length } map { chomp; $_ } `git diff --cached --name-only --diff-filter=ACMR 2>/dev/null`;

sub aviso {
  my ($text) = @_;
  print STDERR "git-hooks(pre-commit): aviso: $text\n";
}

# 1. Documentação funcional (passo 3 do Workflow).
if (my $warning = docs_warning(@staged)) {
  aviso($warning);
}

# 2. Linters condicionais: só se a ferramenta existir e houver ficheiros da área.
my @perl_files = grep { m{^backend/.*\.(?:pm|pl)$} } @staged;
if (@perl_files) {
  if (my $perlcritic = can_run('perlcritic')) {
    print STDERR "git-hooks(pre-commit): perlcritic em " . scalar(@perl_files) . " ficheiro(s)\n";
    system $perlcritic, '--severity', '5', @perl_files;
    aviso('perlcritic apontou problemas (aviso, não bloqueia)') if $? != 0;
  }
}

my @r_files = grep { m{^analysis/.*\.R$} } @staged;
if (@r_files && can_run('Rscript')) {
  my $has_lintr = system(
    'Rscript', '-e',
    'quit(status = !requireNamespace("lintr", quietly = TRUE))'
  ) == 0;

  if ($has_lintr) {
    for my $file (@r_files) {
      my $expr = sprintf 'print(lintr::lint("%s"))', $file;
      system 'Rscript', '-e', $expr;
      aviso("lintr apontou problemas em $file (aviso, não bloqueia)") if $? != 0;
    }
  }
}

# Frontend: não há `npm run lint` no repo (nem eslint). Nada a correr; se um dia
# existir, liga-se aqui condicionalmente, como os de cima.

exit 0;
