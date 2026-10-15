package EduMaps::Ingestion::Job::MapBiomas;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Text::CSV;

# =============================================================================
# MapBiomas: cobertura e uso da terra por município (#241, fase P3 da #156)
# =============================================================================
#
# Fonte (decisão do developer, spec §8): a ESTATÍSTICA OFICIAL da Coleção 10,
# publicada pelo próprio MapBiomas no bucket público, sem token:
#   collection_10/lulc/statistics/MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx
# Não se processa raster: os números são os do MapBiomas, não um cálculo
# zonal nosso. A Coleção 11 (só raster, 2018–2025) entra quando o MapBiomas
# publicar a estatística dela.
#
# Aba COVERAGE_10 (verificada em 2026-10-13): uma linha por município ×
# BIOMA × classe (79.285 linhas, 5.571 geocodes, 31 classes-folha), com a
# área de 1985 a 2024 em colunas. Unidade: hectares (READ_ME: "áreas (ha)
# por classe"). Um município em dois biomas aparece duas vezes: a carga
# SOMA os biomas por (município, classe, ano).
#
# Leitura via GDAL (driver XLSX, ogr2ogr -> CSV): sem dependência CPAN nova;
# o gdal-bin já é instalado no backend pelo Rex (#238). HEADERS=FORCE é
# obrigatório: com anos numéricos no cabeçalho, o driver toma a 1ª linha por
# dado e devolve Field1..Field54. Vai como --config OGR_XLSX_HEADERS, não como
# -oo: o GDAL 3.6.2 do backend ignora a open option (medido na carga, #241);
# o config option vale no 3.6 e no 3.10.
#
# classe = código numérico da legenda (texto), classe_desc = nível mais
# específico (class_level_4). A classe 0 ("Not Observed") é área real e
# entra. Geocode do XLSX que não exista em clean.malha_municipio vai para o
# relatório de órfãos, nunca some em silêncio — mas o conjunto depende da
# malha carregada: a nacional inclui as "Áreas Operacionais" 4300001/4300002
# das lagoas (não são órfãs), enquanto um recorte que as omita as torna órfãs.
#
# Args (--arg): anos=2015-2024 (padrão, decisão do developer; aceita lista e
# intervalos: 2019,2021-2024); xlsx=<arquivo> relê um bruto já baixado.
# =============================================================================

has job_name    => 'MapBiomas';
has description => 'Ingestão MapBiomas: cobertura e uso da terra por município (estatística oficial da Coleção 10)';
has schedule    => 'quarterly';

# ogr2ogr do xlsx + ~690 mil linhas numa transação só: a parte do banco
# passa minutos sem tocar data/ingestao (ver o watchdog do Runner, #238).
has stall_timeout => 1800;

use constant {
  TAB       => 'clean.mapbiomas_cobertura',
  URL_XLSX  => 'https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection_10/lulc/statistics/MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx',
  CAMADA    => 'COVERAGE_10',
  COLECAO   => 'collection10',
  LICENCA   => 'CC-BY-4.0 (MapBiomas)',
  ANO_MIN   => 1985,
  ANO_MAX   => 2024,
  ANOS_PADRAO => '2015-2024',
  LOTE      => 1000,
};

# Colunas da aba COVERAGE_10 que o loader usa (além dos anos).
our @COLUNAS = qw(geocode class class_level_4 municipality);

sub tabelas ($self, $args = {}) { return (TAB) }

