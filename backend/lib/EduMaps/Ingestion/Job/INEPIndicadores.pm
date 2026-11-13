package EduMaps::Ingestion::Job::INEPIndicadores;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path tempfile);
use Mojo::UserAgent;
use IO::Uncompress::Unzip qw(unzip $UnzipError);
use Text::CSV;

# =============================================================================
# INEP — taxas de rendimento e distorção idade-série por escola (#376)
# =============================================================================
#
# Fonte medida em 2026-11-13, em
#   https://download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais/<ano>/
#     tx_rend_escolas_<ano>.zip   (~70 MB; aprovação, reprovação, abandono)
#     TDI_<ano>_ESCOLAS.zip       (~35 MB; distorção idade-série)
# Encontrados 2019 e 2021–2025. Cada zip traz um .xlsx (e um .ods), com UMA
# linha por escola (CO_ENTIDADE); 2025: 126.684 escolas no rendimento e
# 126.605 na distorção, sem duplicata. As 9 primeiras linhas da planilha são
# título; a 10ª traz os códigos das colunas (NU_ANO_CENSO, CO_ENTIDADE,
# 1_CAT_FUN…, FUN_CAT_0…). Taxas em %, uma casa; "--" = sem dado.
#
# O que entra: as quatro etapas agregadas — fundamental total (fun), anos
# iniciais (ai), anos finais (af) e ensino médio (em). As séries uma a uma
# ficam de fora (ruído para meta de plano). Sem dado = NULL, nunca 0 (#154);
# etapa sem nenhum valor não vira linha.
#
# Leitura: a planilha .xlsx é extraída do zip (IO::Uncompress::Unzip, core) e
# lida pelo ogr2ogr, como no MapBiomas, sem dependência CPAN nova. Não dá para
# ler direto por /vsizip/: o .xlsx já é um zip, e o GDAL 3.6 do contêiner
# minion não abre zip dentro de zip (o 3.10 do host abre; medido 2026-11-13).
#
# TLS: o servidor do INEP manda só o certificado folha, sem o intermediário
# (RNP ICPEdu GR46 OV TLS CA 2025, emitido pela GlobalSign Root R46). Os
# navegadores completam pela AIA; aqui o intermediário vai versionado em
# EduMaps/Ingestion/certs/ e é somado às raízes do sistema. A verificação do
# certificado NÃO é desligada.
#
# Licença: a do INEP segue não verificada (e-SIC pendente,
# docs/admin/esic-requests.md). Mesmo tratamento do Censo e do IDEB já
# carregados: uso institucional interno, licença "Não verificada" no
# import_metadata.
#
# Uso:
#   perl ingestion_runner.pl --job=INEPIndicadores                 # 2023–2025
#   perl ingestion_runner.pl --job=INEPIndicadores --arg anos=2019,2021-2025
#   perl ingestion_runner.pl --job=INEPIndicadores --arg dir_zip=/caminho  # zips já baixados
# =============================================================================

has job_name    => 'INEPIndicadores';
has description => 'Ingestão INEP: taxas de rendimento e distorção idade-série por escola';
has schedule    => 'annual';
has stall_timeout => 1800;

use constant {
  TAB_REND    => 'clean.inep_rendimento_escola',
  TAB_TDI     => 'clean.inep_distorcao_escola',
  BASE_URL    => 'https://download.inep.gov.br/informacoes_estatisticas/indicadores_educacionais',
  LICENCA     => 'Não verificada (e-SIC INEP pendente; uso institucional interno, como o Censo e o IDEB)',
  ANO_MIN     => 2019,
  ANO_MAX     => 2025,
  ANOS_PADRAO => '2023-2025',
  LOTE        => 1000,
};

# Etapas que entram e as colunas de cada arquivo.
our @ETAPAS = qw(fun ai af em);
our %COL_REND = (
  fun => 'CAT_FUN', ai => 'CAT_FUN_AI', af => 'CAT_FUN_AF', em => 'CAT_MED',
);    # prefixo 1_ aprovação, 2_ reprovação, 3_ abandono
our %COL_TDI = (
  fun => 'FUN_CAT_0', ai => 'FUN_AI_CAT_0', af => 'FUN_AF_CAT_0', em => 'MED_CAT_0',
);
our %MEDIDA_REND = (1 => 'aprovacao', 2 => 'reprovacao', 3 => 'abandono');

has ua => sub ($self) {
  my $ua = Mojo::UserAgent->new;
  $ua->connect_timeout(30)->inactivity_timeout(300);
  $ua->ca($self->ca_bundle);
  return $ua;
};

