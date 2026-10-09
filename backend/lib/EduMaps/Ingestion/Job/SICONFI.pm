package EduMaps::Ingestion::Job::SICONFI;
use Mojo::Base 'EduMaps::Ingestion::Job::Base', -signatures;

use Mojo::File qw(path);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::UserAgent;
use File::Path qw(make_path);
use POSIX qw(strftime);

use utf8;

has job_name => 'SICONFI';
has description => 'Ingestão SICONFI (receitas RREO; despesas e FUNDEB via DCA) via API DataLake do Tesouro';
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
# 'fundeb' é preenchido a partir do DCA (Anexo I-C, fase 2 da #193): o
# endpoint RREO não expõe a linha detalhada 1.7.5.x (transferências do
# FUNDEB vêm agregadas dentro de TransferenciasCorrentes*) — nunca
# adivinhar pelo nome da conta. Detalhe no bloco do DCA abaixo.
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
    # dca => despesa por função + FUNDEB (DCA anual); senão receitas RREO
    return $args->{dca}
      ? $self->ingest_municipio_dca(%$args)
      : $self->ingest_municipio_receita(%$args);
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
      if ($args->{dca}) {
        # DCA anual é publicado no semestre seguinte ao exercício —
        # município que ainda não publicou é comum e não pode abortar a
        # malha inteira (strict_zero => 0), ao contrário do RREO bimestral.
        $total += $self->ingest_municipio_dca(cod_ibge => $cod[$i], strict_zero => 0, %$args);
      }
      else {
        $total += $self->ingest_municipio_receita(cod_ibge => $cod[$i], %$args);
      }
    }
    return $total;
  }

  # Fase 1 (escopo mínimo da #165): São Paulo quando nada é pedido
  return $args->{dca}
    ? $self->ingest_municipio_dca(cod_ibge => '3550308', %$args)
    : $self->ingest_municipio_receita(cod_ibge => '3550308', %$args);
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
# DCA (demonstrações contábeis anuais, DCASP) — fase 2 (#193)
# ---------------------------------------------------------------------
#
# A pergunta da #193 ("FUNDEB detalhado sai pelo /rreo ou pelo /dca//rgf?")
# foi respondida com medição (2026-10-08): só o /dca. O RREO não traz
# anexo de ensino (2023-2025 medidos) e o /rgf devolve 0. No DCA:
#
#   Anexo I-E  despesa por função/subfunção — códigos numéricos no texto
#              da conta ('12 - Educação', '12.361 - Ensino Fundamental') e
#              colunas Empenhadas/Liquidadas/Pagas (o Anexo 02 do RREO só
#              tem nomes e não tem 'pagas').
#   Anexo I-C  demonstrativo da receita — classificador numérico
#              (1.7.5.1.00.0.0 = FUNDEB; 1.7.1.5.00.0.0 = Complementação
#              da União ao FUNDEB).
#
# `run` com `dca => 1` carrega despesa e FUNDEB de um só fetch por
# município. O exercício é o ANUAL FECHADO (não há bimestre).

# ---------------------------------------------------------------------
# DCA de um município: despesa (I-E) + FUNDEB (I-C) em uma passada
# ---------------------------------------------------------------------
sub ingest_municipio_dca ($self, %args) {
  my $cod_ibge = $args{cod_ibge} or die "cod_ibge e obrigatorio\n";
  my $exercicio = $args{exercicio} // (localtime)[5] + 1900;
  my $dt_snapshot = $args{dt_snapshot} // strftime('%Y-%m-%d', localtime);

  my $items = $self->_fetch_dca(
    id_ente     => $cod_ibge,
    exercicio   => $exercicio,
    strict_zero => $args{strict_zero} // 1,
  );
  return 0 unless $items;

  my $despesas = $self->_map_despesas($cod_ibge, $exercicio, $items, $dt_snapshot);
  my $fundeb   = $self->_map_fundeb($cod_ibge, $exercicio, $items, $dt_snapshot);

  my $n1 = $self->_load_despesa($despesas);
  my $n2 = $self->_load_fundeb($fundeb);
  $self->log_info("SICONFI: $n1 linhas em clean.siconfi_despesa, $n2 em clean.siconfi_receita (fundeb) — $cod_ibge/$exercicio");
  return $n1 + $n2;
}