sub run ($self, $args = {}) {
  my @anos = $self->anos($args);
  return $self->_dry_run_sanidade($args, \@anos) if $self->dry_run;

  my $xlsx = $self->_obter_xlsx($args);
  my $dir  = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;
  my $csv = $dir->child('mapbiomas_col10_coverage.csv');
  $self->xlsx_para_csv($xlsx, "$csv");

  my $ag = $self->agregar("$csv", \@anos);
  my $malha = $self->municipios_malha;
  my ($linhas, $orfaos) = $self->separar_orfaos($ag, $malha);
  my $n_orfaos = $self->registrar_orfaos($orfaos, $dir->child('mapbiomas_orfaos.csv'));
  die "MapBiomas: nenhuma linha casou com clean.malha_municipio\n" unless @$linhas;

  my $n = $self->carregar($linhas, \@anos);
  my %mun = map { $_->{codigo_ibge} => 1 } @$linhas;
  $self->log_info(sprintf('MapBiomas: %d linhas (%d municípios, %d classes, anos %s) em %s',
    $n, scalar keys %mun, scalar keys %{ $ag->{desc} }, _faixa(\@anos), TAB));

  $self->upsert_metadata(TAB, 'MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx (aba ' . CAMADA . ')',
    URL_XLSX, LICENCA, $n,
    sprintf('Estatística oficial do MapBiomas, Coleção 10 (colecao=%s), por município × classe × ano; '
      . 'anos %s. Área em hectares (READ_ME da planilha); area_km2 = area_ha/100. Biomas somados por município '
      . '(%d linhas lidas de município × bioma × classe). classe = código da legenda, classe_desc = class_level_4; '
      . 'classe 0 = Not Observed. %d município(s), %d classe(s). Órfãos (geocode fora da malha_municipio): %d '
      . '(mapbiomas_orfaos.csv). Loader: job MapBiomas (#241).',
      COLECAO, _faixa(\@anos), $ag->{lidas}, scalar keys %mun, scalar keys %{ $ag->{desc} }, $n_orfaos));
  return $n;
}

# -----------------------------------------------------------------------------
# Anos: "2015-2024", "2019,2021-2024"; dentro de 1985..2024 (a Coleção 10).
# -----------------------------------------------------------------------------
sub anos ($self, $args) {
  my $spec = $args->{anos} // ANOS_PADRAO;
  my %anos;
  for my $parte (split /\s*,\s*/, "$spec") {
    next unless length $parte;
    if ($parte =~ /^(\d{4})\s*-\s*(\d{4})$/) {
      die "anos=$spec: intervalo invertido ($parte)\n" if $1 > $2;
      $anos{$_} = 1 for $1 .. $2;
    }
    elsif ($parte =~ /^\d{4}$/) { $anos{$parte} = 1 }
    else { die "anos=$spec: use AAAA, AAAA-AAAA ou lista separada por vírgula\n" }
  }
  my @fora = grep { $_ < ANO_MIN || $_ > ANO_MAX } keys %anos;
  die sprintf("anos=%s: a Coleção 10 cobre %d–%d (fora: %s)\n", $spec, ANO_MIN, ANO_MAX,
    join(',', sort @fora)) if @fora;
  die "anos=$spec: nenhum ano\n" unless %anos;
  return sort { $a <=> $b } keys %anos;
}

sub _faixa ($anos) {
  my @a = @$anos;
  return "$a[0]–$a[-1]" if @a > 1 && $a[-1] - $a[0] == $#a;
  return join(',', @a);
}

# -----------------------------------------------------------------------------
# Dry-run honesto: uma requisição de sanidade (HEAD) + presença do ogr2ogr.
# -----------------------------------------------------------------------------
sub _dry_run_sanidade ($self, $args, $anos) {
  unless ($args->{xlsx}) {
    $self->exigir_allowlist(URL_XLSX);
    my $res = $self->run_with_retry(sub {
      my $tx = $self->ua->head(URL_XLSX);
      die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
      return $tx->result;
    }, 'HEAD ' . URL_XLSX);
    $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d, %s bytes',
      URL_XLSX, $res->code, $res->headers->content_length // '?'));
  }
  my $versao = $self->_ogr2ogr_versao;
  die "[DRY-RUN] ogr2ogr ausente: a leitura do xlsx exige gdal-bin (Rex deploy_minion_dev)\n"
    unless $versao;
  $self->log_info("[DRY-RUN] $versao");
  $self->log_info(sprintf('[DRY-RUN] MapBiomas: Coleção 10, anos %s; nada baixado nem gravado', _faixa($anos)));
  return 0;
}

sub _ogr2ogr_versao ($self) {
  my $v = `ogr2ogr --version 2>/dev/null`;
  chomp $v if defined $v;
  return $v;
}

