# minerador_relacoes.pl — extrai as relações declaradas nos Results DBIC
# lendo o PRÓPRIO código (belongs_to/has_many/might_have/has_one/many_to_many)
# com varredura de parênteses balanceados. A tipologia não fica em
# relationship_info nesta versão do DBIC, e o cond de many_to_many nem sempre é
# hash — por isso lê-se a fonte em vez de perguntar ao objeto.
#
# Uso (OBRIGATÓRIO: de dentro de backend/, pois os globs são relativos):
#   cd backend && perl ../docs/diagramas/validacao/minerador_relacoes.pl \
#       > ../docs/diagramas/validacao/relacoes.tsv
#
# Saída tabulada: SRC (classe, tabela, tipo, arquivo) · COLS · REL (classe,
# attr, tipo, classe-alvo, condição). Nada é executado: é leitura de texto.
use strict;
use warnings;
use utf8;
use File::Basename qw(basename);

my @files = glob('lib/EduMaps/Schema/Result/*.pm lib/EduMaps/Schema/Result/View/*.pm');

binmode STDOUT, ':encoding(UTF-8)';

for my $f (sort @files) {
  open my $fh, '<:encoding(UTF-8)', $f or die "$f: $!";
  local $/; my $src = <$fh>; close $fh;

  my $name = basename($f, '.pm');
  my ($table) = $src =~ /__PACKAGE__\s*->\s*table\s*\(\s*['"]([^'"]+)['"]/;
  my $is_view = ($src =~ /table_class\s*\(\s*['"][^'"]*View/ || $f =~ m{/View/}) ? 1 : 0;
  print join("\t", 'SRC', $name, $table // '?', $is_view ? 'view' : 'table', $f), "\n";

  # colunas (para o diagrama)
  my @cols = $src =~ /^\s*__PACKAGE__->add_columns\(\s*["']([^"']+)["']/mg;
  print join("\t", 'COLS', $name, join(',', @cols)), "\n" if @cols;

  while ($src =~ /\b(belongs_to|has_many|might_have|has_one|many_to_many)\s*\(/g) {
    my $type = $1;
    my $start = pos($src);
    # varre até fechar o parêntese que abriu
    my ($depth, $i, $end) = (1, $start, $start);
    while ($depth > 0 && $i < length($src)) {
      my $c = substr($src, $i, 1);
      $depth++ if $c eq '(';
      $depth-- if $c eq ')';
      $i++;
    }
    $end = $i;
    my $block = substr($src, $start, $end - $start);

    # forma longa: 'nome' => 'Classe'  |  forma curta: nome => 'Classe'
    my ($rel)   = $block =~ /^\s*(?:['"]([^'"]+)['"]|([A-Za-z_]\w*))/;
    $rel //= $2;
    my ($tgt)   = $block =~ /^\s*(?:['"][^'"]+['"]|[A-Za-z_]\w*)\s*(?:=>|,)\s*['"]([^'"]+)['"]/;
    # cond: pares foreign.X => self.Y (pode haver mais de um = chave composta)
    my @pairs = $block =~ /["']foreign\.(\w+)["']\s*=>\s*["']self\.(\w+)["']/g;
    # forma curta: terceiro argumento é o nome da coluna FK
    my ($fk) = $block =~ /^\s*(?:['"][^'"]+['"]|[A-Za-z_]\w*)\s*(?:=>|,)\s*['"][^'"]+['"]\s*(?:=>|,)\s*['"](\w+)['"]/;
    my $cond = '';
    if (@pairs) {
      my @out;
      while (@pairs) { my ($f, $s) = (shift @pairs, shift @pairs); push @out, "$f<->$s"; }
      $cond = join(' + ', @out);
    }
    elsif ($type eq 'many_to_many') {
      # terceiro argumento é o nome da relação-ponte (acessada via accessor)
      my ($bridge) = $block =~ /^\s*['"][^'"]+['"]\s*(?:=>|,)\s*['"][^'"]+['"]\s*(?:=>|,)\s*['"]([^'"]+)['"]/;
      $cond = 'via ponte: ' . ($bridge // '?');
    }
    elsif ($fk) {
      $cond = "$fk<->$fk";
    }
    else {
      # cond em code-ref: quase sempre join espacial (a criação do vínculo é
      # geográfica, não por chave) — registra qual operador PostGIS ele usa
      my $op = $block =~ /ST_(Contains|Within|DWithin|Expand|Intersects|Distance|KNN)/
        ? "espacial: ST_$1"
        : 'cond dinâmico (code-ref)';
      $cond = $op;
    }
    $tgt //= '?';
    $tgt =~ s/^EduMaps::Schema::Result:://;
    $tgt =~ s/^EduMaps::Schema::Result::View::/View::/;
    print join("\t", 'REL', $name, $rel // '?', $type, $tgt, $cond), "\n";
  }
}
