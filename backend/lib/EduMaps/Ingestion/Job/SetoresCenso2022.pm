package EduMaps::Ingestion::Job::SetoresCenso2022;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use POSIX qw(strftime);
use Text::CSV;
use utf8;

# =============================================================================
# Malha de setores + Censo 2022 por setor (#238, fase P2 da #156)
# =============================================================================
#
# Duas tabelas, nesta ordem (censo2022_setor tem FK para a malha):
#
# 1. clean.malha_setor_censitario <- BR_setores_CD2022.gpkg (IBGE geoftp,
#    ~1,49 GB, SIRGAS 2000 / EPSG 4674). Carregado com ogr2ogr numa tabela
#    de passagem em `raw` (apagada no fim) e copiado com INSERT…SELECT:
#    geometria inválida passa por ST_MakeValid (e é contada), setor cujo
#    município não está em clean.malha_municipio (FK) fica de fora e é
#    contado, nunca abortando a carga inteira.
#
# 2. clean.censo2022_setor <- Agregados por Setores Censitários (IBGE FTP),
#    três ZIPs com um CSV cada (latin1, `;`, entre aspas):
#      basico      identificação + domicílios (V0002/V0003/V0004)
#      demografia  moradores, sexo e faixas de idade (V01006..V01041)
#      cor_ou_raca branca/preta/amarela/parda/indígena (V01317..V01321)
#    Sem fonte no Censo 2022 por setor (decisão do developer, #238): esc_*
#    (escolaridade — o tema publicado é só alfabetização), rend_media,
#    rend_per_capita e cor_sem_decl ficam NULL. Não se inventa.
#    Supressão: o IBGE escreve "X" na célula suprimida por sigilo. Vira NULL
#    e marca supressao_celula_pequena = true no setor — nunca 0.
#
# Args (--arg): so=malha|censo (uma parte só); gpkg=<arquivo> e
# dir_zips=<diretório> reaproveitam brutos já baixados (relê sem rede);
# uf=XX restringe a uma UF (teste).
# =============================================================================

# O ogr2ogr do GPKG (1,49 GB) e o INSERT…SELECT com agrupamento de partes
# escrevem só no banco: >10 min sem mudar data/ingestao, que o watchdog do
# Runner (600 s) lia como travamento (medido na P2, #238). O Runner usa este
# prazo quando ele é maior que o seu.
has stall_timeout => 3600;

has job_name    => 'SetoresCenso2022';
has description => 'Malha de setores censitários + Censo 2022 por setor (IBGE)';
has schedule    => 'manual';

use constant {
  TAB_MALHA => 'clean.malha_setor_censitario',
  TAB_CENSO => 'clean.censo2022_setor',
  LICENCA   => 'Domínio público (IBGE)',
  URL_GPKG  => 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/gpkg/BR/BR_setores_CD2022.gpkg',
  CAMADA    => 'BR_setores_CD2022',
  URL_CSVS  => 'https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/Agregados_por_Setor_csv',
  # Tabela de passagem do ogr2ogr: num schema que já existe (raw), apagada
  # ao fim da carga (sucesso ou falha). Não é tabela do modelo.
  STAGE     => 'raw.stage_setores_cd2022',
  LOTE      => 1000,
};

# ZIPs do Censo 2022 por setor (nomes do FTP verificados em 2026-10-13).
our %ZIP = (
  basico      => 'Agregados_por_setores_basico_BR_20260520.zip',
  demografia  => 'Agregados_por_setores_demografia_BR.zip',
  cor_ou_raca => 'Agregados_por_setores_cor_ou_raca_BR.zip',
);

# Colunas do GPKG usadas (confirmadas no DDL do arquivo, 2026-10-13).
our @COLUNAS_GPKG = qw(CD_SETOR SITUACAO CD_UF CD_MUN NM_MUN);

# CD_UF (IBGE) -> sigla.
our %SIGLA_UF = (
  11 => 'RO', 12 => 'AC', 13 => 'AM', 14 => 'RR', 15 => 'PA', 16 => 'AP', 17 => 'TO',
  21 => 'MA', 22 => 'PI', 23 => 'CE', 24 => 'RN', 25 => 'PB', 26 => 'PE', 27 => 'AL',
  28 => 'SE', 29 => 'BA', 31 => 'MG', 32 => 'ES', 33 => 'RJ', 35 => 'SP', 41 => 'PR',
  42 => 'SC', 43 => 'RS', 50 => 'MS', 51 => 'MT', 52 => 'GO', 53 => 'DF',
);

