# Nota técnica 74 — Catálogo e priorização de fontes de dados abertas (#123)

**Data**: 2026-09-30
**PRs**: (ver `gh pr list` — branch `docs/analytics-fontes-de-dados`)
**Issues**: #123 (origem) · #124 a #130 (fases 0–6 do plano) · #131 (Overpass /
viés de cobertura) · #132 (os três e-SIC)
**Áreas**: docs (sem código — **sem deploy**)

## Contexto

O EduMaps combina **Censo Escolar + OpenStreetMap + SIOPE** para sustentar o
**IVET** (Índice de Vulnerabilidade Educacional Territorial). Essa combinação
funciona, mas cobre **três** eixos. O IVET tem, por isso, **seis lacunas
declaradas** — saúde, segurança pública, conectividade, investimentos
planejados, mobilidade e meio ambiente — que hoje são preenchidas, quando muito,
por *proxies* fracos ou por valores uniforme por município.

A issue #123 pedia o **catálogo e a priorização dessas fontes**, com a
implementação explicitamente **fora de escopo** (viria em issues próprias).

Duas decisões de escopo, alinhadas antes de começar:

- **Verificação em profundidade, não sampling.** Cada campo crítico (licença,
  endpoint, granularidade, periodicidade) precisaria ser confirmado em **fonte
  oficial**, não de memória nem de snippet de blog.
- **Layout em duas camadas**: matriz-mestre num arquivo só, fichas completas por
  domínio — para que a leitura de decisão não exija abrir 8 arquivos, mas a
  verificação ainda tenha onde morar.

## Decisão 1 — `não verificado` derruba a prioridade, sem exceção

O critério de aceite nº 9 exigia que licença, endpoint e granularidade fossem
verificados. A tentação previsível era promover as fichas "provavelmente
boas" e fechar o catálogo. A regra adotada foi mais dura que a exigida:

> **Campo não confirmado vira `não verificado` e impede `[alta]`.** Não há
> promoção por inferência.

O custo foi real: o **lote de educação inteiro** (6 fontes) ficou fora de
`[alta]` porque a licença do INEP não foi encontrada. O benefício também foi
real: **zero fontes `[alta]` com campo `não verificado`**, e sete itens do próprio
enunciado da issue não existir ou estar mal nomeados (abaixo).

**O que isso mudou concretamente**: a "licença do INEP" deixou de ser detalhe e
virou **uma e-SIC** que destrava quatro fichas de uma vez — ação administrativa
de baixo custo, registrada como pendência.

## Decisão 2 — rebaixamento é explícito, com o motivo escrito

Quatro regras de rebaixamento foram definidas antes de pontuar. A diferença que
importa é que **todo rebaixamento registra qual regra incide** e por quê.
Sem isso, "prioridade média" vira opinião e o catálogo não é auditável.

Exemplo que mostra a diferença: o **Ipeadata** somou **18 pontos** — o terceiro
maior número do catálogo — e ainda assim é `[média]`, porque a API é **só HTTP
(sem TLS)**, **não aceita paginação** (toda consulta de metadados baixa 7,3 MB) e
a licença é "uso público com citação", **sem SPDX**. A ficha registra os três.

O oposto também valeu: **BrazilCrime** somou 16 e é `[alta]` com um único
`library()`, mas a ficha carrega a advertência de que é a fonte de **maior risco
ético** do catálogo. *Cheap* e *delicado* não são contraditórios.

## Decisão 3 — a API do SUS publica dado individual sem mitigação

Este é o achado mais consequente do trabalho, e é **verificado em payload de
produção**, não inferido de documentação:

| Endpoint | O que devolve |
|---|---|
| `/sisvan/estado-nutricional` | peso, altura, IMC, data — **por pessoa** |
| `/vacinacao/doses-aplicadas-pni-*` | data de vacinação, `codigo_documento`, raça — **por pessoa** |
| `/cnes/estabelecimentos` | **nome de pessoa física**, CNPJ, telefone, e-mail |

As três respostas vieram **200** em requisição anônima, sem challenge.

A consequência não é uma nota de rodapé: é **requisito de arquitetura**. Um job de
ingestão que monta URL por interpolação baixaria microdado sensível de menor para
o banco de desenvolvimento. Daí a **Fase 0** do plano:

1. **Allowlist de endpoints/tabelas** em `data_pipeline/`, revisável em code
   review, com o job **recusando** qualquer endpoint fora da lista.
2. **Proveniência com licença** — estender `clean.import_metadata` (hoje tem
   `table_name`, `source_file`, `import_timestamp`, `row_count_loaded`, `notes`)
   com `source_url`, `source_license` e `retrieved_at`. Sem isso, o critério nº 9
   deixa de ser auditável **depois** da ingestão, e as descobertas de licença
   (ODbL do BCB, CC BY-ND do SUS) se perdem.

