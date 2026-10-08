#!/usr/bin/env perl
# valida.pl — validação dos diagramas ER em docs/diagramas/*.mmd contra o
# catálogo real (banco de dados + código Perl dos Results DBIC).
#
# O que prova, em ordem:
#   1. toda entidade citada existe numa relação do Postgres (tabela/view/matview);
#   2. toda coluna de cada bloco de entidade existe naquela relação;
#   3. o tipo declarado de cada coluna é o tipo real (normalizado);
#   4. toda entidade usada numa aresta tem bloco de atributos no MESMO arquivo;
#   5. todo rótulo "[FK] ..." corresponde a uma FOREIGN KEY do catálogo;
#   6. todo rótulo "[DBIC] ..." corresponde a uma relationship declarada em
#      backend/lib/EduMaps/Schema/Result/*.pm.
#
# Por que 5 e 6 existem: o diagrama não pode nascer só das FKs (o núcleo antigo
# não as tem — o vínculo vive no Perl), nem só da introspecção DBIX (as tabelas
# novas têm FK que o DBIC nem sempre declara). Cada afirmação é verificada na
# fonte que a sustenta.
#
# Uso:
#   perl valida.pl [--dir docs/diagramas] --colunas colunas.txt
#                  [--fks fks.txt] [--relacoes relacoes.tsv] [--normalizar]
#
#   --normalizar  reescreve no local o TIPO de cada coluna do .mmd a partir do
#                 catálogo. Usar ao acrescentar tabelas; refazer o commit dos
#                 .mmd em seguida.
#
# Insumos: gerar com docs/diagramas/validacao/gera_catalogo.sh
# Sai com código != 0 se qualquer checagem falhar.

use strict;
use warnings;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my ($dir, $fcol, $ffk, $frel, $normalizar) = ('docs/diagramas', undef, undef, undef, 0);
while (@ARGV) {
  my $a = shift @ARGV;
  if    ($a eq '--dir')        { $dir        = shift @ARGV }
  elsif ($a eq '--colunas')    { $fcol       = shift @ARGV }
  elsif ($a eq '--fks')        { $ffk        = shift @ARGV }
  elsif ($a eq '--relacoes')   { $frel       = shift @ARGV }
  elsif ($a eq '--normalizar') { $normalizar = 1 }
  else { die "argumento desconhecido: $a\n" }
}
die "falta --colunas <colunas.txt> (gerar com gera_catalogo.sh)\n" unless $fcol;

# ---------------------------------------------------------------- catálogo
# colunas.txt:  schema.tabela|coluna|tipo_pg
# fks.txt:      schema.tabela|coluna|schema.tabela|coluna
# relacoes.tsv: SRC/COLS/REL tabulado (minerador_relacoes.pl)
my (%real, %tipo, %fk, %c2t, %par_dbic);
my ($n_col, $n_fk, $n_rel) = (0, 0, 0);

open my $fh, '<:encoding(UTF-8)', $fcol or die "$fcol: $!";
while (<$fh>) {
  chomp;
  my ($t, $c, $ty) = split /\|/, $_, 3;
  next unless defined $ty;
  $real{$t}{$c} = 1;
  $tipo{"$t|$c"} = $ty;
  $n_col++;
}
close $fh;

if ($ffk) {
  open $fh, '<:encoding(UTF-8)', $ffk or die "$ffk: $!";
  while (<$fh>) {
    chomp;
    my ($a, $ca, $b, $cb) = split /\|/;
    next unless $b;
    $fk{"$a|$b"} = 1;
    $fk{"$b|$a"} = 1;
    $n_fk++;
  }
  close $fh;
}

if ($frel) {
  my @raw;
  open $fh, '<:encoding(UTF-8)', $frel or die "$frel: $!";
  while (<$fh>) {
    chomp;
    my @f = split /\t/;
    if ($f[0] eq 'SRC') {
      $c2t{ $f[1] } = $f[2];
    }
    elsif ($f[0] eq 'REL') {
      # REL  Classe  attr  tipo  ClasseRelacionada  cond
      push @raw, [ $f[1], $f[4] ];
      $n_rel++;
    }
  }
  close $fh;

  # alguns SRC saem sem o schema (ex.: chat_conversas); compara pelo nome
  # desnu — seguro porque os nomes citados nos diagramas são únicos entre si.
  for my $p (@raw) {
    my $ta = $c2t{ $p->[0] };
    my $tb = $c2t{ $p->[1] };
    next unless $ta && $tb;    # classe pendurada / ResultSet: anomalia conhecida
    ($ta) = $ta =~ /\.?([^.]+)$/;
    ($tb) = $tb =~ /\.?([^.]+)$/;
    $par_dbic{$ta}{$tb} = 1;
    $par_dbic{$tb}{$ta} = 1;
  }
}

