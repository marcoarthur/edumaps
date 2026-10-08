use lib qw(t/lib lib);
use strict;
use warnings;
use utf8;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Mojo::File qw(path);

# =====================================================================
# Regressão do script/check_dependencies.pl (#177, passo 2)
#
# O script varre uma árvore (fake) e compara os use/require literais
# contra um cpanfile (fake). Testes:
#   1. árvore limpa → exit 0;
#   2. módulo usado e não declarado → exit 1 e o módulo no relatório;
#   3. pragma `use open` não é denunciado como módulo;
#   4. `use parent qw(Local)` resolve alvos como módulos locais;
#   5. require dinâmico dentro de eval NÃO é inventariado (limitação
#      documentada — é coberto pelo gate de compilação da lib/).
# =====================================================================

my $script = path(__FILE__)->to_abs->dirname->dirname->dirname->child('script', 'check_dependencies.pl');
ok(-f $script, "script existe ($script)");

sub escrever {
  my ($path, $texto) = @_;
  make_path(path($path)->dirname->to_string);
  open my $fh, '>:encoding(utf8)', $path or die "não escreveu $path: $!";
  print $fh $texto;
  close $fh or die $!;
  return $path;
}

sub rodar {
  my ($tree, $expect_ok, $nome) = @_;
  my $out = qx{perl -Ilib "$script" --dirs "$tree/lib $tree/script" --cpanfile "$tree/cpanfile" 2>&1};
  my $rc = $? >> 8;
  is($rc == 0 ? 1 : 0, $expect_ok ? 1 : 0, "$nome: exit " . ($expect_ok ? '0' : '1') . " (rc=$rc)");
  return wantarray ? ($out, $rc) : $out;
}

my $tree = tempdir(CLEANUP => 1);

# ---------------------------------------------------------------- 1. limpa
escrever("$tree/script/a.pl", "use warnings;\nuse strict;\n# apenas pragmas e core declarado\n");
escrever("$tree/lib/Foo.pm", "package Foo;\nuse Carp;\n1;\n");
escrever("$tree/cpanfile", qq{requires "Carp" => "0";\nrequires "Getopt::Long" => "0";\nrequires "strict" => "0";\nrequires "warnings" => "0";\n});
escrever("$tree/lib/Bar.pm", "package Bar;\nuse Getopt::Long;\n1;\n");
my ($clean_out, $clean_rc) = rodar($tree, 1, 'árvore limpa');
like($clean_out, qr/OK/, 'árvore limpa: relatório OK');

# -------------------------------------------------------- 2. em falta
escrever("$tree/lib/Baz.pm", "package Baz;\nuse YAML::XS;\n1;\n");
my ($miss_out, $miss_rc) = rodar($tree, 0, 'módulo usado e não declarado');
like($miss_out, qr/YAML::XS/, 'em falta: módulo aparece no relatório');
like($miss_out, qr/FALHA/, 'em falta: saída marca FALHA');

# ------------------------------------------------- 3. pragma open
escrever("$tree/lib/Quux.pm", "package Quux;\nuse open ':std', ':encoding(UTF-8)';\n1;\n");
my ($pragma_out, $pragma_rc) = rodar($tree, 0, 'pragma open sozinho ainda falha por YAML::XS');
unlike($pragma_out, qr/\[(?:resolvido|FALHA)\]\s*open/, 'pragma open não entra no inventário');

# ---------------------------------------------- 4. parent/base local
escrever("$tree/lib/Plop.pm", "package Plop;\nuse parent qw(Foo);\n1;\n");
my ($parent_out, $parent_rc) = rodar($tree, 0, 'parent local mantém a falha do YAML::XS');
unlike($parent_out, qr/\bFoo\b/, 'alvo de parent (Foo) reconhecido como local');

# --------------------------------- 5. require dinâmico fora do escopo
escrever("$tree/lib/Dyn.pm", "package Dyn;\neval \"require Something::Dynamic\";\n1;\n");
my ($dyn_out, $dyn_rc) = rodar($tree, 0, 'require dinâmico não é inventariado');
unlike($dyn_out, qr/Something::Dynamic/, 'require dinâmico não aparece (limitação documentada)');

done_testing();