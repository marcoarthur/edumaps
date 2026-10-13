package EduMaps::Ingestion::Job::IBGE;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(decode_json);
use POSIX qw(strftime);
use Text::CSV;
use Time::HiRes qw(sleep);
use utf8;

has job_name => 'IBGE';
has description => 'Ingestão IBGE/SIDRA (PIB municipal - tabela 5938) via API pública';
has schedule => 'monthly';

# SIDRA API pública
has sidra_base => 'https://apisidra.ibge.gov.br/values/t';

# Tabela 5938: Produto Interno Bruto dos Municípios
has tabela_pib => '5938';

# Variáveis para dados_ibge (formato largo)
# 37: PIB total
# 513: VAB agropecuária
# 517: VAB indústria
# 525: VAB administração/defesa/saúde pública e seguridade social (governo)
# 6575: VAB serviços (exclusive administração/defesa/educação/saúde públicas e seguridade social)
# Percentuais (quando disponíveis): 516 agro%, 520 indústria%, 528 governo%, 6574 serviços%
has vars_dados_ibge => '37,513,517,525,6575,516,520,528,6574';

# ibge_agregados.classificacao de um agregado sem quebra (ver
# processar_ibge_agregados)
use constant SEM_CLASSIFICACAO => 'Total';

# Throttle leve (API pública, sem limite declarado)
has throttle => 0.2;    # 0.2s entre chamadas


sub tabelas ($self, $args = {}) { return ('clean.dados_ibge', 'clean.ibge_agregados') }

sub run ($self, $args = {}) {
  $self->log_info('Iniciando ingestão IBGE/SIDRA (tabela 5938 - PIB municipal)');

  # ---------------------------------------------------------------------------
  # --dry-run honesto (#231)
  # ---------------------------------------------------------------------------
  # A semântica de 2026-10-06 (abaixo) fazia o dry-run correr a EXTRAÇÃO
  # inteira: ~11 mil GETs ao SIDRA para depois não gravar nada. Isso não é
  # um ensaio, é a carga sem o último passo. Agora o dry-run lê a lista de
  # municípios (só leitura), faz UMA requisição de sanidade (o primeiro
  # município, validada no allowlist) e relata o plano. Nada é escrito.
  return $self->_dry_run_sanidade($args) if $self->dry_run;

  # ---------------------------------------------------------------------------
  # Semântica de --dry-run (corrigido 2026-10-06; SUBSTITUÍDA pela #231,
  # ver acima — o texto fica como histórico da decisão anterior)
  # ---------------------------------------------------------------------------
  # `--dry-run` significa **não escrever na base de dados** — não "não fazer
  # nada". Os guards estavam nas etapas de leitura (`exportar_municipios`,
  # `extrair_dados_ibge`, `extrair_ibge_agregados`), que assim nem sequer
  # escreviam os CSVs intermédios, e `processar_dados_ibge` morria com
  # "Não leu data/ingestao/dados_ibge.csv: No such file or directory".
  #
  # Resultado: o dry-run falhava E, quando não falhava, não reportava contagem
  # nenhuma — ver a #156, "os jobs foram verificados apenas em --dry-run".
  #
  # Agora a corrente corre toda (BD, rede, CSVs locais) e só pára antes de
  # persistir: `carregar_*` e `upsert_metadata` têm guard de dry-run e devolvem
  # a contagem que seria gravada sem gravar nada.
  # ---------------------------------------------------------------------------
  my $dir = $self->dir_trabalho;
  my $mun_csv = "$dir/municipios.csv";
  my $dados_csv = "$dir/dados_ibge.csv";
  my $agregados_csv = "$dir/ibge_agregados.csv";

  # 1. Exportar municípios de referência
  my $n_mun = $self->exportar_municipios($mun_csv);

  # 2. Extrair dados para dados_ibge (formato largo)
  $self->log_info('Extraindo dados IBGE/SIDRA 5938 para clean.dados_ibge');
  # Brutos (#234): os CSVs intermédios são o resultado de ~5,5 mil GETs ao
  # SIDRA; preservados, uma recarga não repete horas de API. Com
  # `--arg dados_csv=<bruto>` a carga relê esse CSV em vez de extrair.
  my $url_sidra = $self->sidra_base . '/' . $self->tabela_pib;
  if (my $bruto = $args->{dados_csv}) {
    die "dados_csv não existe: $bruto\n" unless -f $bruto;
    $self->log_info("Relendo o bruto $bruto (sem extração)");
    $dados_csv = $bruto;
  }
  else {
    $self->extrair_dados_ibge($mun_csv, $dados_csv, $args);
  }
  $self->preservar_raw($dados_csv, $url_sidra, tabelas => ['clean.dados_ibge'])
    unless $self->dry_run;

  # 3. Carregar dados_ibge
  my $rows_dados = $self->processar_dados_ibge($dados_csv);
  die "Nenhuma linha extraída para dados_ibge\n" unless @$rows_dados;
  my $loaded_dados = $self->carregar_dados_ibge($rows_dados);

  # 4. Extrair e carregar ibge_agregados (formato longo)
  $self->log_info('Extraindo dados IBGE/SIDRA 5938 para clean.ibge_agregados');
  if (my $bruto = $args->{agregados_csv}) {
    die "agregados_csv não existe: $bruto\n" unless -f $bruto;
    $self->log_info("Relendo o bruto $bruto (sem extração)");
    $agregados_csv = $bruto;
  }
  elsif ($args->{dados_csv}) {
    # recarga só do dados_ibge a partir do bruto: não refaz os ~5,5 mil GETs
    # do formato longo
    $agregados_csv = undef;
  }
  else {
    $self->extrair_ibge_agregados($mun_csv, $agregados_csv, $args);
  }
  $self->preservar_raw($agregados_csv, $url_sidra, tabelas => ['clean.ibge_agregados'])
    unless $self->dry_run || !$agregados_csv || !-f $agregados_csv;
  my $rows_ag = $agregados_csv ? $self->processar_ibge_agregados($agregados_csv) : [];
  my $loaded_ag = 0;
  if (@$rows_ag) {
    $loaded_ag = $self->carregar_ibge_agregados($rows_ag);
  }

  # 5. Metadados
  $self->upsert_metadata(
    'clean.dados_ibge',
    'SIDRA tabela 5938 (PIB municipal)',
    $self->sidra_base . '/' . $self->tabela_pib,
    'Domínio público (IBGE)',
    $loaded_dados,
    sprintf('Extração SIDRA 5938 (PIB municipal), %d municípios de referência. Período conforme parâmetros; percentuais podem ser NULL quando não divulgados.', $n_mun)
  );

  if ($loaded_ag > 0) {
    $self->upsert_metadata(
      'clean.ibge_agregados',
      'SIDRA tabela 5938 (PIB municipal) - formato longo',
      $self->sidra_base . '/' . $self->tabela_pib,
      'Domínio público (IBGE)',
      $loaded_ag,
      sprintf('Extração SIDRA 5938 em formato longo, %d municípios de referência.', $n_mun)
    );
  }

  $self->log_info(sprintf('IBGE/SIDRA: %d (dados_ibge) + %d (ibge_agregados) registros carregados', $loaded_dados, $loaded_ag));
  return $loaded_dados + $loaded_ag;
};


