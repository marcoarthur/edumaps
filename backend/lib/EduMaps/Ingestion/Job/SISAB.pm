package EduMaps::Ingestion::Job::SISAB;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use POSIX qw(strftime);

use utf8;

has job_name    => 'SISAB';
has description => 'Ingestão PMMB/Mais Médicos consolidado atual (atenção primária) por município via API de dados abertos da Saúde';
has schedule    => 'monthly';

# =====================================================================
# Fonte (#238, P2 da #156) — conferida em 2026-10-13
#
#   GET https://apidadosabertos.saude.gov.br/atencao-primaria/pmmb-consolidado
#       ?limit=<=1000>&offset=<linha>
#
# - A API devolve {"pmmb": [...]}. `limit` acima de 1000 é truncado para
#   1000; `offset` é por LINHA; a última página é curta e a seguinte vem
#   vazia (medido: 5.631 linhas = 5.571 MUNICIPAL + 34 DSEI + 26 ESTADUAL).
# - É o consolidado ATUAL do Programa Mais Médicos (PMMB), não a série do
#   SISAB nem a cobertura APS total: não há histórico na API. A série
#   acumula a cada execução (decisão do developer, #238).
# - `nivel`: 'MUNICIPAL' | 'DSEI' | 'ESTADUAL'. Só MUNICIPAL entra; DSEI
#   (distritos indígenas, co_ibge 1, 2, …) e ESTADUAL (co_ibge 170, 210, …)
#   são contados e descartados.
# - `co_ibge` dos municípios vem com 6 dígitos (sem o dígito verificador):
#   normaliza-se para os 7 de clean.malha_municipio pelo prefixo de 6. O que
#   não casa vai para o relatório de órfãos — nunca some em silêncio.
# - `cobertura` NÃO é percentual: é população coberta estimada (pessoas;
#   ex.: 15000 para 6 equipes). Grava-se como vem em cobertura_aps e a nota
#   do import_metadata diz a unidade.
# - `categoria_ivs` vem como texto ('3 - Media vulnerabilidade') ou 'NA':
#   guarda-se o número; 'NA' vira NULL (vazio ≠ zero).
# - `dt_referencia` da API é a data de geração do consolidado
#   ('2026-10-09'); o contrato da coluna é o primeiro dia do mês de
#   referência, e a data exata vai para a nota.
# =====================================================================
has base_url => 'https://apidadosabertos.saude.gov.br';
has recurso  => '/atencao-primaria/pmmb-consolidado';
has pagina   => 1000;     # máximo aceito pela API
has throttle => 0.5;      # API pública sem limite declarado
has max_paginas => 100;   # trava contra laço infinito (5.631 linhas = 6 páginas)

use constant TABELA  => 'clean.sisab_aps';
use constant LICENCA => 'CC BY 3.0 (dados abertos SUS)';

sub tabelas ($self, $args = {}) { return (TABELA) }

sub url_fonte ($self) { return $self->base_url . $self->recurso }

# ---------------------------------------------------------------------
# Run
#
# Args: json=<bruto> relê o JSON preservado sem chamar a API.
# --dry-run (honesto): UMA página de sanidade, sem gravar nada.
# ---------------------------------------------------------------------
sub run ($self, $args = {}) {
  $self->exigir_allowlist($self->url_fonte);
  return $self->_dry_run_sanidade if $self->dry_run;

  my ($itens, $arquivo);
  if (my $bruto = $args->{json}) {
    die "json não existe: $bruto\n" unless -f $bruto;
    $self->log_info("Relendo o bruto $bruto (sem API)");
    $itens = $self->ler_json($bruto);
    $arquivo = $bruto;
  }
  else {
    $itens = $self->baixar_tudo;
    $arquivo = $self->gravar_json($itens);
  }
  $self->preservar_raw($arquivo, $self->url_fonte, tabelas => [TABELA]);

  my $res = $self->mapear($itens, $self->indice_prefixo6);
  $self->registrar_orfaos($res->{orfaos});
  die sprintf("SISAB: nenhuma linha municipal casou com a malha (%d itens, %d órfãos) — vazio NÃO é sucesso\n",
      scalar @$itens, scalar @{ $res->{orfaos} })
    unless @{ $res->{linhas} };

  my $snapshot = $args->{dt_snapshot} // strftime('%Y-%m-%d', localtime);
  my $n = $self->carregar($res->{linhas}, $snapshot);

  my $e = $res->{estatisticas};
  $self->upsert_metadata(TABELA, 'API Saúde pmmb-consolidado (JSON)', $self->url_fonte, LICENCA, $n,
    sprintf('PMMB (Programa Mais Médicos) consolidado atual — não é a cobertura APS total do SISAB; série acumula a cada execução. '
          . 'cobertura_aps = população coberta estimada (pessoas), não %%. dt_referencia = 1º dia do mês da geração na API (%s). '
          . 'Itens: %d (MUNICIPAL %d, DSEI %d, ESTADUAL %d, outros %d); órfãos sem casa na malha: %d. dt_snapshot %s.',
      join(',', sort keys %{ $e->{datas_api} }) || '?',
      $e->{itens}, $e->{municipal}, $e->{dsei}, $e->{estadual}, $e->{outros},
      scalar @{ $res->{orfaos} }, $snapshot));
  $self->log_info("SISAB: $n linhas carregadas (dt_snapshot $snapshot)");
  return $n;
}

