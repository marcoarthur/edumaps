package EduMaps::Ingestion::Job::ANTT;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;
use utf8;

use Mojo::File qw(path tempdir);
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
# Carrega `clean.antt_acidente_trecho`. O acidente não traz município, só o
# trecho ('BR-393/RJ') e o km. Para chegar à escola, o job:
#   1. carrega a camada de PONTOS de km da ANTT em `clean.antt_marco_km`
#      (SHP lido com ogr2ogr: gdal-bin é dependência de deploy do minion);
#   2. chama `clean.antt_geolocalizar_acidentes()`, que põe o ponto do acidente
#      (marco exato ou interpolação entre marcos vizinhos) e o município
#      (polígono da malha que contém o ponto). O balanço vai ao log e ao
#      import_metadata: acidente não localizado fica contado, nunca some.
#
# As outras três tabelas do desenho original (trecho_geodados, contagem e OD)
# foram removidas pela change `antt_sem_fonte`: a ANTT não publica o dado para
# o qual foram desenhadas (geometria de trecho; código de trecho no volume;
# OD só em grão de viagem individual, negado por LGPD).
#
# Onde a fonte não tem o campo, o valor é NULL — nunca 0 (#154):
# `causa_provavel` e `condicao_tempo` não existem no CSV de acidentes.
#
# Fan-out (#168): não há junção aqui, mas a lição vale para as fatias que virão
# — agregar ANTES de juntar. O acidente é grão de evento (uma linha por
# ocorrência), então nada é agregado.
# =============================================================================

has job_name    => 'ANTT';
has description => 'Ingestão ANTT: acidentes em rodovias federais concedidas (CKAN, 44 CSVs por concessionária), localizados por município pelos marcos de km';
has schedule    => 'monthly';
# ~1 M linhas num COPY: a parte pesada passa minutos sem tocar data/ingestao.
has stall_timeout => 1800;

use constant {
  TAB        => 'clean.antt_acidente_trecho',
  TAB_MARCOS => 'clean.antt_marco_km',
  # Dataset CKAN da camada de pontos de km. A confirmar quando o portal voltar
  # (medido 2026-11-11: dados.antt.gov.br em timeout). Vazio = sem descoberta
  # automática: o job usa `--arg marcos=<arquivo>` ou os marcos já carregados.
  MARCOS_PKG => '',
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

sub tabelas ($self, $args = {}) { return (TAB, TAB_MARCOS) }

# Nomes que a camada de km pode usar para cada campo (o primeiro presente
# vence). A camada real ainda não foi medida; um nome fora desta lista faz o
# job abortar listando os campos que encontrou — nunca carrega às cegas.
our %CAMPOS_MARCO = (
  rodovia        => [qw(rodovia br nm_rodovia sg_rodovia cod_rodovia vl_br)],
  uf             => [qw(uf sg_uf estado)],
  km             => [qw(km nu_km vl_km km_marco)],
  concessionaria => [qw(concessionaria concessao nm_concessionaria)],
);

sub run ($self, $args = {}) {
  return $self->_dry_run_sanidade if $self->dry_run;

  # `--arg apenas_marcos`: troca só os marcos e relocaliza os acidentes já
  # carregados, sem baixar de novo os 44 CSVs.
  my $n = $args->{apenas_marcos} ? undef : $self->carregar_acidentes;
  $self->atualizar_marcos($args);
  my $balanco = $self->geolocalizar;
  $self->registrar_localizacao($balanco);
  return $n // $balanco->{total};
}

sub carregar_acidentes ($self) {
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
      . 'Sem município na fonte: o ponto sai dos marcos de km (clean.antt_marco_km) e o município do '
      . 'polígono que o contém. Job ANTT (#168).',
      scalar @recursos, scalar @conc, $n, $n_dups));
  return $n;
}