sub _dry_run_sanidade ($self, $args) {
  my $anos = $args->{anos} // 'last 10';
  my $db = $self->app->schema->storage->dbh;
  my $rows = $db->selectall_arrayref(
    'SELECT codigo_ibge FROM clean.malha_municipio
      WHERE codigo_ibge IS NOT NULL ORDER BY codigo_ibge', { Slice => {} });
  my @cod = grep { defined && /^\d{7}$/ } map { $_->{codigo_ibge} } @$rows;
  die "IBGE: clean.malha_municipio vazia — nada a extrair\n" unless @cod;

  my $url = sprintf('%s/%s/n6/%s/v/%s/p/%s?formato=json',
    $self->sidra_base, $self->tabela_pib, $cod[0], $self->vars_dados_ibge, $anos);
  $self->exigir_allowlist($url);
  my $tx = $self->ua->get($url);
  my $code = $tx->res->code // 0;
  die "IBGE [DRY-RUN] sanidade: HTTP $code em $url\n" unless $code == 200;
  my $json = $tx->res->json;
  my $n = ref $json eq 'ARRAY' ? scalar(@$json) - 1 : 0;
  $self->log_info(sprintf(
    '[DRY-RUN] IBGE: %d municípios planejados x 2 extrações (~%d GETs), anos=%s; sanidade %s -> HTTP 200, %d valores. Nada extraído nem gravado.',
    scalar @cod, 2 * @cod, $anos, $cod[0], $n));
  return $n;
}

sub dir_trabalho ($self) {
  my $dir = $self->config->{dir_trabalho} // 'data/ingestao';
  $self->_garantir_dir("$dir/dummy");
  return $dir;
}

sub _garantir_dir ($self, $file) {
  my ($dir) = $file =~ m{^(.*)/[^/]+$};
  return unless $dir && !-d $dir;
  require File::Path;
  File::Path::make_path($dir);
}

# Sem guard de dry-run, de propósito: ver `run` para a semântica de --dry-run.
sub exportar_municipios ($self, $destino) {
  my $db = $self->app->schema->storage->dbh;
  my $rows = $db->selectall_arrayref(
    'SELECT codigo_ibge, sigla_uf, nome_municipio
       FROM clean.malha_municipio
      WHERE codigo_ibge IS NOT NULL
      ORDER BY codigo_ibge',
    { Slice => {} }
  );
  $self->_garantir_dir($destino);
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '>:encoding(utf8)', $destino or die "Não abriu $destino: $!";
  $csv->print($fh, [qw(codigo_ibge sigla_uf nome_municipio)]);
  $csv->print($fh, [@{$_}{qw(codigo_ibge sigla_uf nome_municipio)}]) for @$rows;
  close $fh;
  return scalar @$rows;
}

sub extrair_dados_ibge ($self, $mun_csv, $out_csv, $args = {}) {
  # Sem guard de dry-run, de propósito: ver `run` para a semântica de --dry-run.
  # Período: últimos anos (padrão 10 anos)
  my $anos = $args->{anos} // 'last 10';

  my $csv_mun = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh_m, '<:encoding(utf8)', $mun_csv or die "Não leu $mun_csv: $!";
  my $header_m = $csv_mun->getline($fh_m);
  $csv_mun->column_names(@$header_m);

  # Preparar CSV de saída
  my $csv_out = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  $self->_garantir_dir($out_csv);
  open my $fh_o, '>:encoding(utf8)', $out_csv or die "Não abriu $out_csv: $!";
  $csv_out->print($fh_o, [qw(codigo_ibge ano pib_total governo industria agro industria_percent agro_percent governo_percent servicos_percent)]);

  my $cont = 0;
  while (my $r = $csv_mun->getline_hr($fh_m)) {
    my $cod = $r->{codigo_ibge} or next;
    next unless $cod =~ /^\d{7}$/;

    # Buscar dados para este município: vars_dados_ibge, n6, período
    my $url = sprintf('%s/%s/n6/%s/v/%s/p/%s?formato=json',
      $self->sidra_base, $self->tabela_pib, $cod, $self->vars_dados_ibge, $anos);
    $self->exigir_allowlist($url);

    my $res;
    eval {
      my $tx = $self->ua->get($url);
      if ($tx->res->code != 200) {
        die sprintf('HTTP %d', $tx->res->code);
      }
      $res = $tx->res->json;
      1;
    } or do {
      my $err = $@ // 'erro desconhecido';
      chomp $err;
      $self->log->warn(sprintf('Falha ao buscar %s: %s - pulando município', $cod, $err));
      sleep($self->throttle);
      next;
    };

    next unless ref($res) eq 'ARRAY' && @$res > 1;

    # Agrupar por ano
    my %por_ano;
    # header em $res->[0], dados a partir de 1
    for (my $i = 1; $i < @$res; $i++) {
      my $row = $res->[$i];
      my $ano = $row->{D3C} // $row->{D3N};
      my $vcode = $row->{D2C};
      my $v = $row->{V};
      next unless defined $ano && defined $vcode && defined $v;
      $ano += 0;
      # Normalizar valor: ... ou - indica não divulgado -> undef
      if ($v eq '...' || $v eq '-' || $v eq '') {
        $por_ano{$ano}{$vcode} = undef;
      } else {
        # remover separadores se necessário (SIDRA csv/json pode vir sem milhar, decimal ponto)
        $v =~ s/\s+//g;
        $por_ano{$ano}{$vcode} = 0 + $v;
      }
    }

    # Escrever linhas por ano para este município
    for my $ano (sort keys %por_ano) {
      my $h = $por_ano{$ano};
      my @campos = (
        $cod,
        $ano,
        $h->{37},              # pib_total
        $h->{525},             # governo
        $h->{517},             # industria
        $h->{513},             # agro
        $h->{520},             # industria_percent
        $h->{516},             # agro_percent
        $h->{528},             # governo_percent
        $h->{6574},            # servicos_percent
      );
      $csv_out->print($fh_o, \@campos);
      $cont++;
    }

    sleep($self->throttle) if $self->throttle > 0;
  }

  close $fh_m;
  close $fh_o;
  $self->log_info(sprintf('Extraídos %d registros (município-ano) para %s', $cont, $out_csv));
}

sub processar_dados_ibge ($self, $csv_path) {
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não leu $csv_path: $!";
  my $header = $csv->getline($fh);
  $csv->column_names(@$header);

  my @rows;
  my $linha = 1;
  while (my $r = $csv->getline_hr($fh)) {
    $linha++;
    my %row;

    # Campos obrigatórios
    $row{codigo_ibge} = $r->{codigo_ibge};
    $row{ano} = defined $r->{ano} ? 0 + $r->{ano} : undef;

    die sprintf("Linha %d: codigo_ibge inválido\n", $linha)
      unless defined $row{codigo_ibge} && $row{codigo_ibge} =~ /^\d{7}$/;
    die sprintf("Linha %d: ano inválido\n", $linha)
      unless defined $row{ano} && $row{ano} >= 1900 && $row{ano} <= 2100;

    # Numéricos (podem ser undef)
    for my $k (qw(pib_total governo industria agro industria_percent agro_percent governo_percent servicos_percent)) {
      my $v = $r->{$k};
      if (defined $v && $v ne '') {
        $row{$k} = 0 + $v;
      } else {
        $row{$k} = undef;
      }
    }

    _percentuais_do_contrato(\%row);
    push @rows, \%row;
  }
  close $fh;
  return \@rows;
}

# Contrato de clean.dados_ibge (COMMENT da change dados_ibge e consumidores:
# City, analytics.municipios_consolidado): os *_percent são FRAÇÃO DO PIB
# (industria / pib_total, ...) e serviços é o complemento (1 - soma dos
# demais). O SIDRA publica outra grandeza nas variáveis 516/520/528/6574
# (% do valor adicionado, 0-100); carregá-las mudava a escala ×100 e o
# denominador sem aviso (medido na P1, #234). O CSV bruto guarda o valor
# oficial; a carga aplica o contrato a partir dos absolutos.
sub _percentuais_do_contrato ($row) {
  my $pib = $row->{pib_total};
  my %fracao;
  for my $setor (qw(industria agro governo)) {
    $fracao{$setor} = (defined $pib && $pib != 0 && defined $row->{$setor})
      ? $row->{$setor} / $pib : undef;
    $row->{"${setor}_percent"} = $fracao{$setor};
  }
  $row->{servicos_percent} = (grep { !defined } values %fracao)
    ? undef
    : 1 - $fracao{industria} - $fracao{agro} - $fracao{governo};
  return $row;
}

sub carregar_dados_ibge ($self, $rows) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Carregaria " . scalar(@$rows) . " linhas em clean.dados_ibge");
    return scalar @$rows;
  }

  my $dbh = $self->app->schema->storage->dbh;
  my $storage = $self->app->schema->storage;

  my @cols = qw(codigo_ibge ano pib_total governo industria agro industria_percent agro_percent governo_percent servicos_percent);
  my $cols_str = join(', ', @cols);
  my $vals_str = join(', ', map { '?' } @cols);
  my $updates = join(', ', map { "$_ = EXCLUDED.$_" } qw(pib_total governo industria agro industria_percent agro_percent governo_percent servicos_percent));

  my $sql = sprintf(<<'SQL', $cols_str, $vals_str, $updates);
    INSERT INTO clean.dados_ibge (%s)
    VALUES (%s)
    ON CONFLICT (ano, codigo_ibge) DO UPDATE SET
      %s,
      data_acessada = NOW()
