package EduMaps::Ingestion::Job::SICONFI;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use File::Path qw(make_path);
use POSIX qw(strftime);

use utf8;

has job_name => 'SICONFI';
has description => 'Ingestão SICONFI (receitas, RREO) via API DataLake do Tesouro';
has schedule => 'monthly';

# API DataLake do Tesouro (verificada na #165). O host real está dentro do
# spec — sem o prefixo ords/cdwhprd/siconfi/tt/ tudo devolve 404 de Azure
# Static Web Apps. Parâmetro do exercício é `an_exercicio` (não
# `exercicio`) — o esqueleto original usava o nome errado e a API
# respondia "sucesso" com count=0.
has base_url => 'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt';
has ua       => sub { Mojo::UserAgent->new(max_redirects => 5) };

# 1 requisição por segundo (limite declarado no spec; testes passam 0)
has throttle => 1.0;
# Base parte de 3; manter leve: uma página que falha não deve abortar a
# carga inteira de um município por um 429/5xx pontual.
has max_retries => 2;

# Cache local de /entes (chave de tudo: é o cod_ibge que casa com a malha)
has entes_cache_file =>
  sub { path($ENV{TMPDIR} // '/tmp')->child('siconfi_entes.json') };

# ---------------------------------------------------------------------
# Receita do RREO — fonte: RREO-Anexo 01 (Balanço Orçamentário)
#
# O endpoint devolve TODOS os anexos do RREO de uma vez. Vários anexos
# temáticos (03, 06, 14, ...) também trazem linhas de receita, mas com
# rótulos de coluna PRÓPRIOS ('RECEITAS REALIZADAS (a)', 'PREVISÃO
# ATUALIZADA' sem o "(a)", 'PREVISÃO ATUALIZADA 2025', ...) que colidiriam
# na PK com as do Anexo 01 — e o Anexo 06/14 expõe o detalhamento RPPS
# (ReceitaDeContribuicoesDosSegurados*, ReceitaPatrimonialRPPSBruta*, ...)
# que não é a classificação econômica de receita. A fonte autoritativa é o
# Anexo 01; por isso filtra-se por `anexo` e, dentro dele, por coluna.
#
# O mesmo Anexo 01 traz as linhas de DESPESA (DOTAÇÃO*, DESPESAS*) — saem
# pela allowlist de coluna. De cada par orçamento/execução entra UMA coluna
# por classificação:
#
#   'estimativa' <- 'PREVISÃO ATUALIZADA (a)'  (a previsão corrente)
#   'realizada'  <- 'Até o Bimestre (c)'       (a execução acumulada)
#
# 'PREVISÃO INICIAL' e 'No Bimestre (b)' ficam de fora DELIBERADAMENTE:
# caem na mesma PK (codigo_ibge + exercicio + tipo_receita + coluna_receita
# + classificacao + dt_snapshot) que a atualizada/até-o-bimestre, e o
# ON CONFLICT ficaria à mercê da ordem dos itens da API. Percentuais
# ('% (b/a)', '% (c/a)') e 'SALDO (a-c)' não são valor monetário de linha.
my %COLUNA_CLASSIFICACAO = (
  'PREVISÃO ATUALIZADA (a)' => 'estimativa',
  'Até o Bimestre (c)'      => 'realizada',
);

# ---------------------------------------------------------------------
# tipo_receita por cod_conta — SÓ as folhas do RREO-Anexo 01
#
# Linhas de total/subtotal (ReceitasExcetoIntraOrcamentarias,
# ReceitaTributaria, ReceitasCorrentes, TransferenciasCorrentes,
# OutrasReceitasCorrentes, ReceitasDeOperacoesDeCredito, AlienacaoDeBens,
# ReceitaPatrimonial, ReceitaDeServicos, ...) ficam de fora: guardar o
# agregado E os filhos duplica qualquer soma posterior.
#
# 'fundeb' fica reservado no schema mas não é preenchido aqui: o endpoint
# RREO não expõe a linha detalhada 1.7.5.x (transferências do FUNDEB vêm
# agregadas dentro de TransferenciasCorrentes*) — nunca adivinhar pelo
# nome da conta. Quando o esforço fiscal precisar, usar outro endpoint
# ou aceitar a agregação.
#
# Chave não mapeada => warning no log e linha ignorada (o loader não
# inventa classificação) — por isso o mapeamento é uma allowlist explícita.
# Totais/subtotais reconhecidos (%AGREGADO) saem em silêncio; só o que não
# é folha nem agregado conhecido vira warning.
my %TIPO_POR_CONTA = (
  # --- própria: tributos, contribuições, patrimônio, serviços, multas ---
  Impostos                                    => 'propria',
  ImpostosIntra                               => 'propria',
  Taxas                                       => 'propria',
  TaxasIntra                                  => 'propria',
  ContribuicaoDeMelhoria                       => 'propria',
  ContribuicoesSociais                         => 'propria',
  ContribuicoesSociaisIntra                    => 'propria',
  ContribuicaoDeIluminacaoPublica              => 'propria',
  ReceitasImobiliarias                         => 'propria',
  ReceitasImobiliariasIntra                    => 'propria',
  ExploracaoDeRecursosNaturais                 => 'propria',
  ExploracaoDoPatrimonioIntangivel             => 'propria',
  ReceitasDeValoresMobiliarios                 => 'propria',
  ReceitasDeValoresMobiliariosIntra            => 'propria',
  OutrasReceitasPatrimoniais                   => 'propria',
  BensDireitosEValoresIncorporadosAoPatrimonioPublico => 'propria',
  ServicosAdministrativosEComerciaisGerais     => 'propria',
  ServicosAdministrativosEComerciaisGeraisIntra => 'propria',
  ServicosEAtividadesFinanceiras               => 'propria',
  OutrosServicos                               => 'propria',
  OutrosServicosIntra                          => 'propria',
  MultasEJurosDeMora                           => 'propria',
  MultasEJurosDeMoraIntra                      => 'propria',
  IndenizacoesERestituicoes                    => 'propria',
  IndenizacoesERestituicoesIntra               => 'propria',
  ReceitaDaCessaoDeDireitos                    => 'propria',
  ReceitaDeConcessoesEPermissoes               => 'propria',
  ReceitasCorrentesDiversas                    => 'propria',
  ReceitasCorrentesDiversasIntra               => 'propria',
  # --- transferência: intergovernamentais correntes e de capital ---
  TransferenciasCorrentesDaUniaoEDeSuasEntidades => 'transferencia',
  TransferenciasCorrentesDosEstadosEDoDistritoFederalEDeSuasEntidades => 'transferencia',
  TransferenciasCorrentesDeInstituicoesPrivadas => 'transferencia',
  TransferenciasCorrentesDeOutrasInstituicoesPublicas => 'transferencia',
  TransferenciasCorrentesDosMunicipiosEDeSuasEntidadesIntra => 'transferencia',
  OutrasTransferenciasCorrentes                => 'transferencia',
  # 1.7.5 — filha de TransferenciasCorrentes (não é agregada)
  TransferenciasCorrentesDoExterior            => 'transferencia',
  TransferenciasDeCapitalDaUniaoEDeSuasEntidades => 'transferencia',
  TransferenciasDeCapitalDosEstadosEDoDistritoFederalEDeSuasEntidades => 'transferencia',
  TransferenciasDeCapitalDeInstituicoesPrivadas => 'transferencia',
  TransferenciasdeCapitalDosMunicipiosEDeSuasEntidadesIntra => 'transferencia',
  # --- outros: capital próprio (crédito, alienação, amortização, ...) ---
  OperacoesDeCreditoInternas                   => 'outros',
  OperacoesDeCreditoExternas                   => 'outros',
  AlienacaoDeBensImoveis                       => 'outros',
  AlienacaoDeBensImoveisIntra                  => 'outros',
  AlienacaoDeBensMoveis                        => 'outros',
  AlienacaoDeBensMoveisIntra                   => 'outros',
  AmortizacoesDeEmprestimos                    => 'outros',
  MultasEJurosDeMoraDasReceitasDeCapital       => 'outros',
  SaldoDeExerciciosAnterioresUtilizadosParaCreditosAdicionais => 'outros',
  SuperavitFinanceiro                          => 'outros',
);

# Totais/subtotais do Anexo 01 reconhecidos e descartados de propósito
# (guardar o agregado E os filhos duplica qualquer soma). Não geram
# warning — o warning fica reservado para chave realmente desconhecida.
my %AGREGADO = map { $_ => 1 } qw(
  ReceitasExcetoIntraOrcamentarias ReceitasIntraOrcamentarias
  ReceitasIntraOrcamentariasTotal SubtotalDasReceitas TotalReceitas
  TotalReceitasComDeficit ReceitasCorrentes ReceitasCorrentesIntra
  ReceitasDeCapital ReceitasDeCapitalIntra ReceitaTributaria
  ReceitaTributariaIntra ReceitaDeContribuicoes ReceitaDeContribuicoesIntra
  ReceitaPatrimonial ReceitaPatrimonialIntra ReceitaDeServicos
  ReceitaDeServicosIntra TransferenciasCorrentes TransferenciasCorrentesIntra
  TransferenciasDeCapital TransferenciasDeCapitalIntra OutrasReceitasCorrentes
  OutrasReceitasCorrentesIntra OutrasReceitasDeCapital
  OutrasReceitasDeCapitalIntra RREO1OutrasReceitasDeCapital
  RREO1OutrasReceitasDeCapitalIntra AlienacaoDeBens AlienacaoDeBensIntra
  ReceitasDeOperacoesDeCredito
);

# Só o RREO-Anexo 01 (Balanço Orçamentário) tem a classificação econômica
# de receita que interessa. Tolerante à variante sem zero (Anexo 1).
sub _anexo_receita ($anexo) {
  return defined $anexo && $anexo =~ /\bAnexo 0?1$/ ? 1 : 0;
}

# ---------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------
sub run ($self, $args = {}) {
  my $cod_ibge = $args->{cod_ibge};

  if ($cod_ibge) {
    return $self->ingest_municipio_receita(%$args);
  }

  # Iteração sobre a malha via /entes (cache local): por UF ou todos.
  if ($args->{uf} || $args->{todos}) {
    my $entes = $self->_fetch_entes;
    my @cod = map { sprintf('%07d', $_->{cod_ibge}) }
      grep { !$args->{uf} || ($_->{uf} // '') eq $args->{uf} } @$entes;
    my $max = $args->{max_municipios} // scalar @cod;
    @cod = @cod[0 .. $max - 1] if $max < @cod;
    $self->log_info('SICONFI: ' . scalar(@cod) . " municípios a carregar (uf=" . ($args->{uf} // '*') . ')');

    my $total = 0;
    for my $i (0 .. $#cod) {
      $self->_throttle if $i > 0;
      $total += $self->ingest_municipio_receita(cod_ibge => $cod[$i], %$args);
    }
    return $total;
  }

  # Fase 1 (escopo mínimo da #165): São Paulo quando nada é pedido
  return $self->ingest_municipio_receita(cod_ibge => '3550308', %$args);
}

# ---------------------------------------------------------------------
# Receita (RREO) de um município
# ---------------------------------------------------------------------
sub ingest_municipio_receita ($self, %args) {
  my $cod_ibge = $args{cod_ibge} or die "cod_ibge e obrigatorio\n";
  my $exercicio = $args{exercicio} // (localtime)[5] + 1900;
  my $periodo   = $args{nr_periodo} // 2;              # RREO bimestre
  my $dt_snapshot = $args{dt_snapshot} // strftime('%Y-%m-%d', localtime);

  my $rows = $self->_fetch_rreo(
    exercicio   => $exercicio,
    nr_periodo  => $periodo,
    id_ente     => $cod_ibge,
    dt_snapshot => $dt_snapshot,
  );

  return $self->_load_receita($rows);
}

# ---------------------------------------------------------------------
# RREO: /rreo
# params da API: an_exercicio, nr_periodo, co_tipo_demonstrativo=RREO,
# id_ente (= cod_ibge, obrigatório e não vem no /entes)
# ---------------------------------------------------------------------
sub _fetch_rreo ($self, %args) {
  my $cod_ibge = delete $args{id_ente} // delete $args{cod_ibge};
  die "id_ente (cod_ibge) e obrigatorio\n" unless defined $cod_ibge;
  my $exercicio = delete $args{exercicio} // (localtime)[5] + 1900;
  my $periodo   = delete $args{nr_periodo} // 2;
  my $dt_snapshot = delete $args{dt_snapshot};

  my %p = (
    an_exercicio          => $exercicio,
    nr_periodo            => $periodo,
    co_tipo_demonstrativo => 'RREO',
    id_ente               => $cod_ibge,
    limit                 => 1000,
    offset                => 0,
    %args,
  );

  my @items;
  my ($page, $max_pages) = (0, 500);

  while ($page++ < $max_pages) {
    my $tx = $self->run_with_retry(sub {
      my $t = $self->ua->get($self->base_url . '/rreo' => form => { %p });
      die sprintf("SICONFI /rreo: HTTP %d (offset=%d)", $t->res->code, $p{offset})
        unless $t->res->code == 200;
      return $t;
    }, "rreo $cod_ibge offset=$p{offset}");

    my $json = $tx->res->json;
    last unless $json && ref($json) eq 'HASH' && $json->{items} && @{$json->{items}};
    push @items, @{$json->{items}};

    # `count` é POR PÁGINA (limit=2 => count=2), não o total — a
    # paginação decide-se por hasMore (sinal autoritativo). A página curta
    # é só um fallback para respostas sem o campo.
    last if defined $json->{hasMore} && !$json->{hasMore};
    # Fallback apenas para respostas sem o campo hasMore — uma página curta
    # com hasMore=true não pode ser tratada como fim.
    last if !defined $json->{hasMore} && @{$json->{items}} < $p{limit};
    $p{offset} += $p{limit};
    $self->_throttle;
  }

  # Armadilha crítica: HTTP 200 com count==0 é falso sucesso. Município
  # que devia ter RREO devolvendo lista vazia é erro de parâmetro/dado —
  # não pode passar como carga concluída.
  if (@items == 0) {
    die sprintf("SICONFI /rreo devolveu 0 itens para cod_ibge=%s (exercicio=%s periodo=%s) — HTTP 200 com count==0 NAO e sucesso; conferir parametros (an_exercicio e o nome correto)\n",
      $cod_ibge, $exercicio, $periodo);
  }

  return $self->_map_receitas($cod_ibge, $exercicio, \@items, $dt_snapshot);
}

# ---------------------------------------------------------------------
# Mapeamento RREO -> clean.siconfi_receita
# ---------------------------------------------------------------------
sub _map_receitas ($self, $cod_ibge, $exercicio, $items, $dt_snapshot) {
  $dt_snapshot //= strftime('%Y-%m-%d', localtime);
  my @out;
  my %ignorados;

  for my $it (@$items) {
    next unless defined $it->{coluna} && defined $it->{valor};
    # só o Anexo 01: os anexos temáticos repetem receita com outros rótulos
    next unless _anexo_receita($it->{anexo});
    my $class = $COLUNA_CLASSIFICACAO{$it->{coluna}};
    next unless $class;    # % / SALDO / despesa / previsão inicial saem

    my $tipo = $TIPO_POR_CONTA{$it->{cod_conta}};
    unless ($tipo) {
      # Total/subtotal conhecido sai em silêncio; linha desconhecida avisa.
      $ignorados{$it->{cod_conta}}++ unless $AGREGADO{$it->{cod_conta}};
      next;
    }

    push @out, {
      codigo_ibge       => sprintf('%07d', $cod_ibge),
      exercicio         => $exercicio + 0,
      tipo_receita      => $tipo,
      # A API devolve cod_conta como CHAVE (ex.: 'Impostos'), não como o
      # código numérico 1.1.1.1.01 da API antiga — aqui é exatamente isto
      # que distingue as linhas (e é o que o comentário do schema chama
      # de "código da coluna SICONFI").
      coluna_receita    => $it->{cod_conta},
      descricao_receita => $it->{conta} // undef,
      # ORDS devolve número JSON; `+ 0` normaliza NV. String com vírgula
      # não é esperada neste endpoint (verificado) — se aparecer, o teste
      # de mapeamento denuncia.
      valor             => $it->{valor} + 0,
      classificacao     => $class,
      dt_snapshot       => $dt_snapshot,
    };
  }

  if (keys %ignorados) {
    $self->log->warn('[' . $self->job_name . "] cod_contas receita nao mapeados (ignorados): "
      . join(', ', sort keys %ignorados));
  }

  return \@out;
}

# ---------------------------------------------------------------------
# Load idempotente em clean.siconfi_receita
# ---------------------------------------------------------------------
sub _load_receita ($self, $rows) {
  return 0 if $self->dry_run || !$rows || !@$rows;

  my $dbh = $self->app->schema->storage->dbh;
  my $sql = <<'SQL';
INSERT INTO clean.siconfi_receita
  (codigo_ibge, exercicio, tipo_receita, coluna_receita, descricao_receita,
   valor, classificacao, dt_snapshot)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (codigo_ibge, exercicio, tipo_receita, coluna_receita,
             classificacao, dt_snapshot)
DO UPDATE SET valor = EXCLUDED.valor,
              descricao_receita = EXCLUDED.descricao_receita
SQL

  my $loaded = 0;
  $dbh->begin_work;
  eval {
    my $sth = $dbh->prepare($sql);
    for my $r (@$rows) {
      $sth->execute(
        $r->{codigo_ibge}, $r->{exercicio}, $r->{tipo_receita},
        $r->{coluna_receita}, $r->{descricao_receita}, $r->{valor},
        $r->{classificacao}, $r->{dt_snapshot},
      );
      $loaded++;
    }
    $self->upsert_metadata('clean.siconfi_receita',
      'API Tesouro Nacional SICONFI receitas (RREO)',
      'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/rreo',
      'Domínio público (Tesouro Nacional)', $loaded,
      "Ingestão #165. classificacao: 'estimativa' = PREVISÃO ATUALIZADA (a); 'realizada' = Até o Bimestre (c).");
    $dbh->commit;
  };
  # CAPTURAR $@ ANTES do eval de rollback: o eval interno limpa $@, e o
  # erro original se perde (medido — a falha vindo do rollback abortava o
  # processo com a mensagem vazia, impossível de diagnosticar).
  if (my $err = $@) {
    eval { $dbh->rollback };
    die "SICONFI _load_receita falhou: $err";
  }

  $self->log_info("SICONFI: $loaded linhas em clean.siconfi_receita");
  return $loaded;
}

# ---------------------------------------------------------------------
# /entes -> cache local (chave de iteração da malha)
# ---------------------------------------------------------------------
sub _fetch_entes ($self) {
  my $cache = $self->entes_cache_file;
  if (-f $cache && -M $cache < 7) {
    my $cached = eval { decode_json(path($cache)->slurp) };
    return $cached if $cached && ref($cached) eq 'ARRAY' && @$cached;
  }

  my @todos;
  my %p = (limit => 1000, offset => 0);
  my ($page, $max_pages) = (0, 50);

  while ($page++ < $max_pages) {
    my $tx = $self->run_with_retry(sub {
      my $t = $self->ua->get($self->base_url . '/entes' => form => { %p });
      die "SICONFI /entes: HTTP " . $t->res->code unless $t->res->code == 200;
      return $t;
    }, "entes offset=$p{offset}");

    my $json = $tx->res->json;
    last unless $json && $json->{items} && @{$json->{items}};
    push @todos, @{$json->{items}};
    last if defined $json->{hasMore} && !$json->{hasMore};
    # Fallback apenas para respostas sem o campo hasMore — uma página curta
    # com hasMore=true não pode ser tratada como fim.
    last if !defined $json->{hasMore} && @{$json->{items}} < $p{limit};
    $p{offset} += $p{limit};
    $self->_throttle;
  }

  # Só municípios (a malha do projeto é municipal)
  @todos = grep { ($_->{esfera} // '') eq 'M' } @todos;

  make_path(path($cache)->dirname);
  path($cache)->spew(encode_json(\@todos));
  $self->log_info('SICONFI: /entes cache atualizado com ' . scalar(@todos) . ' municípios');

  return \@todos;
}

sub _throttle ($self) {
  select(undef, undef, undef, $self->throttle) if $self->throttle > 0;
}

1;