## Decisão 4 — planejar contra o pipeline real, não contra um ideal

O plano faseado foi escrito contra o que existe no repositório, não contra um
arquitetura imaginária. As conferência renderam:

- `clean.dados_ibge` **já existe** e já consome **SIDRA** (PIB municipal) → as
  fontes IBGE do plano são **extensão**, não greenfield, e seguem o mesmo padrão
  de coluna (`codigo_ibge`, `ano`) que o resto do banco.
- `clean.ideb_notas_escolas` e `raw.inep_raw` **já existem** → o lote educação é
  sobre **ampliar**, não construir.
- A convenção `raw.` → `clean.` → `analytics.` com migration Sqitch em
  `data_pipeline/deploy/` e R em `analysis/edumapsr/R/` foi mantida; os nomes de
  tabela propostos na Fase 1–5 seguem esse padrão.

Também por isso o **IBGE SIDRA entra como `[alta]` mas com uma ressalva
operacional dura**: o host `apisidra.ibge.gov.br` está atrás de Cloudflare e
retorna **403 "Just a moment"** para servidor. O caminho primário é a **v3 em
`servicodados.ibge.gov.br`**, que respondeu **200** sem challenge. Isso não está
em nenhuma documentação do IBGE — só aparece testando.

## Decisão 5 — registrar também o que **não** entra

O enunciado da issue trazia uma lista de candidatos. Sete itens **não existem ou
mudaram de nome**, e isso está registrado em cada ficha e na matriz:

| Item | Correção |
|---|---|
| `ibge7`, `geodesobr` | não existem no CRAN (`geobr` é o substituto correto) |
| `RRPP` | não é do IBGE — é filogenética |
| `PNCT` | **PNATE** é a sigla vigente; `/programas/pnct` → **404** |
| `GESAC` | não é órgão nem portal (`NXDOMAIN`): é a **modalidade satelital do Wi-Fi Brasil** |
| `SIGESC`, `PDL Educationis` | inexistentes |
| `Novo PAC` da CGU | **404**/`NXDOMAIN`; o dado de obras é do **FNDE** |
| `SISLIC` | **exige login** — não é dado aberto |
| `PRODES`/`DETER` | são do **INPE**, não do IBAMA |
| `dados.gov.br` como fonte | CKAN federal exige credencial (**401**) |
| FIPE na BrasilAPI | fora do ar (**404**) |

O valor disso é concreto: sem a checagem, três issues de implementação teriam
sido criadas para endpoints inexistentes. O lote de mobilidade adicionou mais
**sete** correções, listadas em `fontes/mobilidade.md`; as mais graves foram o
**PNCT** (que a issue tratava como malha rodoviária aberta) e o **"Sistema de
Informações sobre Demandas de Transporte"**, que **não existe com esse nome**.

## Decisão 6 — rebaixar o Recife por consistência, mesmo sendo a melhor ficha

A regra "ODbL share-alike não pode ser materializado" já tinha derrubado o Banco
Central. Quando a ficha do **CKAN do Recife** apareceu — com **16 pontos**,
**única granularidade escolar** do lote de mobilidade e a **melhor API** (CKAN
DataStore consultável por SQL, sem autenticação) — a tentação foi aceitá-la
porque a fonte é interessante.

Aceitar aqui teria sido **trapacear no método**: o rebaixamento do BCB não pode
depender de a fonte ser chata. A ficha ficou `[média]`, e a diferença com o
**OSM** (também ODbL, e portanto já ingerido) ficou **explícita na ficha**, não
acidental: lá o share-alike já foi aceito há anos e a tabela existe; aqui a
incorporação criaria a obrigação pela primeira vez.

Consequência prática registrada: a leitura do Recife é permitida e serve de
**prova de viabilidade** para `iv_mobilidade_transporte_escolar`; materializar
sob share-alike é decisão do jurídico, não do pipeline.

## Decisão 7 — licença aberta **não** anula risco LGPD

Dois conjuntos públicos, ambos com licença aberta, foram identificados como
**proibidos** de ingerir:

| Conjunto | Licença | O que expõe |
|---|---|---|
| ANTT — "Monitriip Serviço Regular — Viagens" (74 recursos) | CC BY 4.0 | `cnpj`, `placa`, `numero_imei`, `latitude`, `longitude` **por viagem** |
| SPTRANS — "Créditos Eletrônicos do Bilhete Único — Usuário" | **CCZero** | saldo/crédito **por usuário individual** |

