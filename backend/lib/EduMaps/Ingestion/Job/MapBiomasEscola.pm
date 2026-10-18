package EduMaps::Ingestion::Job::MapBiomasEscola;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Text::CSV;

# =============================================================================
# MapBiomas: cobertura do solo (raster 30 m) na área de influência da escola
# (#255, bloco F do IVET; docs/analises/influencia.md §4 Tier 1 / §8)
# =============================================================================
#
# Fonte (COG público, sem token; PINADA):
#   https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/
#     collection11/lulc/coverage/brazil_coverage/brazil_coverage-col11_<ANO>.tif
# Coleção 11, 1985–2025, ~748 MB/ano, EPSG:4326, 30 m, categórico (código da
# legenda). O ano é VALIDADO no intervalo e o caminho nunca é montado com
# texto do usuário.
#
# Por que aqui e não no PostGIS: o raster de 30 m não cabe no banco (~22 GB/ano
# descomprimido; a base do produto tem ~5,5 GB livres). O COG é lido em
# streaming, no host de ingestão (backend.edumaps, que tem GDAL 3.6.2 e o
# pacote R `terra` instalado pelo Rex), e só as frações vão para a base.
#
# Fluxo:
#   1. exporta os buffers (clean.escola_influencia, tier='buffer') em GeoJSON;
#   2. baixa o COG do ano (preservado no raw, com manifesto);
#   3. roda extract_mapbiomas_escola.R (terra::extract, weights=TRUE) -> CSV;
#   4. carga transacional (o recorte ano×raio é SUBSTITUÍDO) + metadados.
#
# Regra #154: buffer sem interseção com o raster fica SEM LINHA (nunca 0) e
# aparece no relatório de órfãos.
#
# Args (--arg): anos=2024 (aceita lista/intervalo, 1985..2025); uf=SP (recorte
# por UF, para piloto/lote); raio=1000 (500, 1000 ou 2000 — os raios
# materializados em clean.escola_influencia); nu_ano_censo=2025 (opcional).
# =============================================================================

has job_name      => 'MapBiomasEscola';
has description   => 'Ingestão MapBiomas: cobertura do solo (raster 30 m, Coleção 11) na área de influência da escola';
has schedule      => 'annual';
# COG de ~748 MB + arealização de dezenas de milhares de buffers: a parte
# pesada passa minutos sem tocar data/ingestao (watchdog do Runner, #238).
has stall_timeout => 3600;

use constant {
  TAB         => 'clean.mapbiomas_escola',
  URL_COG     => 'https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection11/lulc/coverage/brazil_coverage/brazil_coverage-col11_%d.tif',
  COLECAO     => 'collection11',
  LICENCA     => 'CC-BY-4.0 (MapBiomas)',
  ANO_MIN     => 1985,
  ANO_MAX     => 2025,
  ANO_PADRAO  => 2024,
  RAIO_PADRAO => 1000,
  LOTE        => 1000,
};

my @RAIOS_VALIDOS = (500, 1000, 2000);
my @COLUNAS = qw(co_entidade nu_ano_censo ano raio_m classe classe_desc fracao);

sub tabelas ($self, $args = {}) { return (TAB) }