# ---------------------------------------------------------------------
# DCA: /dca
# params da API: an_exercicio, id_ente (= cod_ibge), limit/offset.
# Sem co_tipo_demonstracao: o default devolve o DCASP anual completo
# (anexos I-AB, I-C, I-D, I-E, I-F, I-G, I-HI). Paginação por hasMore,
# igual ao /rreo.
# strict_zero=1 (município único): count==0 morre, como na fase 1.
# strict_zero=0 (iteração da malha): município que ainda não publicou o
# DCA anual é avisado e pulado — não aborta a carga inteira.
# ---------------------------------------------------------------------
sub _fetch_dca ($self, %args) {
  my $cod_ibge = delete $args{id_ente} // delete $args{cod_ibge};
  die "id_ente (cod_ibge) e obrigatorio\n" unless defined $cod_ibge;
  my $exercicio = delete $args{exercicio} // (localtime)[5] + 1900;
  my $strict = delete $args{strict_zero} // 1;

  my %p = (
    an_exercicio => $exercicio,
    id_ente      => $cod_ibge,
    limit        => 1000,
    offset       => 0,
    %args,
  );

  my @items;
  my ($page, $max_pages) = (0, 500);

  while ($page++ < $max_pages) {
    my $tx = $self->run_with_retry(sub {
      my $t = $self->ua->get($self->base_url . '/dca' => form => { %p });
      die sprintf("SICONFI /dca: HTTP %d (offset=%d)", $t->res->code, $p{offset})
        unless $t->res->code == 200;
      return $t;
    }, "dca $cod_ibge offset=$p{offset}");

    my $json = $tx->res->json;
    last unless $json && ref($json) eq 'HASH' && $json->{items} && @{$json->{items}};
    push @items, @{$json->{items}};

    # `count` é POR PÁGINA (limit=2 => count=2), não o total — a
    # paginação decide-se por hasMore (sinal autoritativo).
    last if defined $json->{hasMore} && !$json->{hasMore};
    # Fallback apenas para respostas sem o campo hasMore — uma página curta
    # com hasMore=true não pode ser tratada como fim.
    last if !defined $json->{hasMore} && @{$json->{items}} < $p{limit};
    $p{offset} += $p{limit};
    $self->_throttle;
  }

  if (@items == 0) {
    my $msg = sprintf("SICONFI /dca devolveu 0 itens para cod_ibge=%s (exercicio=%s) — DCA anual provavelmente ainda nao publicado",
      $cod_ibge, $exercicio);
    if ($strict) {
      die $msg . " (HTTP 200 com count==0 NAO e sucesso)\n";
    }
    $self->log->warn('[' . $self->job_name . "] $msg (pulado)");
    return undef;
  }

  return \@items;
}

# ---------------------------------------------------------------------
# Despesa: DCA-Anexo I-E (execução das despesas por função)
#           -> clean.siconfi_despesa
#
# A linha de FUNÇÃO traz o código no texto da conta ('12 - Educação'); os
# descendentes ('12.361 - Ensino Fundamental') e os buckets sintéticos
# ('FU12 - Demais Subfunções') ficam de fora DELIBERADAMENTE: medido no
# SP 2024, a soma das subfunções não fecha com o total oficial da função
# (diff ~8%) — guardar filhos E pai duplicaria qualquer soma, e guardar só
# os filhos distorceria o total da função 12 que o esforço fiscal usa.
# A linha de função vira subfuncao = 0 (total oficial do demonstrativo).
#
# Colunas: Empenhadas -> valor_empenhado; Liquidadas -> valor_liquidado;
# Pagas -> valor_pago. Inscrições de restos a pagar e colunas não mapeadas
# saem (não são gasto executado da função).
# ---------------------------------------------------------------------
my %COLUNA_DESPESA = (
  'Despesas Empenhadas' => 'valor_empenhado',
  'Despesas Liquidadas' => 'valor_liquidado',
  'Despesas Pagas'      => 'valor_pago',
);

