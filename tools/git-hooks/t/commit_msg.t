use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;
use GitHooks::CommitMsg qw(validate_message);

# Aceite: formato canónico.
ok(validate_message("feat(backend): adiciona endpoint")->{ok}, 'scope + type + subject');
ok(validate_message("docs: atualiza o memory")->{ok}, 'sem scope é aceite');
ok(validate_message("feat(backend)!: quebra compatibilidade")->{ok}, 'breaking change');
ok(validate_message("chore(infra): liga hooks")->{ok}, 'scope infra');

# Isenções: mensagens geradas pelo git.
ok(validate_message("Merge pull request #198 from marcoarthur/x")->{ok}, 'merge isento');
ok(validate_message('Revert "feat(backend): x"')->{ok}, 'revert isento');
ok(validate_message("squash! feat(backend): x")->{ok}, 'squash isento');
ok(validate_message("fixup! docs: x")->{ok}, 'fixup isento');

# Comentários e linhas em branco antes do subject.
ok(validate_message("# comentário\n\nfeat(backend): ok\n")->{ok}, 'ignora comentários');

# Rejeições (bloqueiam).
ok(!validate_message('')->{ok}, 'mensagem vazia bloqueia');
ok(!validate_message("\n# só comentário\n")->{ok}, 'só comentários bloqueia');
ok(!validate_message('adiciona endpoint') ->{ok}, 'sem type bloqueia');
ok(!validate_message('foo(backend): x')    ->{ok}, 'type inválido bloqueia');
ok(!validate_message('feat(backend):x')    ->{ok}, 'sem espaço após ":" bloqueia');
ok(!validate_message('feat backend: x')    ->{ok}, 'sem parênteses/escopo válido bloqueia');

# Avisos (não bloqueiam).
{
  my $r = validate_message('feat(backendentinhas): x');
  ok($r->{ok}, 'scope desconhecido não bloqueia');
  like($r->{warnings}[0] // '', qr/scope/, 'gera aviso de scope');
}

{
  my $r = validate_message('feat(backend): ' . ('x' x 60));
  ok($r->{ok}, 'subject longo não bloqueia');
  like($r->{warnings}[0] // '', qr/subject com \d+ caractere/, 'gera aviso de comprimento');
}

{
  my $r = validate_message('fix(backend): corrige x.');
  ok($r->{ok}, 'ponto final não bloqueia');
  like(join(' ', @{ $r->{warnings} }), qr/ponto final/, 'gera aviso de ponto final');
}

done_testing;
