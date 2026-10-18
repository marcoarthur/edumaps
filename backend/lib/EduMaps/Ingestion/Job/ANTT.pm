package EduMaps::Ingestion::Job::ANTT;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);
use Text::CSV;

# =============================================================================
# ANTT — acidentes em rodovias federais concedidas (issue #168)
# =============================================================================
#
# O job antigo baixava PÁGINAS HTML de dataset como se fossem CSV/GPKG e nunca
# carregou nada (as 4 tabelas antt_* estavam vazias). Reescrito sobre a API
# CKAN real do portal, medida a 2026-10-18:
#
#   GET /api/3/action/package_show?id=acidentes-rodovias
#     -> 44 recursos CSV, um por concessionária (nome "Demonstrativos de
#        Acidentes - <CONCESSIONÁRIA>"), servidos em
#        /dataset/ef0171a8-f0df-4817-a4ed-b4ff94d87194/resource/<uuid>/download/<arquivo>.csv
#
# Cada CSV é separado por ';' e codificado em ISO-8859-1 (o antigo job lia com
# o separador errado). As colunas são estáveis entre concessionárias.
#
# Esta primeira fatia carrega UMA das quatro tabelas — `clean.antt_acidente_trecho`,
# a única sem dependência de geometria nem FK a trechos. As outras três seguem
# bloqueadas por decisão de produto, registrada no relatório de fontes:
#   * `antt_trecho_geodados` exige geometria de trecho (LineString) — o CKAN
#     NÃO publica nenhuma (só KMZ de equipamentos e um SHP de pontos de km);
#   * `antt_contagem_equipamento` tem FK para trecho_geodados (bloqueada junto);
#   * `antt_od_municipio` (MONITRIIP) é grão de viagem individual (CNPJ/placa/
#     IMEI) — a allowlist o nega por LGPD; a agregação a município é decisão.
#
# Onde a fonte não tem o campo, o valor é NULL — nunca 0 (#154):
# `causa_provavel` e `condicao_tempo` não existem no CSV de acidentes.
#
# Fan-out (#168): não há junção aqui, mas a lição vale para as fatias que virão
# — agregar ANTES de juntar. O acidente é grão de evento (uma linha por
# ocorrência), então nada é agregado.
# =============================================================================

has job_name    => 'ANTT';
has description => 'Ingestão ANTT: acidentes em rodovias federais concedidas (CKAN, 44 CSVs por concessionária)';
has schedule    => 'monthly';
# ~1 M linhas num COPY: a parte pesada passa minutos sem tocar data/ingestao.
has stall_timeout => 1800;

use constant {
  TAB      => 'clean.antt_acidente_trecho',
  CKAN_PKG => 'https://dados.antt.gov.br/api/3/action/package_show?id=acidentes-rodovias',
  DATASET  => 'acidentes-rodovias',
  LICENCA  => 'CC-BY-4.0 (ANTT)',
};

# Colunas da fonte que o loader exige (contrato). As colunas de veículos são
# somadas em `veiculos_envolvidos`; `horario`, `n_da_ocorrencia`, `sentido` e
# `moderadamente_feridos` não têm coluna no alvo e ficam de fora.
our @COLUNAS_FONTE = qw(
  data horario n_da_ocorrencia km trecho tipo_de_acidente tipo_de_ocorrencia
  mortos gravemente_feridos levemente_feridos ilesos tipo_de_pista
  automovel bicicleta caminhao moto onibus outros tracao_animal
  transporte_de_cargas_especiais trator_maquinas utilitarios
);

our @VEICULOS = qw(
  automovel bicicleta caminhao moto onibus outros
  tracao_animal transporte_de_cargas_especiais trator_maquinas utilitarios
);

sub tabelas ($self, $args = {}) { return (TAB) }