sub run ($self, $args = {}) {
  my @anos = $self->anos($args);
  my $raio = $self->raio($args);
  my $uf   = $self->uf($args);
  my $nuc  = $self->nu_ano_censo($args);

  return $self->_dry_run_sanidade(\@anos, $raio, $uf) if $self->dry_run;

  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;

  my $buffers = "$dir/mapbiomas_escola_buffers.geojson";
  my $n_buffers = $self->exportar_buffers($buffers, $raio, $uf, $nuc);
  die sprintf("MapBiomasEscola: nenhum buffer para raio=%d%s\n",
      $raio, defined $uf ? " uf=$uf" : '') unless $n_buffers;

  # NÃO usar `my (@todas, $n_orfaos) = ((), 0)`: medido a 2026-10-18, essa
  # forma deixa @todas = ("0") e $n_orfaos = undef — o "0" do lado direito
  # acaba DENTRO do array (a lista `((), 0)` é avaliada como um escalar) e a
  # carga recebe um "0" no lugar de uma linha ("Can't use string as HASH ref").
  my @todas;
  my $n_orfaos = 0;
  for my $ano (@anos) {
    my $cog = $self->download_file($self->url_cog($ano), undef, {}, tabelas => [TAB]);

    my $csv = "$dir/mapbiomas_escola_$ano.csv";
    my $orf = "$dir/mapbiomas_escola_orfaos_$ano.csv";
    $self->run_r_script($self->caminho_rscript('extract_mapbiomas_escola.R'), [
      "--buffers=$buffers", "--raster=$cog", "--ano=$ano", "--raio=$raio",
      "--saida=$csv", "--orfaos=$orf",
    ]);

    $n_orfaos += $self->registrar_orfaos($orf, $ano);
    push @todas, @{ $self->process_csv($csv, $ano, $raio) };
  }

  die "MapBiomasEscola: nenhuma linha extraída (ver o relatório de órfãos)\n"
    unless @todas;

  my $n = $self->carregar(\@todas, \@anos, $raio);
  my %cl = map { $_->{classe} => 1 } @todas;
  $self->log_info(sprintf('MapBiomasEscola: %d linhas (%d buffers, %d classes, %s) em %s',
    $n, $n_buffers, scalar keys %cl, _faixa(\@anos), TAB));

  $self->upsert_metadata(TAB,
    sprintf('brazil_coverage-col11_%s.tif', _faixa(\@anos)),
    $self->url_cog($anos[0]), LICENCA, $n,
    sprintf('Arealização do raster de cobertura MapBiomas (Coleção 11, %s) sobre o buffer de %d m (%s). '
      . 'Fração por classe-folha; soma 1 por escola × ano × raio. %d buffers de entrada; órfãos (sem '
      . 'interseção com o raster): %d — sem linha, nunca 0 (#154). Legenda nível 4; grupos na view '
      . 'clean.v_mapbiomas_escola_grupos. Job MapBiomasEscola (#255).',
      _faixa(\@anos), $raio, $uf // 'BR', $n_buffers, $n_orfaos));
  return $n;
}

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------
# Anos: "2024", "2015-2024", "2019,2021-2024"; dentro de 1985..2025 (Coleção 11).
sub anos ($self, $args) {
  my $spec = $args->{anos} // $args->{ano} // ANO_PADRAO;
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
  die sprintf("anos=%s: a Coleção 11 cobre %d–%d (fora: %s)\n", $spec, ANO_MIN, ANO_MAX,
    join(',', sort @fora)) if @fora;
  die "anos=$spec: nenhum ano\n" unless %anos;
  return sort { $a <=> $b } keys %anos;
}

sub raio ($self, $args) {
  my $r = $args->{raio} // RAIO_PADRAO;
  die "raio=$r: use um dos raios materializados em clean.escola_influencia: @RAIOS_VALIDOS\n"
    unless grep { $_ == $r } @RAIOS_VALIDOS;
  return 0 + $r;
}

sub uf ($self, $args) {
  my $uf = $args->{uf};
  return undef unless defined $uf && length $uf;
  $uf = uc $uf;
  die "uf=$uf: use a sigla de 2 letras (ex.: SP)\n" unless $uf =~ /^[A-Z]{2}$/;
  return $uf;
}

sub nu_ano_censo ($self, $args) {
  my $n = $args->{nu_ano_censo};
  return undef unless defined $n && length $n;
  die "nu_ano_censo=$n: esperado AAAA\n" unless $n =~ /^\d{4}$/;
  return 0 + $n;
}

sub _faixa ($anos) {
  my @a = @$anos;
  return "$a[0]–$a[-1]" if @a > 1 && $a[-1] - $a[0] == $#a;
  return join(',', @a);
}

# URL do COG — pinada na Coleção 11, ano validado. Nunca interpolar texto livre.
sub url_cog ($self, $ano) {
  die "ano inválido: " . (defined $ano ? "'$ano'" : '(vazio)') . "\n"
    unless defined $ano && $ano =~ /^\d{4}$/ && $ano >= ANO_MIN && $ano <= ANO_MAX;
  return sprintf(URL_COG, $ano);
}

# -----------------------------------------------------------------------------
# Dry-run honesto: HEAD do COG (allowlist + alcance) + presença do terra.
# -----------------------------------------------------------------------------
sub _dry_run_sanidade ($self, $anos, $raio, $uf) {
  for my $ano (@$anos) {
    my $url = $self->url_cog($ano);
    $self->exigir_allowlist($url);
    my $res = $self->run_with_retry(sub {
      my $tx = $self->ua->head($url);
      die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
      return $tx->result;
    }, "HEAD $url");
    $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d, %s bytes',
      $url, $res->code, $res->headers->content_length // '?'));
  }
  my $terra_ok = eval {
    qx{Rscript --vanilla -e 'quit(status = !requireNamespace("terra", quietly = TRUE))' 2>/dev/null};
    ($? >> 8) == 0 ? 1 : 0;
  };
  $self->log->warn('[DRY-RUN] pacote R terra AUSENTE — a arealização não vai correr (Rex deploy_minion_dev instala-o)')
    unless $terra_ok;
  $self->log_info(sprintf('[DRY-RUN] MapBiomasEscola: Coleção 11, anos %s, raio %d m%s; nada exportado, baixado nem gravado',
    _faixa($anos), $raio, defined $uf ? ", uf $uf" : ''));
  return 0;
}

# -----------------------------------------------------------------------------
# Caminhos (derivados de __FILE__, não do diretório de trabalho)
# -----------------------------------------------------------------------------
sub dir_rscript ($self) {
  return path(__FILE__)->dirname->dirname->dirname->dirname->dirname
    ->child('templates', 'rscripts', 'ingestion');
}

sub caminho_rscript ($self, $nome) {
  my $p = $self->dir_rscript->child($nome);
  die "Script R não encontrado: $p\n" unless -f $p;
  return $p->to_string;
}

# -----------------------------------------------------------------------------
# 1. Exportar os buffers em GeoJSON (o R não toca na base de dados).
#    O join com censo_escolas dá o filtro de UF; a geometria sai em 4674.
# -----------------------------------------------------------------------------
sub exportar_buffers ($self, $destino, $raio, $uf, $nu_ano_censo) {
  my $dbh = $self->app->schema->storage->dbh;
  my $sql = q{
    SELECT i.co_entidade, i.nu_ano_censo, ST_AsGeoJSON(i.geom) AS geom
      FROM clean.escola_influencia i
      JOIN clean.censo_escolas e
        ON e.co_entidade = i.co_entidade AND e.nu_ano_censo = i.nu_ano_censo
     WHERE i.tier = 'buffer' AND i.raio_m = ?
  };
  my @p = ($raio);
  if (defined $uf)           { $sql .= ' AND e.sg_uf = ?';        push @p, $uf }
  if (defined $nu_ano_censo) { $sql .= ' AND i.nu_ano_censo = ?'; push @p, $nu_ano_censo }
  $sql .= ' ORDER BY i.co_entidade, i.nu_ano_censo';

  my $sth = $dbh->prepare($sql);
  $sth->execute(@p);

  $self->_garantir_dir($destino);
  open my $fh, '>:encoding(UTF-8)', $destino or die "Não abriu $destino: $!\n";
  print {$fh} '{"type":"FeatureCollection","features":[';
  my ($n, $sep) = (0, '');
  while (my $r = $sth->fetchrow_arrayref) {
    my ($co, $ano, $geom) = @$r;
    next unless defined $geom && length $geom;
    print {$fh} $sep,
      '{"type":"Feature","properties":{"co_entidade":', 0 + $co,
      ',"nu_ano_censo":', 0 + $ano, '},"geometry":', $geom, '}';
    $sep = ','; $n++;
  }
  print {$fh} ']}';
  close $fh or die "Não fechou $destino: $!\n";

  $self->log_info(sprintf('Buffers exportados: %d (raio %d m%s) -> %s',
    $n, $raio, defined $uf ? ", uf $uf" : '', $destino));
  return $n;
}

# -----------------------------------------------------------------------------
# 3. Relatório de órfãos: buffers sem NENHUMA interseção com o raster válido.
#    É a regra #154 materializada — não entram com 0.
# -----------------------------------------------------------------------------
sub registrar_orfaos ($self, $path, $ano) {
  return 0 unless -f $path;
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 0, eol => "\n" });
  open my $fh, '<:encoding(UTF-8)', $path or do {
    $self->log_error("Relatório de órfãos ilegível: $path — $!");
    return 0;
  };
  $csv->getline($fh);    # cabeçalho
  my ($n, @amostra) = (0);
  while (my $r = $csv->getline($fh)) {
    next unless defined $r->[0] && length $r->[0];
    $n++;
    push @amostra, $r->[0] if @amostra < 10;
  }
  close $fh;

  if ($n) {
    $self->log->warn(sprintf('[MapBiomasEscola] %d buffer(s) sem interseção com o raster em %d '
      . '(sem linha, #154). Amostra: %s. Relatório: %s', $n, $ano, join(', ', @amostra), $path));
  } else {
    $self->log_info("Órfãos em $ano: 0 — todos os buffers cruzaram o raster");
  }
  return $n;
}

