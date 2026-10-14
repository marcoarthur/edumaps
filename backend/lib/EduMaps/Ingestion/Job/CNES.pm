package EduMaps::Ingestion::Job::CNES;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use POSIX qw(strftime);

use utf8;

has job_name    => 'CNES';
has description => 'Ingestão CNES: estabelecimentos de saúde ATIVOS, sanitizados (sem PII), por UF via API de dados abertos da Saúde';
has schedule    => 'monthly';

# =====================================================================
# Fonte (#241, P3 da #156) — conferida em 2026-10-13
#
#   GET https://apidadosabertos.saude.gov.br/cnes/estabelecimentos
#       ?status=1&codigo_uf=<IBGE>&limit=20&offset=<linha>
#
# - A API devolve {"estabelecimentos": [...]} com NO MÁXIMO 20 registros por
#   página: `limit` maior é ignorado. `offset` é por linha; depois da última
#   página vem uma lista vazia (medido no AC: ~1.770 ativos, última página
#   com 10 itens, a seguinte vazia). ~1,1 s por requisição.
# - Só estabelecimentos ATIVOS (status=1, decisão do developer): a coluna
#   status grava 1. Desabilitados (status=0) não são pedidos.
# - `codigo_municipio` vem com 6 dígitos (sem o verificador): normaliza-se
#   para os 7 de clean.malha_municipio pelo prefixo de 6, como no SISAB. O
#   que não casa vai para o relatório de órfãos.
#
# SANITIZAÇÃO (o requisito central): o registro da API traz PII — razão
# social, nome fantasia, CNPJ, telefone, e-mail, endereço, CEP, bairro. Só
# os campos de @CAMPOS_FONTE sobrevivem, e isso vale para a carga E para o
# bruto preservado em disco: o JSONL gravado já é o sanitizado (nunca a
# resposta da API). O allowlist nega o mesmo recurso no host
# dados.saude.gov.br (sus_cnes_individual); aqui é apidadosabertos, aceito
# só com esta sanitização.
#
# Licença CC BY-ND 3.0: guarda-se um subconjunto de colunas sem alterar
# valores (decisão do developer, §8 da spec: não é obra derivada).
#
# Retomada: cada UF é carregada na sua própria transação, logo uma falha
# tardia (ex.: SP) não desfaz as UFs já gravadas. `--arg uf=SP,RJ` roda só
# as que faltam; `--arg jsonl=<bruto>` recarrega do sanitizado sem a API.
# =====================================================================
has base_url    => 'https://apidadosabertos.saude.gov.br';
has recurso     => '/cnes/estabelecimentos';
has pagina      => 20;      # máximo efetivo da API
has throttle    => 0.3;
has max_paginas => 20_000;  # trava por UF (SP ~ 5 mil páginas)

# O JSONL cresce a cada página em data/ingestao, o que o watchdog do Runner
# lê como progresso; o prazo maior cobre os backoffs de retry da API.
has stall_timeout => 1800;

use constant TABELA  => 'clean.cnes_estabelecimentos';
use constant LICENCA => 'CC BY-ND 3.0 (dados abertos SUS)';

# Campos da API que sobrevivem à sanitização — e NENHUM outro.
our @CAMPOS_FONTE = qw(codigo_cnes codigo_municipio codigo_uf codigo_tipo_unidade
                       latitude_estabelecimento_decimo_grau longitude_estabelecimento_decimo_grau
                       data_atualizacao);

our %UF = (
  RO => 11, AC => 12, AM => 13, RR => 14, PA => 15, AP => 16, TO => 17,
  MA => 21, PI => 22, CE => 23, RN => 24, PB => 25, PE => 26, AL => 27, SE => 28, BA => 29,
  MG => 31, ES => 32, RJ => 33, SP => 35,
  PR => 41, SC => 42, RS => 43,
  MS => 50, MT => 51, GO => 52, DF => 53,
);
my %SIGLA = reverse %UF;

# Caixa do Brasil (com folga): fora disto a coordenada é lixo da fonte.
use constant { LAT_MIN => -34.0, LAT_MAX => 5.5, LON_MIN => -74.5, LON_MAX => -28.5 };

sub tabelas ($self, $args = {}) { return (TABELA) }

sub url_fonte ($self) { return $self->base_url . $self->recurso }