# Coluna da tabela => variáveis do IBGE somadas (todas presentes, senão NULL).
# Demografia: V01031..V01041 são as faixas para ambos os sexos (dicionário
# 20260520); 20-29 é a soma de 20-24 e 25-29.
our %MAPA = (
  basico => {
    dom_total      => ['V0002'],
    dom_particular => ['V0003'],
    dom_coletivo   => ['V0004'],
  },
  demografia => {
    pop_total     => ['V01006'],
    pop_homens    => ['V01007'],
    pop_mulheres  => ['V01008'],
    idade_0_4     => ['V01031'],
    idade_5_9     => ['V01032'],
    idade_10_14   => ['V01033'],
    idade_15_19   => ['V01034'],
    idade_20_29   => ['V01035', 'V01036'],
    idade_30_39   => ['V01037'],
    idade_40_49   => ['V01038'],
    idade_50_59   => ['V01039'],
    idade_60_69   => ['V01040'],
    idade_70_mais => ['V01041'],
  },
  cor_ou_raca => {
    cor_branca   => ['V01317'],
    cor_preta    => ['V01318'],
    cor_amarela  => ['V01319'],
    cor_parda    => ['V01320'],
    cor_indigena => ['V01321'],
  },
);

# Sem fonte no Censo 2022 por setor: ficam NULL (decisão do developer, #238).
our @SEM_FONTE = qw(
  esc_sem_instrucao esc_fund_incomp esc_fund_comp esc_med_incomp esc_med_comp
  esc_sup_incomp esc_sup_comp rend_media rend_per_capita cor_sem_decl
);

sub tabelas ($self, $args = {}) {
  my $so = $args->{so} // '';
  return (TAB_MALHA) if $so eq 'malha';
  return (TAB_CENSO) if $so eq 'censo';
  return (TAB_MALHA, TAB_CENSO);
}

sub run ($self, $args = {}) {
  my $so = $args->{so} // '';
  die "so=$so inválido (use malha ou censo)\n" if length $so && $so !~ /^(?:malha|censo)$/;
  my $uf = $self->_cd_uf($args);

  return $self->_dry_run_sanidade($args) if $self->dry_run;

  my $total = 0;
  $total += $self->carregar_malha($args, $uf) unless $so eq 'censo';
  $total += $self->carregar_censo($args, $uf) unless $so eq 'malha';
  return $total;
}