sub _dry_run_sanidade ($self) {
  my $pg = $self->_pagina(0);
  my %nivel;
  $nivel{ $_->{nivel} // '?' }++ for @$pg;
  $self->log_info(sprintf('[DRY-RUN] SISAB: sanidade offset=0 -> %d itens (%s). Nada gravado.',
    scalar @$pg, join(', ', map { "$_=$nivel{$_}" } sort keys %nivel)));
  die "SISAB: a primeira página veio vazia — API fora ou parâmetros errados\n" unless @$pg;
  return scalar @$pg;
}

# ---------------------------------------------------------------------
# API
# ---------------------------------------------------------------------
sub _pagina ($self, $offset) {
  my $url = $self->url_fonte;
  my $tx = $self->run_with_retry(sub {
    my $t = $self->ua->get($url => form => { limit => $self->pagina, offset => $offset });
    die sprintf("SISAB %s: HTTP %s (offset=%d)", $self->recurso, $t->res->code // '?', $offset)
      unless ($t->res->code // 0) == 200;
    return $t;
  }, "pmmb offset=$offset");
  my $json = $tx->res->json;
  die "SISAB: resposta sem a chave 'pmmb' (offset=$offset)\n"
    unless ref $json eq 'HASH' && ref $json->{pmmb} eq 'ARRAY';
  return $json->{pmmb};
}

sub baixar_tudo ($self) {
  my (@itens, $offset);
  $offset = 0;
  for my $i (1 .. $self->max_paginas) {
    my $pg = $self->_pagina($offset);
    push @itens, @$pg;
    last if @$pg < $self->pagina;
    $offset += $self->pagina;
    sleep($self->throttle) if $self->throttle;
  }
  $self->log_info(sprintf('SISAB: %d itens baixados', scalar @itens));
  return \@itens;
}

# O bruto é o conjunto das páginas num arquivo só ({"pmmb": [...]}), no
# mesmo shape da API, para `--arg json` reler exatamente o que veio.
sub gravar_json ($self, $itens) {
  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;
  my $f = $dir->child('pmmb_consolidado_' . strftime('%Y-%m-%d', localtime) . '.json');
  $f->spew(encode_json({ pmmb => $itens }));
  return "$f";
}

sub ler_json ($self, $arquivo) {
  my $d = decode_json(path($arquivo)->slurp);
  my $itens = ref $d eq 'HASH' ? $d->{pmmb} : $d;
  die "json sem lista 'pmmb': $arquivo\n" unless ref $itens eq 'ARRAY';
  return $itens;
}

# ---------------------------------------------------------------------
# Mapeamento
# ---------------------------------------------------------------------
# prefixo de 6 dígitos (e o próprio código de 7) -> codigo_ibge de 7
# (clean.malha_municipio)
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

sub _num ($v) {
  return undef if !defined $v || $v eq '' || uc($v) eq 'NA';
  return 0 + $v;
}

sub _int ($v) {
  my $n = _num($v);
  return defined $n ? int($n + ($n < 0 ? -0.5 : 0.5)) : undef;
}

sub _ivs ($v) {
  return undef unless defined $v && $v =~ /^\s*(\d+)/;
  return 0 + $1;
}

sub _mes ($data) {
  return undef unless defined $data && $data =~ /^(\d{4})-(\d{2})-\d{2}/;
  return "$1-$2-01";
}

sub mapear ($self, $itens, $indice) {
  my (@linhas, @orfaos, %visto);
  my %e = (itens => scalar @$itens, municipal => 0, dsei => 0, estadual => 0, outros => 0, datas_api => {});
  for my $r (@$itens) {
    my $nivel = uc($r->{nivel} // '');
    if    ($nivel eq 'DSEI')     { $e{dsei}++;     next }
    elsif ($nivel eq 'ESTADUAL') { $e{estadual}++; next }
    elsif ($nivel ne 'MUNICIPAL') { $e{outros}++;  next }
    $e{municipal}++;

    my $cod = defined $r->{co_ibge} ? int($r->{co_ibge}) : '';
    my $c7 = (length($cod) == 6 || length($cod) == 7) ? $indice->{$cod} : undef;
    if (!$c7) {
      push @orfaos, { co_ibge => $cod, municipio => $r->{municipio_dsei}, uf => $r->{uf} };
      next;
    }
    my $ref = _mes($r->{dt_referencia});
    die sprintf("SISAB: dt_referencia inválida para %s: %s\n", $c7, $r->{dt_referencia} // 'undef') unless $ref;
    $e{datas_api}{ $r->{dt_referencia} }++;

    # O consolidado traz uma linha por município; duas para a mesma chave
    # violariam a PK no mesmo INSERT — fica a primeira e conta-se.
    next if $visto{"$c7|$ref"}++;
    push @linhas, {
      codigo_municipio   => $c7,
      dt_referencia      => $ref,
      cobertura_aps      => _num($r->{cobertura}),
      ativas_ff          => _int($r->{ativas_ff}),
      equipe_esf         => _int($r->{equipe_esf}),
      equipe_emsi        => _int($r->{equipe_emsi}),
      total_vagas_ativas => _int($r->{total_vagas_ativas}),
      ocupadas           => _int($r->{total_ocupadas}),
      categoria_ivs      => _ivs($r->{categoria_ivs}),
    };
  }
  $self->log_info(sprintf('SISAB: %d itens -> %d municipais (DSEI %d, ESTADUAL %d, outros %d), %d linhas, %d órfãos',
    $e{itens}, $e{municipal}, $e{dsei}, $e{estadual}, $e{outros}, scalar @linhas, scalar @orfaos));
  return { linhas => \@linhas, orfaos => \@orfaos, estatisticas => \%e };
}

# Município da fonte sem casa na malha: relatório nomeado (como os órfãos
# do BrazilCrime/RENAVAM), nunca descarte silencioso.
sub registrar_orfaos ($self, $orfaos) {
  return 0 unless @$orfaos;
  my $dir = path($self->config->{dir_trabalho} // 'data/ingestao');
  $dir->make_path;
  my $f = $dir->child('sisab_orfaos.csv');
  $f->spew(join('', "co_ibge,uf,municipio\n",
    map { sprintf("%s,%s,\"%s\"\n", $_->{co_ibge} // '', $_->{uf} // '', ($_->{municipio} // '') =~ s/"/""/gr) } @$orfaos),
    'UTF-8');
  $self->log->warn(sprintf('[%s] %d município(s) da fonte sem casa na malha. Amostra: %s. Relatório: %s',
    $self->job_name, scalar @$orfaos,
    join(', ', map { ($_->{uf} // '?') . '/' . ($_->{municipio} // '?') . "($_->{co_ibge})" } @$orfaos[0 .. ($#$orfaos < 4 ? $#$orfaos : 4)]),
    $f));
  return scalar @$orfaos;
}

# ---------------------------------------------------------------------
# Carga (idempotente na PK)
# ---------------------------------------------------------------------
my @COLS = qw(codigo_municipio dt_referencia cobertura_aps ativas_ff equipe_esf equipe_emsi
              total_vagas_ativas ocupadas categoria_ivs);

sub carregar ($self, $linhas, $snapshot) {
  my $storage = $self->app->schema->storage;
  my $dbh = $storage->dbh;
  my $sql = sprintf(
    'INSERT INTO %s (%s, dt_snapshot) VALUES (%s, ?)
     ON CONFLICT (codigo_municipio, dt_referencia, dt_snapshot) DO UPDATE SET %s',
    TABELA, join(', ', @COLS), join(', ', ('?') x @COLS),
    join(', ', map { "$_ = EXCLUDED.$_" } grep { !/^(codigo_municipio|dt_referencia)$/ } @COLS));
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
  } or die "Carga SISAB falhou, nada gravado: $@";
  return $n;
}

1;