# -----------------------------------------------------------------------------
# Marcos de km: camada de pontos da ANTT -> clean.antt_marco_km. A tabela é
# SUBSTITUÍDA inteira (a camada é um retrato único, não um recorte).
# Origem: `--arg marcos=<arquivo .zip/.shp/.gpkg>`, ou o dataset MARCOS_PKG
# quando confirmado. Sem nenhum dos dois, mantém os marcos já carregados.
# -----------------------------------------------------------------------------
sub atualizar_marcos ($self, $args = {}) {
  my ($arquivo, $origem);
  if (my $local = $args->{marcos}) {
    die "ANTT: arquivo de marcos não existe: $local\n" unless -f $local;
    $self->preservar_raw($local, undef, tabelas => [TAB_MARCOS]);
    ($arquivo, $origem) = ($local, $local);
  }
  elsif (my $r = $self->recurso_marcos) {
    $arquivo = $self->download_file($r->{url}, undef, {}, tabelas => [TAB_MARCOS]);
    $origem  = $r->{url};
  }
  else {
    my $n = $self->app->schema->storage->dbh->selectrow_array('SELECT count(*) FROM ' . TAB_MARCOS);
    $self->log->warn(sprintf('[ANTT] camada de marcos de km sem origem (MARCOS_PKG não confirmado, '
      . 'sem --arg marcos): mantidos os %d marcos já carregados', $n));
    return undef;
  }

  my $marcos = $self->ler_marcos($arquivo);
  my ($unicos, $dups) = $self->_dedupe_marcos($marcos);
  my $n = $self->carregar_marcos($unicos);
  $self->log_info(sprintf('ANTT: %d marcos de km em %s (%d repetidos descartados)', $n, TAB_MARCOS, $dups));
  $self->upsert_metadata(TAB_MARCOS, path($arquivo)->basename, $origem, LICENCA, $n,
    sprintf('Marcos quilométricos (pontos de km) das rodovias federais concedidas, camada de geodados da ANTT, '
      . 'lida com ogr2ogr e reprojetada para SIRGAS 2000 (EPSG:4674). Um ponto por (rodovia, UF, km); '
      . '%d repetidos na chave descartados. Usados para localizar os acidentes (#168).', $dups));
  return $n;
}

