package EduMaps::Ingestion::Job::MapBiomasRisco;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Text::CSV;

# =============================================================================
# MapBiomas: exposição a risco (Fogo + Solo) na área de influência da escola
# (#278, bloco F do IVET)
# =============================================================================
#
# Fontes (COG público, sem token; pinadas), no bucket mapbiomas-public:
#   fogo: brasil/fire/coverage-frequency-1/brasil_fire_frequency_1985_<ANO>.tif
#         (frequência acumulada de queimada — Nº de anos em que o pixel ardeu,
#          1985–ANO; ANO 1985..2020). Medido 2026-10-18: valores 0–35 no país.
#         ⚠️ NÃO usar brasil/fire/frequency/ — o mesmo nome de arquivo, mas os
#         valores estão noutra unidade (0, 115, 121, …, 3541), não em anos.
#   solo: brasil/soil/soil_total_carbon_<ANO>.tif
#         (carbono total do solo, tC/ha; ANO ..2021)
# Ambos 30 m, EPSG:4326, Int16, uma banda. O ANO é validado (1985..2020 — a
# interseção das duas séries).
#
# Mesma arquitetura da #255 (MapBiomasEscola): o raster de 30 m não cabe no
# banco; a arealização lê o COG em *streaming* (`terra::extract`) no host de
# ingestão e grava só o indicador por escola.
#
# Indicadores por buffer (peso = fração da célula no polígono):
#   fogo_frequencia_media  média ponderada da frequência de queimada
#   fogo_frequencia_max    máximo da frequência no buffer
#   fogo_fracao_queimada   fração da área do buffer que já ardeu (freq > 0)
#   solo_carbono_medio     média ponderada do carbono do solo (tC/ha)
#
# Regra #154: buffer sem interseção com um raster → coluna NULL; sem NENHUM
# indicador → SEM LINHA. Nunca 0.
#
# Args (--arg): ano=2020 (1985..2020); uf=SP; raio=1000 (500/1000/2000);
# nu_ano_censo=2025 (opcional).
# =============================================================================

has job_name      => 'MapBiomasRisco';
has description   => 'Ingestão MapBiomas: exposição a risco (Fogo + Solo) na área de influência da escola';
has schedule      => 'annual';
has stall_timeout => 3600;

use constant {
  TAB        => 'clean.mapbiomas_escola_risco',
  URL_FOGO   => 'https://storage.googleapis.com/mapbiomas-public/brasil/fire/coverage-frequency-1/brasil_fire_frequency_1985_%d.tif',
  URL_SOLO   => 'https://storage.googleapis.com/mapbiomas-public/brasil/soil/soil_total_carbon_%d.tif',
  LICENCA    => 'CC-BY-4.0 (MapBiomas)',
  ANO_MIN    => 1985,
  ANO_MAX    => 2020,   # interseção fogo (..2020) × solo (..2021)
  ANO_PADRAO => 2020,
  RAIO_PADRAO => 1000,
};

my @RAIOS_VALIDOS = (500, 1000, 2000);
my @COLUNAS = qw(co_entidade nu_ano_censo ano raio_m
                 fogo_frequencia_media fogo_frequencia_max
                 fogo_fracao_queimada solo_carbono_medio);

sub tabelas ($self, $args = {}) { return (TAB) }