# UFs pedidas: siglas ou códigos IBGE; sem `uf`, todas (ordem do código).
sub ufs_alvo ($self, $args) {
  my @pedidas = $self->arg_lista($args, 'uf');
  return sort { $a <=> $b } values %UF unless @pedidas;
  my @cod;
  for my $u (@pedidas) {
    my $c = $u =~ /^\d+$/ ? ($SIGLA{$u} ? 0 + $u : undef) : $UF{ uc $u };
    die "CNES: UF desconhecida: $u\n" unless $c;
    push @cod, $c;
  }
  return @cod;
}

# ---------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------
sub run ($self, $args = {}) {
  $self->exigir_allowlist($self->url_fonte);
  return $self->_dry_run_sanidade if $self->dry_run;

  my $snapshot = $args->{dt_snapshot} // strftime('%Y-%m-%d', localtime);
  my $indice = $self->indice_prefixo6;
  my (%por_uf, @orfaos, %e);
  $e{$_} = 0 for qw(lidos carregados coords_descartadas sem_tipo duplicados);

  my $carregar_uf = sub ($uf, $registros) {
    my $res = $self->mapear($registros, $indice);
    push @orfaos, @{ $res->{orfaos} };
    $e{$_} += $res->{estatisticas}{$_} for qw(coords_descartadas sem_tipo duplicados);
    $e{lidos} += scalar @$registros;
    my $n = $self->carregar_uf($uf, $res->{linhas}, $snapshot);
    $e{carregados} += $n;
    $por_uf{ $SIGLA{$uf} // $uf } = $n;
    $self->log_info(sprintf('CNES %s: %d lidos, %d carregados, %d órfãos',
      $SIGLA{$uf} // $uf, scalar @$registros, $n, scalar @{ $res->{orfaos} }));
  };

  my $arquivo;
  if (my $bruto = $args->{jsonl}) {
    die "jsonl não existe: $bruto\n" unless -f $bruto;
    $self->log_info("Relendo o bruto sanitizado $bruto (sem API)");
    my %alvo = map { $_ => 1 } $self->ufs_alvo($args);
    my $grupos = $self->ler_jsonl($bruto);
    $carregar_uf->($_, $grupos->{$_}) for grep { $alvo{$_} } sort { $a <=> $b } keys %$grupos;
    $arquivo = $bruto;
  }
  else {
    $arquivo = $self->caminho_jsonl($snapshot);
    path($arquivo)->dirname->make_path;
    open my $fh, '>>:raw', $arquivo or die "CNES: não abriu $arquivo: $!\n";
    $fh->autoflush(1);
    for my $uf ($self->ufs_alvo($args)) {
      my $registros = $self->baixar_uf($uf, $fh);
      $carregar_uf->($uf, $registros);
    }
    close $fh or die "CNES: não fechou $arquivo: $!\n";
  }

  $self->registrar_orfaos(\@orfaos);
  die "CNES: nenhum estabelecimento carregado — vazio NÃO é sucesso\n" unless $e{carregados};
  $self->preservar_raw($arquivo, $self->url_fonte . '?status=1', tabelas => [TABELA]);

  # row_count = o que o snapshot do dia tem no banco: uma retomada por UF no
  # mesmo dia soma às UFs já carregadas, e não só ao que esta execução leu.
  my $total = eval {
    ($self->app->schema->storage->dbh->selectrow_array(
      'SELECT count(*) FROM ' . TABELA . ' WHERE dt_snapshot = ?', undef, $snapshot))[0]
  } // $e{carregados};
  $total = $e{carregados} unless $total;

  $self->upsert_metadata(TABELA, 'API Saúde cnes/estabelecimentos (status=1), JSONL sanitizado',
    $self->url_fonte, LICENCA, $total,
    sprintf('Estabelecimentos ATIVOS (status=1), SANITIZADOS: só codigo_cnes, município, tipo de unidade, lat/long e data de atualização — '
          . 'razão social, nome fantasia, CNPJ, telefone, e-mail e endereço descartados na ingestão (o bruto preservado também é o sanitizado). '
          . 'Licença CC BY-ND 3.0: subconjunto de colunas sem alteração de valores (não é obra derivada; decisão do developer, #241). '
          . 'Execução: %d lidos, %d carregados (%s); %d órfãos sem município na malha; %d coordenadas descartadas (ausentes, zero ou fora do Brasil -> NULL); '
          . '%d sem tipo de unidade; %d duplicados. dt_snapshot %s.',
      $e{lidos}, $e{carregados}, join(', ', map { "$_=$por_uf{$_}" } sort keys %por_uf),
      scalar(@orfaos), $e{coords_descartadas}, $e{sem_tipo}, $e{duplicados}, $snapshot));
  $self->log_info("CNES: $e{carregados} estabelecimentos carregados (dt_snapshot $snapshot)");
  return $e{carregados};
}

sub _dry_run_sanidade ($self) {
  my $pg = $self->_pagina(12, 0);
  my @san = map { sanitizar($_) } @$pg;
  $self->log_info(sprintf('[DRY-RUN] CNES: sanidade AC offset=0 -> %d estabelecimentos (sanitizados: %s). Nada gravado.',
    scalar @san, join(',', @CAMPOS_FONTE)));
  die "CNES: a primeira página veio vazia — API fora ou parâmetros errados\n" unless @san;
  return scalar @san;
}

# ---------------------------------------------------------------------
# API
# ---------------------------------------------------------------------
sub _pagina ($self, $uf, $offset) {
  my $url = $self->url_fonte;
  my $tx = $self->run_with_retry(sub {
    my $t = $self->ua->get($url => form => {
      status => 1, codigo_uf => $uf, limit => $self->pagina, offset => $offset });
    die sprintf("CNES %s: HTTP %s (uf=%s offset=%d)", $self->recurso, $t->res->code // '?', $uf, $offset)
      unless ($t->res->code // 0) == 200;
    return $t;
  }, "cnes uf=$uf offset=$offset");
  my $json = $tx->res->json;
  die "CNES: resposta sem a chave 'estabelecimentos' (uf=$uf offset=$offset)\n"
    unless ref $json eq 'HASH' && ref $json->{estabelecimentos} eq 'ARRAY';
  return $json->{estabelecimentos};
}

# Baixa uma UF inteira, sanitizando cada registro ANTES de guardar ou gravar:
# o PII nunca chega ao disco. Cada página é anexada ao JSONL (progresso
# visível ao watchdog e bruto para a retomada).
sub baixar_uf ($self, $uf, $fh = undef) {
  my (@registros, $offset);
  $offset = 0;
  for my $i (1 .. $self->max_paginas) {
    my $pg = $self->_pagina($uf, $offset);
    my @san = map { sanitizar($_) } @$pg;
    if ($fh) { print {$fh} encode_json($_), "\n" for @san }
    push @registros, @san;
    last if @$pg < $self->pagina;
    $offset += $self->pagina;
    $self->log_info(sprintf('CNES %s: %d registros', $SIGLA{$uf} // $uf, scalar @registros))
      unless $i % 500;
    sleep($self->throttle) if $self->throttle;
  }
  return \@registros;
}

# Lista branca: só @CAMPOS_FONTE (+ status, que é o filtro da consulta).
sub sanitizar ($r) {
  my %s = (status => 1);
  $s{$_} = $r->{$_} for grep { exists $r->{$_} } @CAMPOS_FONTE;
  return \%s;
}

sub caminho_jsonl ($self, $snapshot) {
  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  return "" . $dir->child("cnes_ativos_sanitizado_$snapshot.jsonl");
}

# Bruto sanitizado -> { codigo_uf => [registros] }. Re-sanitiza ao ler: um
# arquivo de outra origem não fura a lista branca.
sub ler_jsonl ($self, $arquivo) {
  my %g;
  open my $fh, '<:raw', $arquivo or die "CNES: não leu $arquivo: $!\n";
  while (my $l = <$fh>) {
    next unless $l =~ /\S/;
    my $r = sanitizar(decode_json($l));
    push @{ $g{ $r->{codigo_uf} // 0 } }, $r;
  }
  close $fh;
  return \%g;
}

# ---------------------------------------------------------------------
# Mapeamento
# ---------------------------------------------------------------------
sub indice_prefixo6 ($self) {
  my $db = $self->app->schema->storage->dbh;
  my $cods = $db->selectcol_arrayref('SELECT codigo_ibge FROM clean.malha_municipio WHERE codigo_ibge IS NOT NULL');
  my %idx;
  for my $c (@$cods) {
    next unless defined $c && $c =~ /^\d{7}$/;
    $idx{ substr($c, 0, 6) } = $c;
    $idx{$c} = $c;
  }
  return \%idx;
}

sub _coord ($v, $min, $max) {
  return undef unless defined $v && $v =~ /^\s*-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?\s*$/;
  my $n = 0 + $v;
  return undef if $n == 0 || $n < $min || $n > $max;
  return $n;
}

sub _data ($v) {
  return undef unless defined $v && $v =~ /^(\d{4}-\d{2}-\d{2})/;
  return $1;
}

sub mapear ($self, $registros, $indice) {
  my (@linhas, @orfaos, %visto);
  my %e = (coords_descartadas => 0, sem_tipo => 0, duplicados => 0);
  for my $r (@$registros) {
    my $cnes = $r->{codigo_cnes};
    my $mun  = defined $r->{codigo_municipio} ? int($r->{codigo_municipio}) : '';
    my $c7   = (length($mun) == 6 || length($mun) == 7) ? $indice->{$mun} : undef;
    if (!defined $cnes || $cnes !~ /^\d+$/) {
      push @orfaos, { motivo => 'sem_codigo_cnes', codigo_cnes => $cnes // '', codigo_municipio => $mun, codigo_uf => $r->{codigo_uf} };
      next;
    }
    if (!$c7) {
      push @orfaos, { motivo => 'municipio_sem_casa', codigo_cnes => $cnes, codigo_municipio => $mun, codigo_uf => $r->{codigo_uf} };
      next;
    }
    my $tipo = $r->{codigo_tipo_unidade};
    if (!defined $tipo || $tipo !~ /^\d+$/) {
      $e{sem_tipo}++;
      push @orfaos, { motivo => 'sem_tipo_unidade', codigo_cnes => $cnes, codigo_municipio => $mun, codigo_uf => $r->{codigo_uf} };
      next;
    }
    if ($visto{$cnes}++) { $e{duplicados}++; next }

    my $lat = _coord($r->{latitude_estabelecimento_decimo_grau}, LAT_MIN, LAT_MAX);
    my $lon = _coord($r->{longitude_estabelecimento_decimo_grau}, LON_MIN, LON_MAX);
    # Par incompleto não é ponto: as duas ficam NULL juntas.
    if (!defined $lat || !defined $lon) {
      $e{coords_descartadas}++;
      ($lat, $lon) = (undef, undef);
    }
    push @linhas, {
      codigo_cnes         => 0 + $cnes,
      codigo_municipio    => $c7,
      codigo_tipo_unidade => 0 + $tipo,
      status              => 1,
      latitude            => $lat,
      longitude           => $lon,
      data_atualizacao    => _data($r->{data_atualizacao}),
    };
  }
  return { linhas => \@linhas, orfaos => \@orfaos, estatisticas => \%e };
}

# Órfãos: só códigos (nenhum PII), relatório nomeado em data/ingestao.
sub registrar_orfaos ($self, $orfaos) {
  return 0 unless @$orfaos;
  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;
  my $f = $dir->child('cnes_orfaos.csv');
  $f->spew(join('', "motivo,codigo_cnes,codigo_municipio,codigo_uf\n",
    map { join(',', map { $_ // '' } @{$_}{qw(motivo codigo_cnes codigo_municipio codigo_uf)}) . "\n" } @$orfaos),
    'UTF-8');
  my %m; $m{ $_->{motivo} }++ for @$orfaos;
  $self->log->warn(sprintf('[CNES] %d órfão(s) (%s). Relatório: %s',
    scalar @$orfaos, join(', ', map { "$_=$m{$_}" } sort keys %m), $f));
  return scalar @$orfaos;
}

# ---------------------------------------------------------------------
# Carga: uma transação por UF (idempotente na PK)
# ---------------------------------------------------------------------
my @COLS = qw(codigo_cnes codigo_municipio codigo_tipo_unidade status latitude longitude data_atualizacao);

sub carregar_uf ($self, $uf, $linhas, $snapshot) {
  return 0 unless @$linhas;
  my $storage = $self->app->schema->storage;
  my $dbh = $storage->dbh;
  my $sql = sprintf(
    'INSERT INTO %s (%s, dt_snapshot) VALUES (%s, ?)
     ON CONFLICT (codigo_cnes, dt_snapshot) DO UPDATE SET %s',
    TABELA, join(', ', @COLS), join(', ', ('?') x @COLS),
    join(', ', map { "$_ = EXCLUDED.$_" } grep { $_ ne 'codigo_cnes' } @COLS));
  my $n = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare($sql);
      for my $l (@$linhas) {
        $sth->execute(@{$l}{@COLS}, $snapshot);
        $n++;
      }
    });
    1;
  } or die sprintf("Carga CNES da UF %s falhou (UFs anteriores já gravadas; retomar com --arg uf=): %s",
    $SIGLA{$uf} // $uf, $@);
  return $n;
}

1;