sub tabelas ($self, $args = {}) { return (TAB_REND, TAB_TDI) }

sub url_rend ($self, $ano) { BASE_URL . "/$ano/tx_rend_escolas_$ano.zip" }
sub url_tdi  ($self, $ano) { BASE_URL . "/$ano/TDI_${ano}_ESCOLAS.zip" }

sub run ($self, $args = {}) {
  my @anos = $self->anos($args);
  return $self->_dry_run_sanidade(\@anos) if $self->dry_run;

  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;
  my (@rend, @tdi, %lidas);
  for my $ano (@anos) {
    my $zr = $self->_obter_zip($args, $self->url_rend($ano), TAB_REND);
    my $cr = $dir->child("inep_tx_rend_escolas_$ano.csv");
    $self->xlsx_para_csv($self->extrair_xlsx($zr, $dir), "$cr");
    my $r = $self->ler_rendimento("$cr", $ano);
    push @rend, @{ $r->{linhas} };
    $lidas{"rend_$ano"} = $r->{escolas};

    my $zt = $self->_obter_zip($args, $self->url_tdi($ano), TAB_TDI);
    my $ct = $dir->child("inep_tdi_escolas_$ano.csv");
    $self->xlsx_para_csv($self->extrair_xlsx($zt, $dir), "$ct");
    my $t = $self->ler_distorcao("$ct", $ano);
    push @tdi, @{ $t->{linhas} };
    $lidas{"tdi_$ano"} = $t->{escolas};
  }

  my $n_rend = $self->carregar(TAB_REND, [qw(aprovacao reprovacao abandono)], \@rend, \@anos);
  my $n_tdi  = $self->carregar(TAB_TDI, ['distorcao'], \@tdi, \@anos);
  my $faixa  = _faixa(\@anos);
  my $esc    = sub ($k) { join ', ', map { "$_: " . ($lidas{"${k}_$_"} // 0) } @anos };

  $self->upsert_metadata(TAB_REND, "tx_rend_escolas_<ano>.zip ($faixa)", $self->url_rend($anos[-1]), LICENCA, $n_rend,
    sprintf('Taxas de rendimento por escola (INEP), anos %s; etapas fun/ai/af/em, em %%; "--" = NULL (#154); '
      . 'etapa sem valor não vira linha. Escolas lidas por ano: %s. Loader: job INEPIndicadores (#376).',
      $faixa, $esc->('rend')));
  $self->upsert_metadata(TAB_TDI, "TDI_<ano>_ESCOLAS.zip ($faixa)", $self->url_tdi($anos[-1]), LICENCA, $n_tdi,
    sprintf('Distorção idade-série por escola (INEP), anos %s; etapas fun/ai/af/em, em %%; "--" não vira linha (#154). '
      . 'Escolas lidas por ano: %s. Loader: job INEPIndicadores (#376).',
      $faixa, $esc->('tdi')));
  $self->log_info(sprintf('INEP: %d linhas de rendimento e %d de distorção, anos %s', $n_rend, $n_tdi, $faixa));
  return $n_rend + $n_tdi;
}

# -----------------------------------------------------------------------------
# Anos: "2023-2025", "2019,2021-2025"; dentro do que a fonte publica.
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
  die sprintf("anos=%s: a fonte medida cobre %d–%d (fora: %s)\n", $spec, ANO_MIN, ANO_MAX,
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
# TLS: raízes do sistema + o intermediário que o servidor do INEP não manda.
# -----------------------------------------------------------------------------
sub intermediario ($self) {
  return path(__FILE__)->dirname->dirname->child('certs', 'rnp_icpedu_gr46_ov_tls_ca_2025.pem');
}

sub raizes_sistema ($self) {
  for my $f ($ENV{SSL_CERT_FILE} // (), '/etc/ssl/certs/ca-certificates.crt',
             '/etc/pki/tls/certs/ca-bundle.crt', '/etc/ssl/cert.pem') {
    return $f if -f $f && -s $f;
  }
  my $mozilla = eval { require Mozilla::CA; Mozilla::CA::SSL_ca_file() };
  return $mozilla if $mozilla && -f $mozilla;
  die "INEP: nenhum arquivo de raízes TLS do sistema encontrado (ca-certificates)\n";
}

has _ca_tmp => undef;
sub ca_bundle ($self) {
  my $inter = $self->intermediario;
  die "INEP: intermediário TLS ausente: $inter\n" unless -f $inter;
  my $tmp = tempfile(SUFFIX => '.pem');
  $tmp->spew(path($self->raizes_sistema)->slurp . "\n" . $inter->slurp);
  $self->_ca_tmp($tmp);    # vive enquanto o job viver
  return "$tmp";
}

# -----------------------------------------------------------------------------
# Download (allowlist + raw) ou zip já baixado (dir_zip=…).
# -----------------------------------------------------------------------------
sub _obter_zip ($self, $args, $url, $tab) {
  my $nome = (split m{/}, $url)[-1];
  if (my $dir = $args->{dir_zip}) {
    my $local = path($dir)->child($nome);
    die "zip não existe: $local\n" unless -f $local;
    $self->log_info("Relendo o bruto $local (sem download)");
    $self->preservar_raw("$local", $url, tabelas => [$tab]);
    return "$local";
  }
  return $self->download_file($url, undef, {}, tabelas => [$tab]);
}

# Nome do único .xlsx dentro do zip.
sub xlsx_no_zip ($self, $zip) {
  my $z = IO::Uncompress::Unzip->new($zip) or die "INEP: não abriu o zip $zip: $UnzipError\n";
  my @x;
  my $status = 1;
  while ($status > 0) {
    my $nome = $z->getHeaderInfo->{Name} // '';
    push @x, $nome if $nome =~ /\.xlsx$/i;
    $status = $z->nextStream;
  }
  $z->close;
  die sprintf("INEP: o zip %s tem %d planilhas .xlsx (esperava 1)\n", $zip, scalar @x) unless @x == 1;
  return $x[0];
}

# Extrai a planilha do zip para $dir e devolve o caminho do .xlsx.
sub extrair_xlsx ($self, $zip, $dir) {
  my $membro = $self->xlsx_no_zip($zip);
  my $dest = path($dir)->child(path($membro)->basename);
  unlink "$dest";
  unzip($zip => "$dest", Name => $membro, BinModeOut => 1)
    or die "INEP: não extraiu $membro de $zip: $UnzipError\n";
  die "INEP: extração vazia de $membro\n" unless -s $dest;
  return "$dest";
}

sub comando_xlsx_csv ($self, $xlsx, $csv) {
  return ['ogr2ogr', '--config', 'OGR_XLSX_HEADERS', 'DISABLE',
          '--config', 'OGR_XLSX_FIELD_TYPES', 'STRING', '-f', 'CSV', $csv, $xlsx];
}

sub xlsx_para_csv ($self, $xlsx, $csv) {
  unlink $csv;
  $self->log_info("ogr2ogr: $xlsx -> $csv");
  $self->executar($self->comando_xlsx_csv($xlsx, $csv));
  die "ogr2ogr não gerou $csv\n" unless -s $csv;
  return $csv;
}

sub executar ($self, $argv) {
  my $rc = system { $argv->[0] } @$argv;
  die sprintf("%s falhou (rc=%d)\n", $argv->[0], $rc == -1 ? -1 : $rc >> 8) if $rc;
  return 1;
}

# -----------------------------------------------------------------------------
# Leitura. Devolve { linhas => [...], escolas => n }.
# -----------------------------------------------------------------------------
sub ler_rendimento ($self, $csv_path, $ano) {
  return $self->_ler($csv_path, $ano, sub ($cel) {
    my @linhas;
    for my $e (@ETAPAS) {
      my %v = map { $MEDIDA_REND{$_} => $cel->("${_}_$COL_REND{$e}") } keys %MEDIDA_REND;
      next unless grep { defined } values %v;
      push @linhas, { etapa => $e, %v };
    }
    return @linhas;
  }, [ map { my $e = $_; map { "${_}_$COL_REND{$e}" } sort keys %MEDIDA_REND } @ETAPAS ], 'rendimento');
}

sub ler_distorcao ($self, $csv_path, $ano) {
  return $self->_ler($csv_path, $ano, sub ($cel) {
    return map { my $v = $cel->($COL_TDI{$_}); defined $v ? { etapa => $_, distorcao => $v } : () } @ETAPAS;
  }, [ map { $COL_TDI{$_} } @ETAPAS ], 'distorção');
}

sub _ler ($self, $csv_path, $ano, $extrair, $colunas, $rotulo) {
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
  open my $fh, '<:encoding(UTF-8)', $csv_path or die "Não leu $csv_path: $!\n";
  my %idx;
  while (my $r = $csv->getline($fh)) {
    next unless defined $r->[0] && $r->[0] =~ /^\s*NU_ANO_CENSO\s*$/;
    %idx = map { my $h = $r->[$_] // ''; $h =~ s/^\s+|\s+$//g; length $h ? ($h => $_) : () } 0 .. $#$r;
    last;
  }
  die "INEP ($rotulo $ano): linha de cabeçalho (NU_ANO_CENSO) não encontrada em $csv_path\n" unless %idx;
  my @falta = grep { !exists $idx{$_} } ('NU_ANO_CENSO', 'CO_ENTIDADE', @$colunas);
  die sprintf("INEP (%s %d): faltam colunas: %s\n", $rotulo, $ano, join(', ', @falta)) if @falta;

  my (@linhas, %visto);
  my $escolas = 0;
  while (my $r = $csv->getline($fh)) {
    my $a = $r->[ $idx{NU_ANO_CENSO} ] // '';
    $a =~ s/^\s+|\s+$//g;
    next unless $a =~ /^\d{4}$/;    # rodapé ("Fonte: …") e linhas vazias
    die "INEP ($rotulo $ano): linha do ano $a no arquivo de $ano\n" unless $a == $ano;
    my $inep = $r->[ $idx{CO_ENTIDADE} ] // '';
    $inep =~ s/^\s+|\s+$//g;
    die "INEP ($rotulo $ano): código de escola inválido '$inep'\n" unless $inep =~ /^\d{8}$/;
    die "INEP ($rotulo $ano): escola $inep repetida\n" if $visto{$inep}++;
    $escolas++;
    my $cel = sub ($col) { _taxa($r->[ $idx{$col} ], "$rotulo $ano $inep $col") };
    push @linhas, map { { cod_inep => $inep + 0, ano => $ano + 0, %$_ } } $extrair->($cel);
  }
  close $fh;
  $self->log_info(sprintf('INEP %s %d: %d escolas, %d linhas (escola × etapa)', $rotulo, $ano, $escolas, scalar @linhas));
  return { linhas => \@linhas, escolas => $escolas };
}

# "--" ou vazio -> undef; número -> uma casa ("33.299999999999997" -> 33.3).
sub _taxa ($v, $onde) {
  return undef unless defined $v;
  $v =~ s/^\s+|\s+$//g;
  return undef if $v eq '' || $v eq '--';
  $v =~ tr/,/./;
  die "INEP: taxa não numérica em $onde: '$v'\n" unless $v =~ /^\d+(?:\.\d+)?$/;
  my $n = 0 + sprintf('%.1f', $v);
  die "INEP: taxa fora de 0–100 em $onde: $v\n" if $n > 100;
  return $n;
}

# -----------------------------------------------------------------------------
# Carga: os anos pedidos são SUBSTITUÍDOS por inteiro numa transação.
# -----------------------------------------------------------------------------
sub carregar ($self, $tab, $medidas, $linhas, $anos) {
  my $dbh = $self->app->schema->storage->dbh;
  my @cols = ('cod_inep', 'ano', 'etapa', @$medidas);
  my $n = 0;
  my $ok = eval {
    $self->app->schema->storage->txn_do(sub {
      $dbh->do("DELETE FROM $tab WHERE ano = ANY(?::smallint[])", undef, $anos);
      for (my $i = 0; $i < @$linhas; $i += LOTE) {
        my $fim = $i + LOTE - 1;
        $fim = $#$linhas if $fim > $#$linhas;
        my @lote = @{$linhas}[ $i .. $fim ];
        my $ph = '(' . join(', ', ('?') x @cols) . ')';
        $dbh->do("INSERT INTO $tab (" . join(', ', @cols) . ') VALUES ' . join(',', ($ph) x @lote),
          undef, map { my $l = $_; map { $l->{$_} } @cols } @lote);
        $n += @lote;
      }
    });
    1;
  };
  die "INEP: carga de $tab falhou, nada gravado: $@" unless $ok;
  return $n;
}

# -----------------------------------------------------------------------------
# Dry-run honesto: HEAD de cada zip (allowlist + TLS + alcance) e o ogr2ogr.
# -----------------------------------------------------------------------------
sub _dry_run_sanidade ($self, $anos) {
  for my $ano (@$anos) {
    for my $url ($self->url_rend($ano), $self->url_tdi($ano)) {
      $self->exigir_allowlist($url);
      my $res = $self->run_with_retry(sub {
        my $tx = $self->ua->head($url);
        die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
        return $tx->result;
      }, "HEAD $url");
      $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d, %s bytes', $url, $res->code,
        $res->headers->content_length // '?'));
    }
  }
  my $v = `ogr2ogr --version 2>/dev/null`;
  die "[DRY-RUN] ogr2ogr ausente: a leitura do xlsx exige gdal-bin (Rex deploy_minion_dev)\n" unless $v;
  $self->log_info(sprintf('[DRY-RUN] INEP: anos %s; nada baixado nem gravado', _faixa($anos)));
  return 0;
}

1;