# -----------------------------------------------------------------------------
# 4a. Ler o CSV do R, validando o contrato ANTES de uma linha ser aceita.
# -----------------------------------------------------------------------------
sub process_csv ($self, $csv_path, $ano, $raio) {
  die "Não encontrei o CSV de saída: $csv_path\n" unless -f $csv_path;

  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(UTF-8)', $csv_path or die "Não abriu $csv_path: $!\n";
  my $header = $csv->getline($fh);
  die "CSV vazio: $csv_path\n" unless $header;

  my @dif = $self->_comparar_colunas($header, \@COLUNAS);
  die sprintf("O CSV não corresponde ao contrato de " . TAB . ".\n"
      . "  faltam: %s\n  a mais: %s\n  fora de ordem: %s\nEsperado: %s\nRecebido:  %s\n",
      (join(', ', map  { $_->[0] } grep { !defined $_->[2] } @dif) || '(nenhuma)'),
      (join(', ', map  { $_->[0] } grep { !defined $_->[1] } @dif) || '(nenhuma)'),
      (join(', ', map  { sprintf('%s (no CSV na %d, no contrato na %d)',
                                $_->[0], $_->[2] + 1, $_->[1] + 1) }
             grep { defined $_->[1] && defined $_->[2] } @dif) || '(nenhuma)'),
      join(', ', @COLUNAS), join(', ', @$header))
    if @dif;

  my @rows;
  my $linha = 1;
  while (my $r = $csv->getline($fh)) {
    $linha++;
    my %row = map { $header->[$_] => $r->[$_] } 0 .. $#$header;
    die sprintf("Linha %d: co_entidade vazia ou não numérica ('%s')\n",
      $linha, $row{co_entidade} // '') unless defined $row{co_entidade} && $row{co_entidade} =~ /^\d+$/;
    die sprintf("Linha %d: ano %s fora de %d..%d\n", $linha, $row{ano} // '', ANO_MIN, ANO_MAX)
      unless defined $row{ano} && $row{ano} =~ /^\d{4}$/ && $row{ano} >= ANO_MIN && $row{ano} <= ANO_MAX;
    die sprintf("Linha %d: fração '%s' fora de [0,1] (#154)\n", $linha, $row{fracao} // '')
      unless defined $row{fracao} && $row{fracao} =~ /^\d*\.?\d+$/ && $row{fracao} >= 0 && $row{fracao} <= 1;
    push @rows, \%row;
  }
  close $fh;

  $self->log_info(sprintf('CSV de %d processado: %d linhas', $ano, scalar @rows));
  return \@rows;
}

# -----------------------------------------------------------------------------
# 4b. Carga: o recorte (ano × raio) é SUBSTITUÍDO por inteiro numa transação —
#     uma classe que deixou de existir num buffer não pode ficar para trás.
# -----------------------------------------------------------------------------
sub carregar ($self, $rows, $anos, $raio) {
  my $dbh = $self->app->schema->storage->dbh;
  my $n = 0;
  my $ok = eval {
    $self->app->schema->storage->txn_do(sub {
      $dbh->do('DELETE FROM ' . TAB . ' WHERE ano = ANY(?::smallint[]) AND raio_m = ?',
        undef, $anos, $raio);
      for (my $i = 0; $i < @$rows; $i += LOTE) {
        my $fim = $i + LOTE - 1;
        $fim = $#$rows if $fim > $#$rows;
        my @lote = @{$rows}[ $i .. $fim ];
        my $sql = 'INSERT INTO ' . TAB
          . ' (co_entidade, nu_ano_censo, ano, raio_m, classe, classe_desc, fracao, colecao) VALUES '
          . join(',', ('(?, ?, ?, ?, ?, ?, ?, ?)') x @lote)
          . ' ON CONFLICT (co_entidade, nu_ano_censo, ano, raio_m, classe) DO UPDATE SET'
          . ' classe_desc = EXCLUDED.classe_desc, fracao = EXCLUDED.fracao,'
          . ' colecao = EXCLUDED.colecao, computado_em = now()';
        # `for` explícito, não `map { $_->{...} }`: um elemento que não seja
        # hashref tem de morrer com o índice, não com "Can't use string as
        # HASH ref" (que foi como o defeito do acumulador apareceu, 2026-10-18).
        my @bind;
        for my $r (@lote) {
          die "MapBiomasEscola: linha de carga não é hashref: " . (defined $r ? "'$r'" : 'undef') . "\n"
            unless ref $r eq 'HASH';
          push @bind, $r->{co_entidade}, $r->{nu_ano_censo}, $r->{ano}, $r->{raio_m},
                      $r->{classe}, $r->{classe_desc}, $r->{fracao}, COLECAO;
        }
        $dbh->do($sql, undef, @bind);
        $n += @lote;
      }
    });
    1;
  };
  die "MapBiomasEscola: carga falhou, nada gravado: $@" unless $ok;
  return $n;
}

sub _garantir_dir ($self, $file) {
  my ($dir) = $file =~ m{^(.*)/[^/]+$};
  return unless $dir && !-d $dir;
  require File::Path;
  File::Path::make_path($dir);
  $self->log_info("Directório de trabalho criado: $dir");
}

1;