SQL

  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare($sql);
      for my $r (@$rows) {
        $sth->execute(map { $r->{$_} } @cols);
      }
      $count = scalar @$rows;
    });
    1;
  } or die "Carga falhou, nada foi gravado: $@\n";

  return $count;
}

1;

sub extrair_ibge_agregados ($self, $mun_csv, $out_csv, $args = {}) {
  # Sem guard de dry-run, de propósito: ver `run` para a semântica de --dry-run.
  my $anos = $args->{anos} // 'last 10';

  my $csv_mun = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh_m, '<:encoding(utf8)', $mun_csv or die "Não leu $mun_csv: $!";
  my $header_m = $csv_mun->getline($fh_m);
  $csv_mun->column_names(@$header_m);

  my $csv_out = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  $self->_garantir_dir($out_csv);
  open my $fh_o, '>:encoding(utf8)', $out_csv or die "Não abriu $out_csv: $!";
  $csv_out->print($fh_o, [qw(codigo_ibge ano tabela_id variavel classificacao valor unidade)]);

  my $cont = 0;
  while (my $r = $csv_mun->getline_hr($fh_m)) {
    my $cod = $r->{codigo_ibge} or next;
    next unless $cod =~ /^\d{7}$/;

    my $url = sprintf('%s/%s/n6/%s/v/all/p/%s?formato=json',
      $self->sidra_base, $self->tabela_pib, $cod, $anos);
    $self->exigir_allowlist($url);

    my $res;
    eval {
      my $tx = $self->ua->get($url);
      if ($tx->res->code != 200) {
        die sprintf('HTTP %d', $tx->res->code);
      }
      $res = $tx->res->json;
      1;
    } or do {
      my $err = $@ // 'erro desconhecido';
      chomp $err;
      $self->log->warn(sprintf('Falha ao buscar agregados %s: %s - pulando município', $cod, $err));
      sleep($self->throttle);
      next;
    };

    next unless ref($res) eq 'ARRAY' && @$res > 1;

    for (my $i = 1; $i < @$res; $i++) {
      my $row = $res->[$i];
      my $ano = $row->{D3C} // $row->{D3N};
      my $vcode = $row->{D2C};
      my $v = $row->{V};
      my $unid = $row->{MN} // $row->{MC} // undef;
      next unless defined $ano && defined $vcode && defined $v;
      $ano += 0;

      my $valor;
      if ($v eq '...' || $v eq '-' || $v eq '') {
        $valor = undef;
      } else {
        $v =~ s/\s+//g;
        $valor = 0 + $v;
      }

      $csv_out->print($fh_o, [$cod, $ano, $self->tabela_pib, $vcode, undef, $valor, $unid]);
      $cont++;
    }
    sleep($self->throttle) if $self->throttle > 0;
  }

  close $fh_m;
  close $fh_o;
  $self->log_info(sprintf('Extraídos %d registros (agregados) para %s', $cont, $out_csv));
}