O segundo é o caso-limite instructive: **CCZero é o degrau mais alto de liberdade
de uso**, e ainda assim é dado individual de deslocamento. Cruzado com escola e
horário, reconstrói o trajeto de um aluno. Isso reforçou a **Fase 0**: a
allowlist de endpoints precisa cobrir **tudo**, não só a API do SUS — o vetor de
erro é o mesmo, um job que baixa "o conjunto de viagens certo" em vez do
agregado.

## Achados que mudaram a priorização

1. **Atlas do IDHM publica ~120 indicadores municipais** com dimensões
   **SAÚDE** e **VULNERABILIDADE** já calculadas. Isso abre **parte da lacuna 1
   sem depender do acesso difícil ao DATASUS** — que era o item mais caro do
   plano.
2. **Base dos Dados entrega Censo Escolar 2007–2022 em BigQuery.** Resolve o
   problema de volume (ZIPs de vários GB/ano) e dá série histórica. Limite
   verificado: **2023/2024 ausentes** → precisa combinar com o INEP.
3. **`tesouror` traz SICONFI**, não só SIOPE. Abre uma dimensão que o IVET não
   tinha: **capacidade fiscal municipal** (`FUNDEB`/aluno, dependência federal).
4. **Malha do setor censitário** (via `geobr`/`censobr`, **desde 1960**) permite
   sair do valor municipal uniforme — a maior simplificação atual do IVET.