sub _map_despesas ($self, $cod_ibge, $exercicio, $items, $dt_snapshot) {
  $dt_snapshot //= strftime('%Y-%m-%d', localtime);
  my %by;
  my %desconhecidas;

  for my $it (@$items) {
    next unless ($it->{anexo} // '') eq 'DCA-Anexo I-E';
    next unless defined $it->{coluna} && defined $it->{valor};
    my $slot = $COLUNA_DESPESA{$it->{coluna}};
    unless ($slot) {
      $desconhecidas{$it->{coluna}}++
        unless $it->{coluna} =~ /Restos a Pagar/;
      next;
    }
    my $conta = $it->{conta} // '';
    my ($funcode) = $conta =~ /^(\d{2}) - / or next;
    my $descricao = $conta;
    $descricao =~ s/^\d{2} - //;
    $by{$funcode}{$slot}      = $it->{valor} + 0;
    $by{$funcode}{descricao}  = $descricao;
  }

  if (keys %desconhecidas) {
    $self->log->warn('[' . $self->job_name . '] colunas despesa nao mapeadas no DCA I-E (ignoradas): '
      . join(', ', sort keys %desconhecidas));
  }

  my @out;
  for my $f (sort keys %by) {
    push @out, {
      codigo_ibge       => sprintf('%07d', $cod_ibge),
      exercicio         => $exercicio + 0,
      funcao            => $f + 0,
      subfuncao         => 0,              # linha de função (total oficial)
      descricao_despesa => $by{$f}{descricao},
      valor_empenhado   => $by{$f}{valor_empenhado},
      valor_liquidado   => $by{$f}{valor_liquidado},
      valor_pago        => $by{$f}{valor_pago},
      classificacao     => 'realizada',
      dt_snapshot       => $dt_snapshot,
    };
  }

  return \@out;
}

# ---------------------------------------------------------------------
# FUNDEB: DCA-Anexo I-C (demonstrativo da receita) -> clean.siconfi_receita
#
# Só as duas contas do FUNDEB, identificadas pelo classificador numérico
# (chave robusta — nada de de-para por nome):
#   1.7.5.1.00.0.0  FUNDEB (transferências dos estados)
#   1.7.1.5.00.0.0  Complementação da União ao FUNDEB
# Ambas viram tipo_receita='fundeb'. FNDE / Salário-Educação / convênios
# (1.7.1.4.x, 1.7.2.4.51) NÃO entram: já estão contidos no agregado
# 'transferencia' do RREO (fase 1) e entrariam DUAS vezes no total.
#
# Valor = 'Receitas Brutas Realizadas'; as colunas de dedução saem.
# ---------------------------------------------------------------------
my %FUNDEB_CONTA = map { $_ => 1 } qw(
  1.7.5.1.00.0.0
  1.7.1.5.00.0.0
);

sub _map_fundeb ($self, $cod_ibge, $exercicio, $items, $dt_snapshot) {
  $dt_snapshot //= strftime('%Y-%m-%d', localtime);
  my @out;

  for my $it (@$items) {
    next unless ($it->{anexo} // '') eq 'DCA-Anexo I-C';
    next unless ($it->{coluna} // '') eq 'Receitas Brutas Realizadas';
    my $cod = $it->{cod_conta} // '';
    $cod =~ s/^RO//;                # ORDS prefixa 'RO' nos itens de receita
    next unless $FUNDEB_CONTA{$cod};
    my $descricao = $it->{conta} // '';
    $descricao =~ s/^[0-9.]+ - //;  # tira o código do texto

    push @out, {
      codigo_ibge       => sprintf('%07d', $cod_ibge),
      exercicio         => $exercicio + 0,
      tipo_receita      => 'fundeb',
      coluna_receita    => $cod,
      descricao_receita => $descricao,
      valor             => $it->{valor} + 0,
      classificacao     => 'realizada',
      dt_snapshot       => $dt_snapshot,
    };
  }

  return \@out;
}

# ---------------------------------------------------------------------
# Load idempotente em clean.siconfi_despesa (PK da fase 2 #193:
# codigo_ibge + exercicio + funcao + subfuncao + classificacao + snapshot)
# ---------------------------------------------------------------------
sub _load_despesa ($self, $rows) {
  return 0 if $self->dry_run || !$rows || !@$rows;

  my $dbh = $self->app->schema->storage->dbh;
  my $sql = <<'SQL';
INSERT INTO clean.siconfi_despesa
  (codigo_ibge, exercicio, funcao, subfuncao, descricao_despesa,
   valor_empenhado, valor_liquidado, valor_pago, classificacao, dt_snapshot)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (codigo_ibge, exercicio, funcao, subfuncao, classificacao,
             dt_snapshot)
DO UPDATE SET descricao_despesa = EXCLUDED.descricao_despesa,
              valor_empenhado  = EXCLUDED.valor_empenhado,
              valor_liquidado  = EXCLUDED.valor_liquidado,
              valor_pago       = EXCLUDED.valor_pago
SQL

  my $loaded = 0;
  $dbh->begin_work;
  eval {
    my $sth = $dbh->prepare($sql);
    for my $r (@$rows) {
      $sth->execute(
        $r->{codigo_ibge}, $r->{exercicio}, $r->{funcao}, $r->{subfuncao},
        $r->{descricao_despesa}, $r->{valor_empenhado}, $r->{valor_liquidado},
        $r->{valor_pago}, $r->{classificacao}, $r->{dt_snapshot},
      );
      $loaded++;
    }
    $self->upsert_metadata('clean.siconfi_despesa',
      'API Tesouro Nacional SICONFI despesas por função (DCA-Anexo I-E)',
      'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/dca',
      'Domínio público (Tesouro Nacional)', $loaded,
      "Ingestão #193. classificacao: 'realizada'. Granularidade: linha de função (subfuncao=0).");
    $dbh->commit;
  };
  # CAPTURAR $@ ANTES do eval de rollback (mesma armadilha medida na #165)
  if (my $err = $@) {
    eval { $dbh->rollback };
    die "SICONFI _load_despesa falhou: $err";
  }

  $self->log_info("SICONFI: $loaded linhas em clean.siconfi_despesa");
  return $loaded;
}

# ---------------------------------------------------------------------
# Load idempotente do FUNDEB em clean.siconfi_receita
# ---------------------------------------------------------------------
sub _load_fundeb ($self, $rows) {
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
      'API Tesouro Nacional SICONFI receitas FUNDEB (DCA-Anexo I-C)',
      'https://apidatalake.tesouro.gov.br/ords/cdwhprd/siconfi/tt/dca',
      'Domínio público (Tesouro Nacional)', $loaded,
      "Ingestão #193. tipo_receita='fundeb': 1.7.5.1.00.0.0 (FUNDEB) e 1.7.1.5.00.0.0 (Complementação da União).");
    $dbh->commit;
  };
  if (my $err = $@) {
    eval { $dbh->rollback };
    die "SICONFI _load_fundeb falhou: $err";
  }

  $self->log_info("SICONFI: $loaded linhas FUNDEB em clean.siconfi_receita");
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