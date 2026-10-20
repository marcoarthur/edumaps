package EduMaps::Ingestion::Job::Base;
use Mojo::Base -base, -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Digest::SHA;
use File::Copy qw(copy);
use POSIX qw(strftime);
use EduMaps::Ingestion::NaoCarregada;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::Promise;
use Mojo::Log;
use Mojo::Util qw(trim);
use Time::Piece;
use Time::HiRes qw(sleep);
use Text::CSV;

has job_name => '';
has description => '';
has schedule => 'manual';  # 'daily', 'weekly', 'monthly', 'manual'
has log => sub { Mojo::Log->new };
has config => sub { {} };
has dry_run => 0;
has app => sub { die "app must be set" };

has ua => sub ($self) {
  my $ua = Mojo::UserAgent->new;
  $ua->connect_timeout(30)->inactivity_timeout(300);
  return $ua;
};

has log => sub ($self) { $self->log // Mojo::Log->new };
has max_retries => 3;
has backoff_base => 5;  # seconds

# --- Allowlist (#231) --------------------------------------------------------
# Toda URL que um job busca passa por EduMaps::Data::Allowlist ANTES da
# requisição: NEGADO, fora da lista ou fonte INATIVA morrem alto com o motivo.
# Injetável nos testes.
has allowlist => sub {
  require EduMaps::Data::Allowlist;
  return EduMaps::Data::Allowlist->new;
};

# --- Preservação de raw (#231) -----------------------------------------------
# Todo arquivo baixado vai para <raw_dir>/<fonte_raw>/<AAAA-MM-DD>/<arquivo>,
# fora do pgdata, para que um restore do banco não apague a única cópia (o
# que aconteceu a 2026-10-08). O DVC (#135) virá apontar para o mesmo lugar.
#   raw_dir: config->{raw_dir} > $ENV{EDUMAPS_RAW_DIR} > /srv/edumaps/raw
has raw_dir => sub ($self) {
  return $self->config->{raw_dir} // $ENV{EDUMAPS_RAW_DIR} // '/srv/edumaps/raw';
};
has fonte_raw => sub ($self) { lc($self->job_name || 'desconhecida') };
has data_raw  => sub { strftime('%Y-%m-%d', localtime) };
# Manifesto acumulado na execução: [{url, caminho, sha256, bytes, baixado_em,
# reaproveitado, tabelas?}]. Vai para clean.import_metadata.raw_manifest no
# upsert_metadata de sucesso.
has raw_manifest => sub { [] };

sub run ($self, $args = {}) {
  die "Método run() deve ser implementado na subclasse";
}

# Tabelas que o job alimenta (#231). O Runner usa esta lista para registrar
# o estado da tentativa (em_carga/falhou/nao_carregada) sem tocar na
# proveniência da última carga boa. Recebe os args da execução: um job pode
# alimentar tabelas diferentes conforme o modo (SICONFI receita x DCA).
sub tabelas ($self, $args = {}) { return () }

# Lê um --arg que aceita lista: "SP,RJ", ["SP","RJ"] (chave repetida) ou
# ["SP,RJ","MG"]. Devolve a lista sem vazios (ver CLI::parse_args).
sub arg_lista ($self, $args, $chave) {
  my $v = $args->{$chave};
  return () unless defined $v;
  return grep { length } map { s/^\s+|\s+$//gr } map { split /,/ } (ref $v eq 'ARRAY' ? @$v : $v);
}

# Sinaliza "não carregada por bloqueio conhecido" (e-SIC, API retirada,
# fora do objetivo). Ver EduMaps::Ingestion::NaoCarregada.
sub nao_carregada ($self, $motivo) {
  EduMaps::Ingestion::NaoCarregada->throw(motivo => $motivo, job => $self->job_name);
}

sub log_info ($self, $msg) {
  $self->log->info("[" . $self->job_name . "] $msg");
}

sub log_error ($self, $msg) {
  $self->log->error("[" . $self->job_name . "] $msg");
}

sub run_with_retry ($self, $operation, $description) {
  my $retries = 0;
  while (1) {
    my $result = eval { $operation->() };
    return $result unless $@;
    
    my $error = $@;
    chomp $error;
    $self->log->warn("[$description] Tentativa $retries falhou: $error");
    
    $retries++;
    if ($retries > $self->max_retries) {
      $self->log->error("[$description] Falhou após $self->max_retries tentativas: $error");
      die "Falha permanente: $error";
    }
    
    my $sleep_time = $self->backoff_base * (2 ** ($retries - 1)) + rand(2);
    $self->log->info("[$description] Aguardando ${sleep_time}s antes de retry $retries/$self->max_retries");
    sleep($sleep_time);
  }
}

# Morre alto se a URL não passa no allowlist (NEGADO / fora da lista /
# INATIVA). Vale também em --dry-run: o dry-run tem de denunciar uma URL que
# a carga real recusaria.
sub exigir_allowlist ($self, $url) {
  my $al = $self->allowlist;
  return 1 if $al->validate_url("$url");
  die sprintf("[ALLOWLIST] %s recusou %s: %s\n",
    $self->job_name || ref($self), $url, $al->last_error);
}

sub fetch_with_retry ($self, $url, $headers = {}) {
  $self->exigir_allowlist($url);
  return $self->run_with_retry(sub {
    my $tx = $self->ua->get($url => $headers);
    die $tx->error->{message} if $tx->error;
    return $tx->result;
  }, "GET $url");
}

# ---------------------------------------------------------------------------
# download_file($url, $dest_path = undef, $headers = {}, %opt)
# ---------------------------------------------------------------------------
# 1. valida a URL no allowlist (morre alto se recusada);
# 2. grava em <raw_dir>/<fonte_raw>/<AAAA-MM-DD>/<arquivo> (nome: $opt{nome},
#    ou o último segmento da URL — o nome da FONTE, não o do destino de
#    trabalho —, ou o basename de $dest_path se a URL não tiver nome);
# 3. REAPROVEITA: se o arquivo já existe com esse nome no diretório do dia,
#    não rebaixa (regra de reaproveitamento = mesmo nome, mesmo dia). Entre
#    dias diferentes baixa de novo — cada dia é uma fotografia; o sha256 no
#    manifesto permite deduplicar depois (DVC, #135) sem perder a fotografia;
# 4. calcula sha256 e bytes e acumula a entrada em raw_manifest
#    ($opt{tabelas} restringe a entrada a essas tabelas no upsert_metadata);
# 5. se $dest_path foi dado e é outro lugar, copia o raw para lá (os
#    loaders antigos esperam o arquivo no caminho de trabalho).
# Download vai para "<arquivo>.part" e só é renomeado completo: um download
# interrompido nunca vira "arquivo existente" a reaproveitar.
# Devolve o caminho onde o loader deve ler ($dest_path ou o raw).
sub download_file ($self, $url, $dest_path = undef, $headers = {}, %opt) {
  $self->exigir_allowlist($url);

  my $nome = $opt{nome} // _nome_da_url($url);
  $nome = path($dest_path)->basename if $nome eq 'download' && defined $dest_path;
  $nome =~ s{[^\w.\-]+}{_}g;
  my $raw = $self->caminho_raw($nome);

  if ($self->dry_run) {
    $self->log->info("[DRY-RUN] Download: $url -> $raw" . (defined $dest_path ? " (cópia em $dest_path)" : ''));
    return defined $dest_path ? $dest_path : "$raw";
  }

  my $reaproveitado = (-f $raw && -s $raw) ? 1 : 0;
  if ($reaproveitado) {
    $self->log_info("raw reaproveitado (já baixado hoje): $raw");
  }
  else {
    $raw->dirname->make_path;
    my $part = "$raw.part";
    $self->run_with_retry(sub {
      my $tx = $self->ua->build_tx(GET => "$url" => $headers);
      $tx->res->max_message_size(0);    # malhas de 1,5 GB: sem teto
      $tx = $self->ua->start($tx);
      if (my $err = $tx->error) {
        die(($err->{code} ? "HTTP $err->{code} " : '') . ($err->{message} // 'erro') . "\n");
      }
      unlink $part;
      $tx->result->content->asset->move_to($part);
      return 1;
    }, "DOWNLOAD $url -> $raw");
    rename $part, "$raw" or die "Não renomeou $part -> $raw: $!\n";
  }

  $self->_registrar_raw($url, $raw, $reaproveitado, $opt{tabelas});

  if (defined $dest_path && path($dest_path)->to_abs ne $raw->to_abs) {
    path($dest_path)->dirname->make_path;
    copy("$raw", "$dest_path") or die "Não copiou $raw -> $dest_path: $!\n";
    return $dest_path;
  }
  return "$raw";
}

# Preserva no raw um arquivo que chegou por fora do job (ZIP baixado à mão e
# passado por config, como o RENAEST/RENAVAM do Transportes): copia para
# <raw_dir>/<fonte_raw>/<dia>/ (se ainda não estiver lá) e registra no
# manifesto com a URL de origem declarada. Não valida o allowlist — não há
# requisição; a URL é só proveniência.
sub preservar_raw ($self, $arquivo, $url_origem = undef, %opt) {
  die "preservar_raw: arquivo inexistente: $arquivo\n" unless -f $arquivo;
  my $nome = path($arquivo)->basename;
  $nome =~ s{[^\w.\-]+}{_}g;
  my $raw = $self->caminho_raw($nome);
  if ($self->dry_run) {
    $self->log->info("[DRY-RUN] Preservaria $arquivo -> $raw");
    return "$raw";
  }
  my $reaproveitado = (-f $raw && -s $raw) ? 1 : 0;
  unless ($reaproveitado) {
    $raw->dirname->make_path;
    copy("$arquivo", "$raw.part") or die "Não copiou $arquivo -> $raw: $!\n";
    rename "$raw.part", "$raw" or die "Não renomeou $raw.part: $!\n";
  }
  $self->_registrar_raw($url_origem // "file://" . path($arquivo)->to_abs, $raw, $reaproveitado, $opt{tabelas});
  return "$raw";
}

sub caminho_raw ($self, $nome) {
  return path($self->raw_dir, $self->fonte_raw, $self->data_raw, $nome);
}

sub _nome_da_url ($url) {
  my $p = Mojo::URL->new("$url")->path->parts->[-1];
  return (defined $p && length $p) ? $p : 'download';
}

sub _sha256_arquivo ($arquivo) {
  my $sha = Digest::SHA->new(256);
  $sha->addfile("$arquivo", 'b');
  return $sha->hexdigest;
}

sub _registrar_raw ($self, $url, $raw, $reaproveitado, $tabelas = undef) {
  my $entrada = {
    url           => "$url",
    caminho       => "$raw",
    sha256        => _sha256_arquivo($raw),
    bytes         => -s "$raw",
    baixado_em    => strftime('%Y-%m-%dT%H:%M:%S%z', localtime((stat "$raw")[9])),
    reaproveitado => $reaproveitado ? Mojo::JSON::true : Mojo::JSON::false,
    ($tabelas ? (tabelas => [@$tabelas]) : ()),
  };
  # A mesma URL/caminho duas vezes na execução conta uma vez.
  @{ $self->raw_manifest } =
    grep { !($_->{url} eq $entrada->{url} && $_->{caminho} eq $entrada->{caminho}) }
    @{ $self->raw_manifest };
  push @{ $self->raw_manifest }, $entrada;
  $self->log_info(sprintf('raw: %s (%d bytes, sha256 %s)', $raw, $entrada->{bytes}, $entrada->{sha256}));
  return $entrada;
}

# Entradas do manifesto que valem para $tabela (as sem `tabelas` valem para
# todas as tabelas do job).
sub manifesto_para ($self, $tabela) {
  return [ grep { !$_->{tabelas} || grep { $_ eq $tabela } @{ $_->{tabelas} } }
           @{ $self->raw_manifest } ];
}

# Compara o cabecalho de um CSV com o contrato declarado pelo job e devolve
# SO as diferencas. Cada elemento e' [ $coluna, $pos_contrato, $pos_csv ],
# com posicao 0-based:
#
#   $pos_contrato undef -> a coluna nao esta no contrato  ("a mais")
#   $pos_csv      undef -> a coluna do contrato falta      ("faltam")
#   ambos definidos, diferentes -> esta na posicao errada ("fora de ordem")
#   ambos definidos, iguais    -> conforme, e portanto NAO entra na lista
#
# Medido: a versao anterior fazia push de toda a coluna do cabecalho sem
# comparar nada, e o `die` seguinte comparava um NOME com uma POSICAO
# ("codigo_ibge" ne 0), que e' sempre verdadeiro -- o job abortava mesmo
# com o CSV exactamente igual ao contrato. Os dois lados juntos faziam
# do teste de contrato um no-op que so passava por o dies nunca ter sido
# alcancado com o caminho real.
#
# Vivia privada no BrazilCrime; e' contrato de CSV de extracção, comum aos
# loaders que orquestram R (BrazilCrime, MapBiomasEscola) — por isso mora no
# Base. O nome privado ficou, para os testes que o chamam via o objecto.
sub _comparar_colunas ($self, $header, $esperado) {
  my %pos_esp = map { $esperado->[$_] => $_ } 0 .. $#$esperado;
  my %pos_hdr = map { $header->[$_]  => $_ } 0 .. $#$header;
  my @dif;

  # Colunas que o CSV traz. Se nao estao no contrato, sao "a mais".
  for my $i (0 .. $#$header) {
    my $h = $header->[$i];
    if (!exists $pos_esp{$h}) {
      push @dif, [ $h, undef, $i ];
    }
    elsif ($pos_esp{$h} != $i) {
      push @dif, [ $h, $pos_esp{$h}, $i ];
    }
  }

  # Colunas do contrato que o CSV nao traz. Nao contam as "a mais":
  # a posicao no contrato e' a do indice, mesmo que no CSV nao exista.
  for my $i (0 .. $#$esperado) {
    my $e = $esperado->[$i];
    push @dif, [ $e, $i, undef ] unless exists $pos_hdr{$e};
  }

  return @dif;
}

# A morte por sinal NÃO vira exit code: o /bin/sh (dash) faz `exec` do último
# comando, logo o filho direto do Perl é o próprio script, e `$? >> 8` dá 0
# quando ele morre por sinal. Sem este cheque o job seguia como SUCESSO — foi
# assim que SP/RJ/PE ficaram sem gravar nada e reportaram "OK" (2026-10-19):
# o R estourou a RAM (SIGKILL) e o CSV do bloco anterior foi lido como novo.
sub _abortar_se_morreu_por_sinal ($self, $status, $rotulo, $output) {
  my $sinal = $status & 127;
  return unless $sinal;
  my $dica = $sinal == 9  ? ' (SIGKILL — provável OOM: ver lotes/memória)'
           : $sinal == 11 ? ' (SIGSEGV)' : '';
  die sprintf("%s morreu por sinal %d%s. Última saída:\n%s",
    $rotulo, $sinal, $dica, (defined $output && length $output) ? $output : '(sem saída)');
}

sub run_r_script ($self, $script_path, $args = []) {
  return $self->run_with_retry(sub {
    if ($self->dry_run) {
      $self->log->info("[DRY-RUN] Executando R: Rscript --vanilla $script_path @$args");
      return "DRY-RUN OK";
    }
    my @cmd = ('Rscript', '--vanilla', $script_path, @$args);
    $self->log->info("Executando R: @cmd");
    my $output = `$cmd[0] @cmd[1..$#cmd] 2>&1`;
    my $status = $?;
    $self->_abortar_se_morreu_por_sinal($status, "R script $script_path", $output);
    my $exit_code = $status >> 8;
    die "R script falhou (exit $exit_code): $output" if $exit_code;
    # A saída do R é o único registro de "N linhas gravadas" — logar para o
    # diagnóstico não se perder quando a falha acontecer noutro ponto.
    $self->log->info("Saída do R: $_") for grep { length } split /\n/, ($output // '');
    return $output;
  }, "R script $script_path");
}

sub run_perl_script ($self, $script_path, $args = []) {
  return $self->run_with_retry(sub {
    if ($self->dry_run) {
      $self->log->info("[DRY-RUN] Executando Perl: perl $script_path @$args");
      return "DRY-RUN OK";
    }
    my @cmd = ('perl', $script_path, @$args);
    $self->log->info("Executando Perl: @cmd");
    my $output = `$cmd[0] @cmd[1..$#cmd] 2>&1`;
    my $status = $?;
    $self->_abortar_se_morreu_por_sinal($status, "Perl script $script_path", $output);
    my $exit_code = $status >> 8;
    die "Perl script falhou (exit $exit_code): $output" if $exit_code;
    return $output;
  }, "Perl script $script_path");
}

# ---------------------------------------------------------------------------
# Metadata de SUCESSO: proveniência + estado 'ok' (#231)
# ---------------------------------------------------------------------------
# upsert_metadata($tabela, $source_file, $source_url, $source_license,
#                 $row_count, $notes)
#
# Grava a proveniência da carga boa (source_*, retrieved_at, row_count,
# notes, raw_manifest) e marca ultimo_status='ok'. $source_license = undef
# significa "NÃO TOQUE NA LICENÇA": mantém a que já está no banco (ex.: a
# corrigida à mão na #157) e, se não houver linha, usa a do allowlist
# (get_license_for_url).
#
# Exige a change Sqitch import_metadata_estado (colunas ultimo_* e
# raw_manifest).
sub upsert_metadata ($self, $table_name, $source_file, $source_url, $source_license, $row_count, $notes) {
  if ($self->dry_run) {
    $self->log->info("[DRY-RUN] Upsert metadata: $table_name ($row_count rows)");
    return;
  }
  my $preservar = defined $source_license ? 0 : 1;
  my $licenca = $source_license
    // eval { $self->allowlist->get_license_for_url($source_url) }
    // 'Não verificada';
  my $manifesto = $self->manifesto_para($table_name);
  my $db = $self->app->schema->storage->dbh;
  $db->do(
    q{INSERT INTO clean.import_metadata AS im
        (table_name, source_file, source_url, source_license, retrieved_at,
         row_count_loaded, notes, ultimo_status, ultimo_motivo,
         ultima_tentativa_em, raw_manifest)
      VALUES (?, ?, ?, ?, NOW(), ?, ?, 'ok', NULL, NOW(), ?::jsonb)
      ON CONFLICT (table_name) DO UPDATE SET
        source_file = EXCLUDED.source_file,
        source_url = EXCLUDED.source_url,
        source_license = CASE WHEN ?::boolean
                              THEN COALESCE(im.source_license, EXCLUDED.source_license)
                              ELSE EXCLUDED.source_license END,
        retrieved_at = NOW(),
        row_count_loaded = EXCLUDED.row_count_loaded,
        notes = EXCLUDED.notes,
        ultimo_status = 'ok',
        ultimo_motivo = NULL,
        ultima_tentativa_em = NOW(),
        raw_manifest = EXCLUDED.raw_manifest},
    undef, $table_name, $source_file, $source_url, $licenca, $row_count, $notes,
    (@$manifesto ? encode_json($manifesto) : undef),
    ($preservar ? 1 : 0),
  );
}

# ---------------------------------------------------------------------------
# Metadata de ESTADO da última tentativa (#231)
# ---------------------------------------------------------------------------
# Só tocam ultimo_status / ultimo_motivo / ultima_tentativa_em: a proveniência
# da última carga boa (source_*, retrieved_at, row_count_loaded, notes,
# raw_manifest) sobrevive a qualquer falha. Tabela sem linha ganha uma com
# source_file '(nenhuma carga registrada)' — o estado não pode sumir por
# falta de carga anterior. Em --dry-run não escrevem nada.
my $SEM_CARGA = '(nenhuma carga registrada)';

sub _registrar_estado ($self, $status, $motivo, @tabelas) {
  return 0 unless @tabelas;
  if ($self->dry_run) {
    $self->log->info("[DRY-RUN] Estado $status em: @tabelas");
    return 0;
  }
  $motivo = substr($motivo, 0, 4000) . ' […]' if defined $motivo && length $motivo > 4000;
  my $db = $self->app->schema->storage->dbh;
  for my $t (@tabelas) {
    $db->do(
      q{INSERT INTO clean.import_metadata AS im
          (table_name, source_file, ultimo_status, ultimo_motivo, ultima_tentativa_em)
        VALUES (?, ?, ?, ?, NOW())
        ON CONFLICT (table_name) DO UPDATE SET
          ultimo_status = EXCLUDED.ultimo_status,
          ultimo_motivo = EXCLUDED.ultimo_motivo,
          ultima_tentativa_em = NOW()},
      undef, $t, $SEM_CARGA, $status, $motivo,
    );
  }
  return scalar @tabelas;
}

sub registrar_tentativa ($self, @tabelas) {
  return $self->_registrar_estado('em_carga', undef, @tabelas);
}

sub registrar_falha ($self, $motivo, @tabelas) {
  return $self->_registrar_estado('falhou', $motivo, @tabelas);
}

sub registrar_nao_carregada ($self, $motivo, @tabelas) {
  return $self->_registrar_estado('nao_carregada', $motivo, @tabelas);
}

# Depois de um run() com sucesso: tabela declarada que ficou 'em_carga'
# (o job terminou sem upsert_metadata para ela — ex.: 0 linhas) vira
# 'nao_carregada' com o motivo, e não 'ok': ok é só para carga registrada.
sub fechar_tentativa ($self, @tabelas) {
  return 0 if $self->dry_run || !@tabelas;
  my $db = $self->app->schema->storage->dbh;
  my $n = 0;
  for my $t (@tabelas) {
    $n += 0 + ($db->do(
      q{UPDATE clean.import_metadata
           SET ultimo_status = 'nao_carregada',
               ultimo_motivo = 'execução concluída sem carga registrada para esta tabela (0 linhas?)',
               ultima_tentativa_em = NOW()
         WHERE table_name = ? AND ultimo_status = 'em_carga'},
      undef, $t) || 0);
  }
  return $n;
}

sub get_latest_snapshot ($self, $table_name) {
  my $db = $self->app->schema->storage->dbh;
  my $sth = $db->prepare("SELECT MAX(dt_snapshot) FROM clean.$table_name");
  $sth->execute;
  return $sth->fetchrow_array;
}

# -----------------------------------------------------------------------------
# Exportação de buffers em lotes + invariante do lote (compartilhado pelos
# jobs MapBiomasRisco e MapBiomasEscola — a cópia em cada job era a mesma
# rotina e o Escola ficou para trás na correção de OOM do #288).
# -----------------------------------------------------------------------------

# Buffers por chamada do R. O `terra::extract(weights=TRUE)` materializa uma
# linha por célula×buffer (~35 mil células de 30 m por buffer de 1 km), então
# um bloco grande estoura a RAM do host de ingestão (7,8 GB, sem swap) e o R
# morre com SIGKILL: SP (11.147 buffers ≈ 390 M linhas), RJ (5.846) e PE
# (2.136) falharam assim em 2026-10-19. 400 buffers ≈ 2 GB de pico — limiar
# validado na UF de SC (o maior bloco saudável teve 761; PE, com 2.136,
# morreu). A matemática por buffer é idêntica: mesma chamada, menos por vez.
use constant TAMANHO_LOTE => 400;

# Exporta os buffers (clean.escola_influencia, tier='buffer') em arquivos
# GeoJSON de até TAMANHO_LOTE feições. Devolve [ [indice, arquivo, n], ... ]
# (o primeiro sempre no caminho base, os seguintes com sufixo `_l<N>`).
sub exportar_buffers_lotes ($self, $base, $raio, $uf, $nu_ano_censo, $municipios = undef) {
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

  $self->_garantir_dir("$base.geojson");
  my @lotes;
  my ($fh, $arq, $n_lote, $sep);
  my $total = 0;
  my $fechar = sub {
    return unless $fh;
    print {$fh} ']}';
    close $fh or die "Não fechou $arq: $!\n";
    push @lotes, [ scalar(@lotes) + 1, $arq, $n_lote ];
    $fh = undef;
  };
  while (my $r = $sth->fetchrow_arrayref) {
    my ($co, $ano, $geom) = @$r;
    next unless defined $geom && length $geom;
    if (!$fh || $n_lote >= TAMANHO_LOTE) {
      $fechar->();
      $arq = @lotes ? sprintf('%s_l%d.geojson', $base, scalar(@lotes) + 1) : "$base.geojson";
      open $fh, '>:encoding(UTF-8)', $arq or die "Não abriu $arq: $!\n";
      print {$fh} '{"type":"FeatureCollection","features":[';
      ($n_lote, $sep) = (0, '');
    }
    print {$fh} $sep,
      '{"type":"Feature","properties":{"co_entidade":', 0 + $co,
      ',"nu_ano_censo":', 0 + $ano, '},"geometry":', $geom, '}';
    $sep = ','; $n_lote++; $total++;
  }
  $fechar->();
  return \@lotes unless @lotes;

  $self->log_info(sprintf('Buffers exportados: %d em %d lote(s) de até %d (raio %d m%s) -> %s%s',
    $total, scalar @lotes, TAMANHO_LOTE, $raio, defined $uf ? ", uf $uf" : '',
    $lotes[0][1], scalar(@lotes) > 1 ? sprintf(' (+%d)', scalar(@lotes) - 1) : ''));
  return \@lotes;
}

# A soma do lote tem de fechar com o exportado: o R grava UMA linha por buffer
# com indicador e manda o resto para o relatório de órfãos. Se não fecha, o
# CSV não é deste lote (sobra de execução anterior) ou o R morreu no meio —
# nada é carregado. Inválido em 506/506 blocos saudáveis (2026-10-19, #288).
sub conferir_lote ($self, $rotulo, $n_buffers, $n_csv, $n_orfaos) {
  return if $n_csv + $n_orfaos == $n_buffers;
  die sprintf("%s (%s): linhas (%d) + órfãos (%d) ≠ buffers exportados (%d)"
    . " — CSV de outro lote ou R morto no meio; nada carregado.\n",
    $self->job_name, $rotulo, $n_csv, $n_orfaos, $n_buffers);
}

sub _garantir_dir ($self, $file) {
  my ($dir) = $file =~ m{^(.*)/[^/]+$};
  return unless $dir && !-d $dir;
  require File::Path;
  File::Path::make_path($dir);
  $self->log_info("Directório de trabalho criado: $dir");
}

1;