#!/usr/bin/env perl
# =====================================================================
# Inventário de dependências declarado vs. usado (#177, passo 2)
#
# Extrai os `use`/`require` literais de lib/ + script/ e compara com o
# cpanfile. Sai com código 1 se algum módulo usado não estiver declarado
# (e não for pragma nem módulo local do projeto) — é o gate que teria
# apanhado a cadeia Text::CSV / DateTime::Format::ISO8601 do #177 antes
# do deploy, e que apanha hoje a falta de YAML::XS (o cpanfile declara
# `YAML`, que é outra distribuição, tal como Text::CSV_XS ≠ Text::CSV).
#
# Armadilha documentada na issue: NÃO resolver módulos com
# `eval { require $var }` no mesmo processo — dá falsos negativos (a lista
# de 91 falhas incluía `Carp`, que é core e existe). A resolução é feita
# com um processo por módulo (`perl -Ilib -M<mod> -e1`), e apenas para os
# candidatos "usado e não declarado" (poucos), para o relatório ficar
# calibrado.
#
# `require`/`use` dinâmicos (ex.: `eval "require EduMaps::Ingestion::Job::$name"`
# em Ingestion/CLI.pm) ficam fora do inventário por construção: são
# cobertos pelo gate de compilação de toda a lib/ na CI (passo 1 da issue,
# PR #181). Este script não tenta avaliar nenhum deles.
#
# Uso:
#   perl -Ilib script/check_dependencies.pl [--dirs "lib script"] [--cpanfile cpanfile]
# =====================================================================
use strict;
use warnings;
use utf8;
use v5.36;

use File::Find;
use Getopt::Long;

# Pragmas que não são módulos: `use open ':std'` não referencia nada
# instalável. Sem esta lista, `perl -Mopen -e1` morre com um erro de
# PerlIO e o inventário denuncia o próprio check, não uma dependência.
my %PRAGMA = map { $_ => 1 } qw(
  autodie bytes charnames diagnostics encoding feature filetest if int
  integer lib less mro open overload re sigtrap sort threads utf8 vars
  vmsish
);

my $dirs     = 'lib script';
my $cpanfile = 'cpanfile';
GetOptions(
  'dirs=s'     => \$dirs,
  'cpanfile=s' => \$cpanfile,
) or die "uso: $0 [--dirs 'lib script'] [--cpanfile cpanfile]\n";

my @dirs = split /\s+/, $dirs;
for my $d (@dirs) {
  die "diretório não existe: $d\n" unless -d $d;
}
die "cpanfile não existe: $cpanfile\n" unless -e $cpanfile;

# ---------------------------------------------------------------------
# 1. Extração de use/require literais
# ---------------------------------------------------------------------
my %used;
for my $dir (@dirs) {
  find(
    sub {
      return unless -f $_;
      return unless /\.(?:pm|pl)\z/;
      open my $fh, '<', $_ or return;
      local $/;
      my $src = <$fh>;
      close $fh;
      while ($src =~ /^\s*(?:use|no|require)\s+([A-Za-z_][A-Za-z0-9_:]*)/mg) {
        my $mod = $1;
        # `use v5.36;` / `use 5.010;` não são módulos
        next if $mod =~ /^v?\d/;
        $used{$mod} = 1;
      }
      # `use parent qw(A B)`, `use base qw(A B)`: os alvos também contam
      while ($src =~ /^\s*use\s+(?:parent|base)\s+[qw(]+\s*([^)]+?)\s*\)/mg) {
        for my $mod ($1 =~ /([A-Za-z_][A-Za-z0-9_:]*)/g) {
          $used{$mod} = 1;
        }
      }
      # `use Mojo::Base 'Classe'`: a base em string também é dependência
      # (ex.: ResultSets com DBIx::Class::Core / DBIx::Class::Schema)
      while ($src =~ /^\s*use\s+Mojo::Base\s*(?:\(\s*)?'([A-Za-z_][A-Za-z0-9_:]*)'/mg) {
        $used{$1} = 1;
      }
    },
    $dir,
  );
}

# ---------------------------------------------------------------------
# 2. Declaradas no cpanfile (todas as fases: base, test, develop…)
# ---------------------------------------------------------------------
open my $cfh, '<', $cpanfile or die "não abriu $cpanfile: $!\n";
my $cf_src;
{ local $/; $cf_src = <$cfh> }
close $cfh;
my %declared = map { $_ => 1 } ($cf_src =~ /requires\s+"([^"]+)"/g);

# ---------------------------------------------------------------------
# 3. Classificação
# ---------------------------------------------------------------------
my (@missing, @used_declared, @locals);
for my $mod (sort keys %used) {
  if ($PRAGMA{$mod}) {
    next;
  }
  if (module_local($mod)) {
    push @locals, $mod;
    next;
  }
  if ($declared{$mod}) {
    push @used_declared, $mod;
    next;
  }
  push @missing, $mod;
}

# Resolução por processo (perl -M<mod> -e1) só para candidatos em falta:
# são poucos e o custo de um subprocesso por candidato é irrelevante.
my %resolve;
for my $mod (@missing) {
  system('perl', '-Ilib', '-M' . $mod, '-e1') == 0
    ? ($resolve{$mod} = 'resolvido')
    : ($resolve{$mod} = 'nao_resolve');
}

# ---------------------------------------------------------------------
# 4. Relatório
# ---------------------------------------------------------------------
print "[check_dependencies] usado/local: " . scalar(@locals) . "\n";
print "[check_dependencies] usado/declarado: " . scalar(@used_declared) . "\n";
print "[check_dependencies] modules usados e NAO declarados: " . scalar(@missing) . "\n";
for my $mod (@missing) {
  printf "  [%s] %s\n", $resolve{$mod} eq 'resolvido' ? 'resolvido' : 'FALHA', $mod;
}

# Declaradas mas não referenciadas em lib/ + script/ (informativo —
# várias são usadas apenas em t/ e saem daqui como falso positivo).
my @unused = sort grep { !$used{$_} } keys %declared;
if (@unused) {
  print "[check_dependencies] declaradas e nao referenciadas em lib/script/ (info): " . scalar(@unused) . "\n";
  print "  " . join(', ', @unused) . "\n";
}

if (@missing) {
  print "[check_dependencies] FALHA: " . scalar(@missing) . " modulo(s) usado(s) sem declaracao no cpanfile\n";
  exit 1;
}

print "[check_dependencies] OK: todo uso em lib/ + script/ esta declarado no cpanfile\n";
exit 0;

# ---------------------------------------------------------------------
sub module_local ($mod) {
  return 1 if $mod =~ /^EduMaps::/;
  my $file = join '/', split /::/, $mod;
  for my $dir (@dirs) {
    return 1 if -e "$dir/$file.pm";
  }
  return 0;
}