sub _obter_xlsx ($self, $args) {
  my $tab = [TAB];
  if (my $local = $args->{xlsx}) {
    die "xlsx não existe: $local\n" unless -f $local;
    $self->log_info("Relendo o bruto $local (sem download)");
    $self->preservar_raw($local, URL_XLSX, tabelas => $tab);
    return $local;
  }
  return $self->download_file(URL_XLSX, undef, {}, tabelas => $tab);
}

# -----------------------------------------------------------------------------
# xlsx -> CSV (GDAL). O ogr2ogr não sobrescreve um CSV existente: apaga antes.
# -----------------------------------------------------------------------------
sub comando_xlsx_csv ($self, $xlsx, $csv) {
  return ['ogr2ogr', '--config', 'OGR_XLSX_HEADERS', 'FORCE',
          '--config', 'OGR_XLSX_FIELD_TYPES', 'STRING',
          '-f', 'CSV', $csv, $xlsx, CAMADA];
}

sub xlsx_para_csv ($self, $xlsx, $csv) {
  unlink $csv;
  $self->log_info("ogr2ogr: $xlsx (aba " . CAMADA . ") -> $csv");
  $self->executar($self->comando_xlsx_csv($xlsx, $csv));
  die "ogr2ogr não gerou $csv\n" unless -s $csv;
  return $csv;
}

# Ponto de execução isolado (os testes substituem).
sub executar ($self, $argv) {
  my $rc = system { $argv->[0] } @$argv;
  die sprintf("%s falhou (rc=%d)\n", $argv->[0], $rc == -1 ? -1 : $rc >> 8) if $rc;
  return 1;
}

# -----------------------------------------------------------------------------
# Agregação: soma por (geocode, classe, ano) sobre os biomas.
# Devolve { soma => {"geocode|classe|ano" => ha}, desc => {classe => texto},
#           nome => {geocode => "Município - UF"}, lidas => n }
# -----------------------------------------------------------------------------
sub agregar ($self, $csv_path, $anos) {
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(UTF-8)', $csv_path or die "Não leu $csv_path: $!\n";
  my $header = $csv->getline($fh) or die "MapBiomas: CSV vazio: $csv_path\n";
  $header->[0] =~ s/^\x{FEFF}//;
  my %idx = map { $header->[$_] => $_ } 0 .. $#$header;
  my @falta = grep { !exists $idx{$_} } (@COLUNAS, @$anos);
  die sprintf("MapBiomas: faltam colunas na aba %s: %s\nRecebido: %s\n",
    CAMADA, join(', ', @falta), join(', ', @$header)) if @falta;

  my (%soma, %desc, %nome);
  my $lidas = 0;
  while (my $r = $csv->getline($fh)) {
    $lidas++;
    my $geo = $r->[ $idx{geocode} ] // '';
    my $cls = $r->[ $idx{class} ] // '';
    $geo =~ s/^\s+|\s+$//g;
    $cls =~ s/^\s+|\s+$//g;
    $cls =~ s/\.0+$//;    # "3.0" -> "3" se o driver devolver real
    die "MapBiomas: linha $lidas sem geocode/classe válidos ('$geo', '$cls')\n"
      unless $geo =~ /^\d{7}$/ && $cls =~ /^\d+$/;
    my $d = $r->[ $idx{class_level_4} ] // '';
    $d =~ s/^\s+|\s+$//g;
    $desc{$cls} //= $d;
    $nome{$geo} //= $r->[ $idx{municipality} ];
    for my $ano (@$anos) {
      my $v = $r->[ $idx{$ano} ];
      next unless defined $v && $v =~ /\S/;
      die "MapBiomas: área não numérica em $geo/$cls/$ano: '$v'\n"
        unless $v =~ /^\s*-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?\s*$/;
      $soma{"$geo|$cls|$ano"} += $v;
    }
  }
  close $fh;
  $self->log_info(sprintf('MapBiomas: %d linhas (município × bioma × classe) lidas; %d combinações município × classe × ano',
    $lidas, scalar keys %soma));
  return { soma => \%soma, desc => \%desc, nome => \%nome, lidas => $lidas };
}