# uf=XX -> CD_UF ('35'); undef sem filtro.
sub _cd_uf ($self, $args) {
  my $sigla = uc($args->{uf} // '');
  return undef unless length $sigla;
  my %cd = reverse %SIGLA_UF;
  die "uf=$sigla desconhecida\n" unless $cd{$sigla};
  return "$cd{$sigla}";
}

# ---------------------------------------------------------------------------
# Dry-run honesto: uma requisição de sanidade por fonte (HEAD), ogr2ogr
# presente, nada escrito.
# ---------------------------------------------------------------------------
sub _dry_run_sanidade ($self, $args) {
  my $so = $args->{so} // '';
  my @urls;
  push @urls, URL_GPKG unless $so eq 'censo' || $args->{gpkg};
  push @urls, map { URL_CSVS . "/$ZIP{$_}" } sort keys %ZIP
    unless $so eq 'malha' || $args->{dir_zips};
  for my $url (@urls) {
    $self->exigir_allowlist($url);
    my $res = $self->run_with_retry(sub {
      my $tx = $self->ua->head($url);
      die(($tx->error->{message} // 'erro') . "\n") if $tx->error;
      return $tx->result;
    }, "HEAD $url");
    $self->log_info(sprintf('[DRY-RUN] %s -> HTTP %d, %s bytes',
      $url, $res->code, $res->headers->content_length // '?'));
  }
  unless ($so eq 'censo') {
    my $versao = $self->_ogr2ogr_versao;
    die "[DRY-RUN] ogr2ogr ausente: a carga da malha exige gdal-bin (Rex deploy_minion_dev)\n"
      unless $versao;
    $self->log_info("[DRY-RUN] $versao");
  }
  $self->log_info('[DRY-RUN] SetoresCenso2022: fontes acessíveis; nada baixado nem gravado');
  return 0;
}

sub _ogr2ogr_versao ($self) {
  my $v = `ogr2ogr --version 2>/dev/null`;
  chomp $v if defined $v;
  return ($? == 0 && $v) ? $v : undef;
}

# =============================================================================
# 1. Malha
# =============================================================================
sub carregar_malha ($self, $args, $uf = undef) {
  my $gpkg = $self->_obter_gpkg($args);
  my ($argv, $env) = $self->comando_ogr2ogr($gpkg, $uf);
  $self->log_info('ogr2ogr -> ' . STAGE . ($uf ? " (CD_UF=$uf)" : ''));

  my $dbh = $self->app->schema->storage->dbh;
  my %r;
  my $ok = eval {
    $self->executar($argv, $env);
    %r = $self->_copiar_stage_malha($dbh);
    1;
  };
  my $err = $@;
  eval { $dbh->do('DROP TABLE IF EXISTS ' . STAGE) };
  die "Carga da malha falhou: $err" unless $ok;

  $self->log_info(sprintf(
    'Malha: %d setores carregados de %d no GPKG (%d feições; %d partes extras agrupadas em MULTIPOLYGON); %d geometrias reparadas (ST_MakeValid); %d fora (município ausente da malha_municipio); %d descartados (código inválido ou geometria vazia após reparo)',
    @r{qw(carregados no_stage feicoes multipartes reparadas orfaos descartados)}));
  die "Malha: nenhum setor carregado\n" unless $r{carregados};

  $self->upsert_metadata(TAB_MALHA, CAMADA . '.gpkg (IBGE geoftp, Censo 2022)', URL_GPKG, LICENCA,
    $r{carregados},
    sprintf('Malha de setores do Censo 2022 (camada %s, SIRGAS 2000/EPSG 4674), carregada com ogr2ogr (#238).%s %d setores de %d no arquivo (%d feições: setores multipartes agrupados num MULTIPOLYGON); %d geometrias inválidas reparadas com ST_MakeValid; %d setores fora por município ausente de clean.malha_municipio (FK)%s; %d descartados (código ≠ 15 dígitos, CD_MUN incoerente ou geometria vazia após reparo).',
      CAMADA, ($uf ? " Recorte CD_UF=$uf." : ''), @r{qw(carregados no_stage feicoes reparadas orfaos)},
      ($r{amostra_orfaos} ? " (ex.: $r{amostra_orfaos})" : ''), $r{descartados}));
  return $r{carregados};
}

sub _obter_gpkg ($self, $args) {
  my $tab = [TAB_MALHA];
  if (my $local = $args->{gpkg}) {
    die "gpkg não existe: $local\n" unless -f $local;
    $self->log_info("Relendo o bruto $local (sem download)");
    $self->preservar_raw($local, URL_GPKG, tabelas => $tab);
    return $local;
  }
  return $self->download_file(URL_GPKG, undef, {}, tabelas => $tab);
}

# Credenciais do banco: as mesmas do app (EduMaps::Schema->go lê
# db_params do edu_maps.conf), entregues ao ogr2ogr por variáveis PG* do
# libpq. A senha NUNCA vai na linha de comando (ps, logs).
sub credenciais_pg ($self) {
  my $info = $self->app->schema->storage->connect_info // [];
  my ($dsn, $user, $pass) = ref $info->[0] eq 'HASH'
    ? @{ $info->[0] }{qw(dsn user password)}
    : @$info;
  die "connect_info sem DSN\n" unless defined $dsn && !ref $dsn;
  my ($corpo) = $dsn =~ /^dbi:Pg:(.*)$/i or die "DSN não é dbi:Pg\n";
  my %kv = map { /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ ? (lc $1 => $2) : () } split /;/, $corpo;
  my %env = (
    PGDATABASE => $kv{dbname} // $kv{database} // $kv{db},
    ($kv{host} ? (PGHOST => $kv{host}) : ()),
    ($kv{port} ? (PGPORT => $kv{port}) : ()),
    (defined $user ? (PGUSER => $user) : ()),
    (defined $pass && length $pass ? (PGPASSWORD => $pass) : ()),
  );
  die "DSN sem dbname\n" unless $env{PGDATABASE};
  return \%env;
}

# Linha de comando do ogr2ogr (sem segredo) + ambiente PG*.
sub comando_ogr2ogr ($self, $gpkg, $uf = undef) {
  my @argv = (
    'ogr2ogr', '-f', 'PostgreSQL', 'PG:', "$gpkg", CAMADA,
    '-nln', STAGE, '-overwrite',
    '-select', join(',', @COLUNAS_GPKG),
    '-nlt', 'PROMOTE_TO_MULTI',
    '-t_srs', 'EPSG:4674',
    '-lco', 'GEOMETRY_NAME=geom',
    '-lco', 'SPATIAL_INDEX=NONE',
    '-lco', 'LAUNDER=YES',
    '--config', 'PG_USE_COPY', 'YES',
    ($uf ? ('-where', "CD_UF = '$uf'") : ()),
  );
  return (\@argv, $self->credenciais_pg);
}

# Ponto de execução isolado (os testes substituem).
sub executar ($self, $argv, $env) {
  local @ENV{ keys %$env } = values %$env;
  my $rc = system { $argv->[0] } @$argv;
  die sprintf("%s falhou (rc=%d)\n", $argv->[0], $rc == -1 ? -1 : $rc >> 8) if $rc;
  return 1;
}

# Staging -> clean.malha_setor_censitario, numa transação.
sub _copiar_stage_malha ($self, $dbh) {
  my $stage = STAGE;
  my $siglas = join ', ', map { "('$_', '$SIGLA_UF{$_}')" } sort keys %SIGLA_UF;
  my %r;
  $self->app->schema->storage->txn_do(sub {
    # O GPKG tem um polígono por PARTE: 472.780 feições para 468.099 setores
    # (setores multipartes, ex.: ilhas no AM). Conta-se por setor e as
    # partes são agrupadas num MULTIPOLYGON antes do upsert — senão o
    # ON CONFLICT toca a mesma linha duas vezes e a carga aborta (#238).
    ($r{feicoes}, $r{no_stage}) = $dbh->selectrow_array(
      "SELECT count(*), count(DISTINCT cd_setor) FROM $stage");
    $r{multipartes} = $r{feicoes} - $r{no_stage};
    ($r{reparadas}) = $dbh->selectrow_array("SELECT count(*) FROM $stage WHERE NOT ST_IsValid(geom)");
    my $orfaos = $dbh->selectall_arrayref(qq{
      SELECT s.cd_mun, min(s.nm_mun), count(DISTINCT s.cd_setor)
        FROM $stage s
       WHERE NOT EXISTS (SELECT 1 FROM clean.malha_municipio m WHERE m.codigo_ibge = s.cd_mun)
       GROUP BY s.cd_mun ORDER BY 3 DESC});
    $r{orfaos} = 0;
    $r{orfaos} += $_->[2] for @$orfaos;
    $r{amostra_orfaos} = join ', ', map { "$_->[0] $_->[1]=$_->[2]" } grep { defined $_->[0] } @$orfaos[0 .. ($#$orfaos < 4 ? $#$orfaos : 4)];
    $r{carregados} = 0 + $dbh->do(qq{
      WITH uf(cd, sigla) AS (VALUES $siglas),
      s AS (
        SELECT s.cd_setor, s.cd_mun, s.nm_mun, NULLIF(btrim(s.situacao), '') AS situacao, uf.sigla,
               CASE WHEN ST_IsValid(s.geom) THEN ST_Multi(s.geom)
                    ELSE ST_Multi(ST_CollectionExtract(ST_MakeValid(s.geom), 3)) END AS geom
          FROM $stage s
          LEFT JOIN uf ON uf.cd = s.cd_uf
         WHERE s.cd_setor ~ '^[0-9]{15}\$'
           AND substr(s.cd_setor, 1, 7) = s.cd_mun
           AND EXISTS (SELECT 1 FROM clean.malha_municipio m WHERE m.codigo_ibge = s.cd_mun)
      ),
      partes AS (
        SELECT cd_setor, cd_mun, nm_mun, situacao, sigla, (ST_Dump(geom)).geom AS g
          FROM s
      ),
      agrupado AS (
        SELECT cd_setor, min(cd_mun) AS cd_mun, min(nm_mun) AS nm_mun,
               min(situacao) AS situacao, min(sigla) AS sigla,
               ST_Multi(ST_Collect(g)) AS geom
          FROM partes
         GROUP BY cd_setor
      ),
      final AS (
        -- partes vizinhas que partilham aresta tornam o MULTIPOLYGON
        -- inválido: só então ST_MakeValid (que as funde)
        SELECT cd_setor, cd_mun, nm_mun, situacao, sigla,
               CASE WHEN ST_IsValid(geom) THEN geom
                    ELSE ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3)) END AS geom
          FROM agrupado
      )
      INSERT INTO clean.malha_setor_censitario
        (codigo_setor, codigo_ibge, nome_municipio, sigla_uf, situacao_setor, geometry)
      SELECT cd_setor, cd_mun, nm_mun, sigla, situacao, ST_SetSRID(geom, 4674)
        FROM final
       WHERE NOT ST_IsEmpty(geom) AND ST_IsValid(geom)
      ON CONFLICT (codigo_setor) DO UPDATE SET
        codigo_ibge    = EXCLUDED.codigo_ibge,
        nome_municipio = EXCLUDED.nome_municipio,
        sigla_uf       = EXCLUDED.sigla_uf,
        situacao_setor = EXCLUDED.situacao_setor,
        geometry       = EXCLUDED.geometry});
    $r{descartados} = $r{no_stage} - $r{orfaos} - $r{carregados};
  });
  return %r;
}

# =============================================================================
# 2. Censo 2022 por setor
# =============================================================================
sub carregar_censo ($self, $args, $uf = undef) {
  my %zip = map { $_ => $self->_obter_zip($args, $_) } sort keys %ZIP;
  my $dbh = $self->app->schema->storage->dbh;
  my %r = (carregados => 0, orfaos => 0, suprimidos => 0, atualizados => {});

  $self->app->schema->storage->txn_do(sub {
    # 1ª passada (basico) cria/atualiza a linha do setor e zera as demais
    # colunas: a carga é por inteiro, não um remendo sobre a anterior.
    $self->_ler_csv($zip{basico}, 'basico', $uf, sub ($lote) {
      my ($n, $orf) = $self->_gravar_basico($dbh, $lote);
      $r{carregados} += $n;
      $r{orfaos} += $orf;
    });
    for my $tema (qw(demografia cor_ou_raca)) {
      $self->_ler_csv($zip{$tema}, $tema, $uf, sub ($lote) {
        $r{atualizados}{$tema} += $self->_gravar_tema($dbh, $tema, $lote);
      });
    }
    ($r{suprimidos}) = $dbh->selectrow_array(
      'SELECT count(*) FROM clean.censo2022_setor WHERE supressao_celula_pequena'
      . ($uf ? ' AND sigla_uf = ?' : ''), undef, ($uf ? ($SIGLA_UF{$uf}) : ()));
  });

  $self->log_info(sprintf(
    'Censo 2022 por setor: %d setores (basico); demografia em %d, cor/raça em %d; %d com supressão; %d fora (setor ausente da malha, FK)',
    $r{carregados}, $r{atualizados}{demografia} // 0, $r{atualizados}{cor_ou_raca} // 0,
    $r{suprimidos}, $r{orfaos}));
  die "Censo 2022: nenhum setor carregado (a malha foi carregada antes?)\n" unless $r{carregados};

  $self->upsert_metadata(TAB_CENSO, join(' + ', map { $ZIP{$_} } sort keys %ZIP), URL_CSVS, LICENCA,
    $r{carregados},
    sprintf('Agregados por Setores Censitários do Censo 2022 (#238).%s %d setores (basico); demografia em %d e cor/raça em %d; %d setores com supressao_celula_pequena (célula "X" do IBGE = NULL, não zero); %d setores fora por ausência na malha_setor_censitario (FK). Sem fonte no Censo 2022 por setor, ficam NULL: %s.',
      ($uf ? " Recorte UF=$SIGLA_UF{$uf}." : ''), $r{carregados},
      $r{atualizados}{demografia} // 0, $r{atualizados}{cor_ou_raca} // 0,
      $r{suprimidos}, $r{orfaos}, join(', ', @SEM_FONTE)));
  return $r{carregados};
}

sub _obter_zip ($self, $args, $tema) {
  my $nome = $ZIP{$tema};
  my $url = URL_CSVS . "/$nome";
  my $tab = [TAB_CENSO];
  if (my $dir = $args->{dir_zips}) {
    my $local = path($dir, $nome);
    die "dir_zips: $local não existe\n" unless -f $local;
    $self->preservar_raw("$local", $url, tabelas => $tab);
    return "$local";
  }
  return $self->download_file($url, undef, {}, tabelas => $tab);
}

# Lê o CSV de dentro do ZIP em fluxo (unzip -p), latin1, `;`. Chama $cb
# com lotes de LOTE linhas já convertidas por converter_linha.
sub _ler_csv ($self, $zip, $tema, $uf, $cb) {
  my @membros = grep { /\.csv\z/i } split /\n/, `unzip -Z1 "$zip" 2>/dev/null`;
  die "Nenhum CSV dentro de $zip\n" unless @membros;
  open my $fh, '-|', 'unzip', '-p', $zip, $membros[0] or die "unzip -p $zip: $!\n";
  binmode $fh, ':encoding(latin1)';
  my $n = $self->ler_fluxo($fh, $tema, $uf, $cb);
  close $fh;
  $self->log_info("$tema: $n linhas lidas de $membros[0]");
  return $n;
}

# Separado de _ler_csv para os testes lerem de um handle comum.
sub ler_fluxo ($self, $fh, $tema, $uf, $cb) {
  my $csv = Text::CSV->new({ binary => 1, sep_char => ';', auto_diag => 1 });
  my $header = $csv->getline($fh) or die "$tema: CSV vazio\n";
  $header->[0] =~ s/^\x{FEFF}//;
  my @cab = map { uc } @$header;    # basico usa v0001, demografia CD_setor
  my %idx = map { $cab[$_] => $_ } 0 .. $#cab;
  die "$tema: sem coluna CD_SETOR (recebido: @cab[0..($#cab < 5 ? $#cab : 5)])\n"
    unless defined $idx{CD_SETOR};
  my @falta = grep { !defined $idx{$_} } map { @$_ } values %{ $MAPA{$tema} };
  die "$tema: faltam variáveis: @{[ sort @falta ]}\n" if @falta;

  my (@lote, $n);
  while (my $r = $csv->getline($fh)) {
    my %h = map { $cab[$_] => $r->[$_] } 0 .. $#cab;
    next if $uf && substr($h{CD_SETOR} // '', 0, 2) ne $uf;
    push @lote, $self->converter_linha($tema, \%h);
    $n++;
    if (@lote >= LOTE) { $cb->([@lote]); @lote = () }
  }
  $cb->([@lote]) if @lote;
  return $n // 0;
}

# Uma linha do CSV -> {codigo_setor, <colunas>, suprimido}. "X" = suprimido
# (NULL + flag); "." ou vazio = sem valor (NULL, sem flag).
sub converter_linha ($self, $tema, $h) {
  my %row = (codigo_setor => $h->{CD_SETOR}, suprimido => 0);
  my $mapa = $MAPA{$tema};
  for my $col (sort keys %$mapa) {
    my ($soma, $nulo) = (0, 0);
    for my $var (@{ $mapa->{$col} }) {
      my $v = $h->{$var} // '';
      $v =~ s/^\s+|\s+$//g;
      if ($v eq 'X') { $row{suprimido} = 1; $nulo = 1; next }
      if ($v eq '' || $v eq '.') { $nulo = 1; next }
      $v =~ s/\.//g; $v =~ s/,/./;
      die "$tema: valor não numérico em $var ($h->{CD_SETOR}): '$v'\n"
        unless $v =~ /^-?\d+(?:\.\d+)?$/;
      $soma += $v;
    }
    $row{$col} = $nulo ? undef : $soma;
  }
  if ($tema eq 'basico') {
    $row{codigo_ibge}    = $h->{CD_MUN};
    $row{nome_municipio} = $h->{NM_MUN};
    $row{sigla_uf}       = $SIGLA_UF{ $h->{CD_UF} // '' };
    # 1.103 setores com SITUACAO vazia no arquivo de 20260520: NULL, não ''.
    $row{situacao_setor} = (defined $h->{SITUACAO} && $h->{SITUACAO} =~ /\S/) ? $h->{SITUACAO} : undef;
  }
  return \%row;
}

# INSERT da passada basico; só setores presentes na malha (FK). Devolve
# (gravados, fora).
sub _gravar_basico ($self, $dbh, $lote) {
  my @validos = grep { ($_->{codigo_setor} // '') =~ /^\d{15}$/ } @$lote;
  my $invalidos = @$lote - @validos;
  return (0, $invalidos) unless @validos;
  my @cols = (qw(codigo_setor codigo_ibge nome_municipio sigla_uf situacao_setor),
              sort keys %{ $MAPA{basico} });
  my $tipos = { map { $_ => 'integer' } keys %{ $MAPA{basico} } };
  my $sql = _sql_valores(\@cols, $tipos, scalar @validos);
  my $zera = join ",\n        ", map { "$_ = NULL" } (
    (map { keys %{ $MAPA{$_} } } qw(demografia cor_ou_raca)), @SEM_FONTE);
  my $n = $dbh->do(qq{
    INSERT INTO clean.censo2022_setor (@{[ join ', ', @cols ]}, supressao_celula_pequena, data_acessada)
    SELECT @{[ join ', ', map { "v.$_" } @cols ]}, v.sup, NOW() FROM (
      SELECT @{[ join ', ', map { "x.$_" } @cols ]}, x.sup::boolean AS sup FROM ($sql) x
    ) v
    WHERE EXISTS (SELECT 1 FROM clean.malha_setor_censitario m WHERE m.codigo_setor = v.codigo_setor)
    ON CONFLICT (codigo_setor) DO UPDATE SET
      @{[ join ",\n      ", map { "$_ = EXCLUDED.$_" } grep { $_ ne 'codigo_setor' } @cols ]},
      supressao_celula_pequena = EXCLUDED.supressao_celula_pequena,
      data_acessada = NOW(),
      $zera},
    undef, map { my $r = $_; ((map { $r->{$_} } @cols), $r->{suprimido} ? 1 : 0) } @validos);
  $n = 0 + ($n // 0);
  return ($n, @$lote - $n);
}

# UPDATE das passadas demografia / cor_ou_raca (só setores já gravados).
sub _gravar_tema ($self, $dbh, $tema, $lote) {
  my @validos = grep { ($_->{codigo_setor} // '') =~ /^\d{15}$/ } @$lote;
  return 0 unless @validos;
  my @vars = sort keys %{ $MAPA{$tema} };
  my @cols = ('codigo_setor', @vars);
  my $tipos = { map { $_ => 'integer' } @vars };
  my $sql = _sql_valores(\@cols, $tipos, scalar @validos);
  my $n = $dbh->do(qq{
    UPDATE clean.censo2022_setor t SET
      @{[ join ",\n      ", map { "$_ = x.$_" } @vars ]},
      supressao_celula_pequena = t.supressao_celula_pequena OR x.sup::boolean
    FROM ($sql) x
    WHERE t.codigo_setor = x.codigo_setor},
    undef, map { my $r = $_; ((map { $r->{$_} } @cols), $r->{suprimido} ? 1 : 0) } @validos);
  return 0 + ($n // 0);
}

# SELECT … FROM (VALUES (?::tipo, …), …) AS x(cols…, sup) com $n linhas.
# Os tipos vão em cada placeholder: o Pg não infere tipo em VALUES solto.
sub _sql_valores ($cols, $tipos, $n) {
  my $linha = '(' . join(', ', (map { '?::' . ($tipos->{$_} // 'text') } @$cols), '?::integer') . ')';
  return 'SELECT * FROM (VALUES ' . join(', ', ($linha) x $n) . ') AS x('
    . join(', ', @$cols, 'sup') . ')';
}

1;