sub run ($self, $args = {}) {
  return $self->_dry_run_sanidade if $self->dry_run;

  my @recursos = $self->recursos_acidentes;
  die "ANTT: nenhum recurso CSV no dataset " . DATASET . "\n" unless @recursos;

  my (@todas, @conc);
  for my $r (@recursos) {
    my $csv = $self->download_file($r->{url}, undef, {}, tabelas => [TAB]);
    push @conc, $r->{concessionaria};
    push @todas, @{ $self->processar_csv($csv, $r->{concessionaria}) };
  }

  die "ANTT: nenhuma linha válida extraída dos " . scalar(@recursos) . " CSVs\n"
    unless @todas;

  # A fonte repete o MESMO evento por sentido (Crescente/Decrescente): 1.877
  # duplicados em 1,06 M linhas, idênticos nas colunas do alvo (o `sentido` não
  # existe na tabela). Agregar/desduplicar ANTES de inserir é a lição da #168.
  my ($unicas, $n_dups) = $self->_dedupe(\@todas);

  my $n = $self->carregar($unicas, \@conc);
  $self->log_info(sprintf('ANTT: %d acidentes de %d concessionárias em %s',
    $n, scalar @conc, TAB));

  $self->upsert_metadata(TAB,
    sprintf('%d CSVs por concessionária (%s)', scalar @recursos, DATASET),
    CKAN_PKG, LICENCA, $n,
    sprintf('Acidentes em rodovias federais concedidas, %d CSVs (um por concessionária) descobertos via '
      . 'CKAN package_show. Grão do EVENTO (concessionaria, data, horario, n_ocorrencia); %d concessionárias, '
      . '%d linhas (%d duplicadas na chave do evento descartadas — a fonte repete o evento por sentido). '
      . 'Colunas sem fonte na planilha (causa_provavel, condicao_tempo) ficam NULL — nunca 0 (#154). '
      . 'Sem município na fonte: o join com trecho → município depende de antt_trecho_geodados, que o CKAN '
      . 'ainda não publica. Job ANTT (#168).',
      scalar @recursos, scalar @conc, $n, $n_dups));
  return $n;
}

# Desduplica pela chave do evento, mantendo a primeira ocorrência (as repetições
# são o mesmo acidente com outro `sentido`, ausente no alvo).
sub _dedupe ($self, $rows) {
  my (%visto, @out);
  my $dups = 0;
  for my $r (@$rows) {
    my $k = join "\x1f", map { defined $_ ? $_ : '' }
      @{$r}{qw(concessionaria data_acidente horario n_ocorrencia)};
    if ($visto{$k}++) { $dups++; next }
    push @out, $r;
  }
  if ($dups) {
    $self->log->warn(sprintf('[ANTT] %d linha(s) descartada(s) por repetir a chave do evento '
      . '(mesmo dia/hora/nº de ocorrência) — a fonte repete o evento por sentido', $dups));
  }
  return (\@out, $dups);
}