sub processar_ibge_agregados ($self, $csv_path) {
  my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, eol => "\n" });
  open my $fh, '<:encoding(utf8)', $csv_path or die "Não leu $csv_path: $!";
  my $header = $csv->getline($fh);
  $csv->column_names(@$header);

  my @rows;
  my $linha = 1;
  while (my $r = $csv->getline_hr($fh)) {
    $linha++;
    my %row;
    $row{codigo_ibge} = $r->{codigo_ibge};
    $row{ano} = defined $r->{ano} ? 0 + $r->{ano} : undef;
    $row{tabela_id} = $r->{tabela_id} // '';
    $row{variavel} = $r->{variavel} // '';
    # classificacao faz parte da PK (NOT NULL). Agregado sem quebra (a
    # tabela 5938 não tem classificação) é 'Total', a convenção do próprio
    # SIDRA; undef violava a PK e a carga inteira abortava (P1, #234).
    $row{classificacao} = $r->{classificacao};
    $row{classificacao} = SEM_CLASSIFICACAO
      unless defined $row{classificacao} && $row{classificacao} ne '';

    die sprintf("Linha %d: dados obrigatórios inválidos\n", $linha)
      unless defined $row{codigo_ibge} && $row{codigo_ibge} =~ /^\d{7}$/
             && defined $row{ano} && $row{ano} >= 1900 && $row{ano} <= 2100
             && $row{tabela_id} ne '' && $row{variavel} ne '';

    my $v = $r->{valor};
    if (defined $v && $v ne '') {
      $row{valor} = 0 + $v;
    } else {
      $row{valor} = undef;
    }
    $row{unidade} = $r->{unidade};
    $row{unidade} = undef if defined $row{unidade} && $row{unidade} eq '';

    push @rows, \%row;
  }
  close $fh;
  return \@rows;
}