5. **Censo Escolar do INEP vai de 1995 a 2025** — a alegação inicial do
   levantamento de pesquisa estava certa e foi confirmada por extração dos
   `href`. Mas a URL de **2025 tem underscore extra**
   (`microdados_censo_escolar_2025_**.zip**): um ETL que interpola `%d` recebe
   **404 só naquele ano**, sem erro nos outros 30. Isso virou requisito: tabela
   de exceções ou scraping do `href`.
6. **O Overpass tem limite de taxa verificado de 2 slots simultâneos.** A
   extração atual do EduMaps, se paralelizada, seria bloqueada. Toda consulta ao
   OSM precisa de **fila com repetição espaçada** e **persistência do bruto em
   disco** — reconsultar o OSM para o mesmo objeto é desperdício.
7. **Os roteadores abertos verificados são servidores de demonstração, sem
   SLA.** Como as isocronas são o indicador mais defensável da lacuna 5, a
   recomendação virou arquitetura: **extrair o *tileset* uma vez e auto-hospedar
   OSRM/Valhalla em container** — o que também elimina a dependência de
   servidores comunitários estrangeiros.
8. **O PNCT não é malha aberta.** `/dadospnct/downloads` → **404**, o VGeo é
   visualizador sem API e a página declara "Todos os Direitos Reservados". O
   caminho aberto real (camada de VMDA espelhada no INDE, em domínio público)
   só apareceu por metadados de terceiro — o que reforça a regra de não confiar
   na documentação e **testar o endpoint**.

## Lacunas que o catálogo **não** resolveu

Registrado com o mesmo destaque das resolvidas, porque é a informação mais útil
que a issue entrega:

- **Conectividade (lacuna 3)**: a única medição real de banda larga por escola é
  o Medidor Educação Conectada, que **não tem API nem licença publicada** (o
  próprio `licenca.txt` do rodapé é **404**) e está atrás de app Shiny. Não há
  solução limpa no catálogo atual. A contramedida correta **não é scraper**, é
  **e-SIC** — a metodologia de agregação já está publicada na aba "Dados".

Recomendação registrada: para conectividade, **e-SIC**, e o bloco fica
explicitamente vazio no IVET até lá.

### A leitura de mobilidade mudou — e mudou porque o catálogo foi maior

A primeira passada de curadoria registrou a mobilidade como **não resolvida**:
"não existe base nacional comparável; o padrão de dados abertos de transporte é
GTFS, municipal e não padronizado". **Essa conclusão estava errada**, e o erro
só apareceu ao verificar o lote de mobilidade com o mesmo rigor dos outros.

O que a verificação encontrou são **quatro bases nacionais**, todas com
granularidade e periodicidade utilizáveis:

| Dimensão | Fonte | Chave |
|---|---|---|
| Fluxo de deslocamento | **ANTT / MONITRIIP** | par de municípios, mensal, desde jan/2019 |
| Tráfego e risco de trecho | **ANTT** (SAT, acidentes, geodados) | trecho viário com coordenada |
| Malha com volume | **DNIT/INDE** (SNV + modelagem de VMDA) | trecho de rodovia, domínio público |
| Frota e sinistralidade | **Transportes** (RENAVAM, RENAEST) | município, mensal, desde mai/2013 |

E a peça que fecha o ciclo: **OSRM/Valhalla** geram isocronas a partir da malha
do OSM, que é **exatamente o elo entre a rede viária e a malha censitária do
IBGE** — sem tocar em dado de passageiro, o que faz dela a solução mais segura
em LGPD para a lacuna.

**A ressalva real é de granularidade, não de cobertura.** Deslocamento escolar
com **chave de escola** existe em **um único município verificado** — o Recife,
que publica vagas de transporte escolar gratuito por unidade e por turno. O
diagnóstico certo não é "não há dado": é que **o dado existe nos DETRANs e nas
secretarias de educação e quase nunca é publicado**. O gargalo da lacuna 5 é
**publicação, não coleta** — o que muda completamente a recomendação, de
"piloto municipal com honestidade" para "ingerir as quatro bases nacionais e
usar o Recife como prova de viabilidade do indicador escolar".

Sete premissas da issue #123 caíram na verificação; a mais séria era o **PNCT**,
que a issue tratava como malha rodoviária aberta e na verdade tem página de
download em **404**, visualizador sem API e rodapé "Todos os Direitos
Reservados". O caminho aberto real — a camada de modelagem de VMDA espelhada no
INDE — só apareceu por metadados de terceiro.

## Resultado

- **61 fontes** com ficha verificada em **8 domínios**, acima do mínimo de 25.
- **21 fontes `[alta]`** (mínimo exigido: 5), **nenhuma** com campo
  `não verificado`.
- **14 correções** ao próprio enunciado da issue (7 na primeira passada, 7 no
  lote de mobilidade).
- Plano em **7 fases** com pré-requisitos de arquitetura identificados, cada
  fase com **issue própria** (#124–#130) mais duas transversais (#131, #132).
- **3 e-SIC** listadas como ação de maior retorno — administrativas, não de
  engenharia (#132).
- **4 das 6** lacunas bem resolvidas, **2** parciais mas utilizáveis, **1**
  (conectividade) sem solução verificada.

### As issues criadas

| Issue | Fase | Prioridade |
|---|---|---|
| [#124](https://github.com/marcoarthur/edumaps/issues/124) | Fase 0 — allowlist + proveniência | **alta** (bloqueia todas) |
| [#125](https://github.com/marcoarthur/edumaps/issues/125) | Fase 1 — contexto municipal/sub-municipal | **alta** |
| [#126](https://github.com/marcoarthur/edumaps/issues/126) | Fase 2 — saúde (CNES + DATASUS) | **alta** |
| [#127](https://github.com/marcoarthur/edumaps/issues/127) | Fase 3 — eventos e risco | média |
| [#128](https://github.com/marcoarthur/edumaps/issues/128) | Fase 4 — financeiro e investimento | média |
| [#129](https://github.com/marcoarthur/edumaps/issues/129) | Fase 5 — segurança e LGPD | **alta** |
| [#130](https://github.com/marcoarthur/edumaps/issues/130) | Fase 6 — mobilidade | **alta** |
| [#131](https://github.com/marcoarthur/edumaps/issues/131) | Overpass conforme + viés de cobertura | **alta** |
| [#132](https://github.com/marcoarthur/edumaps/issues/132) | Três e-SIC (administrativo) | **alta** |

Uma fonte `[alta]` por fase, não uma issue por fonte: o que se entrega é a
*tabela* e a *view* analítica, e nove issues simultâneas de pipeline
interdependente serializariam o trabalho sem ganho.

## Pendências

- **e-SIC ao INEP** (licença de Censo Escolar, IDEB, ENEM, painel do PNE) —
  desbloqueia 4 fichas de `[alta]`. → **#132**
- **e-SIC ao MEC/NIC.br** (CSV + dicionário do Medidor Educação Conectada) —
  fecha a lacuna 3. → **#132**
- **e-SIC ao FNDE** (URL + dicionário do Novo PAC/Proinfância e do PNATE). →
  **#132**
- **e-SIC às secretarias municipais de educação** (vagas de transporte escolar
  por unidade e por turno) — o gargalo da lacuna 5 é **publicação, não
  coleta**, e esta é a pergunta certa a se fazer. → **#132**
- **Decisão institucional sobre PeNSE** (CEP/Conep, ambiente controlado, regra
  de não-persistência) — a fonte de maior valor de saúde do catálogo e a única
  que exige decisão não técnica.
- **Decisão de leitura do IVET**: índice *territorial* ou *escolar com contexto*?
  A escolha altera a interpretação de todos os coeficientes (pendência P5 da
  `pesquisadora-educacional`).
- Verificar handshake TLS com `download.inep.gov.br` a partir da rede de deploy
  (falhou neste ambiente; DNS resolve).