# Códigos da malha (a FK lógica do resto do schema).
sub municipios_malha ($self) {
  my $dbh = $self->app->schema->storage->dbh;
  my $rows = $dbh->selectall_arrayref(
    'SELECT codigo_ibge FROM clean.malha_municipio WHERE codigo_ibge IS NOT NULL');
  return { map { $_->[0] => 1 } @$rows };
}

# Linhas da tabela + órfãos (geocode fora da malha), agregados por município.
sub separar_orfaos ($self, $ag, $malha) {
  my (@linhas, %orf);
  for my $k (sort keys %{ $ag->{soma} }) {
    my ($geo, $cls, $ano) = split /\|/, $k;
    my $ha = $ag->{soma}{$k};
    if (!$malha->{$geo}) {
      my $o = $orf{$geo} //= { geocode => $geo, nome => $ag->{nome}{$geo} // '', area_ha => 0, linhas => 0 };
      $o->{area_ha} += $ha;
      $o->{linhas}++;
      next;
    }
    push @linhas, {
      codigo_ibge => $geo, ano => $ano, classe => $cls,
      classe_desc => $ag->{desc}{$cls}, area_ha => $ha, area_km2 => $ha / 100,
    };
  }
  return (\@linhas, [ map { $orf{$_} } sort keys %orf ]);
}

sub registrar_orfaos ($self, $orfaos, $destino) {
  my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
  open my $fh, '>:encoding(UTF-8)', "$destino" or die "Não escreveu $destino: $!\n";
  $csv->print($fh, [qw(geocode nome linhas area_ha)]);
  $csv->print($fh, [ @{$_}{qw(geocode nome linhas)}, sprintf('%.4f', $_->{area_ha}) ]) for @$orfaos;
  close $fh;
  if (@$orfaos) {
    $self->log->warn(sprintf('[MapBiomas] Órfãos (fora da malha_municipio): %s. Relatório: %s',
      join(', ', map { "$_->{geocode} $_->{nome}" } @$orfaos), $destino));
  }
  return scalar @$orfaos;
}

# -----------------------------------------------------------------------------
# Carga: o recorte (colecao, anos) é SUBSTITUÍDO por inteiro numa transação —
# uma classe que deixou de existir num município não pode ficar para trás.
# Inserção em lotes de LOTE linhas (VALUES múltiplo); ON CONFLICT mantém a
# idempotência mesmo sem o DELETE.
# -----------------------------------------------------------------------------
sub carregar ($self, $linhas, $anos) {
  my $dbh = $self->app->schema->storage->dbh;
  my $n = 0;
  my $ok = eval {
    $self->app->schema->storage->txn_do(sub {
      $dbh->do('DELETE FROM ' . TAB . ' WHERE colecao = ? AND ano = ANY(?::smallint[])',
        undef, COLECAO, $anos);
      for (my $i = 0; $i < @$linhas; $i += LOTE) {
        my $fim = $i + LOTE - 1;
        $fim = $#$linhas if $fim > $#$linhas;
        my @lote = @{$linhas}[ $i .. $fim ];
        my $sql = 'INSERT INTO ' . TAB
          . ' (codigo_ibge, ano, colecao, classe, classe_desc, area_ha, area_km2) VALUES '
          . join(',', ('(?, ?, ?, ?, ?, ?, ?)') x @lote)
          . ' ON CONFLICT (codigo_ibge, ano, colecao, classe) DO UPDATE SET'
          . ' classe_desc = EXCLUDED.classe_desc, area_ha = EXCLUDED.area_ha,'
          . ' area_km2 = EXCLUDED.area_km2, data_acessada = NOW()';
        $dbh->do($sql, undef,
          map { ($_->{codigo_ibge}, $_->{ano}, COLECAO, $_->{classe}, $_->{classe_desc},
                 $_->{area_ha}, $_->{area_km2}) } @lote);
        $n += @lote;
      }
    });
    1;
  };
  die "MapBiomas: carga falhou, nada gravado: $@" unless $ok;
  return $n;
}

1;