sub carregar_ibge_agregados ($self, $rows) {
  if ($self->dry_run) {
    $self->log_info("[DRY-RUN] Carregaria " . scalar(@$rows) . " linhas em clean.ibge_agregados");
    return scalar @$rows;
  }

  my $dbh = $self->app->schema->storage->dbh;
  my $storage = $self->app->schema->storage;

  my @cols = qw(codigo_ibge ano tabela_id variavel classificacao valor unidade);
  my $cols_str = join(', ', @cols);
  my $vals_str = join(', ', map { '?' } @cols);
  my $updates = join(', ', map { "$_ = EXCLUDED.$_" } qw(valor unidade));

  my $sql = sprintf(<<'SQL', $cols_str, $vals_str, $updates);
    INSERT INTO clean.ibge_agregados (%s)
    VALUES (%s)
    ON CONFLICT (codigo_ibge, ano, tabela_id, variavel, classificacao) DO UPDATE SET
      %s,
      data_acessada = NOW()
SQL

  my $count = 0;
  eval {
    $storage->txn_do(sub {
      my $sth = $dbh->prepare($sql);
      for my $r (@$rows) {
        $sth->execute(map { $r->{$_} } @cols);
      }
      $count = scalar @$rows;
    });
    1;
  } or die "Carga falhou, nada foi gravado: $@\n";

  return $count;
}