sub run ($self, $args = {}) {
  my @anos = $self->anos($args);
  my $raio = $self->raio($args);
  my $uf   = $self->uf($args);
  my $municipios = $self->municipios($args);
  my $nuc  = $self->nu_ano_censo($args);

  return $self->_dry_run_sanidade(\@anos, $raio, $uf) if $self->dry_run;

  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;

  my $buffers = "$dir/mapbiomas_risco_buffers.geojson";
  my $n_buffers = $self->exportar_buffers($buffers, $raio, $uf, $nuc, $municipios);
  die sprintf("MapBiomasRisco: nenhum buffer para raio=%d%s%s\n",
      $raio, defined $uf ? " uf=$uf" : '',
      defined $municipios ? " municipios=" . scalar(@$municipios) : '') unless $n_buffers;

  my @todas;
  my $n_orfaos = 0;
  for my $ano (@anos) {
    # Os COGs de fogo/solo têm ~2 GB cada e o disco do host de ingestão é
    # pequeno (~3 GB livres): em vez de baixar, lê-se em *streaming* pelo GDAL
    # via /vsicurl (HTTP range). O allowlist é validado aqui antes.
    my $fogo = $self->url_fogo($ano);
    my $solo = $self->url_solo($ano);
    $self->exigir_allowlist($fogo);
    $self->exigir_allowlist($solo);

    my $csv = "$dir/mapbiomas_risco_$ano.csv";
    my $orf = "$dir/mapbiomas_risco_orfaos_$ano.csv";
    $self->run_r_script($self->caminho_rscript('extract_mapbiomas_risco.R'), [
      "--buffers=$buffers", "--raster_fogo=/vsicurl/$fogo", "--raster_solo=/vsicurl/$solo",
      "--ano=$ano", "--raio=$raio", "--saida=$csv", "--orfaos=$orf",
    ]);

    $n_orfaos += $self->registrar_orfaos($orf, $ano);
    push @todas, @{ $self->process_csv($csv) };
  }

  die "MapBiomasRisco: nenhuma linha extraída (ver o relatório de órfãos)\n"
    unless @todas;

  my $n = $self->carregar(\@todas, \@anos, $raio);
  $self->log_info(sprintf('MapBiomasRisco: %d linhas (%d buffers, %s) em %s',
    $n, $n_buffers, _faixa(\@anos), TAB));

  $self->upsert_metadata(TAB,
    sprintf('brasil_fire_frequency_1985_%s.tif + soil_total_carbon_%s.tif',
      _faixa(\@anos), _faixa(\@anos)),
    $self->url_fogo($anos[0]), LICENCA, $n,
    sprintf('Arealização de exposição a risco (MapBiomas Fogo frequência 1985–%s + Solo carbono) sobre o buffer de %d m (%s). '
      . 'Indicadores: frequência de queimada (média/máx/fração) e carbono do solo (média). %d buffers; órfãos '
      . '(sem interseção com os rasters): %d — sem linha, nunca 0 (#154). Job MapBiomasRisco (#278).',
      _faixa(\@anos), $raio, $uf // 'BR', $n_buffers, $n_orfaos));
  return $n;
}

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------
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
  die sprintf("anos=%s: as séries cobrem %d–%d (fora: %s)\n", $spec, ANO_MIN, ANO_MAX,
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

# Lista de códigos IBGE de município (7 dígitos), separados por vírgula — o
# recorte fino para aplicar a extração "aos poucos" (por região/município).
sub municipios ($self, $args) {
  my $m = $args->{municipios};
  return undef unless defined $m && length $m;
  my @c = grep { length } split /\s*,\s*/, $m;
  die "municipios: nenhum código\n" unless @c;
  my @ruins = grep { !/^\d{7}$/ } @c;
  die "municipios: código IBGE inválido: @ruins\n" if @ruins;
  return \@c;
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

sub url_fogo ($self, $ano) {
  die "ano inválido: " . (defined $ano ? "'$ano'" : '(vazio)') . "\n"
    unless defined $ano && $ano =~ /^\d{4}$/ && $ano >= ANO_MIN && $ano <= ANO_MAX;
  return sprintf(URL_FOGO, $ano);
}

sub url_solo ($self, $ano) {
  die "ano inválido: " . (defined $ano ? "'$ano'" : '(vazio)') . "\n"
    unless defined $ano && $ano =~ /^\d{4}$/ && $ano >= ANO_MIN && $ano <= ANO_MAX;
  return sprintf(URL_SOLO, $ano);
}

sub _dry_run_sanidade ($self, $anos, $raio, $uf) {
  for my $ano (@$anos) {
    for my $url ($self->url_fogo($ano), $self->url_solo($ano)) {
      $self->exigir_allowlist($url);
      my $res = $self->run_with_retry(sub {
        my $tx = $self->ua->head($url);
        die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
        return $tx->result;
      }, "HEAD $url");
      $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d, %s bytes',
        $url, $res->code, $res->headers->content_length // '?'));
    }
  }
  my $terra_ok = eval {
    qx{Rscript --vanilla -e 'quit(status = !requireNamespace("terra", quietly = TRUE))' 2>/dev/null};
    ($? >> 8) == 0 ? 1 : 0;
  };
  $self->log->warn('[DRY-RUN] pacote R terra AUSENTE — a arealização não vai correr')
    unless $terra_ok;
  $self->log_info(sprintf('[DRY-RUN] MapBiomasRisco: anos %s, raio %d m%s; nada exportado, baixado nem gravado',
    _faixa($anos), $raio, defined $uf ? ", uf $uf" : ''));
  return 0;
}

# -----------------------------------------------------------------------------
# Caminhos e exportação de buffers (idênticos ao MapBiomasEscola)
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

sub exportar_buffers ($self, $destino, $raio, $uf, $nu_ano_censo, $municipios) {
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
  if (defined $municipios)   { $sql .= ' AND e.co_municipio::text = ANY(?::text[])'; push @p, $municipios }
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

sub registrar_orfaos ($self, $path, $ano) {
  return 0 unless -f $path;
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 0, eol => "\n" });
  open my $fh, '<:encoding(UTF-8)', $path or do {
    $self->log_error("Relatório de órfãos ilegível: $path — $!");
    return 0;
  };
  $csv->getline($fh);
  my ($n, @amostra) = (0);
  while (my $r = $csv->getline($fh)) {
    next unless defined $r->[0] && length $r->[0];
    $n++;
    push @amostra, $r->[0] if @amostra < 10;
  }
  close $fh;
  if ($n) {
    $self->log->warn(sprintf('[MapBiomasRisco] %d buffer(s) sem indicador em %d (sem linha, #154). Amostra: %s',
      $n, $ano, join(', ', @amostra)));
  } else {
    $self->log_info("Órfãos em $ano: 0");
  }
  return $n;
}

sub process_csv ($self, $csv_path) {
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
    $row{$_} = undef for grep { defined $row{$_} && $row{$_} eq '' } keys %row;
    die sprintf("Linha %d: co_entidade vazia/não numérica ('%s')\n",
      $linha, $row{co_entidade} // '') unless defined $row{co_entidade} && $row{co_entidade} =~ /^\d+$/;
    die sprintf("Linha %d: ano %s fora de %d..%d\n", $linha, $row{ano} // '', ANO_MIN, ANO_MAX)
      unless defined $row{ano} && $row{ano} =~ /^\d{4}$/ && $row{ano} >= ANO_MIN && $row{ano} <= ANO_MAX;
    if (defined $row{fogo_fracao_queimada}) {
      die sprintf("Linha %d: fração '%s' fora de [0,1] (#154)\n", $linha, $row{fogo_fracao_queimada})
        unless $row{fogo_fracao_queimada} =~ /^\d*\.?\d+$/ && $row{fogo_fracao_queimada} >= 0 && $row{fogo_fracao_queimada} <= 1;
    }
    push @rows, \%row;
  }
  close $fh;
  $self->log_info(sprintf('CSV processado: %d linhas', scalar @rows));
  return \@rows;
}

sub carregar ($self, $rows, $anos, $raio) {
  my $dbh = $self->app->schema->storage->dbh;
  # O DELETE é escopado às ESCOLAS desta carga (não ao ano×raio inteiro): a
  # extração é aplicada em BLOCOS (região imediata) e um DELETE por ano×raio
  # apagaria os blocos já carregados. #278.
  my %cos;
  $cos{ $_->{co_entidade} } = 1 for grep { ref $_ eq 'HASH' } @$rows;
  my @cos = sort { $a <=> $b } keys %cos;
  require POSIX;
  my $sigset = POSIX::SigSet->new(POSIX::SIGALRM());
  POSIX::sigprocmask(POSIX::SIG_BLOCK(), $sigset);
  my $ok = eval {
    $self->app->schema->storage->txn_do(sub {
      $dbh->do('DELETE FROM ' . TAB
        . ' WHERE co_entidade = ANY(?::bigint[]) AND ano = ANY(?::smallint[]) AND raio_m = ?',
        undef, \@cos, $anos, $raio);
      $dbh->do('COPY ' . TAB . ' (co_entidade, nu_ano_censo, ano, raio_m,'
        . ' fogo_frequencia_media, fogo_frequencia_max, fogo_fracao_queimada, solo_carbono_medio)'
        . ' FROM STDIN WITH (FORMAT csv)');
      for my $r (@$rows) {
        die "MapBiomasRisco: linha de carga não é hashref\n" unless ref $r eq 'HASH';
        $dbh->pg_putcopydata(join(',', map { _csv_campo($_) } (
          $r->{co_entidade}, $r->{nu_ano_censo}, $r->{ano}, $r->{raio_m},
          $r->{fogo_frequencia_media}, $r->{fogo_frequencia_max},
          $r->{fogo_fracao_queimada}, $r->{solo_carbono_medio},
        )) . "\n");
      }
      $dbh->pg_putcopyend();
    });
    1;
  };
  my $erro = $@;
  POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $sigset);
  die "MapBiomasRisco: carga falhou, nada gravado: $erro" unless $ok;
  return scalar @$rows;
}

sub _csv_campo ($v) {
  return '' unless defined $v;
  $v =~ s/\x00//g;
  $v =~ s/"/""/g;
  return qq{"$v"};
}

sub _garantir_dir ($self, $file) {
  my ($dir) = $file =~ m{^(.*)/[^/]+$};
  return unless $dir && !-d $dir;
  require File::Path;
  File::Path::make_path($dir);
  $self->log_info("Directório de trabalho criado: $dir");
}

1;