# Descoberta CKAN do recurso de marcos (SHP/ZIP). Sem MARCOS_PKG, não há.
sub recurso_marcos ($self) {
  return undef unless MARCOS_PKG;
  my $url = 'https://dados.antt.gov.br/api/3/action/package_show?id=' . MARCOS_PKG;
  $self->exigir_allowlist($url);
  my $tx = $self->ua->get($url);
  die 'ANTT: CKAN (marcos) falhou: ' . ($tx->error->{message} // 'erro') . "\n" if $tx->error;
  my $d = eval { decode_json($tx->res->body) };
  die "ANTT: CKAN (marcos) não devolveu JSON válido\n" unless $d && $d->{success};
  my @shp = grep { ($_->{format} // '') =~ /^(?:shp|zip|shapefile|gpkg)$/i } @{ $d->{result}{resources} // [] };
  die sprintf("ANTT: dataset %s devolveu %d recursos de geometria (esperava 1)\n", MARCOS_PKG, scalar @shp)
    unless @shp == 1;
  return { url => $shp[0]{url} };
}

# Comando GDAL: qualquer formato vetorial -> GeoJSON em EPSG:4674. RFC7946=NO
# é o que faz o -t_srs valer: no modo RFC 7946 (e no GeoJSONSeq) o GDAL grava
# sempre em WGS 84 e ignora o SIRGAS 2000 pedido (medido: avisa e reprojeta).
# Um .zip é lido sem descompactar (/vsizip/).
sub comando_marcos ($self, $arquivo, $saida) {
  my $fonte = $arquivo =~ /\.zip$/i ? "/vsizip/$arquivo" : $arquivo;
  return ['ogr2ogr', '-f', 'GeoJSON', '-lco', 'RFC7946=NO', '-t_srs', 'EPSG:4674', $saida, $fonte];
}

# Lê a camada e devolve [{rodovia, uf, km, concessionaria, x, y}]. Campos
# resolvidos por %CAMPOS_MARCO; a falta de rodovia ou km aborta a carga.
sub ler_marcos ($self, $arquivo) {
  my $dir = tempdir;    # apagado quando sai de escopo
  my $saida = "$dir/marcos.geojson";
  $self->log_info("ogr2ogr: $arquivo -> GeoJSON (EPSG:4674)");
  $self->executar($self->comando_marcos($arquivo, $saida));
  die "ANTT: ogr2ogr não gerou $saida\n" unless -s $saida;

  my $fc = decode_json(path($saida)->slurp);
  my (%campo, @rows);
  my ($lidas, $sem_ponto, $ilegiveis) = (0, 0, 0);
  for my $f (@{ $fc->{features} // [] }) {
    $lidas++;
    my $p = $f->{properties} // {};
    %campo = $self->_resolver_campos_marco([keys %$p]) unless %campo;

    my $xy = _ponto($f->{geometry});
    if (!$xy) { $sem_ponto++; next }

    my $rod = $p->{ $campo{rodovia} };
    my $uf  = defined $campo{uf} ? $p->{ $campo{uf} } : undef;
    my $r = {
      rodovia        => $self->rodovia_normalizada($rod),
      uf             => $self->_uf($uf) // $self->_uf_do_trecho($rod),
      km             => $self->_num($p->{ $campo{km} }),
      concessionaria => defined $campo{concessionaria} ? $self->_txt($p->{ $campo{concessionaria} }) : undef,
      x => $xy->[0], y => $xy->[1],
    };
    if (!defined $r->{rodovia} || !defined $r->{uf} || !defined $r->{km}) { $ilegiveis++; next }
    push @rows, $r;
  }
  die "ANTT: camada de marcos sem nenhum ponto legível ($lidas feições)\n" unless @rows;
  $self->log_info(sprintf('ANTT marcos: %d feições, %d válidas (descartadas: %d sem ponto, %d sem rodovia/UF/km)',
    $lidas, scalar @rows, $sem_ponto, $ilegiveis));
  return \@rows;
}

sub _resolver_campos_marco ($self, $nomes) {
  my %por_minusculo = map { lc($_) => $_ } @$nomes;
  my %campo;
  for my $alvo (keys %CAMPOS_MARCO) {
    my ($achado) = grep { exists $por_minusculo{$_} } @{ $CAMPOS_MARCO{$alvo} };
    $campo{$alvo} = $por_minusculo{$achado} if defined $achado;
  }
  my @falta = grep { !defined $campo{$_} } qw(rodovia km);
  die sprintf("ANTT: camada de marcos fora do contrato (sem campo de %s); campos encontrados: %s\n",
    join(' e ', @falta), join(', ', sort @$nomes)) if @falta;
  return %campo;
}

# Point ou MultiPoint (primeiro ponto). Outras geometrias: não é marco.
sub _ponto ($g) {
  return undef unless ref $g eq 'HASH';
  my $c = $g->{coordinates};
  return [ @{$c}[0, 1] ] if ($g->{type} // '') eq 'Point' && ref $c eq 'ARRAY';
  return [ @{ $c->[0] }[0, 1] ] if ($g->{type} // '') eq 'MultiPoint' && ref $c eq 'ARRAY' && ref $c->[0] eq 'ARRAY';
  return undef;
}

# Mesma regra de clean.antt_rodovia_normalizada(): 'BR-393/RJ', 'BR 40', '393' -> 'BR-393'/'BR-040'.
sub rodovia_normalizada ($self, $v) {
  return undef unless defined $v;
  my $t = uc $v;
  $t =~ s/^\s+|\s+$//g;
  return sprintf('BR-%03d', $1) if $t =~ /^BR\s*-?\s*0*(\d{1,3})(?!\d)/;
  return sprintf('BR-%03d', $1) if $t =~ /^0*(\d{1,3})(?:\.0+)?$/;    # campo numérico: só o número da BR
  return undef;
}

sub _uf ($self, $v) {
  return undef unless defined $v;
  my $t = uc $v;
  $t =~ s/^\s+|\s+$//g;
  return $t =~ /^[A-Z]{2}$/ ? $t : undef;
}

sub _uf_do_trecho ($self, $v) {
  return undef unless defined $v;
  return uc($1) if $v =~ m{/\s*([A-Za-z]{2})\s*$};
  return undef;
}

sub _dedupe_marcos ($self, $rows) {
  my (%visto, @out);
  my $dups = 0;
  for my $r (@$rows) {
    my $k = join "\x1f", $r->{rodovia}, $r->{uf}, 0 + $r->{km};
    if ($visto{$k}++) { $dups++; next }
    push @out, $r;
  }
  return (\@out, $dups);
}

sub carregar_marcos ($self, $rows) {
  my $dbh = $self->app->schema->storage->dbh;
  # Mesmo cuidado do COPY dos acidentes: o SIGALRM do watchdog no meio de um
  # COPY FROM STDIN aborta a carga (ver carregar()).
  require POSIX;
  my $sigset = POSIX::SigSet->new(POSIX::SIGALRM());
  POSIX::sigprocmask(POSIX::SIG_BLOCK(), $sigset);
  my $ok = eval { $self->app->schema->storage->txn_do(sub {
    $dbh->do('DELETE FROM ' . TAB_MARCOS);
    $dbh->do('COPY ' . TAB_MARCOS . ' (rodovia, uf, km, concessionaria, geom) FROM STDIN WITH (FORMAT csv)');
    for my $r (@$rows) {
      $dbh->pg_putcopydata(join(',', map { _csv_campo($_) } (
        $r->{rodovia}, $r->{uf}, $r->{km}, $r->{concessionaria},
        sprintf('SRID=4674;POINT(%.10f %.10f)', $r->{x}, $r->{y}),
      )) . "\n");
    }
    $dbh->pg_putcopyend();
  }); 1 };
  my $erro = $@;
  POSIX::sigprocmask(POSIX::SIG_UNBLOCK(), $sigset);
  die "ANTT: carga dos marcos falhou, nada gravado: $erro" unless $ok;
  return scalar @$rows;
}

# -----------------------------------------------------------------------------
# Localização dos acidentes (função do banco). Devolve o balanço por situação
# mais `total` e `localizados` (com município).
# -----------------------------------------------------------------------------
sub geolocalizar ($self) {
  my $dbh = $self->app->schema->storage->dbh;
  my %b;
  $self->app->schema->storage->txn_do(sub {
    %b = map { @$_ } @{ $dbh->selectall_arrayref(
      'SELECT situacao, n FROM clean.antt_geolocalizar_acidentes()') };
  });
  $b{total} = 0;
  $b{total} += $b{$_} for grep { $_ ne 'total' } keys %b;
  $b{localizados} = ($b{marco} // 0) + ($b{interpolado} // 0);
  $self->log_info(sprintf('ANTT localização: %d de %d acidentes com município (%s)',
    $b{localizados}, $b{total},
    join(', ', map { "$_=$b{$_}" } sort grep { !/^(?:total|localizados)$/ } keys %b)));
  return \%b;
}

# O balanço vai para as notas do import_metadata do acidente (substitui o da
# carga anterior): quem consulta a proveniência vê quanto ficou sem município.
sub registrar_localizacao ($self, $b) {
  return if $self->dry_run;
  my $txt = sprintf(' Localização: %d de %d acidentes com município (%s).',
    $b->{localizados}, $b->{total},
    join(', ', map { "$_=$b->{$_}" } sort grep { !/^(?:total|localizados)$/ } keys %$b));
  $self->app->schema->storage->dbh->do(
    q{UPDATE clean.import_metadata
         SET notes = regexp_replace(coalesce(notes, ''), ' Localização: .*$', '') || ?
       WHERE table_name = ?}, undef, $txt, TAB);
  return $txt;
}

# Ponto de execução isolado (os testes substituem).
sub executar ($self, $argv) {
  my $rc = system { $argv->[0] } @$argv;
  die sprintf("%s falhou (rc=%d)\n", $argv->[0], $rc == -1 ? -1 : $rc >> 8) if $rc;
  return 1;
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
  my $gdal = $self->_ogr2ogr_versao;
  die "[DRY-RUN] ogr2ogr ausente: a camada de marcos de km exige gdal-bin (Rex deploy_minion_dev / imagem do minion)\n"
    unless $gdal;
  $self->log_info("[DRY-RUN] $gdal");
  $self->log_info('[DRY-RUN] ANTT: acidentes-rodovias (44 CSVs) + marcos de km ('
    . (MARCOS_PKG || 'dataset a confirmar') . '); nada baixado nem gravado');
  return 0;
}

sub _ogr2ogr_versao ($self) {
  my $v = `ogr2ogr --version 2>/dev/null`;
  chomp $v if defined $v;
  return $v;
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