# -----------------------------------------------------------------------------
# Descoberta: CKAN package_show → recursos CSV. A concessionária sai do nome do
# recurso ("Demonstrativos de Acidentes - RODOVIA DO AÇO").
# -----------------------------------------------------------------------------
sub recursos_acidentes ($self) {
  $self->exigir_allowlist(CKAN_PKG);
  my $tx = $self->ua->get(CKAN_PKG);
  die 'ANTT: CKAN falhou: ' . ($tx->error->{message} // 'erro') . "\n" if $tx->error;

  my $d = eval { decode_json($tx->res->body) };
  die "ANTT: CKAN não devolveu JSON válido\n" unless $d && $d->{success};
  my $recursos = $d->{result}{resources} // [];

  my @r;
  for my $res (@$recursos) {
    next unless (($res->{format} // '') =~ /^csv$/i);
    my $url = $res->{url} // next;
    next unless $url =~ /\.csv(?:\?|$)/i;
    push @r, {
      url            => $url,
      concessionaria => $self->concessionaria_de($res->{name} // ''),
    };
  }
  $self->log_info(sprintf('ANTT: %d recursos CSV descobertos em %s', scalar @r, DATASET));
  return @r;
}

sub concessionaria_de ($self, $nome) {
  my $c = $nome;
  $c =~ s/^\s*Demonstrativos?\s+de\s+Acidentes\s*-\s*//i;
  $c =~ s/^\s+|\s+$//g;
  return length $c ? $c : 'DESCONHECIDA';
}

# -----------------------------------------------------------------------------
# Parse: ';' + ISO-8859-1. Contrato conferido por arquivo: um CSV com cabeçalho
# diferente é PULADO com aviso, não derruba a carga inteira.
# -----------------------------------------------------------------------------
sub processar_csv ($self, $csv_path, $conc) {
  # allow_loose_quotes/escapes: a fonte tem `"` dentro de campos (medido: o
  # Text::CSV para cedo com EIQ e perde o resto do arquivo — 56 mil linhas
  # viravam 44). Sem estas opções, o parser trunca EM SILÊNCIO.
  my $csv = Text::CSV->new({
    binary => 1, sep_char => ';', auto_diag => 1,
    allow_loose_quotes => 1, allow_loose_escapes => 1,
  });
  open my $fh, '<:encoding(iso-8859-1)', $csv_path
    or die "ANTT: não abriu $csv_path: $!\n";
  my $header = $csv->getline($fh) or do { close $fh; die "ANTT: CSV vazio: $csv_path\n" };
  $header->[0] =~ s/^\x{FEFF}//;
  my %idx = map { $header->[$_] => $_ } 0 .. $#$header;

  my @falta = grep { !exists $idx{$_} } @COLUNAS_FONTE;
  if (@falta) {
    $self->log->warn(sprintf('[ANTT] %s (%s): cabeçalho fora do contrato (faltam: %s) — arquivo pulado',
      $conc, path($csv_path)->basename, join(', ', @falta)));
    close $fh;
    return [];
  }

  # Declaração explícita: `my (@rows, $lidas, …) = ((), 0, …)` é um footgun
  # (medido a 2026-10-18: o `()` do lado direito vai parar no array).
  my @rows;
  my ($lidas, $sem_data, $sem_trecho) = (0, 0, 0);
  while (my $r = $csv->getline($fh)) {
    $lidas++;
    my $data = $self->_data_iso($r->[ $idx{data} ]);
    if (!$data) { $sem_data++; next }
    my $trecho = $self->_txt($r->[ $idx{trecho} ]);
    if (!$trecho) { $sem_trecho++; next }

    push @rows, {
      concessionaria       => $conc,
      data_acidente        => $data,
      horario              => $self->_hora($r->[ $idx{horario} ]),
      n_ocorrencia         => $self->_txt($r->[ $idx{n_da_ocorrencia} ]),
      km                   => $self->_num($r->[ $idx{km} ]),
      trecho               => $trecho,
      tipo_acidente        => $self->_txt($r->[ $idx{tipo_de_acidente} ]),
      classificacao        => $self->_txt($r->[ $idx{tipo_de_ocorrencia} ]),
      causa_provavel       => undef,    # #154: ausente na fonte
      condicao_tempo       => undef,    # #154: ausente na fonte
      pista                => $self->_txt($r->[ $idx{tipo_de_pista} ]),
      mortos               => $self->_int($r->[ $idx{mortos} ]),
      feridos_graves       => $self->_int($r->[ $idx{gravemente_feridos} ]),
      feridos_leves        => $self->_int($r->[ $idx{levemente_feridos} ]),
      ilesos               => $self->_int($r->[ $idx{ilesos} ]),
      veiculos_envolvidos  => $self->_soma_veiculos($r, \%idx),
    };
  }
  # `getline` devolve undef a meio do arquivo quando encontra um erro que não
  # tolera; o loop terminaria e a carga seria TRUNCADA em silêncio (medido:
  # 56 mil linhas viravam 44). Se o fim do arquivo não foi alcançado, aborta.
  # (Não usar error_diag: devolve 2012 até num EOF limpo.)
  my $truncou = !eof($fh);
  close $fh;
  die sprintf("ANTT: parsing de %s parou antes do fim do arquivo (%d linhas lidas) — abortando para não truncar a carga\n",
    $conc, $lidas) if $truncou;

  $self->log_info(sprintf('ANTT %s: %d linhas lidas, %d válidas%s',
    $conc, $lidas, scalar @rows,
    ($sem_data || $sem_trecho) ? sprintf(' (descartadas: %d sem data, %d sem trecho)', $sem_data, $sem_trecho) : ''));
  return \@rows;
}

# -----------------------------------------------------------------------------
# Carga: o recorte por concessionária é SUBSTITUÍDO numa transação. ~1 M linhas
# usam COPY (STDIN csv), não INSERT em lotes: com 16 colunas por linha, o INSERT
# de 500 em 500 levava minutos e o watchdog do Runner matava a carga (medido a
# 2026-10-18: 605 s sem progresso). COPY não faz ON CONFLICT — e não precisa: o
# DELETE prévio já substitui o recorte.
# -----------------------------------------------------------------------------
sub carregar ($self, $rows, $concessionarias) {
  my $dbh = $self->app->schema->storage->dbh;

  # O watchdog do Runner (SIGALRM) consulta a BD a cada 60 s NA MESMA conexão —
  # isso aborta um COPY FROM STDIN a meio ("no COPY in progress", medido a
  # 2026-10-18 com ~958 mil linhas). Bloqueia o SIGALRM durante a carga: o
  # sinal pendente é entregue (e o watchdog re-armado) ao desbloquear.
  require POSIX;
  my $sigset = POSIX::SigSet->new(POSIX::SIGALRM());
  POSIX::sigprocmask(POSIX::SIG_BLOCK(), $sigset);

  my $ok = eval {
    $self->app->schema->storage->txn_do(sub {
      $dbh->do('DELETE FROM ' . TAB . ' WHERE concessionaria = ANY(?::text[])',
        undef, $concessionarias);
      $dbh->do('COPY ' . TAB . ' (concessionaria, data_acidente, horario, n_ocorrencia, km,'
        . ' trecho, tipo_acidente, classificacao, causa_provavel, condicao_tempo, pista,'
        . ' mortos, feridos_graves, feridos_leves, ilesos, veiculos_envolvidos)'
        . ' FROM STDIN WITH (FORMAT csv)');
      for my $r (@$rows) {
        die "ANTT: linha de carga não é hashref\n" unless ref $r eq 'HASH';
        $dbh->pg_putcopydata(join(',', map { _csv_campo($_) } (
          $r->{concessionaria}, $r->{data_acidente}, $r->{horario}, $r->{n_ocorrencia},
          $r->{km}, $r->{trecho}, $r->{tipo_acidente}, $r->{classificacao},
          $r->{causa_provavel}, $r->{condicao_tempo}, $r->{pista}, $r->{mortos},
          $r->{feridos_graves}, $r->{feridos_leves}, $r->{ilesos}, $r->{veiculos_envolvidos},
        )) . "\n");
      }
      $dbh->pg_putcopyend();
    });
    1;
  };
  my $erro = $@;

  POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $sigset);
  die "ANTT: carga falhou, nada gravado: $erro" unless $ok;
  return scalar @$rows;
}

# Campo para COPY ... FORMAT csv: undef vira campo VAZIO (NULL no COPY csv);
# qualquer outro valor sai entre aspas (vírgulas/quebras/quotes escapados).
sub _csv_campo ($v) {
  return '' unless defined $v;
  $v =~ s/\x00//g;    # NUL não existe em coluna texto do Postgres (medido: 0x00 na fonte)
  $v =~ s/"/""/g;
  return qq{"$v"};
}

# -----------------------------------------------------------------------------
# Dry-run honesto: HEAD na API CKAN + presença do host.
# -----------------------------------------------------------------------------
sub _dry_run_sanidade ($self) {
  $self->exigir_allowlist(CKAN_PKG);
  # GET, não HEAD: a API CKAN responde 500 a HEAD (medido 2026-10-18).
  my $res = $self->run_with_retry(sub {
    my $tx = $self->ua->get(CKAN_PKG);
    die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
    return $tx->result;
  }, 'GET ' . CKAN_PKG);
  $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d', CKAN_PKG, $res->code));
  $self->log_info('[DRY-RUN] ANTT: acidentes-rodovias (44 CSVs); nada baixado nem gravado');
  return 0;
}

# -----------------------------------------------------------------------------
# Conversores (métodos, para os testes os chamarem via o objecto).
# -----------------------------------------------------------------------------
sub _data_iso ($self, $v) {
  return undef unless defined $v;
  $v =~ s/^\s+|\s+$//g;
  return $v if $v =~ /^\d{4}-\d{2}-\d{2}$/;
  return "$3-$2-$1" if $v =~ m{^(\d{2})/(\d{2})/(\d{4})$};
  return undef;
}

sub _hora ($self, $v) {
  return undef unless defined $v && $v =~ /\S/;
  $v =~ s/^\s+|\s+$//g;
  return sprintf('%02d:%s:%02d', $1, $2, $3 // 0) if $v =~ /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/;
  return undef;
}

sub _num ($self, $v) {
  return undef unless defined $v && $v =~ /\S/;
  $v =~ s/^\s+|\s+$//g;
  $v =~ s/\.//g if $v =~ /,/ && $v =~ /\./;   # 1.234,5 -> 1234,5
  $v =~ s/,/./;
  return undef unless $v =~ /^-?\d+(?:\.\d+)?$/;
  return 0 + $v;
}

sub _int ($self, $v) {
  return undef unless defined $v && $v =~ /\S/;
  $v =~ s/^\s+|\s+$//g;
  return undef unless $v =~ /^\d+$/;
  return 0 + $v;
}

sub _txt ($self, $v) {
  return undef unless defined $v;
  $v =~ s/^\s+|\s+$//g;
  return length $v ? $v : undef;
}

sub _soma_veiculos ($self, $r, $idx) {
  my ($soma, $tem) = (0, 0);
  for my $c (@VEICULOS) {
    my $n = $self->_int($r->[ $idx->{$c} ]);
    next unless defined $n;
    $soma += $n;
    $tem = 1;
  }
  return $tem ? $soma : undef;   # #154: sem nenhum veículo informado -> NULL
}

1;
