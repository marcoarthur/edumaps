#!/usr/bin/env perl
use Mojo::Base -strict, -signatures;
use FindBin;
use lib "$FindBin::Bin/../lib";

use EduMaps::Schema;
use EduMaps::Ingestion::DatasetsLock;
use Digest::SHA ();
use JSON::PP ();
use Getopt::Long qw(GetOptions);

# ============================================================================
# bin/datasets_lock.pl — manifesto de hashes dos datasets (#135)
#
# Fixa (pin) o conjunto de dados do pipeline num lockfile versionado no git,
# a partir de clean.import_metadata.raw_manifest (sha256 por arquivo bruto,
# gravado pelo job de ingestão desde o #231).
#
# Uso:
#   perl bin/datasets_lock.pl --write            # (re)gera o lockfile
#   perl bin/datasets_lock.pl --write --out F    # grava em outro caminho
#   perl bin/datasets_lock.pl --verify           # falha (exit 1) se houver deriva
#   perl bin/datasets_lock.pl --check-files      # re-hash dos blobs em disco
#   perl bin/datasets_lock.pl --print-version    # só a chave de conteúdo
#
# Saída:
#   data_pipeline/datasets.lock.json  (default; versionado no git)
#
# Fluxo recomendado: rodar `--write` depois de uma carga e commitar o lockfile;
# rodar `--verify` no CI (ou antes de publicar um número) para denunciar deriva.
#
# O lockfile descreve o banco de DEV (`database.edumaps`): `--verify` só faz
# sentido contra a MESMA base que gerou o arquivo.
# ============================================================================

my $DEFAULT_LOCK = "$FindBin::Bin/../../data_pipeline/datasets.lock.json";

my %opt = (lock => $DEFAULT_LOCK);
GetOptions(
  'write'         => \$opt{write},
  'verify'        => \$opt{verify},
  'check-files'   => \$opt{check_files},
  'print-version' => \$opt{print_version},
  'out=s'         => \$opt{out},
  'lock=s'        => \$opt{lock},
) or die "uso: $0 [--write | --verify | --print-version] [--check-files] [--out F | --lock F]\n";

$opt{out} = $opt{lock} if $opt{write} && !defined $opt{out};

my @acoes = grep { $opt{$_} } qw(write verify print_version);
die "escolha no máximo uma ação entre --write/--verify/--print-version\n" if @acoes > 1;
die "informe uma ação (--write/--verify/--print-version/--check-files)\n"
  unless @acoes || $opt{check_files};

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $schema = EduMaps::Schema->go;
my $dbh    = $schema->storage->dbh;
my $lockm  = EduMaps::Ingestion::DatasetsLock->new;

my $exit = 0;

# Lê um arquivo como texto UTF-8.
sub _slurp_utf8 ($path) {
  open my $fh, '<:encoding(UTF-8)', $path or die "não abri $path: $!\n";
  local $/;
  return <$fh>;
}

# --- --print-version / --write / --verify (mutuamente exclusivas) -----------
if (@acoes) {
  my $lock = $lockm->from_db($dbh);

  if ($opt{print_version}) {
    print $lockm->dataset_version($lock), "\n";
  }
  elsif ($opt{write}) {
    my $doc = $lockm->document($lock);
    open my $fh, '>:encoding(UTF-8)', $opt{out} or die "não abri $opt{out}: $!\n";
    print {$fh} $lockm->pretty_json($doc), "\n";
    close $fh;
    my $n       = scalar @{ $doc->{tables} };
    my $com_raw = scalar grep { @{ $_->{raw} } } @{ $doc->{tables} };
    print "datasets.lock.json escrito em $opt{out}\n";
    print "  tabelas: $n ($com_raw com hashes raw)\n";
    print "  dataset_version: $doc->{dataset_version}\n";
  }
  elsif ($opt{verify}) {
    die "lockfile não encontrado: $opt{lock} (rode --write)\n" unless -f $opt{lock};
    my $doc = JSON::PP->new->decode(_slurp_utf8($opt{lock}));

    my @drift       = @{ $lockm->diff($doc, $lock) };
    my $dv_esperado = $doc->{dataset_version} // '(sem dataset_version)';
    my $dv_atual    = $lockm->dataset_version($lock);

    if (!@drift && $dv_esperado eq $dv_atual) {
      print "datasets.lock.json OK — sem deriva (dataset_version $dv_atual)\n";
    }
    else {
      print "DERIVA detectada entre o lockfile e a base:\n";
      print "  dataset_version lock=$dv_esperado base=$dv_atual\n" if $dv_esperado ne $dv_atual;
      print "  $_\n" for @drift;
      $exit = 1;
    }
  }
}

# --- --check-files (ortogonal; re-hash dos blobs preservados) ---------------
if ($opt{check_files}) {
  my $rows = $dbh->selectall_arrayref(
    q{SELECT table_name, raw_manifest FROM clean.import_metadata
       WHERE raw_manifest IS NOT NULL AND jsonb_array_length(raw_manifest) > 0},
    { Slice => {} },
  );
  my ($ok, $falta, $mudou) = (0, 0, 0);
  for my $r (@$rows) {
    my $m = $r->{raw_manifest};
    $m = JSON::PP->new->decode($m) if defined $m && !ref $m;
    for my $e (@{ $m // [] }) {
      my $f = $e->{caminho};
      next unless defined $f && length $f;
      if (!-f $f) {
        print "FALTA  $r->{table_name}: $f\n";
        $falta++;
        next;
      }
      open my $bf, '<:raw', $f or die "não abri $f: $!\n";
      my $sha = Digest::SHA->new(256)->addfile($bf)->hexdigest;
      close $bf;
      if (($e->{sha256} // '') ne $sha) {
        print "MUDOU  $r->{table_name}: $f (base=$e->{sha256} disco=$sha)\n";
        $mudou++;
      }
      else {
        $ok++;
      }
    }
  }
  print "blobs: $ok ok, $falta faltando, $mudou alterados\n";
  $exit = 1 if $falta + $mudou;
}

exit $exit;