# ------------------------------------------------ normalização de tipos PG
sub norm_pg {
  my ($pg) = @_;
  return 'varchar'     if $pg =~ /^character varying/;
  return 'char'        if $pg =~ /^character\(/;
  return 'text'        if $pg eq 'text';
  return 'int'         if $pg eq 'integer';
  return 'bigint'      if $pg eq 'bigint';
  return 'smallint'    if $pg eq 'smallint';
  return 'numeric'     if $pg =~ /^numeric/;
  return 'double'      if $pg eq 'double precision';
  return 'bool'        if $pg eq 'boolean';
  return 'date'        if $pg eq 'date';
  return 'timestamptz' if $pg eq 'timestamp with time zone';
  return 'timestamp'   if $pg eq 'timestamp without time zone';
  return 'time'        if $pg eq 'time without time zone';
  return 'jsonb'       if $pg eq 'jsonb';
  return 'geometry'    if $pg =~ /^geometry/;
  return $pg;                      # tipos-domínio (ex.: minion_state)
}

# --------------------------------------------------------------- checagem
my (@e_ent, @e_col, @e_tipo, @e_bloco, @e_fk, @e_dbic);
my ($alteradas, $arquivos) = (0, 0);

for my $f (sort glob("$dir/*.mmd")) {
  (my $base = $f) =~ s{.*/}{};
  open my $m, '<:encoding(UTF-8)', $f or die "$f: $!";
  my @linhas = <$m>;
  close $m;

  # 00-visao-geral é flowchart, não erDiagram: fora desta checagem
  next unless grep { /^\s*erDiagram\b/ } @linhas;

  my ($ent, $in) = (undef, 0);
  my (%tem_bloco, %tem_aresta);
  my $neste = 0;
  $arquivos++;

  for my $i (0 .. $#linhas) {
    my $l = $linhas[$i];

    if ($l =~ /^\s*([A-Za-z0-9_.]+)\s*\{\s*$/) {
      $ent = $1; $in = 1; $tem_bloco{$ent} = 1; next;
    }
    if ($in && $l =~ /^\s*\}\s*$/) { $in = 0; $ent = undef; next; }

    # aresta:  esquema.tabela  ||--o{  esquema.tabela : "rótulo"
    if (!$in && $l =~ /^\s*([A-Za-z0-9_.]+)\s+\S+\s+([A-Za-z0-9_.]+)\s*:\s*"([^"]*)"/) {
      my ($a, $b, $lab) = ($1, $2, $3);
      $tem_aresta{$a} = 1;
      $tem_aresta{$b} = 1;

      if ($lab =~ /^\[FK\]/ && $ffk && !$fk{"$a|$b"}) {
        push @e_fk, "  $base: $a -> $b  [$lab]";
      }
      elsif ($lab =~ /^\[DBIC/ && $frel) {
        (my $ka = $a) =~ s/^.*\.//;
        (my $kb = $b) =~ s/^.*\.//;
        push @e_dbic, "  $base: $a -> $b  [$lab]" unless $par_dbic{$ka}{$kb};
      }
      next;
    }

    next unless $in && $l =~ /^\s*(\S+)\s+(\S+)/;
    my ($decl, $col) = ($1, $2);
    next unless $ent;

    if (!$real{$ent})                       { push @e_ent, "  $base: $ent"; next }
    if (!$real{$ent}{$col})                 { push @e_col, "  $base: $ent.$col"; next }

    my $real_pg = $tipo{"$ent|$col"};
    if (norm_pg($decl) ne norm_pg($real_pg)) {
      push @e_tipo, "  $base: $ent.$col  declarado=$decl  real=$real_pg";
    }
    if ($normalizar) {
      my $novo = norm_pg($real_pg);
      (my $nova_l = $l) =~ s/^(\s*)\S+/$1$novo/;
      if ($nova_l ne $l) { $linhas[$i] = $nova_l; $neste++ }
    }
  }

  for my $e (sort keys %tem_aresta) {
    push @e_bloco, "  $base: $e aparece numa aresta sem bloco de atributos"
      unless $tem_bloco{$e};
  }

  if ($normalizar && $neste) {
    open my $o, '>:encoding(UTF-8)', $f or die "$f: $!";
    print $o @linhas;
    close $o;
    $alteradas += $neste;
  }
}

# -------------------------------------------------------------- relatório
sub bloco {
  my ($titulo, $arr) = @_;
  print "== $titulo ==\n";
  print @$arr ? join("\n", sort @$arr) . "\n" : "(nenhuma)\n";
  print "\n";
}

printf "catálogo: %d colunas · %d FKs · %d relationships DBIC · diagramas erDiagram: %d\n\n",
  $n_col, $n_fk, $n_rel, $arquivos;

bloco('ENTIDADE INEXISTENTE NO BANCO', \@e_ent);
bloco('COLUNA INEXISTENTE NO BANCO',  \@e_col);
bloco('TIPO DIVERGENTE DO BANCO',      \@e_tipo);
bloco('ARESTA SEM BLOCO DE ATRIBUTOS', \@e_bloco);
bloco('[FK] SEM FOREIGN KEY REAL',     \@e_fk)   if $ffk;
bloco('[DBIC] SEM DECLARACAO NO PERL', \@e_dbic) if $frel;

my $falhas = @e_ent + @e_col + @e_tipo + @e_bloco + @e_fk + @e_dbic;
printf "--normalizar: %d linhas de tipo reescritas\n", $alteradas if $normalizar && $alteradas;
exit($falhas ? 1 : 0);
