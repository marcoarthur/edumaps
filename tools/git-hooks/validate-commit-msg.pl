#!/usr/bin/env perl

# Hook commit-msg do EduMaps. Recebe o caminho do ficheiro de mensagem (argv[0]).
# Bloqueia (exit 1) formato inválido e `type` desconhecido; avisa scope
# desconhecido e subject > 50. Ver tools/git-hooks/README.md.

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";

use GitHooks::CommitMsg qw(validate_message);

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my $file = shift @ARGV;
if (!defined $file || !length $file) {
  print STDERR "git-hooks(commit-msg): uso: $0 <ficheiro-da-mensagem>\n";
  exit 0;    # sem ficheiro não há o que validar; não bloquear
}

open my $fh, '<:encoding(UTF-8)', $file or do {
  print STDERR "git-hooks(commit-msg): não abriu '$file': $!\n";
  exit 0;
};
my $message = do { local $/; <$fh> };
close $fh;

my $result = validate_message($message);

for my $warning (@{ $result->{warnings} }) {
  print STDERR "git-hooks(commit-msg): aviso: $warning\n";
}

if (!$result->{ok}) {
  print STDERR "git-hooks(commit-msg): mensagem rejeitada:\n";
  print STDERR "    $_\n" for @{ $result->{errors} };
  print STDERR "    mensagem: $result->{subject}\n" if length $result->{subject};
  print STDERR "    convenção: <type>(<scope>): <subject>  (ver AGENTS.md)\n";
  print STDERR "    bypass pontual: git commit --no-verify\n";
  exit 1;
}

exit 0;
