# Memory — EduMaps

> Arquivo de restauração de sessão. Registrar aqui tudo que foi descoberto
> e/ou informado pelo usuário, para retomar o contexto em sessões futuras.
> As seções abaixo ficam em ordem cronológica reversa (sessão mais recente no topo).

## Sessão 2026-09-30 — Implementação #125: Fase 1 IBGE contexto municipal

Ciclo **com código** (data_pipeline → **deploy necessário**).

**Mergeado**: PR **#142** (merge commit `c10600b`, commit `d30a4bc`),
branch `feat/data/fase1-ibge-contexto` → `main`, +656 −1 em 14 arquivos.

**Deploy Sqitch confirmado**:
- `+ malha_municipio ......... ok` — 5.573 municípios (derivado de clean.municipios_sp)
- `+ malha_setor_censitario .. ok` — tabela vazia (estrutura p/ 316k setores)
- `+ ibge_agregados .......... ok` — SIDRA v3 formato longo + view pivô
- `+ censo2022_setor ......... ok` — supressao_celula_pequena (vazio ≠ zero)
- `sqitch verify`: 4 novos **OK** (falha em rede_escolas_etapas é pré-existente)

### Entregue

Ciclo **com código** (data_pipeline + backend → **deploy necessário**).

**Mergeado**: PR **#141** (merge commit `163d1d5`, commit `886b571`),
branch `feat/data/fase0-allowlist-proveniencia` → `main`, +549 −4 em 11 arquivos.

**Deploy Sqitch confirmado** (commit `2fb0059`):
- `sqitch deploy` via container `sqitch/sqitch:latest` alvo `db:pg://devel:senhaboa123@db/edumaps_dev`
- `+ import_metadata_fase0 .. ok` — colunas `source_url`, `source_license`, `retrieved_at` em `clean.import_metadata`
- `+ censo_data_dictionary .. ok` — tabela `clean.censo_data_dictionary` (764 linhas, 4 tabelas censo)
- `sqitch verify`: ambos os novos changes **OK** (falha em `rede_escolas_etapas` é pré-existente, divisão por zero)

### Entregue

- **Migration Sqitch** `import_metadata_fase0`: adiciona `source_url`,
  `source_license`, `retrieved_at` em `clean.import_metadata` + índice.
- **Allowlist YAML** versionada em `data_pipeline/allowlist.yaml`:
  6 fontes permitidas (FNDE SIOPE agregado, IBGE SIDRA/servicodados,
  INMET, MapBiomas, Transportes) + 5 recursos **explicitamente NEGADOS**
  (ANTT viagens, SPTRANS Bilhete Único Usuário, SUS SISVAN/Vacinação/CNES).
- **Módulo Perl** `EduMaps::Data::Allowlist`: valida URL antes de request
  HTTP, falha fechada por padrão, suporta `source_id` para restringir
  àquela fonte. Integrado no scraper SIOPE (`Gastos.pm`).
- **Migrations Censo** (4) atualizadas para popular proveniência
  (`source_url`, `source_license`, `retrieved_at`) em `clean.import_metadata`.
- **Testes**: `t/02-models/allowlist.t` (8 subtests) — permitido, negado,
  host desconhecido, licenças, restrição por source_id.
- **Verificação**: migration verify passa; import_metadata populada para
  4 tabelas censo.

### Decisões de Design

1. **Allowlist por recurso, não por host**: ANTT viagens e SPTRANS usuário
   estão no mesmo host de recursos permitidos, mas são **negados
   explicitamente** por serem nível individual (LGPD). Licença aberta
   (CCZero SPTRANS) não anula risco.
2. **Proveniência em import_metadata**: metadado canônico da ingestão;
   dicionário (#134) referencia via DO block dinâmico.
3. **Fail-fast**: validação antes do HTTP — dado sensível nunca chega ao
   banco de dev.
4. **DO block no dicionário**: roda sem erro antes de #124; popula
   proveniência automaticamente quando Fase 0 existir.

### Dependências Desbloqueadas

- **#125–#130** (todas as fases): allowlist já cobre IBGE, INMET, MapBiomas,
  Transportes, ANTT (agregado), SUS (agregados via e-SIC).
- **#134** (dicionário): DO block popula proveniência quando Fase 0 rodar.
- **#132** (e-SIC INEP): licença oficial do Censo → atualizar "Não verificada".

### Arquivos

- `data_pipeline/deploy|revert|verify/import_metadata_fase0.sql` (novos)
- `data_pipeline/allowlist.yaml` (novo)
- `backend/lib/EduMaps/Data/Allowlist.pm` (novo)
- `backend/lib/EduMaps/Task/Siope/Scrap/SpreadSheet/Gastos.pm` (atualizado)
- `data_pipeline/deploy/censo_escolar_2025.sql`, `censo_docentes.sql`,
  `matriculas_censo_2025.sql`, `censo_gestor.sql` (atualizados)
- `backend/t/02-models/allowlist.t` (novo)

### Nota Técnica

`docs/new_ideas/implementations_ideas/notas_tecnicas_76.md`

---

## Sessão 2026-09-30 — Implementação #134: dicionário de dados do Censo Escolar

Ciclo **com código** (data_pipeline + analysis → **deploy necessário**).

**Mergeado**: PR **#140** (merge commit `54afa9f`, 2 commits `eaaf66d`..`267cefd`),
branch `feat/data/censo-dictionary` → `main`, +1252 −37 em 8 arquivos.

### Entregue

- **Migration Sqitch** `censo_data_dictionary`: tabela `clean.censo_data_dictionary`
  (PK composta `table_name, column_name, year_introduced`), `value_domain` JSONB
  para enums, `year_changed`/`year_deprecated` para versionamento entre edições,
  proveniência (`source_url`, `source_license`, `retrieved_at`) populada por
  DO block dinâmico quando Fase 0 (#124) existir.
- **764 linhas** populadas automaticamente para as 4 tabelas censo
  (`censo_escolas`: 306, `censo_matriculas`: 237, `censo_docentes`: 156,
  `censo_gestor`: 65) a partir do catálogo + YAML curado.
- **Interface R** `censo_dictionary()` em `analysis/edumapsr/R/censo-dictionary.R`
  com filtro por ano, validação (`censo_dict_validate` — quebra build se coluna
  nova ou tp_*/in_* sem domínio), helpers (`filter`, `domain`, `summary`).
- **Chat integrado**: `chat-dictionary.R` usa `censo_dictionary()` como fonte
  primária para tabelas censo; YAML vira camada de curadoria (termos, conexões,
  ocultar). Prompt mostra `[enum: ...]` inline.
- **Testes**: 6 subtests Perl + 34 testes R passando.

### Decisões de Design

1. **PK composta por edição**: `(table_name, column_name, year_introduced)`
   permite rastrear mesma coluna across Censo 2025/2026+.
2. **DO block dinâmico**: só atualiza proveniência se colunas Fase 0 existirem
   — migration roda sem erro antes de #124.
3. **YAML curado como fonte de domínio**: 19 enums injetados via `UNION ALL`
   na migration; `tp_*` sem domínio ganha nota `"Enum tp_* sem domínio no YAML — revisar"`.
4. **Validação que quebra build**: `censo_dict_validate()` falha se houver
   coluna no banco ausente no dicionário, ou enum sem `value_domain`.

### Dependências Registradas

- **#124 antes de tudo**: DO block popula proveniência quando Fase 0 rodar.
- **#134 antes de #137**: treinar modelo sem dicionário/proveniência gera
  coeficiente impossível de auditar.
- **#135 depois de #124**: versionar (DVC) sem proveniência registra erro
  com data — pior que não versionar.

### Arquivos

- `data_pipeline/deploy|revert|verify/censo_data_dictionary.sql` (novos)
- `backend/lib/EduMaps/Schema/Result/CensoDataDictionary.pm` (novo)
- `backend/t/02-models/censo_dictionary.t` (novo)
- `analysis/edumapsr/R/censo-dictionary.R` (novo)
- `analysis/edumapsr/tests/testthat/test-censo-dictionary.R` (novo)
- `analysis/edumapsr/R/chat-dictionary.R` (atualizado)

### Nota Técnica

`docs/new_ideas/implementations_ideas/notas_tecnicas_75.md`

---

## Sessão 2026-09-30 — Backlog consolidado: #123 fechada e #134–#139 criadas

Ciclo administrativo (issues + documentação, **sem código → sem deploy**),
pedido do developer a partir da lista de backlog.

- **#123 fechada** com comentário apontando as 9 issues filhas (#124–#132) e as
  3 decisões que continuam abertas. O trabalho já estava mergeado (PR #133) e a
  issue ficou aberta por engano.
- **6 issues novas** para as direções priorizadas pelo Tech Lead que **não**
  eram ingestão de fonte e estavam sem issue: **#134** dicionário de dados do
  Censo Escolar (`[alta]`, Z:9892), **#135** DVC, **#136** git hooks, **#137**
  índices/RandomForest a produto, **#138** PgVector, **#139** fundamentação
  na literatura. Todas com Zotero na referência.
  ⚠️ Eu anunciei "5 direções" e eram **6** — o erro foi meu, na contagem.
- **Bug de referência cruzada corrigido**: o corpo da #137 apontava para
  "#137/DVC" — que era ela própria. Passou a apontar **#135**.
- **Dependências reveladas pelas issues** e registradas: **#124 antes de tudo**;
  **#134 antes de #137**; **#135 depois de #124** (versionar sem proveniência
  registra o erro com data, o que é pior que não registrar).
- **`memory.md`**: a lista de pendências da sessão #123 estava partida em duas
  pela tabela de issues inserida no meio. Reestruturada em "Pendências sem
  issue" + "Backlog registrado no GitHub", com as 16 issues em tabela única e
  coluna de origem (plano de fontes × acervo).

## Sessão 2026-09-30 — Curadoria do `eduBR` saiu deste repositório

Informado pelo developer: o **loop de curadoria do `eduBR` passou para o
repositório do próprio `eduBR`** (`~/Projects/eduBR`), que já tem `AGENTS.md`,
`docs/personas/` (perfil **e** memória das três personas) e o backlog
consolidado. Segunda instrução na mesma sessão: **o repo `eduBR` é
somente-leitura — não escrever nele de maneira alguma.**

🔴 **REGRA PERMANENTE: nunca escrever no repositório `eduBR`.** Nem arquivo de
persona, nem `AGENTS.md`, nem `memory.md`, nem backlog; nem rodar rodada de
curadoria lá; nem abrir PR, issue ou commit. Achado sobre o `eduBR` é registrado
**aqui**.

Consequência neste repo:

- **`AGENTS.md`**: removido o "Protocolo do loop (curadoria eduBR)". A seção
  "Personas de curadoria" agora avisa que a curadoria está dividida: o `eduBR`
  guarda o acervo dele (leitura), aqui fica só o **Tech Lead**.
- **As cópias em `docs/personas/` (pesquisadora-educacional, especialista-ml,
  gestora-escolar) PERMANECEM aqui como histórico congelado** — decisão do
  developer ("o histórico aqui pode permanecer"). **Não editar, não apagar.**
  Já divergiram: a `pesquisadora-educacional.md` daqui tem a 3ª rodada (P10/P11 +
  veredito, do ciclo #123) que não existe no repo `eduBR`, e **fica assim** —
  reconciliar exigiria escrever lá, o que está proibido. Para a versão
  corrente, ler no repo `eduBR`.
- `docs/indice.md` seção 7 reescrita; `memory.md`, `notas_tecnicas_74.md` e
  `docs/analises/fontes_de_dados.md` ajustados para apontar o repo `eduBR` como
  fonte da verdade (leitura).
- Ciclo **só de documentação** → push direto em `main` (exceção do passo 6 do
  Workflow), **sem deploy**.

## Sessão 2026-09-30 — Catálogo e priorização de fontes de dados abertas (issue #123)

Ciclo **100% de documentação** (sem código → **sem deploy**).

**Mergeado**: PR **#133** (7 commits, `28178ae`..`f8a97cd`, merge `3003d00`),
branch `docs/analytics-fontes-de-dados` → `main`, +5096 −31 em 16 arquivos.
Issues #124 a #132 criadas.

### Entregue
- `docs/analises/fontes_de_dados.md` — matriz-mestre (**61 fontes, 21 `[alta]`**),
  cobertura por lacuna, plano em **7 fases** (#124–#130) e tabela de issues.
- `docs/analises/fontes/` — **61 fichas** em 8 domínios (educacao,
  socioeconomico, conectividade-obras, **mobilidade (13 fichas, novo)**,
  saude, seguranca, meio-ambiente, agregadores).
- `docs/funcionalidades/plataforma/fontes-de-dados.md` — capacidade de curadoria
  de fontes, reescrita em alto nível.
- `docs/indice.md` — nova seção 12; **numeração duplicada "## 11." corrigida**
  (Funcionalidades / Clientes → 11 e 13).
- Entradas datadas em `docs/personas/tech-lead.md` e, para a rodadas de
  pesquisa, `docs/personas/pesquisadora-educacional.md` (ver nota de curadoria
  abaixo).
- `docs/new_ideas/implementations_ideas/notas_tecnicas_74.md`.

### Decisões de projeto
1. **`não verificado` impede `[alta]`** — sem exceção. Custo real: o lote
   educação inteiro (6 fontes) ficou fora de `[alta]` por falta da licença do
   INEP. Benefício: **zero** fontes `[alta]` com campo não confirmado.
2. **Todo rebaixamento registra a regra que incide e o motivo** — senão "média"
   vira opinião. Exemplo: Ipeadata somou 18 e é `[média]` (HTTP sem TLS, sem
   paginação, licença sem SPDX).
3. **Fase 0 do plano = allowlist de endpoints + proveniência com licença.** Não
   é melhoria: a API do SUS publica microdado individual sem mitigação
   (verificado em payload 200) e um erro de URL baixaria dado sensível de menor
   para o banco de dev.
4. **Rebaixar o CKAN do Recife (ODbL) por consistência com o BCB**, mesmo
   sendo a melhor ficha do lote de mobilidade (16 pts, única granularidade
   escolar, melhor API do lote). A diferença com o **OSM** (também ODbL, já
   ingerido) está escrita na ficha: lá a obrigação já existe, aqui criaria a
   partir de zero. Ler o Recife é permitido — vale como prova de viabilidade do
   indicador; materializar sob share-alike é decisão do jurídico.
5. **Licença aberta não anula risco LGPD.** SPTRANS "Créditos Eletrônicos do
   Bilhete Único — Usuário" é **CCZero** e ainda assim é nível individual — o
   caso-limite que generaliza a allowlist da Fase 0 para *todas* as fontes.

### Achados que mudam decisões futuras
- **`apisidra.ibge.gov.br` está atrás de Cloudflare** → 403 para servidor. Usar
  a **v3 em `servicodados.ibge.gov.br`** (200 sem challenge). Não está em
  documentação do IBGE.
- **API do SUS devolve dado individual sem mitigação** em
  `/sisvan/estado-nutricional`, `/vacinacao/doses-aplicadas-pni-*` e
  `/cnes/estabelecimentos` (este último com nome de pessoa física, CNPJ,
  telefone, e-mail). Allowlist é obrigatória antes de qualquer job de saúde.
- **BCB usa ODbL share-alike** → não pode ser materializado no Postgres.
  Descartado por licença, não por mérito.
- **Portal de dados abertos do FNDE é SPA sem SSR** e o CKAN federal exige
  credencial (**401**) → pipeline R direto é inviável. Três fontes rebaixadas por
  **acesso**, não por valor.
- **Censo Escolar do INEP: 1995–2025** (confirmado). ⚠️ a URL de 2025 é
  `microdados_censo_escolar_2025_**.zip**` (underscore extra) → 404 só naquele
  ano para ETL que interpola. Usar tabela de exceções ou scraping do `href`.
- **Censo 2022 por setor censitário**: malha com atributos = **748 MB**; **vazio
  ≠ zero** (supressão de células pequenas é estado distinto).
- **MapBiomas**: fixar a URL da **Coleção** (ex.: `collection11`), não do ano.
- **Atlas do IDHM** publica ~120 indicadores municipais com dimensões SAÚDE e
  VULNERABILIDADE → abre parte da lacuna 1 sem depender do DATASUS.
- **Base dos Dados** entrega Censo Escolar 2007–2022 em BigQuery (2023/2024
  ausentes). `tesouror` traz **SICONFI** → nova dimensão fiscal no IVET.
- **Catorze itens do enunciado #123 não existem/estão mal nomeados**: `ibge7`,
  `geodesobr`, `RRPP`, `CNTramas`, `PDL Educationis`, `SIGESC`, `Novo PAC da
  CGU`; `PNCT`→**PNATE**; `GESAC`→modalidade do Wi-Fi Brasil; `PRODES/DETER`
  são do **INPE**; `SISLIC` **exige login**; FIPE na BrasilAPI fora do ar.
  Do lote de mobilidade: **"Sistema de Informações sobre Demandas de
  Transporte" não existe** (o real é a SIMU/SIMOB da ANTP, de frota/tarifa/
  semáforo, **2014**, e só publica um PDF); **SNV** é *Sistema Nacional de
  **Viação***; **CARR/matriz OD não existe** no portal do Ministério dos
  Transportes; **SENATRAN** e **NITTrans** em NXDOMAIN; **OSMnx é Python** (em
  R: `sf` + `httr2`); Google/Mapbox são proprietários (delimitação negativa).
- **Mobilidade tem 4 bases nacionais verificadas** (a leitura inicial de "não
  resolvida" estava **errada**): ANTT/MONITRIIP (par de municípios, mensal
  desde jan/2019, CC BY), ANTT SAT+acidentes+geodados (trecho viário, CC BY),
  DNIT/INDE SNV + modelagem de VMDA (domínio público), Transportes
  RENAVAM/RENAEST (município, domínio público). As **isocronas OSRM/Valhalla**
  fecham o elo com a malha censitária do IBGE sem tocar em dado de passageiro.
  **A ressalva é de granularidade, não de cobertura**: transporte escolar com
  chave de escola existe em **um só município verificado** (Recife) → o gargalo
  é **publicação, não coleta**.
- **PNCT não é malha aberta**: `/dadospnct/downloads` → **404**, VGeo é
  visualizador sem API, página com "Todos os Direitos Reservados". O caminho
  aberto real é a camada de VMDA espelhada no **INDE** (encontrada por
  metadados, não por documentação).
- **Overpass tem rate limit verificado de 2 slots simultâneos** → fila com
  repetição espaçada e persistência do bruto em disco.
- **OSRM/Valhalla públicos são servidores de demonstração, sem SLA** →
  extrair o *tileset* uma vez e **auto-hospedar** os roteadores.
- **Bilhetagem por viagem: nunca ingerir.** ANTT "Monitriip Serviço Regular —
  Viagens" (74 recursos, CC BY) expõe `cnpj`, `placa`, `imei`, `lat`, `long` por
  viagem; SPTRANS "Bilhete Único — Usuário" é **nível individual sob CCZero**.
- **Mobility Database inacessível deste host** (403, 413, NXDOMAIN) e **nenhum
  link GTFS** em SPTrans/Metrô/CPTM/SuperVia. Registrado como *não verificado
  neste host*, **não** como inexistente.

### Contexto de pipeline usado (verificado no repositório)
- `clean.dados_ibge` **já existe** e já consome **SIDRA** (PIB municipal) → as
  fontes IBGE do plano são **extensão**, não greenfield. Mesma chave
  (`codigo_ibge`, `ano`).
- `clean.ideb_notas_escolas` e `raw.inep_raw` **já existem**.
- `clean.import_metadata` tem `table_name`, `source_file`, `import_timestamp`,
  `row_count_loaded`, `notes` — **falta** `source_url`, `source_license`,
  `retrieved_at` (Fase 0).
- Convenção mantida: `raw.` → `clean.` → `analytics.`, migrations Sqitch em
  `data_pipeline/deploy/`, R em `analysis/edumapsr/R/`.

### Lacunas que o catálogo NÃO resolveu
- **Conectividade**: só o Medidor Educação Conectada mede banda por escola, e
  **não tem API nem licença publicada** (`licenca.txt` → 404), atrás de Shiny.
  Contramedida correta é **e-SIC**, não scraper.
  ⚠️ **Esta é a ÚNICA lacuna sem solução verificada em todo o catálogo.**
- **Transporte escolar com chave de escola** permanece não resolvido em escala
  nacional (ver seção de achados). A Fase 6 do plano trata isso como prova de
  viabilidade no Recife, não como cobertura nacional.

### Pendências sem issue (decisões e ações administrativas)
- **Decisão institucional sobre PeNSE** (CEP/Conep, ambiente controlado) — a
  maior fonte de saúde do catálogo e a única que exige decisão não técnica.
- **Decisão de leitura do IVET**: territorial ou escolar com contexto? Muda a
  interpretação de todos os coeficientes (P5 da pesquisadora-educacional, roda
  no repo `eduBR`).
- **Verificar handshake TLS com `download.inep.gov.br`** a partir da rede de
  deploy (falhou neste ambiente; DNS resolve para `200.130.24.15`).
- **Quatro e-SICs** — administrativos, sem código, todos rastreados em **#132**:
  INEP (licença de Censo Escolar, IDEB, ENEM, painel do PNE — desbloqueia 4
  fichas de `[alta]`), MEC/NIC.br (CSV + dicionário do Medidor Educação
  Conectada — fecha a lacuna 3), FNDE (URL + dicionário do Novo PAC/Proinfância
  e do PNATE) e secretarias municipais de educação (vagas de transporte escolar
  por unidade e turno — o gargalo da lacuna 5 é **publicação, não coleta**).

### Backlog registrado no GitHub (15 issues abertas)
Até o ciclo #123 o backlog de código e o de curadoria de acervo estavam
**desconectados**: as direções priorizadas pelo Tech Lead que não eram ingestão
de fonte não tinham issue. As #134–#139 fecham essa lacuna.

| Issue | Origem | Escopo | Prioridade |
|---|---|---|---|
| **#124** | plano de fontes | Fase 0 — allowlist de endpoints + proveniência com licença | **alta** (bloqueia todas) |
| **#125** | plano de fontes | Fase 1 — contexto municipal e sub-municipal | **alta** |
| **#126** | plano de fontes | Fase 2 — saúde (CNES + DATASUS) com sanidade de LGPD | **alta** |
| **#127** | plano de fontes | Fase 3 — eventos e exposição a risco (MapBiomas + INMET) | média |
| **#128** | plano de fontes | Fase 4 — financeiro e investimento | média |
| **#129** | plano de fontes | Fase 5 — segurança e sinistralidade viária + LGPD | **alta** |
| **#130** | plano de fontes | Fase 6 — mobilidade | **alta** |
| **#131** | plano de fontes | Overpass conforme à política de uso + viés de cobertura do OSM | **alta** |
| **#132** | plano de fontes | Os três e-SIC (administrativo, sem código) | **alta** |
| **#134** | acervo (Z:9892) | Dicionário de dados versionado do Censo Escolar | **alta** |
| **#135** | acervo (Z:10097) | Versionar datasets do pipeline com DVC | média |
| **#136** | acervo (Z:9931) | Validar convenções do repositório em git hooks | média |
| **#137** | acervo (Z:10450/10297) | Promover índices e RandomForest a produto versionado | média |
| **#138** | acervo (Z:11766) | Similaridade escolar e municipal com PgVector | baixa |
| **#139** | acervo (Z:10454/10673/10456) | Fundamentar os coeficientes do IVET na literatura | baixa |

Duas ordens obrigatórias que as dependências revelaram: **#124 antes de tudo**,
e **#134 antes de #137** (treinar modelo sobre tabela sem dicionário nem
proveniência gera coeficiente impossível de auditar). Uma fonte `[alta]` por
fase, não uma issue por fonte: o entregável é a tabela + a view analítica, e
nove issues de pipeline interdependente serializariam o trabalho sem ganho.

### Notas de ambiente
- `sqlite3` CLI **ausente** no host; usar `python3 -c "import sqlite3"` em
  read-only (já documentado em `tech-lead.md`).
- `webfetch` do IBGE (`www.ibge.gov.br`, `sidra.ibge.gov.br`) → **403
  Cloudflare**; `servicodados.ibge.gov.br` e `ftp.ibge.gov.br` abrem normalmente.
- **Subagentes de pesquisa às vezes ecoam o template vazio e emitem texto-lixo em
  CJK/cirílico.** Revisar e limpar cada arquivo antes de commitar. A varredura de
  CJK/cirílico **não basta**: nesta sessão apareceram **homóglifos
  cirílicos no lugar da palavra "sem"** (letras visualmente idênticas) e
  **uma palavra em espanhol** (*ayuda*), além de anglicismos (*turned out*,
  *incidence*, *embarrassingly*, *Depending*, *adopter*). `grep -P` de
  CJK/cirílico passa limpsinho nos dois casos. Varredura completa (confusáveis + léxicos):
  `python3` com `re.compile(r'[\u0370-\u03ff\u0400-\u04ff\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7ff\ufe30-\ufe4f\uff01-\uff60]')`
  sobre `docs/**/*.md` e `memory.md`, mais
  `grep -rniE 'embarrassingly|turned out|incidence|ayuda|Depending|adopter'`.

## Sessão 2026-09-29 — Sentry ativado com DSN real (projeto único)

O usuário criou o projeto no sentry.io e forneceu o DSN real; a integração
(feita com placeholder no PR #122) foi **ativada**. Região **us**. Decisão do
usuário: **um único DSN de projeto** usado pelo Svelte **e** pelo backend/Minion.

- **DSN** (público por design — vai embutido no bundle da SPA, mas **não
  commitado**; fica no env do deploy e no `edu_maps.conf` do host):
  `https://<key>@o4512171792662528.ingest.us.sentry.io/4512171824381952`
  (projeto **4512171824381952**, região **us**). Valor real: pedir ao usuário
  ou ler `/opt/edumaps/backend/edu_maps.conf` (host `backend.edumaps`).
- **NUNCA commitado**: ativação via env `EDUMAPS_SENTRY_DSN` exportado **antes**
  de `rex prepare` + deploys (mesmo padrão de `EDUMAPS_DB_PASS`). O Rexfile usa
  `get('sentry_dsn')` tanto no bloco `sentry` do `edu_maps.conf` (linha ~78)
  quanto no `VITE_SENTRY_DSN` do build da SPA (linha ~364). Release = SHA curto
  do git no host (`5e33c41`).
- **Ativar/re-ativar após um deploy** (senão o conf é reescrito com `dsn => ''`
  e o Sentry volta a no-op):
  ```bash
  cd backend/script/deploy
  export EDUMAPS_SENTRY_DSN='<DSN do projeto sentry.io — ver conf do host>'
  rex prepare && rex -H backend.edumaps deploy_backend_dev && \
    rex -H backend.edumaps deploy_minion_dev && rex -H backend.edumaps deploy_frontend_dev
  ```
- **Validação (29/09)**:
  - Envelope real → Sentry **HTTP 200** `{"id":...}` (formato do service Perl e
    formato browser `platform: javascript`); TLS ok no **carton do host**
    (`IO::Socket::SSL 2.081`; o perlbrew *local* não tem TLS ≥2.009 — smoke
    local só via `curl`).
  - Host: `edu_maps.conf` com `dsn` preenchido e `release => '5e33c41'`;
    `edumaps-web` e `edumaps-minion` bootam ("EduMaps inicializado…").
  - SPA: `dist/assets/index-*.js` contém `ingest.us.sentry.io` + release
    `5e33c41`; `ubatexu.lan:8080` → 200.
  - e2e visual no navegador não feito: o desktop não estava conectado à sessão
    (pendente de validação do usuário, se quiser).
- **Nota**: `EDUMAPS_SENTRY_DSN` vazio em deploy futuro = no-op silencioso
  (comportamento esperado, não é bug).

## Sessão 2026-09-29 — Observabilidade com Sentry (backend + Minion + frontend)

Integração **sentry.io cloud** (free tier) com placeholder de DSN: sem
`EDUMAPS_SENTRY_DSN`/`VITE_SENTRY_DSN` o sistema é **no-op silencioso**
(decisão: usuário ainda não tem conta/DSN; implementação não bloqueia).

- **Backend**:
  - `EduMaps::Services::Sentry` — thin client da **Envelope API** (zero deps
    CPAN): `_ingest_url` (DSN → `https://<host>/api/<project>/envelope/`),
    `_build_envelope` (3 linhas, `length` em bytes), `capture_exception`/
    `capture_message`, **envio adaptativo** (`is_running` → `post_p`
    fire-and-forget no web; `post` síncrono no fork do worker, onde o loop é
    resetado — lição do PR #121), `ua` injetável p/ teste.
  - `EduMaps::Plugin::Sentry` — registrado em `EduMaps.pm` após o Minion.
    Hooks: `after_dispatch` (≥500 → `stash->{exception}` ou msg genérica;
    nunca corpo de request) + `around 'Minion::Job::fail'` (**choke point
    único**: Minion 12 não tem evento de estado; fail explícito e óbito
    convertido por `start`/`_reap` passam por aí). Guard `$WRAPPED` anti
    re-wrap.
  - `_sanitize_args`: descarta 11+ dígitos (CPF/CNPJ), chaves sensíveis
    (`salario|senha|token|cpf|...`), valores > 200 chars; máx. 10.
- **Frontend**: `@sentry/svelte` + `@sentry/browser` 9.47.2 (npm install no
  container); `src/shared/sentry.js` com **import dinâmico** (sem DSN nada é
  carregado — vitest/MSW intactos), `sendDefaultPii: false`, `beforeSend`
  redige em qualquer profundidade; `client.js` emite `EVENTS.API_ERROR`
  (≥ 500) no eventBus; `main.js` bootstrap assíncrono com `onerror` no mount.
- **Deploy**: `Rexfile` (`sentry_dsn`/`sentry_release`, release = SHA curto
  local), `files/edumaps_db.conf` + `docker-entrypoint.sh` (bloco `sentry`),
  `deploy_frontend_dev` passa `VITE_*` no build; `docker-compose.yml`
  (`EDUMAPS_SENTRY_DSN`/`_RELEASE` no backend e minion).
- **Testes**: `t/sentry_service.t` (parse DSN, envelope, utf-8/length, no-op,
  sanitização, Mojo::Exception com frames) e `t/sentry_plugin.t` (5xx via
  Test::Mojo, 5xx explícito, wrap de `Minion::Job::fail` com FakeBackend/
  FakeMinion — sem DB, e no-DSN no-op). Frontend: `sentry.test.js` +
  `client.test.js` (ponte `api:error`) — **393 testes verdes**.
- **Decisão de teste**: `Test2::V0` **não exporta `is_deeply`** — usar `is`.
- **Pendência** → **resolvida** na sessão acima (DSN real ativado nos hosts);
  traces/replay = fase 2 (`tracesSampleRate: 0`).

## Sessão 2026-09-29 — POIs OSM no Painel do Gestor (PRs #118/#119/#120)

Botão "Equipamentos no entorno (OSM)" no painel do gestor: busca (assíncrona)
os equipamentos públicos num buffer ao redor da escola, com catálogos
(perfis) multi-seleção e raio 100–10000 m.

- **DB — migração `school_osm_query`** (`clean.school_osm_query`): por
  `(co_entidade, nu_ano_censo)` guarda `raio`, `profiles JSONB`, `digest`
  (FK `clean.osm_query`) e `updated_at`. Base do upsert, do aviso de recência
  e do status. Result class `EduMaps::Schema::Result::SchoolOsmQuery`.
- **Backend**:
  - `Task::OSM` — task `query_osm_school` com role `+Progress` (encaminha o
    `progress` do `Model::OSM`/`Services::OSM` para as notes do job → SSE);
    valida raio 100..10000 e catálogos (`Services::OSM::Query->valid_profile`);
    helper `get_osm_school` enfileira com `notes => { co_entidade => … }` e
    `queue => $app->config->{osm_queue} // 'default'`.
  - `Model::OSM` — `current_selection`/`record_selection`/`school_pois_summary`
    (resumo por categoria) + emissão de `progress`; `osm_for_school` grava a
    seleção (upsert) no fim.
  - `Controller::Gestor` — `osm_pois_request` (validação, **idempotência**:
    reusa job pendente da escola → mesmo `job_id`; 202 + `Location`) e
    `osm_pois_status` (seleção + resumo + `job_id`); rotas autenticadas
    `POST/GET /api/gestor/:cod_inep/osm/pois` em `Plugin::API::Gestor`.
  - **Achados do Minion** (nesta versão): `minion->jobs(...)` devolve
    `Minion::Iterator` (sem `first`); `->next` devolve o **hashref** do job
    (não objeto); o filtro `notes => [...]` casa por **chave**, não valor
    (por isso o dedup itera e compara `notes->{co_entidade}`); `fail` grava em
    `result` (não há coluna `error` separada).
  - `Services::OSM` — modo offline carrega a fixture **sincronamente** no
    `run` (um `die` dentro do `async run_p` virava promise rejeitada não
    tratada, sem propagar); `Task::OSM::Service::run_query` passa a usar
    `$svc->run`.
  - Teste `t/04-api/gestor/osm_pois.t` (7 subtests): 401/403, 202, validações,
    idempotência, GET status e task offline (progresso/finish/fail). Usa fila
    dedicada `osm_test` (`$t->app->config->{osm_queue}`) + `perform_jobs({
    queues => ['osm_test'] })` para não disputar com o worker do compose; os
    casos offline forçam `refresh => 1` (evita cache de runs anteriores).
- **Frontend**:
  - Seção `OsmPoisPanel.svelte`: catálogos (checkboxes; "Todos" é exclusivo),
    slider de raio, botão, **barra de progresso** (SSE), **confirmação quando
    os dados têm < 7 dias**, **trava quando há job pendente** (anexa ao
    `job_id` do status), erro imediato e resumo por categoria.
  - `shared/api/taskProgress.js` — `watchJobProgress`/`getJobProgress`
    extraídos de `schools/api/schoolApi.js` (que os re-exporta).
  - Eventos `gestor/osm-pois-{start,progress,done,error}` no EventBus
    (`constants/osm.js`); mocks MSW (`gestor/mocks/osmHandlers.js`).
  - **Bug pego na validação visual**: o `GestorPanelPage` é público e não
    chamava `restaurarSessao()`; o token não ia no `apiClient` → **401**. O
    componente passou a restaurar a sessão no mount (PR #119).
- **Mapa dos POIs (PR #120)**:
  - `GET /osm/pois` agora devolve `escola` (nome/lat/lon de `censo_escolas`) e
    `geojson` (FeatureCollection com **centroide** `ST_PointOnSurface`, + 
    `category`, `nome` da tag `name` e `distance_m`, ordenado por distância).
  - `Model::OSM`: `school_location` e `school_pois_geojson` (via `_dbh`);
    `_load_school` passou a selecionar `no_entidade`.
  - Frontend: `OsmPoisMap.svelte` (marcador da escola, círculo do buffer,
    pontos coloridos por categoria, popup com nome) e o resumo virou
    **legenda com toggle** (`hidden` no `OsmPoisPanel`). Categorias em **PT**
    via `categoryLabel` (`constants/osm.js`).
  - **Bug de efeito**: `OsmPoisMap` lia e escrevia o mesmo `$state`
    (`tick += 1`) → `effect_update_depth_exceeded`. Agora `layersByCategory`
    é `$state` escrito pelo efeito de desenho e lido pelo de visibilidade
    (escrever ≠ ler no mesmo efeito).
  - **Topologia**: `ubatexu.lan` = 192.168.0.42 (LXC `backend.edumaps`), e a
    validação visual usa o deploy LXC (`database.edumaps`). O compose local
    (`192.168.0.13:8080`) usa o Postgres Docker próprio (`DB_HOST=db`),
    separado — não confundir. Dados de teste da escola 35246177 ficam no
    `edumaps_dev` do LXC.
- **Validação**: backend verde e estável; frontend **384 testes** (72
  arquivos); deploy (`deploy_db_dev` + `deploy_backend_dev` +
  `deploy_minion_dev` + `deploy_frontend_dev`) e compose local rebuildado
  (o build local exigiu `docker builder prune -af` — disco a 100%); validação
  visual PASS (resumo, mapa, categorias PT e correções). PRs #118/#119/#120
  mergeados.
- **Doc funcional**: nova capacidade `docs/funcionalidades/gestor/equipamentos-entorno.md`
  (+ índice e `fontes-de-dados` com OpenStreetMap).
- **Fixes do teste no Docker local (PR #121)**:
  - **`docker-compose.yml`**: o `ENTRYPOINT` da imagem é o próprio
    `docker-entrypoint.sh`; o `command` passava o caminho de novo → `$1` virava
    o script → o container `minion` subia o **morbo (web)** e não consumia
    jobs. Agora `command: ["minion"]` (roda `minion worker`). Infra Docker local
    → branch/PR, sem deploy Rex.
  - **Falha silenciosa do OSM**: o Overpass devolvia 504 e o job "concluía" com
    `related: 0` e `raw_results: null` (sem erro). Causa: `die` dentro de
    `async sub` vira promise rejeitada **não tratada**, e
    **`Mojo::Promise::wait` engole a rejeição** (e ainda retorna cedo se o
    IOLoop já está rodando — caso do worker). Correção: `Services::OSM::_request`
    usa **Mojo::UserAgent síncrono** (padrão do `EduMaps::Analytics::Client`,
    usado em tasks); `run` é síncrono e o erro propaga (`die`) → job falha com a
    mensagem. `run_p` virou wrapper de promise; `related` saiu numérico
    (`0 + ($n // 0)`). Testes em `t/osm_service_errors.t`.
  - Lição: em task Minion, **não** use `->wait`/`async sub` para HTTP; use o UA
    síncrono (ou awaits com tratamento explícito). Verificado no compose:
    504 → job `failed` com o erro; retry OK → `finished` com `related: 1`.

## Sessão 2026-09-29 — Módulos OSM generalizados (Services/Model)

Generalização do OSM (antes só `Task::OSM` municipality+landuse+way):

- **Migração `osm_generalize`**: `clean.osm_feature` (node/way/relation, PK
  `(osm_type, osm_id)`), `osm_query_feature` (proveniência), `school_osm_feature`
  (buffer escola, com `raio`/`distance_m`) e `municipio_osm_feature`; migra o
  legado `osm_landuse` (way) para `osm_feature`. Result classes + resultset.
- **`EduMaps::Services::OSM::Query`**: descreve a consulta (alvo `around`
  raio 100–10000 m ou `poly`), filtros e **catálogo de perfis** de
  equipamentos públicos (transporte/saúde/educação/assistência/cultura-lazer/
  segurança/administração; default `equipamentos_publicos`); gera o Overpass
  QL e `digest`.
- **`EduMaps::Services::OSM`**: cliente Overpass + parser genérico
  nwr→GeoJSON (Point/LineString/Polygon/MultiPolygon); modo offline/fixture;
  eventos (query/query_data/feature/progress).
- **`EduMaps::Model::OSM`**: cache (digest + `cache_ttl_days`, default 30) e
  relações — `osm_for_school` (buffer em `censo_escolas`) e
  `osm_for_municipio` (`municipios_sp`, nacional apesar do nome); valida por
  `ST_DWithin`/`ST_Within`; leituras `school_features`/`municipio_features`.
- **Wrappers**: `Task::OSM::Service` delega ao `Services::OSM` (QL/API legados
  preservados; `t/osm_service.t` segue verde); `Task::OSM` ganha a task
  `query_osm_school` + helper `get_osm_school`.
- **Testes**: offline (`t/osm_query_builder.t`, `t/osm_service_offline.t`,
  `t/osm_model_offline.t` com banco em rollback), online opt-in
  (`t/osm_service_online.t`, `OSM_ONLINE=1`). Fixture `t/fixtures/osm/mixed.json`.
  Obs.: o `ubaxala` não tem TLS no perlbrew (IO::Socket::SSL) → teste online
  só roda no LXC.

## Sessão 2026-09-29 — Legendas e caixa "(?)" no Perfil (PR #116)

Cada tabela/gráfico do Perfil da Escola (e do Perfil da Rede) passou a exibir
uma **legenda** e um botão **"(?)"** com a proveniência/cálculo do dado.

- Componente compartilhado `src/shared/ui/components/InfoHint.svelte`
  (popover acessível; Enter/Espaço abre, Escape/clique-fora fecha), exportado em
  `src/shared/ui/index.js`.
- Aplicado em: Sinais de atenção, Posição relativa, Evolução, Distribuição no
  cluster e Escolas similares; e no Perfil da Rede (Rede vs. Brasil,
  Distribuição por cluster).
- Frontend 375 testes / 70 arquivos. Deploy `ubatexu.lan` (bundle
  `index-Ch1QyaWl.js`) + rebuild do compose local. Validação visual PASS.

## Sessão 2026-09-29 — Container analítico no Docker (PR #115)

O compose local não tinha o serviço analítico, então o backend caía em 503 nas
rotas do perfil/evolução/rede. Entregue:

- **`analysis/edumapsr/Dockerfile`** + **`docker/entrypoint.sh`**: imagem R
  (rocker, binários do PPM) com o `edumapsr` instalado; entrypoint gera o
  `/root/.pg_service.conf` (edumaps/edumaps_local/edumaps_leitor), fixa
  TZ/locale e `EDUMAPS_R_PORT=8000`, e habilita LOGIN+senha da role leitora
  (espelha o `deploy_db_dev`). `.dockerignore` exclui `.Rcheck`/`.tar.gz`.
- **`docker-compose.yml`**: serviço `analytic` (`:8000`, depends_on db healthy);
  `ANALYTICS_URL=http://analytic:8000` no backend e no minion.
- **`frontend/nginx.conf`**: proxy `/analytic-api/` habilitado → `analytic:8000`.
- **Fix R** (achado ao subir o container): `.school_indicators_has_cluster_id()`
  — o `network_profile` consultava `school_indicators.cluster_id` sem checar a
  coluna (criada dinamicamente pelo job de clustering); em banco sem
  clusterização agora degrada para um grupo "Sem cluster". O perfil da escola
  reusa o mesmo check. (No `ubaxala`, o DB `edumaps_dev` não tem a coluna.)

**Validado no compose local**: `analytic /health` 200, `/analytic-api/health`
(via nginx) 200, `/api/school/:cod/profile` 200, `/evolution` 200,
`/network/:ibge/profile` 200. Testes R: 440 (falha pré-existente de
`test-cluster.R`). Fix R também deployado no `analytic.edumaps` (rex).

## Sessão 2026-09-29 — Roadmap do #105 (itens A/B/C; PRs #112/#113/#114)

Continuidade do Perfil da Escola. Três itens do roadmap do #105, cada um em
branch/PR próprio (por decisão do usuário), com issue aberto antes:
**A=#110** (evolução), **B=#109** (perfil da rede), **C=#111** (perfil no
/ask).

**A — `school_evolution` (PR #112)**
- `analyze_school_evolution()` + `school_evolution_model` + DataSource sobre
  `clean.ideb_notas_escolas` (IDEB por etapa) e
  `clean.inep_notas_desagregadas` (SAEB por ano); `POST /school_evolution`
  (400/500); registry com `model_class`; facades.
- Backend: `GET /api/school/:cod_inep/evolution`.
- Frontend: seção "Evolução" no `/escola/perfil` (série por indicador/etapa,
  barras por ano, variação); carregada em paralelo ao perfil.

**B — `/network_profile` (PR #113)**
- `analyze_network_profile()` + `network_profile_model` + DataSource que
  agrega as escolas ativas do município (opcional por `tp_dependencia`) por
  cluster e compara a rede vs. Brasil (reusa
  `analytics.school_profile_reference` do #107); `POST /network_profile`.
- Backend: `GET /api/network/:codigo_ibge/profile`.
- Frontend: página `/municipio/perfil?ibge=…` ("Rede vs. Brasil" +
  "Distribuição por cluster").

**C — perfil no `/ask` (PR #114)**
- View achatada `analytics.school_profile_flat` (self-provisioning a partir do
  JSONB de `analytics.school_profile`), com `GRANT SELECT` para a role
  `edumaps_leitor`; entradas no `inst/chat/dicionario.yml` (whitelist, colunas,
  conexão, termos) e regra no system prompt.
- Validação: `POST /ask` respondeu coerente consultando a view (mestrado/sem
  especialização em atenção; licenciatura vs. município; IDEB etc.).

**Testes**: R 440 passam (falha de `test-cluster.R:154` pré-existente);
backend `t/04-api/school/evolution.t` e `t/04-api/network/profile.t`; frontend
369.

**Deslize de processo (corrigido)**: o commit do item C foi feito direto na
`main` local por engano; o push falhou (branch inexistente) e o commit foi
movido para `feat/analytics-ask-profile`, com a `main` resetada para
`origin/main` antes de qualquer push. A regra branch→PR→merge foi respeitada.

**Pendências**
- Documentar os endpoints batch (`/school_profile/reference|cluster|batch`) e os
  novos (`/school_evolution`, `/network_profile`) também no `api.json`? (os dois
  últimos já têm schemas; só os batch do #107 ficaram sem).
- `docs/indice.md` (Tech Lead) segue sem passada recente.

## Sessão 2026-09-28/29 — Perfil da Escola Fase 2 (issue #107, PR #108)

Segunda fase do painel do gestor: separa **cálculo** de **leitura**. Issue
#107 (derivada do #105), PR #108 mergeado em `main` (`fe8ce76`).

**Entregue**
- R: `analytics.school_profile_reference` (50.184 linhas; médias
  Brasil/rede/município por ano) e `analytics.school_cluster_profile`
  (p25/p50/p75 por cluster); `compute_and_save_school_profile_reference/
  cluster_profile/profiles`; DataSource lê o pré-computado
  (`prefer_reference`) com fallback live; `/school_profile` virou
  **read-through** (`metadata.cached`/`computed_at`, `refresh=true`);
  endpoints `/school_profile/reference|cluster|batch`.
- Backend: `Task::SchoolProfile` (Minion, fila `analytics`, modos
  reference/cluster/profiles), `POST /api/task/school_profile`, métodos no
  `Analytics::Client`.
- Agendamento: systemd service+timer diário (03:20) chamando o script
  `backend/script/tasks/school_profile_refresh.sh` (instalado no
  `deploy_backend_dev`).
- Frontend: linha "Perfil atualizado em … · cluster <run>".

**Desempenho**: read-through warm **~0,1–0,4s** (antes ~2–3,4s); cold ~1s.
O gargalo era a agregação nacional por request; agora é materializada.

**Bugs corrigidos no caminho**
- `scale()`/`daisy` devolviam NaN com indicadores constantes (escolas
  pequenas) → batch falhava; fix remove features sem variância.
- `/api/task/school_profile` não lia o corpo JSON (Mojolicious não mescla
  JSON nos params) → `limit`/`mode` do timer eram ignorados; normalizado
  como em `request_cluster`.
- Serialização: o round-trip do payload no cache perdia os marcadores
  `unbox`; o handler fixa `serializer_json(auto_unbox=TRUE)`.

**Nuance**: o UPSERT em lote não pode usar `unnest` com bind vetorial no
RPostgres (parâmetro escalar) → usa tabela temporária (`dbWriteTable`) +
`INSERT ... SELECT`.

**Testes**: R 372 (falha de `test-cluster.R:154` pré-existente); backend
`t/04-api/task.t` (25); frontend 355.

**Pendências**
- Documentar os endpoints batch no `api.json` (hoje só o `/school_profile`).
- Disparo event-driven após a clusterização (hoje só o timer diário).
- Itens 2–4 do roadmap do #105 (`school_evolution`, `/network_profile`,
  `/ask` sobre o perfil) seguem como issues futuros.

## Sessão 2026-09-28 — Perfil da Escola (issue #105, PR #106)

Painel analítico do gestor entregue de ponta a ponta: **R → backend Perl →
frontend SPA**. Issue #105 (`refs #105`), PR #106 mergeado em `main`
(`bca9e66`).

**Decisões do usuário** (questionário): escopo = R + backend + frontend
(a SPA fala só `/api/*`); painel em rota nova `/escola/perfil`; cluster de
fallback **restrito ao município**. Peers: `analytics.similarity_pairs` ou,
na ausência, Gower no município.

**Entregue**
- R: `analyze_school_profile()`, `school_profile_model`, DataSource Postgres
  (`$1`/`$2`), `POST /school_profile`, repository UPSERT em
  `analytics.school_profile`, `api.json`. `analysis_registry` ganhou
  `model_class`.
- Backend: `Analytics::Client#run_school_profile`, rota
  `GET /api/school/:cod_inep/profile` (400/404/503; mensagem higienizada).
- SPA: `/escola/perfil` + componentes, transform, mocks MSW, testes; links no
  `SchoolPanel` e `GestorPanel`. Doc funcional `analise/perfil-escola.md`.

**Testes**: R 348 passam (falha de `test-cluster.R:154` é pré-existente —
confirmado no `main`); `R CMD check` só com o ERROR conhecido de
`Author`/`Maintainer`; backend `t/04-api/school/profile.t` (5); frontend 353
testes.

**Desempenho** (host analítico de dev): escola típica sem cluster persistido
~1,7–2,4s; com cluster persistido ~3,4s. Otimizações aplicadas: ano do censo
resolvido uma vez (PK de `censo_matriculas`), IDEB via `DISTINCT ON` no ano
mais recente (tirou a LATERAL de 180k probes), frame municipal filtrado por
`co_municipio`, `co_entidade` dos peers como text.

**Nuances de dados descobertas** (dev): `clean.school_indicators` tem 214.192
linhas mas só **2.821 com `cluster_id`** e **27 com `cluster_label`** — o
fallback kmeans é o caminho comum. `analytics.similarity_pairs` **não existe**
no dev (peers caem no Gower municipal). `analytics.ranking_escola` e
`clustering_metadata` vazios.

**Deploy**: `rex prepare` + `deploy_analytics_dev` + `deploy_backend_dev` +
`deploy_frontend_dev`. Bundle servido em `ubatexu.lan:8080`
(`index-DAS1-W4A.js`).

**Pendências / próximos passos**
- `<2s` pleno para cluster persistido exige **pré-computar** os percentis do
  cluster e as médias de referência (Brasil/rede) — citado nos "próximos
  passos" do #105.
- Escopo ampliado vs. o checklist do #105 (proibia `backend/`/`frontend/`):
  o texto do issue pode ser atualizado.
- `docs/indice.md` (Tech Lead) não foi revisitado nesta passada.

> ## ▶ RETOMADA — ponto de partida (2026-09-27, atualizado)
>
> **PRs do histórico de conversas MERGEADOS em `main` (2026-09-28)**: #100
> (`fix/chat-meta-jsonb`, `meta` como objeto + POST 400) e #101
> (`fix/chat-historico-e2e`, 10 bugs achados na e2e). O bloco "Ambiente" e a
> sessão "Verificação do histórico de conversas" abaixo descrevem o estado
> **antes** desses merges — as pendências que eles resolveram já não valem.
>
> Ambiente **refeito e validado**: perlbrew restaurado, banco em Docker
> (PG16 + PostGIS 3.5 + pgvector 0.8.6) com as **58 migrations aplicadas**
> (exit 0) e a suíte de backend rodando (**345 testes, 57 arquivos**).
> O commit `9fd4a0e` foi **verificado**: 1 das 6 pendências foi corrigida
> (o `meta` jsonb), as outras 5 seguem abertas. Ver bloco "Ambiente" e a
> sessão "Verificação do histórico de conversas" abaixo.
> Notas técnicas do ciclo: `notas_tecnicas_64.md` (meta/`POST 400`) e
> `notas_tecnicas_65.md` (os 10 bugs da e2e + ambiente local com Docker).
>
> **O que ainda trava o ambiente**: `ubatexu.lan` e `backend.edumaps`
> continuam **fora do ar**, então o **deploy (Rex) segue impossível** e o hook
> de auto-deploy continua desativado. Testes de frontend também dependem do
> container `backend.edumaps`.
>
> Ao voltar, ler nesta ordem:
>
> 1. **Bloco "Ambiente"** logo abaixo — o que foi resolvido e o que falta.
> 2. **Bloco "Pendências do histórico de conversas"** — 5 itens do commit
>    `9fd4a0e` ainda **não verificados**.
> 3. Reativar o hook: `mv .git/hooks/post-commit.sample .git/hooks/post-commit`
>    (só depois de corrigir a linha 32 — ver bloco "Ambiente").
>
> **Backlog no GitHub**: issue **#1** (GH Actions) aberta por decisão do
> usuário; PR **#76** (docs de clientes) aberto, **110 commits atrás** e com
> conflito em `memory.md` — resolver com rebase quando der.

> **Convenções duráveis (valem para toda sessão)**:
> - **Onde rodar os testes depende da máquina** (2026-09-28, por indicação do
>   usuário):
>   - **No host `ubaxala`** (a máquina local, `127.0.1.1` — onde a sessão está
>     rodando) o ambiente de teste é **preferencialmente Docker**. Subir o que
>     for preciso com `docker compose`/`docker run` e rodar ali, em vez de
>     depender dos containers LXC. Vale para o Postgres (`docker-compose.yml`,
>     publicado no loopback), para o build e o `vitest` do frontend
>     (`node:22-slim` com o repositório montado) e para o e2e (SPA em build de
>     produção servido por nginx, Chrome via CDP). O `docker` precisa de
>     `sg docker -c '...'` — o `sudo` pediria senha.
>   - **Nos demais hosts** (`backend.edumaps`, `database.edumaps`,
>     `analytic.edumaps`) é **exclusivamente o deploy em `ubatexu.lan`**
>     (`192.168.0.42`): `rex prepare` + a task da área, e os testes de frontend
>     por `ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npm run
>     test:run'`. Nada de ambiente local aí.
>   Ou seja: **Docker é o padrão no `ubaxala`; o deploy é o padrão no resto.**
> - **Testes de frontend** (`vitest` / `npm run test:run`): ver a regra acima
>   sobre onde rodar. Em `ubaxala`, dentro do container:
>   `docker run --rm -v "$PWD/frontend/edumaps:/src" -w /src node:22-slim sh -c
>   "npm ci --no-audit --no-fund && npx vitest run"`. Não há `node` no host —
>   o build da SPA também vai no container.
> - **Testes de backend**: mesma regra por máquina. No `ubaxala`, o backend roda
>   no **perlbrew do host** apontando para o Postgres do Docker, e o
>   `env -u PERL5LIB` é **obrigatório** — o `PERL5LIB` do shell tem caminhos de
>   uma máquina antiga e o `prove` aborta antes de rodar qualquer teste:
>   `cd backend && env -u PERL5LIB EDUMAPS_DB_HOST=127.0.0.1 EDUMAPS_DB_PORT=5432 prove -r -l t/04-api/`.
>   Sempre com `-l`, sempre de `backend/`.
> - **Falha pré-existente conhecida** (não é regressão): `t/04-api/municipio.t`
>   subteste 8 (OSM features sem dados carregados) e
>   `t/04-api/network/schools.t` subteste 3 (dois subtestes com expectativas
>   contraditórias). Antes de atribuir uma falha a si mesmo, rodar o arquivo sem
>   a mudança, em `git stash`.
> - **Componente com LeafletMap em teste (jsdom)**: NUNCA instanciar o
>   `LeafletMap` real — usar o stub `features/<feature>/components/__tests__/LeafletMapStub.svelte`
>   (importa o `provideMapContext` real de `features/map/context.js` e injeta
>   `{map:null, ready:false}`, assim os filhos como `SimilarMarkers` não tocam
>   Leaflet). Padrão em `SimilarSchoolsSearch.test.js`.
> - **`curl` no container via nginx**: o fallback SPA depende do `server_name`;
>   `curl http://localhost/...` (Host localhost) devolve 404 mesmo para rotas
>   válidas. Usar `-H "Host: ubatexu.lan"`.
> - **Constraints de rota no Mojolicious**: passar hashref depois do path
>   (`$r->get('/:x' => {x => qr/\d+/})`) vira **defaults**, não constraint — a
>   rota casa qualquer valor. Use **arrayref**: `$r->get('/:x' => [x => qr/\d+/])`.
> - **Validação (Mojolicious::Validator)**: `$v->error($campo)` devolve
>   `[$check, $result, @args]`; `->[0]` é o **nome do check** (`like`, `size`…),
>   não mensagem. Mapear para texto legível antes de renderizar.
> - **Dois bancos em dev**: o backend em container usa `Database` (LXC, user
>   `edumaps`/`change_me`, `ssh root@database.edumaps`); os testes locais (`t/`)
>   usam `ubatexu.lan` (user `devel`/`senhaboa123`). Migrações manuais precisam
>   ser aplicadas nos **dois**. No `ubaxala` há ainda um **terceiro**, o Postgres
>   do `docker-compose.yml` (PostGIS 3 + pgvector, `127.0.0.1:5432`), que é o
>   preferencial para teste local — apontar o backend para ele com
>   `EDUMAPS_DB_HOST=127.0.0.1 EDUMAPS_DB_PORT=5432`. `num` do Validator só
>   aceita inteiro — decimais exigem `like(qr/\d+(?:[.,]\d+)?/)` + normalizar
>   vírgula.
> - **`$_[0]` em `map` dentro de sub com `-signatures`**: lê o `@_` da sub, não o
>   `$_` da lista. Usar `$_->[0]` (ex.: `map { $_->[0] + 0 } @$rows`).
> - **Código de município NÃO é o prefixo do `cod_inep`**: usar a fonte oficial
>   (`clean.censo_escolas.co_municipio` 7→6 dígitos; fallback nome+UF em
>   `raw.br_municipios_2024`).
> - **Coluna `jsonb` no DBIC deste projeto**: o DBIx::Class 0.0828 **não tem
>   inflator json/jsonb** (só DateTime/File) e `is_json` não existe — sem
>   tratamento, `$obj->coluna_jsonb` sai como **string**, e uma API que
>   `render(json => ...)` devolve string onde o frontend espera objeto (falha
>   silenciosa: some o metadado, sem erro). Usar `inflate_column` com
>   `inflate` **e** `deflate` (sem o deflate o DBIC estoura *"No deflator
>   found"* toda vez que a coluna recebe uma ref):
>   `use Mojo::Base 'DBIx::Class::Core', 'DBIx::Class::InflateColumn', -signatures;`
>   (via `load_components` o C3 resolve o nome do componente **relativo** ao
>   pacote da classe e quebra). Ver `Schema/Result/ChatMensagem.pm`.
> - **Validação de jsonb na entrada**: um `meta` que não é objeto (texto
>   solto, array, número) não tem tradução para jsonb — o Postgres recusa com
>   `invalid input syntax for type json` e a requisição estoura em **500 com a
>   página de erro HTML**. Validar no controller e devolver **400**.
> - **Teste que pega "a conversa mais recente"**: se outro subtest faz POST no
>   mesmo recurso, a ordenação (`created_at DESC`) passa a devolver outro
>   registro e o teste mede a coisa errada. Usar o **id devolvido no POST**.
> - **Content-type de xlsx não contém "excel"**: é
>   `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` — validar
>   por `excel|spreadsheetml|officedocument|octet-stream`.
> - **Contagem "distinta" no painel financeiro**: `remuneracao_municipal` tem uma
>   linha por servidor **por competência**; a competência mais recente pode ter
>   poucos servidores. Para "quantos profissionais a escola tem", usar
>   `COUNT(DISTINCT cpf)` no total — não o número da última competência.
> - **SIOPE nem sempre detalha por escola**: em ~3819 municípios a folha vem
>   agregada sob `cod_inep=99999999` (`"SEC MUN DE EDUC ..."`). Para achar a folha
>   de uma escola, tentar `cod_inep`; se vazio, cair para `cod_municipio`
>   (agregado da Secretaria) e sinalizar a origem. **Ao exibir o agregado, escopar
>   como "rede municipal"** (nunca como se fosse da unidade) e não oferecer a
>   folha detalhada por nomes.

> **Pendências / correções futuras (backlog técnico)**:
> - _(vazio no momento — os 3 itens anteriores foram resolvidos no PR #79,
>   2026-09-20: `info_enrollment` somava turno como deficiência; timestamps
>   `null` no upsert de gestor; `?inep=abc` devolvia 400 em vez de 404.)_
> - **Upload multipart em testes (vitest+MSW+jsdom)**: o `File` do jsdom, ao
>   cruzar para o `fetch` do undici interceptado pelo MSW, perde o nome e vira
>   `filename="blob"` (a extensão falha a validação). Convenção do repo: anexar
>   um campo extra `_original_nome=file.name` no FormData e o handler MSW ler
>   `form.get("_original_nome")` como nome (ver `uploadAnexo` de reunioes/inventario).
> - _(Correções latentes "Alta" concluídas em 2026-09-24, PRs #96/#97 — ver
>   sessão "Correções latentes (backlog Alta)" abaixo.)_

## Sessão — Bug dos mapas sem tiles: troca CARTO → OSM (2026-09-28)

**Relato do usuário**: "mapas leaflet renderizado no frontend estão todos
sem os tiles, com uma tarja para definir a chave API (API key)" — ocorre
na URL padrão (`http://ubatexu.lan:8080/gestor/painel?inep=...`, ex. escolas
similares) e no localhost. O usuário apontou que a direção certa era
"**saber do leaflet o que pode evitar o carto na URL**" e que "**o correto é
usar o OSM**".

**Causa**: o tile layer usava o CDN `basemaps.cartocdn.com` (`light_all`),
que exige chave/API em algumas condições → tarja "defina sua API key".
**Fix (código)**:

- `frontend/edumaps/src/features/map/components/LeafletMap.svelte` —
  `tileUrl` default CARTO → `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`
  e attribution `© OpenStreetMap contributors`. Nenhum caller passa
  `tileUrl` custom (SimilarSchoolsSearch, SchoolMap, NetworkSchoolMap,
  ClusterSchoolMap usam todos o default) — a troca única corrige todos os
  mapas.
- `frontend/map_app/src/lib/AnalBaseMap.svelte` (legado) — mesma troca
  (usava CARTO `light_all` + subdomains `abcd`; agora OSM + `abc`).
- `frontend/edumaps/frontend.md` — doc atualizada (contexo Leaflet).

**Validação**:
- Unit tests frontend (docker `node:22-slim`): 26 arquivos / 138 testes ✅.
- Deploy: `rex prepare` + `rex -H backend.edumaps deploy_frontend_dev` ✅
  (build + nginx restarted). Bundle novo servido: `index-CWm3qagX.js`.
- Bundle novo: `cartocdn: 0`; única `tileUrl` = OSM.
- E2e Chrome CDP `:9333` (alvo `ubatexu.lan:8080`, fluxo escolas similares):
  15/15 tiles OSM, hosts `a/b/c.tile.openstreetmap.org`, 17 respostas
  **200 `image/png`**, 0 falhas, `keyTexts: []`, `tileErrorCls: false`.
- Rodada e2e registrada em `docs/e2e/cobertura.md`.

**Estado**: `main` em `529db60`, working tree limpo ao final do
ciclo; commit do fix segue via PR + merge. Chrome CDP reiniciado em
`:9333` (profile `/tmp/edumaps-cdp2`) durante a validação.

**PR #104 mergeado em `main`** (`dfcdd2b`). Nota técnica:
`docs/new_ideas/implementations_ideas/notas_tecnicas_68.md`.

**Notificações de ciclo (`tools/notify`, commit `54bc13a`)**: implementado
push para o developer via Telegram (Bot API grátis) + reforço em bloqueios
comentando no PR/issue via `gh` (GitHub mobile). Triggers no `AGENTS.md`
passo 9 (stage/blocked/done). **Pendência**: usuário ainda **não tem bot do
Telegram configurado** — setup em `tools/notify/README.md` (@BotFather →
token → chat_id → `.env`). Enquanto isso o `notify.sh` degrada calado.
**STATUS 2026-09-28 (após): ativado** — usuário preencheu
`tools/notify/.env` (token + chat_id) e o push real validado
(`notify.sh --event stage` → Telegram `ok:true`). Sem pendência.

## Sessão — Compose completo no ubaxala + regra de rebuild pós-merge (2026-09-28)
- **Regra nova (usuário)**: sempre que houver **merge em `main`**, rebuildar os
  containers Docker locais (`docker compose up -d --build`). **Só no `ubaxala`**;
  demais hosts (`backend.edumaps`, `database.edumaps`, `analytic.edumaps`) usam
  Rex, regra não se aplica. Gravada em `memory.md` (commit `1557410`).
- **Regra nova (usuário, `AGENTS.md` passo 6)**: **toda `feat`/`fix` entra via
  branch → PR → merge**; push direto em `main` só p/ mudanças de documentação.
  Vale também p/ infra Docker local (compose). Registrada no `AGENTS.md`
  (2026-09-28) após os commits diretos `5ea2100`/`3a86822`.
- **Revisão do deploy**: banco do compose (`edumaps_dev` @127.0.0.1:5432)
  **populado** (clean.escolas=158.182, todas c/ geometria; censo/ideb/inep OK;
  58/58 migrations sqitch). O `public` está vazio **por design** (dados em
  `clean.*`/`analytics.*`) — não é banco vazio. O "vazio" na UI era o
  **backend ausente** na cadeia (na :8080 respondia o nginx e2e com proxy para
  `host.docker.internal:3000`, e nada rodava em :3000 → HTTP 502 na API).
- **Compose buildado e de pé no ubaxala** (commit `5ea2100`):
  `db` (healthy) + `sqitch` (deploy ok) + `backend` (:3000) + `minion`.
  Build: `docker compose build backend frontend minion` (imagens novas).
  Fix: serviço `minion` não injetava `DB_NAME/DB_USER/DB_PASS` — o entrypoint
  gera o `edu_maps.conf` a partir delas; missing → `fe_sendauth` ao conectar.
  Credenciais adicionadas ao serviço (`docker-compose.yml`).
- **Backend validado**: `GET /api/school/25058533/info` → 200 c/ dados (ESC MUL
  JANUARIO GONCALVES DA SILVA, PB); `/api/school/search?q=Soledade` → 200 54KB;
  proxy `:8080/api/*` → 200. Mapa carrega os 158k pontos.
- **Atenção**: o serviço `frontend` do compose ainda builda o **`map_app`
  legado** (não a SPA `frontend/edumaps`) — o compose está desatualizado nesse
  ponto; a SPA atual é servida pelo nginx e2e (:8080). Pendência: alinhar
  `frontend/Dockerfile` + nginx p/ a SPA atual se o compose for o alvo.
- **RESOLVIDO (commit `3a86822`)**: `frontend/Dockerfile` agora builda a SPA
  `edumaps` (npm ci + vite build, espelhando o `deploy_frontend_dev` do Rex);
  `frontend/nginx.conf` replicou o nginx real (PWA manifest, `sw.js` no-cache,
  assets imutáveis, `/api/` proxied p/ `backend:3000`, `client_max_body_size
  12m`; `/analytic-api/` comentado — sem serviço `analytic` no compose).
  Containers e2e legados removidos (8080-8084); o `frontend` do compose agora
  serve a SPA em :8080. Validado: index 200, bundle `index-CWm3qagX.js` (OSM
  presente, CARTO ausente), manifest/SW 200, API via proxy 200.

## Sessão — CI Fase 1: fixtures do banco + workflow de testes (2026-09-28)

Issue #1 (GH Actions). **Rede voltou parcialmente**: `ubatexu.lan`
(192.168.0.42) ressobeu e os aliases SSH do `~/.ssh/config` funcionam
(`backend.edumaps` = porta 2031, `database.edumaps` = 2032, `analytic.edumaps` =
2033). O `rex` **foi instalado nesta máquina** (cpanm; precisou de
`XML::Parser`, que exige o header `expat.h`). O **deploy saiu**: `rex prepare`
(rsync do working tree nos 3 hosts) + `rex -H backend.edumaps
deploy_backend_dev` (serviço reiniciado, exit 0).

**Fase 1 entregue na branch `ci/backend-tests`** (3 commits + 1 fix de
workflow), **PR #102 mergeado** (`d4344dd`, merge commit em 2026-09-28) —
**workflow `backend-tests` VERDE no primeiro run de verdade** (a suíte do PR
rodou inteira no runner: build da imagem, espelho, deploy das 64 migrations,
deps via `apt`+`sudo cpanm` e `prove -r -l t/` com exit 0):

| Commit | Mudança |
|--------|---------|
| `feat(db): fixtures de CI + espelho HTTPS local` | `db/fixtures/`: 12 CSVs (headers verbatim IBGE/INEP, 18 municípios, 182 escolas) + `BR_Municipios_2024.zip` + `countries.geo.json` + `gerar.py` + `gerar_zip_municipios.sh` + `fix-manifest.json` + `mirror_countries.py` (espelho HTTPS com `Range`/206) + `ci_db.sh` (sobe/derruba o banco de CI: imagem, rede, espelho, `sqitch deploy`) + `README.md` |
| `test(backend): suíte adaptada ao fixture de CI` | `t/lib/CI.pm` (guardas `skip_r`/`skip_network`/`skip_staging`/`skip_fixtures`, no-op em dev); 17 testes pulam com motivo; `t/ci/edu_maps.conf` (config por env); correções de testes latentes: `grades.t` (`_escolas_notas_na_forma`, sem INEP fixo), `rank.t` modelo+API (`rede => 'Estadual'` + desempate por `id_escola`), `cluster.t`/`clustering.t` (`city_id_with_grades` por `clean.inep.vl_observado_2023` — o que o clustering lê de verdade), `Utils.pm` (`_distintos` deduplica amostras); `cpanfile` declara `DBD::Pg` |
| `feat(backend): workflow roda suíte no banco de fixtures` | `.github/workflows/backend-tests.yml` |

**Fatos duros aprendidos** (não repetir):

- **A migration `raw_countries` lê `/vsicurl` do `cdn.jsdelivr.net`** e não pode
  mudar (checksum Sqitch). O CDN (Cloudflare) responde chunked sem
  `Content-Length`; o callback de escrita do `/vsicurl` recusa e o GDAL reporta
  *unable to connect to data source* mesmo com HTTP 200. Nenhuma knob do GDAL
  resolve (GDAL_HTTP_HEADERS idem). Solução: espelho HTTPS local com CA própria,
  `--network-alias cdn.jsdelivr.net` na rede Docker, e `CURL_CA_BUNDLE` no
  container do Postgres. O espelho precisa responder `Range` (206 +
  `Content-Range`), senão o GDAL aborta com "Range downloading not supported!",
  e `Content-Length`/`Connection: close` (framing HTTP/1.0).
- Os 12 `COPY` das migrations leem caminhos **fixos** `/data/*.csv`; o CI monta
  `db/fixtures:/data:ro`. `BR_Municipios_2024.zip` também é `/data/`-local
  (`raw_municipios_sp` já apontava para ele). Só `raw_countries` precisa de rede.
- **`clean.school_indicators` nasce vazia**: é o job de análise (R) que a
  popula, não migration. Por isso a suíte de CI pula os testes que a exigem.
- **`actions/setup-perl` e `perl-actions/setup-perl` não existem** (404 até na
  API do GitHub deste mirror). Instalar deps do backend com `sudo cpanm
  --notest --installdeps .` (perl 5.38 do runner serve: sem pins de versão no
  repo).
- **Três INEPs de testes são inalcançáveis no fixture**: `23027010` (ausente de
  todas as fontes), `33064164`/`33069395` (só no IDEB do Rio) — resolvido
  test-side (`_escolas_notas_na_forma`), não no fixture.
- Cluster: `simple_cluster_school` lê `clean.inep` com `vl_observado_2023 IS
  NOT NULL` (não `clean.ideb_notas_escolas`); o helper de teste tem de casar com
  essa tabela. `clean.censo_escolas.co_municipio` é varchar vs
  `codigo_ibge` integer — CAST.

**Validação**: suíte completa contra o banco de fixture recriado do zero
(`ci_db.sh up`): **PASS** (71 arquivos, 302 testes, exit 0; 17 skips com
`# SKIP CI/fixtures: <motivo>`). Cluster tests ×8 estáveis. Em dev (sem
`EDUMAPS_FIXTURES`, Docker local com dados reais): guardas são no-op e os 5
arquivos com lógica nova passam. `t/dbic/base.t` falhou contra o `ubatexu.lan`
compartilhado (atraso de migration no DB compartilhado — passa no Docker local).

**Primeiro run do workflow (PR #102) falhou em 8s** — `actions/setup-perl`
irresolvível ("repository not found"). Corrigido trocando por `apt` +
`sudo cpanm`; **re-run VERDE** (um run intermediário foi cancelado pelo
concurrency ao re-pushar, sem falha). Deploy da Fase 1 feito (`rex prepare` +
`deploy_backend_dev`).

**Pendências Fase 2/3**: frontend CI (vitest + MSW, sem DB — o frontend já
tem vitest 4 + jsdom + MSW 2 configurados, `src/mocks/server.js`, 62 arquivos
de teste; falta só o workflow com `actions/setup-node`, que existe neste
mirror); decisão do Cloudflare Workers (config vs. desconectar — o check está
vermelho em todo PR; a proposta ficou para a Fase 3).

## Sessão — CI Fase 2/3: frontend no CI e a decisão do Cloudflare (2026-09-28)

**Fase 2 mergeda** (PR **#103**, `ci/frontend-tests` → `80bd7e1`):
`feat(frontend): workflow CI roda vitest no PR` (`.github/workflows/
frontend-tests.yml` — `actions/setup-node@v4` node 22 + cache npm → `npm ci`
→ `npx vitest run`; sem DB, mocks vêm do MSW) e `fix(frontend): polyfill SVG
transform no setup vitest`. **Workflow `frontend-tests` VERDE** no primeiro
run do PR (62 arquivos / 337 testes, exit 0). Deploy feito: `rex prepare` +
`deploy_frontend_dev` (nginx reiniciado, exit 0). **Nota técnica 67**.

Fato duro de Fase 2: o `@carbon/charts` lê `el.transform.baseVal.
consolidate()` ao aplicar zoom/pan; o jsdom não implementa
`SVGElement.transform` e o acesso estourava a cada frame de animação. Todos os
337 testes passavam **mas o vitest saía com exit 1** (unhandled error) — falso
negativo que derrubaria o CI. Polyfill em `src/vitest-setup.js` (padrão de
`consolidate()` → `null` = matriz identidade).

**Fase 3 — decisão documentada (recomendação: desconectar)**: o check
"Workers Builds: edumaps" (app Cloudflare Workers and Pages) falha em todo PR.
Fatos: **não há `wrangler.toml`, código de worker nem diretório `workers/` em
todo o histórico do repo**; o service `edumaps` na dashboard CF (conta
`07f55e66...`) é órfão; o check **não é required** (nunca bloqueou merge —
#60, #100-103 mergearam normalmente). Remover a integração **não é possível
via `gh`** (o endpoint de installation exige JWT do app; token de usuário →
401) — é ação de UI do admin: Settings → Integrations → GitHub Apps →
Cloudflare Workers and Pages → remover do repositório. Alternativas
descartadas: `wrangler.toml` falso para "passar" o check (CI fictício,
pior que ruído) e manter como está (ruído permanente na lista de checks, que
agora tem checks reais verdes). Sem código → sem PR/deploy para a Fase 3.

**Status final**: issue **#1 "Create GH Actions" FECHADA** (2026-09-28, por
instrução do usuário). Comentário de fechamento registra as Fases 1/2
mergeadas e a pendência operacional (remover o app Cloudflare via UI) como
não-bloqueante. Estado: `main` = `4aad876`, sincronizada com o remoto,
working tree limpo.

## Sessão — merge dos PRs abertos (2026-09-28)

Os três PRs abertos foram mergeados em `main` por instrução do usuário
("merge de todos os PR abertos"), **sem deploy** — a rede continuava fora.

| PR | Branch | Merge commit | Conflito |
|----|--------|--------------|----------|
| #100 | `fix/chat-meta-jsonb` | `5e9b918` | nenhum |
| #101 | `fix/chat-historico-e2e` | `b7cd5ca` | `memory.md` (com o #100) |
| #76 | `docs/clients-apresentacao` | `900ecb9` | `memory.md` (após rebase) |

**Os três se atropelavam em `memory.md`**, e sempre pela mesma razão: o
arquivo é reverse-cronológico e **toda branch de sessão insere no topo**, então
qualquer trabalho paralelo com #100/#101 colide. O padrão se repetiu porque
`git` só resolve automaticamente quando as inserções não se sobrepõem — aqui
as duas branches tocaram a mesma faixa de ~1000 linhas.

- **#100 × #101**: cada um era limpo sobre `main` sozinho, mas colidiam entre si.
  Resolvido com merge de `main` na branch do #101. O **código auto-mergeou
  limpo** — as duas mudanças coexistem em `Chat.pm` (validação de `meta`,
  linha ~102; filtro de `ids` no export, linha ~260) e em `Conversas.pm`.
  Mantidas as duas seções de sessão, e corrigidas as afirmações que o merge
  invalidou ("PR #100 aberto / não mergeado").
- **#76**: 125 commits atrás, 1 commit. Rebase sobre o `main` novo. O lado
  dele é de **2026-09-19**, então a sessão foi inserida na **posição
  cronológica** (antes de "Pesquisas do gestor (fase 2)", linha 1111) em vez
  do topo, e não no lugar onde o rebase a queria. Corrigida a nota que dizia
  que `docs/clients/` "ficou fora deste PR".
- **Ruído no histórico**: `5e9b918` e `82fced8` têm a mesma mensagem
  ("Merge pull request #100…") — o commit de merge que fiz na branch do #101
  herdou a mensagem automática do git. Cosmético, conteúdo correto.

**Validação**: suíte de backend comparada com `origin/main` **num worktree
separado** (não num `git stash`, para não arriscar o merge em andamento) —
**17 arquivos falhando antes e depois, a mesma lista**: nenhuma regressão.
398 testes (o +1 é o subtest de filtro do export do #101). `t/04-api/chat/`
12/12. Frontend no container: 62 arquivos / 337 testes, todos passando (o
"1 error" do vitest é o `runAnimationFrameCallbacks` do jsdom em
`SchoolFinancePage.test.js`, pré-existente e não é falha de teste).

**Pendente — deploy**: `ubatexu.lan` (192.168.0.42) segue sem resposta no
SSH, `backend.edumaps`/`database.edumaps`/`analytic.edumaps` não resolvem no
DNS, e o **`rex` nem está instalado** nesta máquina. Como o `main` agora tem
código (PRs #100 e #101), o passo de deploy do workflow está **em aberto** —
assim que a rede voltar: `rex prepare` + `deploy_backend_dev` (e
`deploy_frontend_dev` para o #101). O `check` do Cloudflare Workers está
**vermelho nos dois PRs** e não tem run correspondente no `main` para
comparar — provavelmente é pré-existente, mas ficou sem confirmação.

## Sessão — e2e do histórico de conversas em Chrome real (2026-09-28)

`ubatexu.lan`, `backend.edumaps` e `analytic.edumaps` estavam fora do ar, o que
travou a suíte de frontend no container e o deploy. Rodada feita com o
ambiente inteiro local (Postgres em Docker + backend no perlbrew do host + SPA
em build de produção servido por nginx + Chrome via CDP).

### O que a rodada encontrou

`/chat/historico` **não funcionava** — a lista nunca carregava e os botões de
exportar/excluir eram stubs. Detalhe em `docs/e2e/cobertura.md` (16 achados).
Os que mudam código:

- `ChatCalendar.svelte`: `$effect(buildCalendar())` passava o **retorno** da
  função. O `TypeError` no flush do Svelte **aborta o `onMount` da página**,
  então a lista nunca era buscada.
- `ChatConversaItem.svelte`: template usava o identificador solto `snippet`
  em vez de `conversa.snippet`.
- `ChatHistoricoPage.svelte`: a busca preenchia `searchResults` mas o template
  passava `conversas` — o resultado era buscado e descartado.
- `ChatConversaList.svelte`: exportar/excluir/`onOpen` eram `() => {}`.
- **Overlay z-index**: o botão "Ver conversa" é um `absolute inset-0` sobre o
  card e interceptava o clique dos botões de exportar/excluir. `stopPropagation`
  não adianta — o clique nem chega nos handlers. `document.elementFromPoint` no
  centro do botão resolve isso na hora.
- `searchQuery` era `bind:value` num prop não bindável (precisava de
  `$bindable` + `bind:` do pai).
- `exportConversas` era a única função de `chatApi.js` **fora do `apiClient`**:
  `fetch` cru com `credentials: "include"`, mas `_require_gestor` só lê o
  header `Authorization: Bearer` → **401** nos dois botões.

### Armadilhas de contrato do chat (custaram tempo — não repetir)

- **`?ids[]=1` NÃO é a forma que o Mojolicious lê.** `to_hash` não converte a
  notação de colchete: a chave vira literalmente `ids[]` e `to_hash->{ids}`
  volta `undef`. O filtro era ignorado e o export saía com **todas** as
  conversas, em silêncio. A forma lida é `?ids=1&ids=2`.
- **Com o filtro aplicado, o export estourava 500**: `prefetch => mensagens`
  fazia JOIN e `id` existe nas duas tabelas. O prefetch era **descartado**
  (o loop já buscava com `$c->mensagens->search(...)`) — remover resolveu.
- **`POST /api/chat/conversas` espera `messages`**, não `mensagens`; e responde
  só `{id}`, apesar de o comentário prometer `{id, created_at}`.
- **Teste que usava a forma quebrada passava sem verificar nada**: conferia
  `## Pergunta 1` num corpo que vinha com todas as conversas. Ao corrigir o
  filtro, o teste passou a falhar — porque a conversa mais recente do banco só
  tinha mensagem de `user` e o export só numera `Resposta N` para `assistant`.
- **`{#each}` com key + id repetido derruba a tela** (`each_key_duplicate`). A
  busca devolve a mesma conversa mais de uma vez (o `snippet` entra no
  `DISTINCT` do SQL). O sintoma — "a busca não filtra nada" — é parecido com o
  do `searchResults` não lido, e confunde o diagnóstico.

### Driver CDP: o que precisou de ajuste

- `Runtime.evaluate` sem `awaitPromise: true` devolve o **objeto `Promise`**
  (`{"type":"object","value":{}}`), não o resultado — o driver tem que sempre
  pedir `awaitPromise` e fazer `json.loads` do valor, que é uma string.
- O `wrap()` do driver embute a expressão num IIFE: passar uma **arrow** devolve
  a própria função (inserializável), não o valor. Precisa ser uma expressão.
- **`a.click()` de script não dá *user activation*** e o Chrome descarta o
  download de `blob:`. Só funciona com `Input.dispatchMouseEvent` de verdade.
  O `Page.setDownloadBehavior` na sessão de página não redirecionou o download
  — o arquivo foi para o diretório padrão do Chrome.
- `confirm()` trava o renderer: é preciso responder a
  `Page.javascriptDialogOpening` com `Page.handleJavaScriptDialog`. Como o
  `Session.send` descarta eventos sem `id`, o handler tem de ser chamado ali.

### Estado

- PR #100 (`fix/chat-meta-jsonb`, `meta` do chat como objeto + POST 400) foi
  **mergeado em `main` antes deste PR** (`5e9b918`). Os 3 arquivos backend
  tocados nos dois PRs mudavam em trechos distintos — o auto-merge foi limpo,
  e o único conflito real foi `memory.md` (as duas branches prependem sessão
  no topo; resolvido mantendo as duas seções em ordem cronológica).
- `edu_maps.conf` ganhou um bloco `admin` **gitignored** (login do e2e);
  backup em `/tmp/opencode/edu_maps.conf.bak`.
- Hook de post-commit segue desativado (`ubatexu.lan` fora do ar); reabilitar
  com `mv "$(git rev-parse --git-dir)"/hooks/post-commit.sample \
  "$(git rev-parse --git-dir)"/hooks/post-commit` quando a rede voltar.
> **Ambiente (2026-09-27 — resolvido; ver o que ainda falta)**:
> - Repositório agora em **`/home/itaipu/Code/Data/leaflet`** (o caminho
>   `/home/itaipu/Projects/leaflet` que aparece em alguns `@INC` é resíduo da
>   máquina antiga — ignore).
> - **Perl**: restaurado via **perlbrew 5.44.0** (o do sistema, 5.40.1, segue
>   sem `Mojolicious`/`DBIx::Class`/`DBD::Pg`). `prove`/`mojo` resolvem para o
>   perlbrew, que tem `DBIx::Class 0.082844`. Faltavam 4 deps de teste, instaladas
>   com `cpanm` (instalado junto): **`strictures`**, **`EventBus`**,
>   **`Text::Table`** e `App::cpanminus`. Sem elas 23 arquivos de teste nem
>   compilavam (0 testes, wstat 512) — instalar essas 4 levou a suíte de **281
>   para 344 testes**.
> - **Banco em Docker** (funcionando): serviço `db` em `pgvector/pgvector:pg16-bookworm`
>   + `postgresql-16-postgis-3` + `postgresql-16-ogr-fdw`, exposto em
>   **`127.0.0.1:5432`** (só loopback, para o `prove -l` da máquina alcançar).
>   `sqitch deploy` completo: **exit 0**, `clean.escolas` com 158.182 linhas.
>   Os testes locais rodam com `EDUMAPS_DB_HOST=127.0.0.1` e **`env -u PERL5LIB`**
>   (o `PERL5LIB` do shell ainda aponta pra `/home/itaipu/Projects/leaflet/lib`).
> - **`/vsicurl` da migration `raw_countries` (GDAL × Cloudflare)**: o
>   `cdn.jsdelivr.net` responde `Transfer-Encoding: chunked` sem `Content-Length`
>   conforme o edge, e o callback de escrita do `vsicurl` **recusa corpo chunked**
>   → `unable to connect to data source` **com HTTP 200 no log do curl** (o
>   sintoma engana). Nenhuma knob do GDAL resolveu de forma confiável
>   (`GDAL_HTTP_VERSION`, `GDAL_HTTP_HEADERS`, `CPL_VSIL_CURL_*`: chegou a passar
>   3/3 e depois 0/6 na mesma sessão). **Solução adotada**: espelho HTTPS
>   **local e transitivo** dentro do container (nginx em 443 + CA própria +
>   `127.0.0.1 cdn.jsdelivr.net` no `/etc/hosts`), montado por `docker exec`.
>   Some quando o container é recriado — só é preciso ao criar o banco do zero.
>   **Não** alterar as migrations (checksum quebra em ambiente já implantado).
> - **Trocar a base da imagem do `db` exige recriar o cluster**: `pgdata` é do
>   uid 999 (não apagável sem root — usar `docker run --rm -v ./pgdata:/data …
>   rm -rf /data/*`) e um cluster initdb em bullseye (collation 2.31) faz o
>   Postgres recusar `CREATE DATABASE` no bookworm (2.36).
> - **Deploy ainda IMPOSSÍVEL**: `ubatexu.lan` e `backend.edumaps` continuam sem
>   resposta. Nenhum ciclo com código pode fechar o passo de deploy até a rede
>   voltar — e é por isso que o hook segue desligado.
> - **`gh` instalado** (2.101.0, autenticado como `marcoarthur`, git via ssh,
>   scopes `repo`/`read:org`/`read:project`) — o passo de PR+merge do workflow
>   volta a ser possível.
> - **Hook de auto-deploy DESATIVADO** (`.git/hooks/post-commit` →
>   `post-commit.sample`): ele roda `rex prepare` + tasks por área, mas está
>   **quebrado** — com `set -euo pipefail` e `$GIT_DIR` não exportado para
>   hooks, ele **aborta na linha 32** (antes do `run_task prepare`). Bug
>   questionado: o `9fd4a0e` provavelmente **nunca foi deployado** pelo hook.
>   Correção: `"$GIT_DIR"` → `"$(git rev-parse --git-dir)"`. Reativar
>   (`mv .git/hooks/post-commit.sample .git/hooks/post-commit`) só quando o
>   `ubatexu.lan` voltar, senão todo commit quebra no `rex prepare`.
>
> **Suíte de backend — linha de base (2026-09-27)**: 57 arquivos / 345 testes,
> **9 arquivos com falha, todas pré-existentes** (não são regressão):
> `City.t` (contrato de retorno), `domain/quality.t` e `indicators/quality.t`
> (`ige: score <= 1`), `indicators_quality.t` (R::Pipe), `analytics.t` (serviço
> de analytics), `municipio.t` (`clean.osm_landuse` **vazia** — depende de
> ingestão OSM), `network/schools.t` (404 em `/api/cluster/schools`),
> `dbic/inject*.t` (worker Minion).

> **Pendências do histórico de conversas (commit `9fd4a0e`)** — 1 de 6
> resolvida, as outras 5 **ainda não verificadas**:
> - ~~**`meta` jsonb~~ — **RESOLVIDO e corrigido** (2026-09-27). A hipótese
>   original estava **errada na causa**: o banco grava **objeto** jsonb
>   correto (`jsonb_typeof(meta) = 'object'`) — o cast text→jsonb do PG faz
>   parse do JSON, não cria escalar. O defeito era **só na leitura**: o
>   DBIx::Class 0.0828 **não tem inflator json/jsonb** (só DateTime/File) e o
>   projeto não usava `is_json` em lugar nenhum, então `$m->meta` saía como
>   **texto** e a API devolvia uma **string** onde o contrato — e o
>   `ChatMessage.svelte`, que lê `meta.timestamp`/`meta.sql`/`meta.origem` —
>   espera objeto. Corrigido com `inflate_column` em `ChatMensagem` (veja a
>   convenção nova abaixo). **Lição: `jsonb` no DBIC deste projeto precisa de
>   inflate/deflate explícito; o default devolve string.**
> - **Frontend sem teste nem MSW**: o commit `9fd4a0e` adicionou
>   `ChatHistoricoPage` + 4 componentes + 5 funções de API **sem** nenhum
>   `*.test.js` e **sem** handlers em `src/mocks/handlers.js` (só o
>   `routes.test.js` +5). Viola a convenção do repo (toda feature entra com
>   teste + mock). **Agora é a pendência de maior risco**: nada exercita a
>   página de histórico na SPA.
> - **`per_page` sem clamp** em `list_conversas` (o `num` só garante inteiro):
>   `?per_page=100000` passa. `search_conversas` tem guarda de `> 0`, o
>   `list` não. Padronizar um clamp (1..100) como no resto da API.
> - **`/conversas/:id` inválido → 400**, enquanto a convenção do projeto para
>   identificador malformado é **404** (ver `codigo_ibge`). Uniformizar.
> - **`save_conversa` devolve só `{id}`** mas o comentário do handler promete
>   `{ id, created_at }` — doc × código divergentes.
> - **SQL fora do padrão do projeto**: `search_conversas`,
>   `calendar_conversas` e `export_conversas` usam
>   `$self->schema->storage->dbh` (DBI cru) com `LIMIT ?/OFFSET ?` sem tipo,
>   enquanto as demais roles usam `dbh_do` (Mojo::Pg). Funciona, mas é
>   divergente — e `LIMIT ?` com parâmetro não tipado é exatamente o cenário
>   que já mordeu em `CASE WHEN ? IS NULL` (ver convenção de prepared
>   statement).
> - **Latente, mesma classe do bug do `meta`**: `OsmLanduse.tags` é `jsonb` e
>   também sai como string. Hoje não tem efeito — `City/Profile.pm` não expõe
>   `tags` — mas é a mesma armadilha esperando alguém ler a coluna.

## Sessão — Verificação do histórico de conversas e correção do `meta` (2026-09-27)

**Objetivo**: validar o commit `9fd4a0e` com um ambiente de teste funcionando.
**Resultado**: ambiente refeito (ver bloco "Ambiente") e **1 bug real corrigido**,
com teste. 5 das 6 pendências continuam abertas.

### Bugs encontrados (ambos confirmados contra o banco, não por leitura)

**1. `meta` jsonb saía como string na API** (o de maior risco da lista, e a
hipótese original estava errada na causa). Detalhado no bloco "Pendências":
o banco está correto, o defeito era só a leitura. Impacto real hoje é
**latente** — `getConversa(id)` existe em `chatApi.js` mas **nenhum código do
frontend chama** (a página de histórico só lista, busca, apaga e exporta), então
a falha apareceria no dia em que alguém ligar "abrir conversa salva", e
sumiria a metainformação (timestamp, SQL, prévia do resultado, tabelas) sem
nenhum erro na tela.

**2. `POST /api/chat/conversas` com `meta` inválido devolvia 500.** `meta` fora de
objeto (texto solto, array) não tem tradução para jsonb; o Postgres recusava e a
resposta era **500 com a página de erro em HTML de desenvolvimento** — vazamento
de página de debug, e não o 400 que o resto da API usa. Um número era aceito
(201) e gravado como escalar jsonb silenciosamente.

### O que mudou

- `Schema/Result/ChatMensagem.pm` — `inflate_column` em `meta` (inflate +
  deflate). Ver convenção durável acima.
- `Roles/Business/Chat/Conversas.pm` — `save_conversa` parou de fazer
  `encode_json` à mão; a serialização passou a ser da coluna. O import de
  `Mojo::JSON` ficou sem uso e saiu.
- `Controller/Chat.pm` — valida `meta` e devolve 400
  `{"error":"meta deve ser um objeto JSON"}`.
- `t/04-api/chat/conversas.t` — subtest novo para o `meta` inválido (3 formatos)
  + asserções de forma no detalhe. 10 → **11 subtests, todos passando**.

**Efeito colateral de contrato**: `meta` enviado como *string* JSON passou a dar
400 (antes 201). O frontend manda objeto, e aceitar a string era justamente o
que produzia o escalar jsonb silencioso.

**Ganho no teste**: o subtest de detalhe pegava "a conversa mais recente da
lista"; com o subtest novo fazendo POST no mesmo recurso, a ordenação passou a
devolver outro registro e o teste media a coisa errada. Passou a usar o id
devolvido no POST.

### Verificação

- `conversas.t`: 11/11 PASS.
- Suíte completa (57 arquivos, **345 testes**): os **mesmos 9 arquivos** falhando
  com as **mesmas contagens** de antes da mudança — nenhuma regressão.
- Sondas descartáveis (fora do repo) gravaram e releram o `meta`: banco `object`,
  API devolvendo `HASH`.

### Não feito (e por quê)

- **Deploy**: impossível — `ubatexu.lan` e `backend.edumaps` sem resposta. O PR
  foi aberto sem o passo de deploy do workflow, e o hook segue desligado.
- **Teste de frontend**: precisa do container `backend.edumaps`. Continua sendo
  a pendência de maior risco (a página de histórico não tem teste nem MSW).
- **`OsmLanduse.tags`**: mesma classe de bug, sem efeito hoje — não tocado.

## Sessão — Histórico de conversas do Assistente do Censo (commit `9fd4a0e`, 2026-09-25)

> ⚠️ **Sessão registrada a posteriori** (2026-09-27), reconstruída por leitura
> do diff. O commit foi direto na `main`, **sem PR** e **sem deploy
> documentado**; nada pôde ser validado porque o ambiente já estava fora do ar
> (ver bloco "Ambiente" acima). Tudo abaixo é **código entregue**, não
> **comportamento verificado**.

- **O quê**: o gestor passa a poder **salvar** a conversa do chat (perguntas +
  respostas), **listar/buscar** o histórico com full-text, navegar por
  **calendário** e **exportar para Markdown**. Tudo escopado no gestor logado.
- **data_pipeline** — `chat_conversas [gestor_pesquisas]` (`sqitch.plan`,
  2026-09-25T18:00:00Z): `clean.chat_conversas` (id, `gestor_id` FK
  `clean.gestores` `ON DELETE CASCADE`, `titulo` opcional, `created_at`,
  `updated_at`) e `clean.chat_mensagens` (id, `conversa_id` FK cascade, `role`
  com CHECK `user|assistant`, `content`, `meta` jsonb, `created_at`) + 2
  índices GIN de `to_tsvector('portuguese', …)` (título e conteúdo), 2 B-tree
  (listagem e mensagens) e trigger `tg_chat_conversas_updated_at`. `verify.sql`
  confere 2 tabelas, 4 índices, o trigger e as 2 FKs.
- **backend**:
  - `Roles/Business/Chat/Conversas.pm` (232 linhas): `save_conversa`,
    `list_conversas`, `get_conversa`, `delete_conversa`, `search_conversas`
    (CTE com `plainto_tsquery` + `ts_headline` para o snippet),
    `calendar_conversas` (dias com contagem) e `export_conversas` (Markdown).
  - `Model/Chat/Conversas.pm` (compõe a role), `Schema/Result/ChatConversa.pm`
    e `ChatMensagem.pm` (**sem** `is_json` no `meta` — ver pendência).
  - `Controller/Chat.pm` ganhou os 7 handlers; o `export` responde
    `text/markdown` com `Content-Disposition: conversas-<data>.md`.
  - `Plugin/API/Chat.pm`: as rotas novas ficam **sob um `under` que reusa
    `pesquisa#_require_gestor`** (o mesmo guard de sessão das pesquisas) —
    assim o histórico herda a autenticação já testada. Ordem correta:
    `calendar`/`search`/`export` (literais) **antes** de `:id`.
- **frontend**: rota `/chat/historico` (`ChatHistoricoPage`: busca, filtro por
  período, calendário, seleção para export, exclusão) + componentes
  `ChatCalendar`, `ChatConversaList`, `ChatConversaItem`, `ChatExportModal`;
  `chatApi.js` ganhou 5 funções; `ChatPage.svelte` ganhou os botões
  **"Salvar conversa"** (modal de título opcional), **"Buscar conversas
  anteriores"** e manteve "Limpar conversa"; uma classe utilitária
  `.hChatHistorico` no `app.css`.
- **Testes**: `t/04-api/chat/conversas.t` — 10 subtests (save 201, save sem
  mensagens 400, list, show, search, calendar, export, delete, 401 sem token,
  403 gestor comum) com guarda `plan skip_all` quando
  `clean.chat_conversas` não existe, e **limpeza dos dados no `END`**.
- **Não feito** (lacunas do ciclo, ver pendências acima): deploy, validação,
  teste/MSW de frontend, `docs/funcionalidades/analise/assistente-censo.md`
  (que descreve o chat mas **não** o histórico) e nota técnica.

## Sessão — Admin de instalação via config (bootstrap provisório), PR #99 (2026-09-25)

- **Mecanismo provisório** para bootstrap de admin no deploy: credenciais admin
  (email + senha) em texto plano no `edu_maps.conf` (bloco `admin`), lidas
  pelo backend no login. Se batem, materializa/garante gestor em
  `clean.gestores` com **INEP reservado 0** e `access_role='admin'`, emite
  sessão normal.
- **Rexfile adaptado**: settings `admin_email` / `admin_password` a partir de
  `$ENV{EDUMAPS_ADMIN_EMAIL}` / `$ENV{EDUMAPS_ADMIN_PASSWORD}`; passados ao
  template `edumaps_db.conf` que gera o `edu_maps.conf` no container (só emite
  bloco admin quando ambos definidos).
- **Config local** (`backend/edu_maps.conf`, gitignored): bloco admin com
  fallback `$ENV{...} // default` para dev local.
- **Teste novo**: `t/04-api/admin/bootstrap.t` (4 testes — login admin 200,
  senha errada 401, `/me` expõe access_role, `/api/admin/config/tree` 200).
- **Validado no container** (backend.edumaps): login admin → 200 + token +
  gestor (cod_inep=0, access_role=admin); painel `/api/admin/config/tree` → 200.
- **Registrado como PROVISÓRIO** — nota técnica 63 documenta a necessidade de
  substituir por gestão própria de administradores (cadastro, listagem,
  revogação, MFA) em ciclo futuro. Backlog: único issue aberto segue **#1
  (GH Actions)**.

## Sessão — Painel de Configuração (admin), PR #98 (2026-09-25)

- **Entregue e mergeado** o Painel de Configuração da plataforma (admin):
  migrações `app_config` (schema + tabela `items`; secrets via
  `pgp_sym_encrypt/decrypt`) e `gestor_access_role` (`clean.gestores.access_role`),
  API admin (`/_require_admin`: 401 sem sessão / 403 sem papel admin; login/me
  agora expõem `access_role`), model `AppConfig` (secret do tipo `secret`
  mascara como `{set:0/1}`; cifra no banco, nunca no JSON), rota SPA `/config`
  (árvore Sistema/Integrações/Aparência/Comportamento/Outros + editor), e o
  Assistente do Censo passa a ler a config global da instalação.
- **Master key**: `EDUMAPS_CONFIG_MASTER_KEY` injetada no Rexfile + systemd
  (`edumaps-web/minion/minion-analytics`). **Nunca commitar.** Chave atual (dev)
  está em `/tmp/edumaps_master_key.txt`.
- **R**: `chat_config(override)` agora recalcula `engine` pelo `cfg$provider`
  pós-override (bug: usava a env em vez do provider efetivo); `chat_db_connection(cfg)`.
  Cache do `run_chat` inclui `config_version` (hash da config LLM) — troca de
  provedor/chave invalida o cache sem vazar a chave.
- **Dois bancos em dev**: o banco do container `database.edumaps` difere do
  `ubatexu.lan` (testes locais). Migrações manuais foram aplicadas **nos dois**
  (container via `ssh root@database.edumaps`, `sudo -u postgres psql -d edumaps_dev`).
  O gestor-teste do container (`marina.e2e@edu.gov.br`, INEP 11000040) foi
  promovido a `admin` na validação e revertido depois.
- **Validação e2e real** (Chrome CDP, PASS 2026-09-25): `/config` com sessão
  admin (token injetado no `localStorage` `edumaps_gestor_token`) → árvore +
  editor; chave salva e confirmada **cifrada** no banco (descriptografável com a
  master key). Fluxo completo da API admin validado no container (tree → show →
  validate → put). Registrado em `docs/e2e/cobertura.md` (item 27, 🟢).
- **Testes novos**: backend `t/02-models/app-config.t` + `t/04-api/admin/config.t`
  (13 ok), R `test-config.R` (15 ok, novo), rota SPA `/config` (15+5 ok). Suíte
  frontend completa: 63 files/337 testes (1 erro pré-existente @carbon/charts).
- **Ciclo completo**: build OK → deploy Rex `prepare` + backend/minion/frontend/
  analytics → PR #98 mergeado → `main` sincronizado. Backlog: único issue aberto
  segue **#1 (GH Actions)**.

## Sessão — Backlog GitHub: limpeza de issues

- **10 issues fechados** (2026-09-25) via `gh issue close --comment`, com
  referência ao commit/PR de implementação no `main`:
  - **#50** endpoint similares (`ede1ad7`/`e85a8d5`/`bf8f9c5`, PR #72);
  - **#51** UI seleção/lista similares (`bf8f9c5`);
  - **#52** mapa Leaflet similares (`bf8f9c5`, `ec95bba`);
  - **#35** download SIOPE (`ef38fa0`, `275d503` — `script/tasks/siope.pl` +
    middleware `SiopeTask` à la Minion);
  - **#33** dados IBGE estruturados (`7e1e21c` tabela `dados_ibge`; `766eef3`
    model `DadosIbge`);
  - **#14** testes organizados (backend t/02-models, t/04-api, t/05-tasks;
    frontend vitest; e2e CDP em `docs/e2e/`);
  - **#42**, **#45**, **#53**, **#23** fechados como **defasados**
    (epics/fora do escopo atual, após decisão explícita do usuário).
- **#1 (Create GH Actions) mantido ABERTO** a pedido do usuário — `deploy` atual
  é via Rex (as-is), sem `.github/workflows`; check "Workers Builds" é órfão.
  Pendência de infra genuína a rastrear.
- Resta **#1** como único issue aberto no backlog.

## Sessão — Testes e2e via browser real (CDP, plugin opencode-chrome-devtools)

- **Plugin instalado** (2026-09-24): `opencode-chrome-devtools@1.0.4` no config
  **global** `~/.config/opencode/opencode.jsonc` (`"plugin": ["opencode-chrome-devtools"]`)
  + `~/.config/opencode/node_modules`. Ferramentas: `browser_list`,
  `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_fill`,
  `browser_eval`, `browser_screenshot`. Skill nova `.opencode/skills/browser-automation.md`.
- **Chrome >= 136 ignora `--remote-debugging-port` no profile padrão** —
  exige `--user-data-dir` dedicado. Instância usada:
  `setsid nohup /opt/google/chrome/chrome --remote-debugging-port=9222
  --user-data-dir=/tmp/edumaps-cdp ...` (porta 9222, `http://127.0.0.1:9222`).
- **Docs**: runbook em `docs/e2e/README.md`; inventário/cobertura das 26 rotas
  em `docs/e2e/cobertura.md` (executar contra todas as features da SPA, exceto
  páginas só-documentação/solo-backend; atualizar PASS/FAIL a cada rodada).
  Seções novas no `AGENTS.md` (tests e2e + skill table).
- **Nuance Svelte 5/Svelte (runes)**: `browser_snapshot` costuma vir vazio
  (`RootWebArea` só) — usar `browser_eval`. Preencher inputs exige **setter
  nativo** do prototype + `input` event (Svelte runes não captura `el.value=x`
  simples); clicar botões funciona com `.click()`.
- **Validado (PASS, 2026-09-24)**: `/escola/search` (município=Ubatuba → cards
  com INEP/telefone/Painel) e `/escola/panel?inep=35245239` (matrículas,
  etapas, infraestrutura). Rastro em `docs/e2e/cobertura.md` (itens 4 e 5).

## Sessão — Correções latentes (backlog Alta)

- **PR #96** (`fix/alta-backend-summary-stubs`) e **PR #97**
  (`fix/alta-frontend-pwa-tests`) → `main` (merges `ecc57b5`/`d0c3ad8`,
  2026-09-24). Ciclo de correções latentes do backlog técnico.
- **`/summary` rejeita sub-análise não suportada (400 explícito)**:
  `Controller/Task.pm::request_summary` valida `analysis` (`full_summary | score_distribution | school_clusters`); se ≠ `full_summary` → **400** com
  `"Sub-análise '...' não suportada: o motor R ainda não persiste esse recorte.
  Use 'full_summary'."` (antes aceitava o param e o R falhava/500). Regressão em
  `t/04-api/task.t` (subtest novo). **Decisão do usuário**: 400 explícito em vez
  de perseguir suporte do motor R agora.
- **Rotas stub → 501 explícito**: `School.pm::grades`/`full_grades` retornam
  501 `"Não implementado: métricas de notas ainda não estão disponíveis."`
  (antes `...` = 500 silencioso). **Decisão do usuário**: marcar 501 em vez de
  código vazio.
- **Stubs de `CensoEscolas.pm` com `die` explícito**: `with_critical_infra_highlight`,
  `with_vulnerability_score`, `with_highlight_badges`, `with_extra_activities_score`
  agora `die "…ainda não implementado"` (antes `...;`/`{}` silencioso). Sem
  consumidores no frontend.
- **Código morto removido**: `_reuniao_validation` não seta mais
  `$input->{__duracao}`/`__aviso` (controller ignora; default no model). As
  validações de `duracao_min` (15–480) e `aviso_metodo` (`AVISOS`) foram
  mantidas.
- **`Profile.pm` NÃO precisou de mudança**: verificado — a soma de deficiência
  já usa `qt_mat_esp`/`esp_cc_total`/`esp_ce_total` (não `d+dm+dv`) e turno usa
  `qt_mat_bas_d/dm/dv/n/int`; o "bug latente" da memória era **informação
  desatualizada** (já corrigido antes). Só a memória foi atualizada.
- **Testes backend corrigidos (2 flakies reais)**:
  - `t/04-api/school/clustering.t`: regex `/error` de "Não encontrado" →
    `qr/n[aã]o encontrad[oa]s/i` (mensagem real com "parametros").
  - `t/02-models/school/searching.t`: `telefone`/`whatsapp` agora `E()` (exist)
    nos subtestes EMEF e Ubatuba — escolas sem telefone cadastrado no Censo são
    válidas; antes `L()`/`match` falhavam por dado, não por código.
  - Verificado **não**-regressões: `task.t`, `reunioes.t`, `rank.t` (flaky de
    performance 3.7s>2.5s quando MV `ranking_escola` vazia → cálculo ao vivo;
    passa em re-execução), `osm.t` (falha por serviço externo Overpass 504 —
    não é bug). `.test_info.*.json` criado por backup de teste → remover.
- **Testes frontend corrigidos (4)**: `paginationStore.test.js` (3: não esperar
  mais `q:""`, store omite query vazia — convenção de `memory.md` já documentava)
  e `SchoolRankingPage.test.js` (rota real `/escola/search`, não `/busca`).
  Suíte completa no container: **62 arquivos / 331 testes verdes**.
- **PWA instalável**: falta era só o **ícone 180 (apple-touch-icon)** +
  `robots.txt` (512/192/maskable já existiam). Gerado
  `public/icons/icon-180.png` (placeholder a partir do 512), `robots.txt`
  (`User-agent: * / Allow: /`), `<link rel="apple-touch-icon">` no `index.html`
  e entrada `180x180` no `manifest` do VitePWA. **Decisão do usuário**: PNG
  placeholder simples.
- **Deploy**: `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev`
  (atenção: `prepare` rsync do working tree da branch ativa — rodar
  `deploy_backend_dev` com a branch backend no checkout, ou a última rodada
  sobrescreve os arquivos de backend com a versão da base). Smoke no container:
  `/grades`/`/full_grades` → **501**, `/api/task/summary` com
  `analysis=score_distribution` → **400 + mensagem**, `/icons/icon-180.png` e
  `/robots.txt` → **200**.

## Sessão — Documentos e planos escolares (gestor, fase 1)

- **PR #94 merged** (`feat/gestor-documentos` → `main`, merge `d57cab0`).
  Repositório de documentos e
  planos da escola em pastas/subpastas, upload versionado (mesmo nome+média =
  nova versão), tags livres e auditoria de toda mudança.
- **Backend**: 3 commits em `main` — `feat(data_pipeline)` (migration
  `gestor_documentos` com `clean.pastas_escolares`, `escola_documentos`,
  `escola_documentos_versoes`, `escola_documentos_auditoria` + índices/constraint
  únicos `uq_pastas_escolares_inep_pai_nome`/`uq_escola_documentos_inep_pasta_nome`
  → 409), `feat(backend)` (role `DocumentosEscolares.pm` com `normalize_tags`
  público; `Model/Gestor.pm`; `Controller/Gestor.pm` com 12 handlers e eval guard
  em toda mutação + `%CAMPO_LABEL` + mapeamentos de violação única em
  `_render_db_error`; `Plugin/API/Gestor.pm` com PATCH nas atualizações e rotas
  literais antes de `/:id`). `subir_documento` devolve `pasta_id`.
- **Frontend**: `feat(frontend)` commitado (`a02abbb`) — `api/gestorDocumentosApi.js`,
  `api/gestorDocumentosApi.test.js`, `pages/DocumentosPage.svelte` + teste,
  `components/documentos/{DocumentosArvore,TagEditor,VersoesModal,HistoricoModal}.svelte`,
  `constants/documentos.js`, `mocks/documentos{Fixtures,Handlers}.js`; rota
  `/gestor/documentos`, botão no `GestorPanelPage`, `apiClient.patch` adicionado,
  handlers registrados em `src/mocks/handlers.js`.
- **Bugs encontrados e corrigidos**: rotas de documento montavam duplo
  `/documentos/documentos/:id` (BASE já termina em `/documentos`) — corrigido
  para `${BASE(inep)}/${id}`; `#each` de documentos sem `id` na chave (duplicado
  `docundefined`); pastas não expandiam porque `abertas` capturava valor inicial
  vazio — refatorado para "recolhidas" (raiz aberta por padrão); MSW rejeitava
  upload vindo do jsdom (nome "blob") — campo `_original_nome` (convenção do repo).
- **Migração aplicada nos DOIS bancos**: `ubatexu.lan` manualmente (psql — sqitch
  falha no extension `vector` local) e no container via `rex -H database.edumaps
  deploy_db_dev` (lá o pgvector existe e o sqitch deploy roda normalmente).
- **nginx**: `client_max_body_size 12m;` no `edumaps-frontend-nginx.conf`
  (commit `d4d5773`) + deploy feito.
- **Deploy**: `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev` +
  `deploy_db_dev` (database.edumaps). E2E via curl no container verde (perfil,
  login, GET árvore, criar pasta, duplicada 409, upload 201, download v1, tags,
  histórico, auditoria, delete doc/pasta 204). Gestores e dados e2e temporários
  removidos do container DB.
- **Testes**: backend `prove -l t/04-api/gestor/` (10 arquivos, 67 testes) verde;
  frontend 14/14 novos verdes; suíte completa 327/331 (4 falhas pré-existentes e
  não relacionadas: `paginationStore.test.js` espera `q:''` fixo e
  `SchoolRankingPage.test.js` "Voltar para busca").
- **Docs**: `docs/funcionalidades/gestor/documentos-planos.md` (capacidade nova)
  + índice `README.md`.
- **Hotfix pós-#94**: criar pasta na raiz falhava 400 — o frontend envia
  `pasta_pai_id: ""` e o Validator (`optional` só ignora `undef`) reprovava o
  `num`. Na criação trocado para `like(qr/^\d*$/)` ('' = raiz; upload/update já
  normalizavam). Regressão em `documentos.t` + validação curl no container com o
  INEP real (`52094618`, payload `""` → 201; pasta criada e removida). Fix
  `55c38e3`, **PR #95**.

## Sessão — Assistente do Censo (chat NL/SQL)

- **Branch** `feat/assistente-censo` (PR a abrir). Feature de chat em linguagem
  natural sobre o Censo: `POST /api/chat/ask` → job Minion (fila `analytics`) →
  Plumber `POST /ask` (edumapsr) → LLM.
- **Backend**: `EduMaps::Controller::Chat` + `Plugin::API::Chat` +
  `Task::Chat`. O **contexto do gestor vem aninhado** em `contexto` no JSON; o
  controller lê o objeto aninhado com fallback na raiz (o bug de contexto vazio
  era o controller lendo campos na raiz). `GET /api/chat/progress` devolve o
  `result` do job quando `finished`.
- **Analysis**: `R/chat-translate.R`, `chat-dictionary.R`, `chat-plotly.R` e
  `inst/chat/dicionario.yml`. Provider nativo Gemini (`gemini-flash-lite-latest`),
  engine de 1 turno p/ TPM baixo (Groq). `chat_redact` remove PII **e colunas
  geométricas** (`pq_geometry`), que quebravam a serialização (`No method asJSON
  S3 class: pq_geometry` → 500).
- **DB**: role `edumaps_leitor` (somente leitura) via sqitch
  `edumaps_leitor_role`. `pg_service.conf` com `[edumaps_leitor]`.
- **Frontend**: feature `src/features/chat/` (rota `/chat/censo`), Svelte 5.
  Pré-preenche o escopo com a escola do gestor logado (`/me` → `/painel`); o
  painel passou a expor `cod_municipio`. Aviso quando a sessão expira (401).
- **PWA/nginx**: SW normaliza o precache (evita `addAll` duplicado), **não
  cacheia** `sw.js`/`registerSW.js`/`manifest.webmanifest`, `CACHE_VERSION` v2.
  nginx: `default_server` (hosts fora do `server_name` davam 404 em `/api/`),
  MIME `application/manifest+json`, `index.html` com `no-cache`, ícones PWA.
- **Deploy**: `EDUMAPS_LLM_PROVIDER/MODEL/URL/API_KEY` por env (chave preservada
  quando ausente). `TZ` + `LANG/LC_ALL=C.UTF-8` no `.Renviron`.
- **Testes**: `t/04-api/chat.t`, `t/03-plugins/analytics.t`,
  `t/04-api/gestor/painel.t`; frontend `ChatPage.test.js` + integração (8 no
  total). Frontend verde; backend preso ao perl 5.38 ausente no container.

## Sessão — eduBR: perfil modal de diretores (censo_gestor)

- **Repo** `~/Projects/eduBR`; branch **`feat/edubr-perfil-gestor`**; commits
  `7e13343` `feat(edubr): perfil modal de diretores (censo_gestor)`,
  `2ec38b7` `docs(edubr): report de perfil modal de diretores` e `589d582`
  `docs(edubr): skill com perfil de gestores`. **PR #3 merged** (2026-09-21,
  merge commit **`2d57181`**); `main` == `origin/main`.
- **Fonte**: `~/Documents/Notas/gestor_edumaps_perfil.md` é **referência à
  parte** — decidido: nossos números primeiro, literatura não é assertada.
  Decisões do usuário: só análise no eduBR (sem API/UI); unidade **gestor**
  (principal) + **escola** (sensibilidade); base válida por dimensão (cor/raça
  "não declarada" fora do denominador; vínculo só públicas; escola privada sem
  forma de acesso público); Brasil/rede/região/UF.
- **`R/gestor.R`**: `censo_gestor()` (catálogo +`clean.censo_gestor`),
  `gestores()` (lazy; filtra/rotula no SQL via `eduBR_case_when_lookup` —
  `case_when` a partir de vetor nomeado; **evitar** indexação R e `.env$fn()`
  dentro de `filter`/`mutate` em tbl dbplyr), `perfil_gestor()` (9 dimensões;
  materializa e agrega **em R**; retorna `$proporcoes`/`$modal` com
  Herfindahl/`$n`; `composicao=FALSE` marca categorias fora da composição do
  modal).
- **Pegadinhas da rodada**: colunas reais de `clean.censo_gestor`/`censo_escolas`
  são **minúsculas** (`tp_dependencia`, `no_municipio`), não o `UPPER_CASE` do
  deplay `.sql` (desatualizado); `dplyr::select(tbl, "co_entidade")` sem
  `all_of()` gera NOTE no check; lint non-ASCII no código → escapar literais
  com `\uXXXX` (comentários ficam UTF-8); fixture de teste precisa de TODAS as
  colunas de contagem das dimensões testadas; `.env$fn()` dentro de `filter`
  não traduz (pré-computar o valor).
- **Números reais (2025)**: 190.641 diretores / 180.540 escolas. Feminino em
  todas (municipal 82,1%, privada 83,9%, estadual 65,6%); **federal 73,7%
  masculino**. Cor/raça modal branca em todas; municipal na borda (45,6%).
  Acesso ao cargo separa redes: proprietário/sócio privada 52,1%, eleição
  federal 81,6%, municipal processo seletivo 33,8% + indicação 32,9% + eleição
  15,2%, estadual três vias ≈ 20–26%. Formação continuada em gestão 7,2%
  (federal) a 27,0% (municipal). Sensibilidade gestor→escola: **zero** trocas
  de categoria modal (só variação ≤3,3pp).
- **Report**: `analysis/perfil_gestor.Rmd` renderizado no container
  `rstudio.dev` (html ~9MB, gitignored); snapshot `analysis/capturar_gestor.R`
  → `analysis/dados_gestores.rds` (180.540 linhas × 77 col). Render exige
  `devtools::load_all()` (a cópia instalada do eduBR no container é
  desatualizada e `install_local` não funciona).
- **Testes/check**: `devtools::test()` 282 ok (+1 skip smoke) e
  `devtools::check()` **0/0/0**, no container. Após o 2º commit o rsync
  post-commit falhou uma vez (`code 255`) — re-sync manual confirmou.
- **Repo `edumaps`**: sem mudanças de código neste ciclo (só docs: NOTA 51,
  este memory).

## Sessão — Financeiro: escopo de rede no agregado da Secretaria

- **Repo** `edumaps`; branch `fix/financeiro-escopo-rede` (a partir de
  `origin/main`); commit `598aa9a`. **PR #92** → `main`, merge commit
  **`bf54363`** (2026-09-22). `main` == `origin/main`.
- **Motivação**: exibir o agregado da Secretaria como se fosse da escola é
  **misleading** (não dá para saber quem atua na unidade). Mantém o dado, mas
  escopado.
- **Mudanças (frontend/docs)**: aviso **"Painel da rede municipal — não desta
  escola"**; títulos/cards com sufixo "Rede municipal (Secretaria)"; **"Ver
  folha completa"** (nomes) **desabilitado** no agregado. `origem=escola` segue
  sem escopo de rede.
- **Testes**: `SchoolFinance.test.js` + `SchoolFinancePage.test.js` 10 ok; suite
  304 ok (4 pré-existentes).
- **Deploy**: `deploy_frontend_dev`.

## Sessão — Financeiro: agregado da Secretaria (SIOPE sem folha por escola)

- **Repo** `edumaps`; branch `fix/financeiro-agregado-secretaria` (a partir de
  `origin/main`); commit `938ad32`. **PR #91** → `main`, merge commit
  **`fefa1a8`** (2026-09-22). `main` == `origin/main`.
- **Diagnóstico (não era bug do EduMaps)**: em Taubaté e **~3819 municípios**, o
  SIOPE **não detalha a folha por escola** — o FNDE entrega tudo sob
  `cod_inep=99999999` / `"SEC MUN DE EDUC ..."` (a Secretaria). Confirmado no
  xlsx bruto (todas as linhas com `99999999`; num município que declara por
  escola, como 353650, vem 1 cod_inep por unidade). Os dados existem; o painel
  busca pela escola real e ficava vazio.
- **Fix**: `financial_summary` tenta a escola; se vazia, cai para o **agregado
  do município** (`cod_municipio`) e devolve `origem` (`escola`|`secretaria`) +
  `rotulo_origem`. Frontend mostra aviso destacado quando `origem=secretaria`.
- **Validado no real**: escola sem folha própria → `origem=secretaria`, 12
  competências, 3.632 profissionais.
- **Testes**: backend `prove -rl t/04-api/school/ t/04-api/gestor/` (novo
  `finance_secretaria.t`); frontend `SchoolFinancePage.test.js` 6 ok; suite 303
  ok (4 pré-existentes). **Nota**: `t/04-api/school/clustering.t` falha no HEAD
  (depende de R/serviço) e `search_paginated.t` é flaky de performance — não são
  regressões.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`.

## Sessão — Importar contatos da folha de pagamento

- **Repo** `edumaps`; branch `fix/importar-contatos-folha` (a partir de
  `origin/main`); commit `850f15e`. **PR #90** → `main`, merge commit
  **`2febbc9`** (2026-09-21). `main` == `origin/main`.
- **Bug**: a folha criava apenas **grupos** (`origem='folha'`) — rótulos vazios —
  sem importar as pessoas. Na agenda/wizard os grupos apareciam **todos vazios**;
  o import de contatos da folha nunca existiu (só colagem manual).
- **Fix**: `Gestor::Reunioes#importar_contatos_folha` cria os profissionais de
  `clean.remuneracao_municipal` como **contatos** (nome + cargo), vinculados ao
  grupo `folha` (Professores/Administrativos/Outros via `_grupo_para_categoria`),
  **idempotente** (pula mesmo nome+grupo). Rota
  `POST /api/gestor/:cod_inep/contatos/importar-folha` + botão **"Importar da
  folha"** na agenda.
- **Validação**: container (escola `35245239`, 206 registros de folha) → **21
  contatos** importados; 2ª rodada `n_inseridos=0`; backend 71 ok (novo
  `contatos_folha.t`); frontend `ContatosPage.test.js` 4 ok; suite 302 ok
  (4 pré-existentes).
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`.

## Sessão — Financeiro: card de profissionais (total distinto)

- **Repo** `edumaps`; branch `fix/financeiro-total-profissionais` (a partir de
  `origin/main`); commit `5c66d01`. **PR #89** → `main`, merge commit
  **`177409a`** (2026-09-21). `main` == `origin/main`.
- **Investigação (não era bug de parsing)**: a escola `35268800` tem 45
  registros / 5 CPFs distintos / 14 competências; o CSV do xlsx e o banco batem
  linha a linha. O "1" era o card **"Profissionais"**, que exibia a
  **competência mais recente** (Out/2024 tem 1 servidor), com rótulo ambíguo.
- **Fix**: backend expõe `total_profissionais` (`COUNT(DISTINCT cpf)` na escola,
  todos os meses); o card vira **"Profissionais (total)"** e a competência mais
  recente vira nota secundária.
- **Testes**: backend `prove -rl t/04-api/gestor/finance_siope.t t/04-api/gestor/
  t/04-api/pesquisa.t` (68 ok); frontend `SchoolFinancePage.test.js` (5 ok);
  suite 301 ok (4 falhas pré-existentes). Endpoint real: `total_profissionais: 5`.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`.

## Sessão — Fix: download do SIOPE + monitor de job que falha

- **Repo** `edumaps`; branch `fix/siope-download-e-monitor` (a partir de
  `origin/main`); commits `8ceb6a2` (backend), `8021302` (frontend/docs).
  **PR #88** → `main`, merge commit **`efd3961`** (2026-09-21). `main` == `origin/main`.
- **Bug 1 — download (`Gastos.pm`)**: o FNDE responde com
  `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`; o teste
  `/excel/i` **não casava** → corpo descartado → `xlsx2csv_fast` morria com
  `Cannot open /tmp/<mun>_<ano>.xlsx.Planilha.csv`. Fix: aceitar
  `excel|spreadsheetml|officedocument|octet-stream`. (O fix do município do PR
  #87 estava certo; o download é que estava quebrado.)
- **Bug 2 — monitor (`Plugin::Helpers#_monitor_minion_job`)**: só encerrava o
  stream em `finished`; em `failed` o SSE ficava pendurado e a UI em
  "Enfileirando… (0%)". Fix: encerra em `finished` **e** `failed`, não emite
  progresso no estado terminal e sintetiza `result` de erro no `on_finish`.
- **Frontend** (`watchJobProgress`): guarda contra `onerror` duplicado e lê o
  snapshot final (`GET /api/task/progress`) para decidir sucesso/erro.
- **Validação**: scraper real → **Caçapava 350850/2026 = 5152 linhas**,
  **Taubaté 355410/2026 = 17753**; SSE de job failed encerra de imediato;
  `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t t/01-app/helpers.t` (70 ok);
  `SchoolFinancePage.test.js` (4 ok). Nota: o subteste SSE de `t/05-tasks/
  siope.t` **já falhava no HEAD** (job rápido + sem worker local) — não é regressão.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`.

## Sessão — Fix: município correto no SIOPE (bug do código do INEP)

- **Repo** `edumaps`; branch `fix/siope-codigo-municipio` (a partir de
  `origin/main`); commit `275d503`. **PR #87** → `main`, merge commit
  **`0f221e8`** (2026-09-21). `main` == `origin/main`.
- **Bug (reportado no teste manual de Cuiabá)**: o código do município do SIOPE
  era `substr(cod_inep,0,6)`. **O prefixo do INEP NÃO é o código do município**
  (ex.: INEP `51065592` é de Cuiabá, código antigo `510340`; o job recebia
  `510655` → "Cannot open /tmp/510655_2026.xlsx.Planilha.csv"). Confirmado no
  censo: `co_municipio=5103403` → `510340`, INEP prefixo `510655`.
- **Fix**: `_cod_municipio_escola` deriva de **`clean.censo_escolas.co_municipio`**
  (7→6 dígitos), com fallback nome+UF em `raw.br_municipios_2024`; `habilitado`
  exige município derivável. Também corrigido `map { $_->[0] }` em sub com
  assinatura (o `$_[0]` lia o `@_` da sub — `anos_presentes` vinha com lixo).
- **Verificação**: `51065592`→`510340`; `35051780`→`355030`; privada→`habilitado=0`;
  job real `["510340",2024]`. Teste cobre **prefixo ≠ município**.
- **Testes**: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (68 ok).
- **Deploy**: `deploy_backend_dev` (sem migração/frontend).

## Sessão — Buscar dados do SIOPE pelo Painel Financeiro

- **Repo** `edumaps`; branch `feat/financeiro-siope` (a partir de `origin/main`);
  commits `ef38fa0` (backend), `468ba80` (frontend), `cd04f9a` (docs). **PR #86**
  → `main`, merge commit **`630c627`** (2026-09-21). `main` == `origin/main`.
- **Contexto**: a task `query_siope` (Minion) já baixa a planilha do FNDE e
  popula `clean.remuneracao_municipal`; testada em `t/05-tasks/siope.t`.
- **Entregas**:
  - backend: `School::Finance#siope_status`/`siope_disponivel` (rede com fallback
    no censo `tp_dependencia=3`; município = prefixo de 6 dígitos do INEP; anos
    já baixados **por município**) e `financial_summary` com `escola.
    dependencia_administrativa`, `escola.cod_municipio` e bloco `siope`.
    Novo `POST /api/gestor/:cod_inep/financeiro/siope` (auth do gestor; 422 se
    não municipal; 400 fora de 2020..atual; 409 se o ano já existe) → enfileira
    `get_siope` → 202 + `Location`.
  - frontend: card **SIOPE** no `SchoolFinancePage` (só gestor autenticado da
    escola municipal): drop list 2020..atual menos já baixados + botão, com
    **progresso via SSE** (`EventSource` + snapshot final no `onerror`) e recarga
    ao concluir. `schoolApi`: `requestSchoolSiope`, `watchJobProgress`.
  - docs: `docs/funcionalidades/analise/financeiro.md` atualizado (novo passo do
    workflow).
- **Decisões**: endpoint school-scoped sob a auth do gestor · SSE · faixa
  2020..atual · exclusão por município · card oculto para não-logado.
- **Armadilha**: o SSE do `monitor_job` **não emite falha** (só progresso) —
  ao fechar o stream, o frontend lê o snapshot (`GET /api/task/progress`) para
  decidir sucesso/erro.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (68 ok;
  novo `finance_siope.t`); frontend `SchoolFinancePage.test.js` (4 ok); suite
  completa 300 ok (4 falhas pré-existentes). Smoke real: `siope.habilitado=1`,
  POST → 202, progresso `active`, sem sessão → 401.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev` (sem migração).

## Sessão — Catálogo de Funcionalidades (`docs/funcionalidades/`)

- **Repo** `edumaps`; branch `docs/funcionalidades` (a partir de `origin/main`);
  commit `2fde95e`. **PR #85** → `main`, merge commit **`a154a1b`** (2026-09-21).
  `main` == `origin/main`.
- **Objetivo**: ponto central de documentação **funcional** em markdown, de alto
  nível (capacidades de negócio, sem rotas/arquivos/funções), para síntese
  (PDF/wiki) e para o Workflow manter atualizado a cada mudança.
- **Entregas**:
  - `docs/funcionalidades/`: `README.md` (índice/síntese), `_template.md`
    (front-matter YAML: `titulo`, `modulo`, `status`, `audiencia`,
    `relacionadas`) e **20 capacidades** por módulo:
    - `busca/`: escolas🟢, similaridade🟢, analises⚪, pessoas⚪;
    - `analise/`: painel-escola, ranking, clusters, rede-municipal, financeiro,
      folha-pagamento (🟢);
    - `gestor/`: acesso, painel, pesquisas, reunioes-atas, contatos-grupos,
      inventario, relacoes-institucionais (🟢);
    - `comunidade/`: resposta-pesquisa🟢;
    - `plataforma/`: fontes-de-dados🟢, privacidade-lgpd🟢.
  - `AGENTS.md`: novo passo **3. Documentação funcional** (após a Execução; passos
    seguintes renumerados 4–8) + seção "Documentação funcional" com estrutura,
    template, status e anti-padrão.
  - `docs/indice.md`: seção "11. Funcionalidades (catálogo)".
- **Status**: 🟢 ativo · 🟡 parcial · ⚪ planejado · 🔴 descontinuado.
- **Escopo**: docs-only (`docs/`, `AGENTS.md`) → **sem deploy**.

## Sessão — Landpage e acessos ao Painel do Gestor

- **Repo** `edumaps`; branch `feat/landpage-gestor` (a partir de `origin/main`);
  commit `18b8d94` (frontend). **PR #84** → `main`, merge commit **`29c72f1`**
  (2026-09-21). `main` == `origin/main`.
- **Objetivo**: refletir a maturidade (busca + análise **+ gestão**) na landpage
  e no banner, com fluxo natural de cadastro/login do gestor a partir da escola.
- **Entregas (só frontend)**:
  - Landpage: pilar **"Gestão escolar"** + CTA **"Sou gestor"** → `/gestor`.
  - Banner (`app/App.svelte`): link **"Gestor"**.
  - **Nova página `/gestor`** (`GestorAcessoPage.svelte`): abas **Já tenho conta**
    (reusa `GestorLoginCard`, agora com props `titulo`/`descricao`) e **Criar
    conta** (INEP pré-preenchível, nome, e-mail, senha + telefone/cargo); já
    logado → atalho ao painel + Sair; login/cadastro → `/gestor/painel?inep=`
    (cadastro faz auto-login).
  - **"Você é o gestor?"** no card da escola (`?inep=&modo=cadastro`), no painel
    público da escola e no cabeçalho da busca.
- **Decisão**: **sem validação de titularidade**; reusa `POST /perfil`, `/login`,
  `/me` (nenhuma alteração de backend).
- **Testes**: 5 arquivos → 30 ok; suite completa **296 ok** (4 falhas
  pré-existentes). Build ok (`deploy_frontend_dev`).
- **Deploy**: `deploy_frontend_dev` (sem migração/backend).

## Sessão — Relações Institucionais: Etapa 5 (tarefas + indicadores)

- **Repo** `edumaps`; branch `feat/relacoes-tarefas` (a partir de `origin/main`);
  commits `f06d2b8` (data_pipeline), `5f8ce06` (backend), `5760c1f` (frontend).
  **PR #83** → `main`, merge commit **`0226819`** (2026-09-21). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `relacoes_tarefas` (checklist por relação: descrição,
    responsável, prazo, status `pendente|concluida`, `concluida_em`; FK CASCADE).
  - backend: CRUD de tarefas por relação (o detalhe passa a incluir `tarefas`);
    `GET /relacoes/indicadores` (derivado, sem tabela) com resumo, demandas por
    grupo, relações sem atividade (60 dias) e tempo médio até a 1ª interação.
  - frontend: checklist de tarefas no detalhe e aba **Indicadores** em
    `/gestor/relacoes`.
- **Fora do escopo (documentado)**: **grafo institucional cross-escola**
  ("fornecedores atendem várias escolas") — exige política de
  agregação/anonimização entre escolas; os indicadores entregues são por escola.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (63 ok);
  frontend (container) `npx vitest run src/features/gestor` (118 ok); suite
  completa 290 ok (4 falhas pré-existentes). Smoke real: tarefa 201, indicadores
  `abertas=1`/`vencidas=1`/`tarefas_pendentes=1`.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Status do módulo de Relações Institucionais**: Etapas 1–5 concluídas.

## Sessão — Relações Institucionais: Etapa 4 (interações + documentos)

- **Repo** `edumaps`; branch `feat/relacoes-gestao` (a partir de `origin/main`);
  commits `aa3e788` (data_pipeline), `083f368` (backend), `8c5c2c7` (frontend).
  **PR #82** → `main`, merge commit **`2cbbb90`** (2026-09-21). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `relacoes_gestao` — `relacoes_interacoes` (timeline:
    data/canal/participante/assunto/descrição/resultado) e `relacoes_documentos`
    (tipo/data/referência + arquivo no `upload_dir`), FK `relacoes` `ON DELETE
    CASCADE`.
  - backend: CRUD de interações e documentos (upload/download/delete) por
    relação; `relacao_detail` devolve `interacoes` e `documentos`; excluir a
    relação remove os arquivos do disco. Rotas `.../relacoes/:id/interacoes[/:interacao_id]`
    e `.../relacoes/:id/documentos[/:documento_id]` (constraints arrayref).
  - frontend: `RelacaoDetailPage.svelte` em `/gestor/relacoes/:id` (resumo,
    timeline de interações, documentos anexar/baixar/remover) + link "Abrir" na
    lista.
- **Armadilha**: um `}` sobrando no `.svelte` só apareceu no `vite build` (o
  build/deploy é a validação real do frontend).
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (61 ok);
  frontend (container) `npx vitest run src/features/gestor` (115 ok); suite
  completa 287 ok (4 falhas pré-existentes). Smoke real: interação 201,
  documento anexado, detalhe com `interacoes`/`documentos`.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Pendência/próxima etapa**: Etapa 5 (tarefas + indicadores/rede).

## Sessão — Relações Institucionais: Etapa 3 (Agenda institucional)

- **Repo** `edumaps`; branch `feat/relacoes-agenda` (a partir de `origin/main`);
  commits `5475720` (backend), `c2ab6e0` (frontend). **PR #81** → `main`, merge
  commit **`cfb31ae`** (2026-09-21). `main` == `origin/main`.
- **Sem tabela nova**: a agenda é **derivada** de `clean.relacoes`.
- **backend**: `agenda_relacoes` — relações abertas com prazo e/ou próxima ação,
  ordenadas por prazo, recorte `de`/`ate`, separação das **sem prazo** e contagem
  de **vencidas**. Rota `GET /api/gestor/:cod_inep/relacoes/agenda` (literal
  antes de `/:id`).
- **frontend**: aba **Agenda** em `/gestor/relacoes` — agrupamento por mês,
  destaque de vencidas, recorte por data e seção "Sem prazo definido";
  `getAgenda` + handler MSW.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (59 ok);
  frontend (container) `npx vitest run src/features/gestor` (111 ok); suite
  completa 283 ok (4 falhas pré-existentes). Smoke real: `total=2`,
  `vencidas=1`, 1 com prazo e 1 sem prazo.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev` (sem migração).
- **Pendências/próximas etapas**: Etapa 4 (interações + documentos/anexos) e
  Etapa 5 (tarefas + indicadores/rede).

## Sessão — Relações Institucionais da escola (entidades + relações, MVP)

- **Repo** `edumaps`; branch `feat/relacoes-gestor` (a partir de `origin/main`);
  commits `dfed292` (data_pipeline), `27629a6` (backend), `31db7bc` (frontend).
  **PR #80** → `main`, merge commit **`2c2b54b`** (2026-09-20). `main` == `origin/main`.
- **Fonte**: `~/Documents/Notas/gestor_relacoes.md` (discussão de categorias,
  taxonomias e operações). **Decisões do usuário**: MVP = Etapas 1+2; taxonomia
  editável semeada; responsável interno em texto livre; fornecedores separados do
  inventário; anexos só na Etapa 4; status/prioridade enums fixos; painel
  "Relações da escola" em `/gestor/relacoes` com link "🤝 Relações".
- **Entregas**:
  - data_pipeline: `relacoes_categorias` (eixo `entidade|finalidade`, origem
    `padrao|manual`, UNIQUE `cod_inep+eixo+lower(nome)`), `relacoes_entidades`
    (atores externos + `atributos jsonb`) e `relacoes` (centro: entidade →
    assunto/finalidade/responsável/próxima ação/prazo; `status` e `prioridade`
    com CHECK; FK entidade `ON DELETE RESTRICT`).
  - backend: `Roles::Business::Gestor::Relacoes` — `sincronizar_categorias_padrao`
    (7 grupos + 10 finalidades), CRUD de categorias/entidades/relações e filtros
    (`status`, `prioridade`, `vencidas`, `entidade_id`, `q`); `vencida` derivado.
    Rotas `/api/gestor/:cod_inep/relacoes[/...]` (constraints arrayref).
  - frontend: `/gestor/relacoes` (abas Relações/Entidades externas, filtros,
    badges, destaque de vencidas, modais) + link no painel.
- **Armadilha (Role::Tiny "last wins" é falso na prática)**: `list_categorias`/
  `create_categoria`/`update_categoria`/`delete_categoria` do módulo Relações
  colidiam com `Inventario.pm` (composto **antes**) e as chamadas caíam na versão
  do inventário. Renomeados para `*_relacoes_categoria(s)`. **Ao compor várias
  roles no mesmo Model, use nomes de método únicos por módulo** — ou confira qual
  role vence. (O mesmo vale para helpers `_rows/_row/_txn`/`_encode_atributos`:
  manter cópias idênticas.)
- **Não é CRM**: o centro é a relação; sem leads/oportunidades/pipeline.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (58 ok);
  frontend (container) `npx vitest run src/features/gestor` (109 ok); suite
  completa 281 ok (4 falhas pré-existentes). Smoke real: 17 categorias, entidade
  e relação criadas (201).
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Pendências/próximas etapas**: Etapa 3 (Agenda institucional), Etapa 4
  (interações + documentos/anexos), Etapa 5 (tarefas + indicadores/grafo da rede).

## Sessão — Limpeza do backlog técnico (turno, timestamps, 404)

- **Repo** `edumaps`; branch `fix/backlog-tecnico` (a partir de `origin/main`);
  commits `87f0d27` (data_pipeline), `80c7eea` (backend). **PR #79** → `main`,
  merge commit **`f8c3312`** (2026-09-20). `main` == `origin/main`.
- **[alta] `info_enrollment` somava TURNO como deficiência**:
  `deficiencia_basica` = `qt_mat_bas_d + dm + dv`, mas `_d/_dm/_dv/_n` são
  **Diurno/Matutino/Vespertino/Noturno** (validado: `dm+dv=d` e `d+n=total` em
  **100%** das linhas; `avg(d/bas)=0,934`, `avg(esp/bas)=0,056`). Removido o
  campo e adicionado o bloco **`turno`** (diurno/matutino/vespertino/noturno/
  integral). Educação especial fica em `especial`/`esp_cc_total`/`esp_ce_total`
  (`qt_mat_esp*`). `info_enrollment` **não é exposta por controller** — só o
  teste `t/02-models/school/matricula.t` a usa.
- **Comentários das 60 colunas de turno** estavam rotulados como "Deficiência"
  pelo loader. Nova migração **`censo_turno_comments`** (60 `COMMENT ON COLUMN`)
  + POD de `Schema/Result/CensoMatriculas.pm` (replace global).
- **[média] `upsert_gestor`**: `RETURNING` agora inclui `created_at, updated_at`.
- **[baixa] `Pesquisa#index`**: `?inep` ausente → 400; formato inválido → 404
  (padrão do projeto p/ `codigo_ibge`, via constraint de rota).
- **Correção de registro**: a observação do PR #78 sobre `scores_view.sql`/
  `badge_functions.sql` usarem `in_in_*` era **falsa** (usam
  `in_material_ped_*`); corrigida no corpo do PR #78.
- **Testes**: `prove -vl t/02-models/school/matricula.t t/04-api/pesquisa.t`
  (PASS; novos asserts de `turno`/`DNE`/timestamps/404) e
  `prove -rl t/04-api/gestor/` (41 ok). Smoke real: `?inep=abc`→404, sem
  `inep`→400, `POST /perfil` com timestamps.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` (sem frontend).

## Sessão — Painel de Inventário Escolar (recursos e serviços)

- **Repo** `edumaps`; branch `feat/inventario-escolar` (a partir de `origin/main`);
  commits `eb574c7` (data_pipeline), `331a236` (backend), `a547c20` (frontend).
  **PR #78** → `main`, merge commit **`dc16c3c`** (2026-09-20). `main` == `origin/main`.
- **Decisões do usuário**: baseline **derivado do Censo ao vivo** (nunca copiado
  no banco); itens/serviços **unificados** (tipo vem da categoria); **semear a
  taxonomia do Censo** (9 categorias); **importar do Censo**; **anexos no v1**
  (vários por item); obrigatórios `nome`+`categoria` (`quantidade`/`valor`
  opcionais); **qualquer gestor** edita; sem catálogo global (por escola).
- **Entregas**:
  - data_pipeline: `inventario_categorias` (tipo recurso/servico, origem
    censo/manual, UNIQUE `cod_inep+tipo+lower(nome)`), `inventario_fornecedores`,
    `inventario_itens` (recursos e serviços, `atributos jsonb` + GIN,
    `censo_ref` UNIQUE parcial p/ import idempotente) e `inventario_anexos`
    (vários por item).
  - backend: `Roles::Business::Gestor::Inventario` — `inventario_censo` (lê
    `clean.censo_escolas`, 6 grupos), `sincronizar_categorias_censo` (lazy),
    `importar_censo` (idempotente por `censo_ref`), CRUD de
    categorias/itens/fornecedores e anexos. Rotas
    `/api/gestor/:cod_inep/inventario[/...]` (constraints arrayref).
  - frontend: `/gestor/inventario` (abas Do Censo/Recursos/Serviços/
    Fornecedores, modais, atributos livres chave-valor, anexos) + link no painel.
- **Técnica de flexibilidade**: nenhuma coluna nova para criar categoria/item —
  categorias livres + `atributos jsonb`; arquivos de anexo em `upload_dir`.
- **Armadilhas**: (1) colisão de métodos de role — `registrar_anexo`/`anexo_row`
  do Inventário colidiam com Reuniões (Role::Tiny mantém o da **primeira** role);
  renomeados para `registrar_anexo_item`/`anexo_item_row`/etc. (2) `$anexo_check`
  com arrayref aninhado quebra constraints (deve ser lista plana). (3) `num` só
  inteiro (ver convenção). (4) backend de container usa banco `Database` (ver
  convenção) — migração aplicada em `ubatexu.lan` **e** `Database`.
- **Testes**: backend `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` (53 ok);
  frontend (container) `npx vitest run src/features/gestor` (102 ok); smoke real
  `GET /inventario` (9 categorias + baseline), `POST /importar-censo` → 39 itens,
  reimport → 0.
- **Deploy**: migração em `ubatexu.lan` + `Database`; `deploy_backend_dev` +
  `deploy_frontend_dev`.

## Sessão — Reuniões e atas do gestor (agenda, contatos e anexos)

- **Repo** `edumaps`; branch `feat/reunioes-gestor` (a partir de `origin/main`);
  commits `196497d` (data_pipeline), `6bc6d4f` (backend), `0974a5a` (frontend).
  **PR #77** → `main`, merge commit **`fde99b2`** (2026-09-20). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `gestor_reunioes` (contato_grupos, contatos, reunioes,
    reunioes_participantes, reuniao_anexos) e `gestor_reunioes_grupos_folha`
    (origem folha/manual, `gestor_id` opcional).
  - backend: módulo Reuniões & Atas (CRUD de contatos/grupos, agenda, ata e
    anexos em `upload_dir`), `perfil_escola`/`transferencia` (gestor responsável
    pela agenda = criador da 1ª reunião), auto-cadastro governado (409 para
    e-mail novo em escola com agenda) e task `GruposFolha` (seed idempotente).
  - frontend: páginas de contatos e reuniões (lista com filtros, wizard de 4
    passos, detalhe com ata/anexos), `apiClient.upload/download` (multipart +
    blob) e link "Reuniões da escola" no painel do gestor.
- **Decisões**:
  - Rotas novas usam **arrayref** de constraints — hashref vira defaults (ver
    convenção durável); foi a causa do 401 em `/api/gestor/pesquisas`.
  - `QUANDO_RE` aceita `[ T]` (o `buildReuniaoPayload` do frontend envia espaço).
  - `_render_validation` (Gestor e Pesquisa) mapeia o check para mensagem PT-BR
    (antes expunha `like`/`size`); correção do "❌ like" no botão "Agendar".
  - Edição preenche o `datetime-local` com `T` (formato válido do input).
- **Testes**: backend `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` (46 ok);
  frontend (container) `npx vitest run src/features/gestor` (94 ok); smoke real
  `POST /api/gestor/:inep/reunioes` com data do frontend → 201.
- **Deploy**: `deploy_frontend_dev` + `deploy_backend_dev` (dev).
- **Pendências**: `_reuniao_validation` calcula `$input->{__duracao}`/`__aviso`
  que o controller ignora (código morto; default aplicado no model). O diretório
  `docs/clients/` do branch `docs/clients-apresentacao` ficou fora daquele PR —
  **entrou depois, no PR #76, mergeado em 2026-09-28** (rebased sobre o `main`
  novo; a inserção da sessão acima respeita a ordem cronológica do arquivo).

## Sessão — Documentos de potencial (gestor público + investidor privado) (2026-09-19)

- **Repo** `edumaps`; docs-only (sem deploy). Branch `docs/clients-apresentacao`.
- **Entregáveis** (novos, em `docs/clients/`):
  - `docs/clients/gestor/potencial.md` — apresenta o EduMaps ao **gestor público**
    em linguagem simples, **sem monetizar a relação** (zero preço/cobrança):
    intro do setor, o que é a plataforma, **dores → soluções** (tabela), cenário
    de uma semana, privacidade/LGPD, como começar (piloto).
  - `docs/clients/privado/setor.md` — apresenta o EduMaps a um **investidor de
    rede privada/edtech** com ênfase **financeira**: intro do setor, capital de
    dados, segmentos-alvo, **modelos de receita com faixas ilustrativas**
    (SaaS rede privada R$ 1,2k–4,8k/escola/ano; licença municipal R$ 30k–120k/ano;
    projeto estadual/federal R$ 200k–500k; API R$ 20k–80k; impl 15–30%), economia
    da unidade (margem SaaS 70–80%; B2G 50–65%), riscos/mitigação, go-to-market
    em 4 fases e o que o aporte habilita. Valores marcados como "exemplo ilustrativo".
  - `docs/clients/Makefile` — `make pdf` gera ambos os PDFs via
    `pandoc --pdf-engine=weasyprint --toc` (`.gitignore` com `*.pdf`; PDFs são
    artefatos locais, não commitados).
- **Decisões do usuário**: caminho padronizado **`docs/clients/`** (plural) nos
  dois; entregar **md + script de PDF**; profundidade financeira = **faixas ilustrativas**.
- **Fatos do setor usados (fontes citadas nos docs)**: Censo Escolar 2025 →
  46,0 M de matrículas e queda de ~1 M em 1 ano (2024→2025); Censo 2024 → 179,3 mil
  escolas e rede privada ~20% das matrículas (+1% vs pública caindo); Fundeb
  ~R$ 341 bi (2025) → ~R$ 370 bi (2026) com complementação da União ~R$ 69 bi
  (Portaria Interministerial MEC/MF 14/2025, FNDE). VALIDADO via websearch —
  não inventar números do setor sem fonte.
- **Validação local**: `make pdf` OK (gestor 5 pág., setor 8 pág., TOC+tables).
- `docs/indice.md` ganhou seção "Clientes / apresentação".

## Sessão — Pesquisas do gestor (fase 2: link público + login + resultados)

- **Repo** `edumaps`; branch `feat/pesquisas-gestor-fase2`; commits:
  `7c17a06` (data_pipeline: migração `gestor_respostas`), `6fdd9d5` (backend:
  coleta pública/login/resultados), `ff00633` (frontend fase 2), `14b683f`
  (fix backend: `/publica/` sem token → 404 em vez de 500). **PR #75** →
  `main`, merge commit **`837c573`** (2026-09-19). `main` == `origin/main`.
  memory+nota técnica no commit `52553be`. Números: backend 12/12 PASS;
  frontend novo 53 PASS; suite completa 230/234 (4 falhas pré-existentes).
- **Escopo fase 2** (decisões do usuário): link público **`/p/<token-uuid>`**
  (UUID aleatório por pesquisa — impede enumeração por id); bloqueio leve
  "já respondeu" por dispositivo (`edumaps_dispositivo_id` em localStorage +
  UNIQUE no servidor, 409); **login do gestor** (`POST /api/gestor/login`,
  `GET /me`, `POST /logout`; senha no `POST /perfil` 6..64, hash
  HMAC-SHA256+salt em `clean.gestores.senha_hash`); sessão bearer em
  `clean.sessoes` (expira 30 dias); escrever/publicar **não** exigem login;
  **resultados exigem sessão do gestor da mesma escola** (403 se `cod_inep`
  diverge); gráficos em **SVG puro** (componente `OpcaoBars`, sem charts lib).
- **Schema**: nova migração `gestor_respostas [gestor_pesquisas]`
  (`token` uuid, `senha_hash`, `clean.sessoes`, `clean.gestor_pesquisas_respostas`
  + `_itens`). Aplicada em `database.edumaps` via `deploy_db_dev` e local
  via psql manual (sqitch registry local desyncado — passada manual como na
  fase 1).
- **Backend**: `Roles/Business/Pesquisa/Respostas.pm` (novo) — `survey_for_public`,
  `register_answer` (valida por pergunta: exatamente uma opção p/ unica/dropdown,
  texto 1..500, UNIQUE dispositivo → 409 `already_answered`), `survey_results`
  (contagem/pct + textos livres). `Gestores.pm` ganhou login/me/logout/sessão.
  `Controller/Pesquisa.pm`: `_require_gestor` (under bearer; **retorna 0** após
  render de 401), `publica_form/publica_resposta`, `resultados` (403 por escola),
  `_valid_public_token` (guarda contra `qr` injetado por Mojolicious no segmento
  vazio → "Cannot bind a reference").
- **Frontend**: `routes.js` agora faz match segmento a segmento (`matchRoute`
  retorna `{path, component, params}`); `App.svelte` renderiza `/p/:token` sem
  nav/Toast (full-bleed) e injeta os params. `client.js` ganhou
  `setApiToken/getApiToken` (injeta `Authorization: Bearer` em toda request).
  Feature `resposta/` (página pública) + `GestorLoginCard` + `OpcaoBars` +
  `GestorPesquisasResultadosPage` (login se 401, "Sair", volta à lista).
  `GestorPesquisasPage`: "Copiar link" + "Resultados" para publicadas.
  MSW com auth exigida (`Authorization: Bearer 88888888-…`).
- **E2E (container)**: fluxo completo passou — perfil→login(ok/401)→
  create(`perguntas:[]`)/PUT/finalizar→publica form→resposta(ok/409)→
  resultados(401/200)→logout invalida `/me`. `/p/<uuid>` servido pelo nginx
  (fallback SPA 200). Deploy: `rex prepare` + `deploy_db_dev` +
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Nota técnica**: `docs/new_ideas/implementations_ideas/notas_tecnicas_43.md`.

## Sessão anterior — Pesquisas do gestor (fase 1: cadastro + criação/gestão)

- **Repo** `edumaps`; **PR #74** (`feat/gestor-pesquisas`) → `main`, merge commit
  **`1235494`** (2026-09-19). Commit único `67ba676` (33 files, +2877). `main` ==
  `origin/main`. **Migração Sqitch** `gestor_pesquisas [schemas]` aplicada nos
  dois alvos: `database.edumaps` (containers, via `rex deploy_db_dev`) e local
  (`ubatexu.lan/edumaps_dev`, via psql manual — o alvo `dev_super` NÃO tem
  pgvector e não consegue deploiar a cadeia completa).
- **Escopo fase 1** (decisões do usuário): apenas criação/gestão; identidade
  anônima `?inep=` (sem login); autosave no servidor (debounce 600ms, sem botão
  salvar); 1 gestor = 1 escola (`cod_inep`); nome/e-mail obrigatórios (e-mail
  identifica a sessão → upsert), telefone/cargo/CPF opcionais; **LGPD: CPF
  sempre mascarado na API** (`***.***.***-123`, `cpf_masc`); sessão via
  localStorage (`edumaps_gestor_<inep>`). Coleta de respostas, login e
  gráficos → **fase 2**.
- **Schema**: `clean.gestores`, `clean.gestor_pesquisas`,
  `clean.gestor_pesquisas_perguntas` (FK cascade; `opcoes` JSONB; `id` de opção
  preservado do uuid do wizard; `status` com CHECK `rascunho|publicada|arquivada`).
- **Backend** `Plugin/API/Pesquisa.pm` (base `/api/gestor/pesquisas`):
  `POST /perfil` (upsert por e-mail), `GET /` (`?inep=`), `POST /` (cria
  **rascunho com 0 perguntas** — autosave ao digitar o título), `GET|PUT|DELETE
  /:id`, `POST /:id/finalizar`. Regras: `publicada` é **read-only** (PUT/DELETE →
  409); `finalizar` exige ≥1 pergunta; `_survey_payload` valida 0..30 no
  create/update; formato inválido de `inep` → 400 (decidido). Model compõe
  Roles `Gestores` + `Surveys` (Role::Tiny, SQL raw via `dbh_do`).
- **Armadilhas de implementação no backend**:
  - Mojolicious 9.49 **não tem check `length`** — validar tamanho com
    `size(min, max)` (built-ins: `equal_to/in/like/num/size/upload`).
  - `txn_do` retorna o valor da **última expressão do bloco**; um `for (...)`
    como última expressão devolve falsy → `update_survey` dá resultado próprio
    (re-registra o survey e relê o detail) em vez de depender do retorno.
  - `survey_detail` monta `gestor` (nome/email) **antes** de remover os campos
    do hash (senão sumiam do join).
  - DELETE 204 exige `render(status => 204, text => '')` (senão "Could not
    render a response").
- **Frontend** (pastas em `features/gestor/`):
  - `pages/GestorPesquisasPage.svelte` (`/gestor/pesquisas?inep=` — lista por
    status, excluir rascunho com `confirm`, banner do gestor/sessão) e
    `pages/GestorPesquisasWizardPage.svelte` (nova/editar; `readonly` se
    `publicada`).
  - `components/survey/{SurveyWizard,StepsIndicator,PhoneMockup,QuestionEditor}.svelte`
    — wizard: passo gestor → dados → **1 pergunta por tela** → revisão/finalizar;
    preview em moldura de celular; autosave `PUT`/`POST`; `beforeunload` flush.
  - `utils/pesquisaDraft.js` (modelo local: `emptyDraft/newPergunta/
    surveyToDraft/draftToPayload/perguntaErros/tituloValido/
    draftValidoParaFinalizar`) e `utils/gestorSession.js` (localStorage);
    `constants/pesquisas.js` (ANSWER_TYPES, LIMITS); `api/gestorPesquisasApi.js`;
    `mocks/{handlers,fixtures}.js` registrados no barrel `src/mocks/handlers.js`.
  - `apiClient` ganhou `put`/`delete` (`src/shared/api/client.js`).
  - **Pitfalls do wizard (Svelte 5)**: `stepKeys` é `$derived` — navegar por
    chave (`goToKey('info'/'revisao'/'q<n>')` com `tick()` após `push`) em vez
    de índices; `addPergunta` usa `tick().then()` porque o derivado ainda não
    recompilou ao setar `step`.
  - **`questionIndex`/`QuestionEditor` mutam o objeto `pergunta` do
    `$state` do rascunho** (não copiar — Svelte 5 rastreia a mutação).
- **Testes**: backend `prove -l t/04-api/pesquisa.t` **8/8 PASS** (local; push
  de fixtures via SQL manual no `ubatexu` porque o cluster local não tem
  pgvector). Frontend `vitest src/features/gestor` **49/49 PASS** (container);
  as 4 falhas de `paginationStore`/`SchoolRankingPage` na suite completa são
  **pré-existentes** (confirmado stashando minhas mudanças no container).
  Testing-library: usar `getByRole('heading', …)` quando o passo aparece no
  StepsIndicator E no `<h2>` (multi-match); resetar mocks manuais entre testes
  (`vi.clearAllMocks()` — vitest não limpa `vi.fn()` por padrão).
- **Deploy**: `rex prepare` (rsync) + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev`. E2E via curl **dentro do container**
  (`ssh root@backend.edumaps 'curl -H "Host: ubatexu.lan" http://127.0.0.1:3000/...'`
  — `:3000`/morbo não é exposto ao host; `backend.edumaps` vindo do host não
  resolve). Fluxo completo validado e **dados de teste removidos** (psql no
  `database.edumaps` user `edumaps`). O container roda **Perl 5.36** (testes
  backend rodam só local, precisam de 5.38+ p/ `feature ':5.38'`).

## Sessão — eduBR: random forest p/ classificar desempenho (fund. I/II)

- **Repo** `~/Projects/eduBR`; **PR #2** (`feat/edubr-random-forest-desempenho`)
  → `main`, merge commit **`cdd741f`** (2026-09-18). Dois commits: `b070451`
  `feat(edubr): random forest p/ desempenho` + `02e3878`
  `docs(edubr): report RF de desempenho (fund I/II)`. `main` == `origin/main`.
- **Modelo**: classificar **escolas públicas** (fund. I/II) em
  **alto/médio/baixo** pelos **terços globais** de `nota_media` (SAEB
  matemática+português, IDEB 2023) com **Random Forest (ranger)** sobre a MV
  `analytics.escola_features` (`analytics.prepare_school_data()`: censo 2025 ×
  nota 2023 → **associativa/diagnóstica**, não previsão). Referências:
  `~/Documents/Notas/pesquisa.md` (Fusco et al. 2025; Cechinel et al. 2026,
  *Scientific Reports* — RF + importância p/ reduzir dimensão).
- **`R/desempenho.R`**: `features_escola()` (lazy; `tp_dependencia ∈ {1,2,3}`),
  `classificar_desempenho()` (tercis por etapa → fator ordenado `baixo/medio/alto`),
  `limites_desempenho()` (vetor simples se 1 grupo, senão lista nomeada).
- **`R/floresta.R`**: `dividir_dados()` (estratificado), `treinar_floresta()`
  (ranger `classification+probability+importance="permutation"`; **exclusão
  padrão inclui identificadores espaciais** `sg_uf/uf/co_municipio/...` — UF
  é rótulo de agregação, nunca preditor — pegadinha corrigida no meio da
  rodada), `importancia_floresta()`, `predizer_floresta()`
  (`nivel_pred` + `p_<classe>`), `metricas_floresta()` (acuracia, F1/AUC macro
  por postos/Wilcoxon, `baseline_acerto`; attrs `confusao`/`f1_classe`/
  `auc_classe`). `ranger` em **Suggests** (não usar `vip`: só instala no
  container; daria NOTA no check).
- **Resultados reais**: tercis fund. I = 5,42/6,26; fund. II = 4,72/5,33.
  Com acc. 0.594/0.566 vs baseline 0.333; AUC macro 0.78/0.76; **top-15
  features preserva desempenho** (0.575/0.541); variante **sem INSE** cai
  ~0.05 (NSE domina, mas sobra sinal estrutural). N da base: 41.229 (fund. I)
  e 31.078 (fund. II) públicas com nota.
- **Report**: `analysis/classificacao_desempenho_rf.Rmd` (pipeline por etapa,
  confusão, importância top-20, perfil por nível, % por UF via
  `clean.ideb_notas_escolas.id_escola == co_entidade`). Snapshot de dados em
  `analysis/capturar_dados_rf.R` → `analysis/dados_classificados_rf.rds`
  (`analysis/*.rds` e `tests/testthat/_problems/` gitignored).
- **Execução/testes SEMPRE no container `rstudio.dev` (rsuser)** — nunca
  local. Suite verde (só smoke requer `EDUBR_SMOKE=1`, que também passa);
  `devtools::check()` 0/0/0. Sync via `tools/sync-rstudio.sh` (post-commit).
- **Limites do container**: enlace c/ `Database` intermitente (pulls grandes
  às vezes morrem sem rastro) → **snapshot RDS**; treino com base completa
  estoura memória (**OOM `Killed`**, host ~8 GB) → **amostra estratificada de
  15k escolas/etapa** (`n_amostra`), `num.threads = 2`, `trees = 250`; render
  em background (`nohup /tmp/render_rf.sh`, log em `/tmp/render_rf.log`).
  knitr não renderiza ggplot dentro de listas de `map()` → `|> lapply(print)`.
- **Pendências**: `analytics.view_escolas_ml` é o caminho futuro p/ previsão
  (forecasting) — report documenta que a análise atual é associativa.

## Sessão atual — Busca por escolas similares no painel do gestor

- **PR #72** (`feat/escolas-similares`) → `main`, merge commit **`5e55dfa`**
  (2026-09-18). Commits `e85a8d5` (backend), `bf8f9c5` (frontend), `5f3ba49`
  (docs: nota técnica 40).
- **Backend**: rota **`GET /api/gestor/:cod_inep/similares`** — nova role
  `Roles::Business::Gestor::SimilarSchools` (`similar_schools`, SQL raw via
  `dbh_do`, `$FEATURE_VECTOR`). Similaridade = cosseno pgvector (`<=>`) **on-the-fly**
  (sem migration), **10 dims**: porte (ordinal 0..1 das 6 categorias de
  `clean.escolas.porte_escola`), localização (urbana 1/rural 0 via
  `tp_localizacao`), INSE (`media_inse_alvo/10`; **0 quando o alvo não tem INSE** =
  comparação neutra), 7 etapas one-hot (`in_comum_creche/pre/fund_ai/fund_af/
  medio_medio`, `in_eja`, `in_profissionalizante`). Escopo município/estado/região
  (default município); limit clamp 1..50 (default 10); 404 para INEP inválido.
- **Armadilhas SQL (validado na prática)**:
  - `ARRAY[...]::vector` quebra com NULLs → `COALESCE` nos flags de etapa;
  - `ROUND((1 - (v <=> v))::numeric, 4)` no SQL dá "syntax error at or near AS" →
    arredondar no Perl (`sprintf('%.4f', ...)`), sem cast no SQL;
  - **`CASE WHEN ? IS NULL`** falha em prepared statement server-side
    ("could not determine data type of parameter $1") → cast explícito
    `?::numeric IS NULL`;
  - clamp: `$limit = 10 if $limit < 1 || $limit > 50` trocava `999` por 10 (deveria
    ser 50) → corrigido para `$limit = 1 if $limit < 1; $limit = 50 if $limit > 50`.
- **Frontend**: `SimilarSchoolsSearch.svelte` (dropdown `SCOPE_OPTIONS` + botão
  Buscar + `LeafletMap` + `SimilarMarkers` — alvo azul `#2563eb`, similares laranja
  `#f97316` — + tabela com links `/escola/panel?inep=`); seção `#escolas-similares`
  no `GestorPanel`; `getSchoolSimilares(codInep, {scope, limit})` em `gestorApi.js`.
  INSE ausente na UI → "—" e texto "INSE ausente é ignorado na comparação".
- **Testes**: backend `prove -l t/04-api/gestor/` (painel+similares) 10 PASS;
  frontend gestor 20 PASS no container. `t/04-api/gestor/similares.t` skip local
  (cluster antigo sem pgvector) — happy path só no container app.
- **Deploy**: `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev`.
- **E2E (container, `-H "Host: ubatexu.lan"`)**: município/estado/região corretos;
  região multi-UF (AM/PA/RR); similaridades 0.8381..0.9921; clamp 999→50, 0→1;
  SPA `/gestor/painel` 200.
- Dados úteis: `clean.inse` cobre só ~39% (69.756) das escolas; INSE ausente no alvo
  neutraliza a dimensão (não cobra das candidatas).

## Sessão anterior — Painel do Gestor (`/gestor/painel`)

- **PR #71** (`feat/painel-gestor`) → `main`, merge commit **`82ccb80`**.
  Commits `9e743d4` (backend), `63dc345` (frontend), `45c9d96` (memória).
- **O quê**: nova rota **`/gestor/painel?inep=…`** com **API isolada**
  `GET /api/gestor/:cod_inep/painel`. Raio-x da escola para leitura em ~2 min:
  matrículas por **etapa, turno, modalidade e faixa etária**; salas; docentes
  por **formação, vínculo e disciplina**; **infraestrutura**, **equipamentos**
  e **acessibilidade**.
- **Arquitetura isolada** (sem tocar em módulos pré-existentes além dos pontos
  de integração): `Roles::Business::Gestor::Overview` (lógica), `Model::Gestor`,
  `Controller::Gestor`, `Plugin::API::Gestor` (path `/api/gestor`); registrado
  com **1 linha** em `EduMaps.pm`. Reusa os ResultSets genéricos `CensoEscolas`,
  `CensoMatriculas`, `CensoDocentes` e a `Model::Base`/`Controller::Base`.
- **Descoberta importante (dados)**: as colunas `qt_mat_bas_d / _dm / _dv / _n`
  são **TURNO** (Diurno / Matutino / Vespertino / Noturno), **não deficiência** —
  os comentários do loader (`Deficiência – …`) estão errados. Confirmado em
  todas as ~178,7 mil linhas: `d + n = bas` e `dm + dv = d`. `qt_mat_bas_int`
  (integral) e `qt_mat_bas_ead` são dimensões à parte. **Atenção**: o
  `Profile.pm` (pré-existente) soma `d+dm+dv` como "deficiência" — bug latente,
  não mexido nesta sessão.
- **Limitação "turmas"**: o Censo agregado **não** traz o número de turmas.
  Usamos **salas de aula utilizadas** como referência e expomos `turmas.nota`
  explicando. `alunos_por_sala = matrículas / salas_utilizadas`.
- **Frontend**: feature nova `features/gestor/` (api, constants, utils puros,
  componentes, ícones). Ícones reaproveitam o acervo de `features/schools` e
  acrescentam novos (turno, modalidade, faixa etária, formação, vínculo,
  equipamentos, acessibilidade). Único módulo pré-existente alterado:
  `app/routes.js` (rota nova) e `routes.test.js`.
- **Testes**: backend `prove -l t/04-api/gestor/painel.t` → 6/6; frontend **no
  container** → 19/19 (`transformGestorData`, `GestorPanel`, `gestorApi`,
  `routes`).
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`. E2E:
  `/api/gestor/11000040/painel` 200; SPA `/gestor/painel` 200; bundle OK.

## Sessão anterior — Painel Financeiro da escola (folha/remuneração)

- **PR #70** (`feat/painel-financeiro-escola`) → `main`, merge commit **`99c0573`**
  (2026-09-17). Commits `ec525fe` (backend), `3964643` (frontend), `8cc5663`
  (docs regra), `692a3ca` (memória).
- **O quê**: nova **página separada** `/escola/financeiro` (look-and-feel do
  painel), linkada do `SchoolPanel` ("Painel financeiro →"). Mostra: custo total
  mensal (LineChart), profissionais por mês (LineChart), custo por categoria
  (DonutChart + lista com **ícones**), e um dropdown de competência que leva à
  folha completa (`/escola/payroll?inep=…&date=MM-YYYY`). **Sem nomes** de
  profissionais no painel (só na folha/detalhes).
- **Fonte**: `clean.remuneracao_municipal` (~30,9M linhas, índice por `cod_inep`).
  `categoria` = texto longo; `tipo` = 2 valores (com encoding zoado); `mes` =
  nome PT ("Janeiro"…"Dezembro", "Março" corrompido).
- **Backend**: `GET /api/school/:cod_inep/finance` (`Finance::financial_summary`)
  devolve `escola`, `series` (por ano/mes, com `mes_num` derivado por LIKE de
  prefixo p/ ordenar) e `categorias` (agregado do período todo). Registrado em
  `Plugin::API::School` + `Controller::School#finance`.
- **Frontend**: `schoolApi.getSchoolFinance`; `constants/finance.js` (buckets
  curados Docentes/Administrativo/Alimentação/Multimeios + fallback, com ícones
  novos em `icon-data.js` categoria `finance`); `utils/transformFinanceData.js`
  (puro, testado); `components/panel/SchoolFinance.svelte`;
  `pages/SchoolFinancePage.svelte`; rota em `routes.js`/`schools/index.js`.
  `SchoolPayrollPage` passou a aceitar `?date=`.
- **Bugs corrigidos**: (1) `map { ... } LIST, 'x'` em Perl engolia os itens
  seguintes na LIST (`$_->[0]` em string → 500); corrigido guardando o `map` num
  array. (2) rodei `vitest` local indevidamente — corrigido (regra acima).
- **Validação**: `GET /api/school/11000040/finance` → 200 (12 competências,
  2 categorias); SPA `/escola/financeiro` 200; bundle com "Painel Financeiro".
  Testes de frontend **no container**: 25/25.
- **Commits**: `ec525fe` (backend), `3964643` (frontend), `8cc5663` (docs regra).

## Sessão anterior — seção Desempenho (IDEB) no painel da escola

- **PR #69** (`feat/desempenho-painel-escola`) → `main`, merge commit **`2803421`**
  (2026-09-17). Commits `606a66e` (backend) e `6661691` (frontend).
- **O quê**: nova seção **"Desempenho"** no painel da escola, **abaixo de
  "Escolas semelhantes"**, só quando a escola tem histórico. Um `LineChart`
  (Carbon) com **uma linha por etapa** (`Fundamental I/II`, `Ensino Médio`),
  x = ano, y = **IDEB observado**.
- **Backend**: `School::Profile::panel_info` ganhou o campo `desempenho` lido de
  **`clean.ideb_notas_escolas`** (`IdebNotasEscolas`), ordenado por etapa/ano.
  **NÃO** usar `clean.inep` / `clean.inep_notas_desagregadas` (deprecated).
  Nota: as rotas `/grades` e `/full_grades` do controller são stubs vazios.
- **Frontend**: `transformPanelData.js` normaliza `desempenho`; `SchoolPanelPage`
  repassa; `SchoolPanel` renderiza a seção; novo `SchoolPerformance.svelte`.
- **Dados**: etapas em `clean.ideb_notas_escolas` = `fundamental_i` (2005–2023),
  `fundamental_ii` (2005–2023), `ensino_medio` (2017–2023).
- **Testes**: `SchoolPerformance` (2), `SchoolPanel` (+2), `transformPanelData`
  (2) — 13/13. Deploy backend + frontend; E2E `GET /api/school/35011162/panel/info`
  com `desempenho` (13 itens).

## Sessão anterior — autocomplete de indicadores (cluster) + build no container

- **Autocomplete do cluster (`FeatureSelect`)** — commit `d8a58f7`
  (`fix(frontend): autocomplete de indicadores do cluster`). Dois bugs:
  1. `filtered` usava `$derived(() => {...})`: a função virava o **valor** da
     derived (não o retorno), então `filtered.length === 0` e o dropdown nunca
     renderizava. Corrigido para **`$derived.by(() => {...})`**.
  2. Race `onblur` × clique: o `mousedown` na opção roubava o foco do input →
     `blur` → `open = false` → a lista desmontava antes do `click` → `select()`
     nunca rodava. Corrigido com `onmousedown={(e) => e.preventDefault()}` nas
     opções.
  Além disso: a busca exige **mínimo 2 caracteres** (com dica), `title` com o
  `comment` (metadado do banco) e o `column_name` fica visível. Teste
  `FeatureSelect.test.js` (5 casos). Deployado (`deploy_frontend_dev`).
- **BUILD DO FRONTEND — rodar no container `backend.edumaps`** (via
  `rex -H backend.edumaps deploy_frontend_dev`, que executa `npm run build` lá):
  é **mais robusto e rápido**. O `npm run build` **local** conclui
  (`✓ built in ~25s`), porém o processo do Vite **não retorna** no shell (fica
  pendurado; só encerra com `timeout`). Usar o build do container como validação
  real.

## Sessão — eduBR (pacote R): regiões, INSE e camada declarativa

- **Repo** `~/Projects/eduBR` (GitHub `marcoarthur/eduBR`, repo separado do
  `edumaps`). Pacote R de acesso de alto nível à base do EduMaps (objetos S3
  + consultas `dbplyr` preguiçosas).
- **PR #1** (`feat/edubr-analises-declarativas`) → `main`, merge commit
  **`c7e8e80`** (2026-09-16). 10 commits (`b7f4898`..`9a498cb`): setup +
  região/tendência + INSE + camada declarativa + sync + docs.
  `main` == `origin/main` == `c7e8e80`; branch deletada.
- **Setup**: `AGENTS.md` + skills `.opencode/skills/{agent-persona,r-edubr,postgres-postgis}.md`.
  Curadoria das personas em `docs/personas/especialista-ml.md` (rodadas 2–4).
- **Região/tendência**: `ideb_regiao()` (macrorregião derivada da UF via
  `case_when`; helpers em `R/regiao.R`) e `tendencia_regiao()` (parsnip
  `ideb_medio ~ ano` por região×etapa). Report
  `analysis/tendencia_ideb_regiao.Rmd`.
- **INSE**: `clean.inse` só tem **2023** e só **públicas** (69.756 escolas).
  `inse()`, `ideb_inse()` (join por `id_escola` e `ano = nu_ano_saeb`) e
  `regressao_inse()` (transversal, nível escola). Report
  `analysis/regressao_inse_regiao.Rmd`. Gradiente (fund. II): CO 1,22 > SE 1,13
  > N 1,09 > S 1,03 > **NE 0,61**.
- **Camada declarativa**: `especificar_regressao()` / `ler_espec()` /
  `ler_especs()` (YAML) + `executar_regressao(con, espec, dados = NULL)`
  (mesma regressão para N combinações de `cuts`, com **pushdown** de colunas
  antes do `collect`), `coeficientes()`, `metricas()` (logit: `auc` +
  `mcfadden`) e `coletar(x, n =)` (limite + aviso de custo). Exemplo
  `analysis/regressoes_censo.{yaml,Rmd}` (81 modelos UF×etapa em ~48 s).
- **Sync RStudio**: `tools/sync-rstudio.sh` → `rstudio.dev:/home/rsuser/projetos/eduBR`
  (sem `--delete`; `chown -R rsuser:rsuser`), disparado por
  `.git/hooks/post-commit` (symlink para o script). Hook é **local** —
  reinstalar após clonar: `ln -sf ../../tools/sync-rstudio.sh .git/hooks/post-commit`.
- **Dados**: `clean.ideb_notas_escolas` tem `sg_uf`, `co_municipio`, `etapa`,
  `rede`; IDEB↔censo/scores casam por `id_escola == co_entidade`. Base remota
  (`ubatexu.lan:5432`, cluster **ANTIGO**) com picos de lentidão (~2k linhas/s),
  daí o pushdown de colunas.
- **Validação**: `devtools::test()` 0 fail / 0 warn; `R CMD check` 0/0/0.
- **Pendências** (backlog em `docs/personas/especialista-ml.md`): dicionário do
  Censo, reprodutibilidade dos `scores()`, `as_sf()`/PostGIS,
  `registrar_relacao()`, INSE histórico p/ painel, PDF nos reports, join
  escola→município por código.

## Sessão atual — sw.js (PWA app shell offline)

- **PR #66** (`feat/sw-app-shell`) → `main`, merge commit **`9fb0d9c`**
  (2026-09-16). Commit `548bf7e feat(frontend): sw.js basico app shell offline`.
- **Contexto**: o frontend não tinha service worker próprio (só o `sw.js`
  opaco gerado pelo Workbox em `generateSW`).
- **`src/sw.js`** (novo, vanilla, sem Workbox em runtime): app shell offline —
  `install` precacheia shell + assets com hash injetados (`self.__WB_MANIFEST`
  → `.url`) + `skipWaiting`; `activate` limpa caches + `clients.claim`; `fetch`
  navegação network-first com fallback offline, `/api/` network-only, estáticos
  stale-while-revalidate.
- **`vite.config.js`**: `VitePWA` de `generateSW` → **`injectManifest`**
  (`srcDir: "src"`, `filename: "sw.js"`); removido o `runtimeCaching` do `/api/`
  e o `robots.txt` inexistente do `includeAssets`.
- **Deploy/validação**: `npm run build` gera `dist/sw.js` (nosso código, 7
  entradas de precache); `deploy_frontend_dev`; no container `/sw.js` 200 e
  `registerSW.js` 200.
- **Pendências**: ícones `public/icons/icon-*.png` e `robots.txt` inexistentes —
  PWA ainda não instalável.
- Nota: no build, `injectManifest` exige o ponto de injeção
  `self.__WB_MANIFEST` no sw de origem (erro "Unable to find a place to inject
  the manifest" se faltar).

## Sessão anterior — fix uuid (crypto.randomUUID em contexto inseguro)

- **PR #65** (`fix/uuid-contexto-inseguro`) → `main`, merge commit **`d522d10`**
  (2026-09-16). Commit `cca4d76 fix(frontend): uuid sem contexto seguro`.
- **Bug**: `crypto.randomUUID()` só existe em **contexto seguro** (HTTPS/
  `localhost`); em dev por host/IP (`http://<host>:5173`) o `crypto` existe mas
  `randomUUID` é `undefined` → `TypeError: crypto.randomUUID is not a function`
  em `EventBus.emit` (`EventBus.js:72`).
- **Correção**: helper `src/shared/utils/uuid.js` (nativo, sem dependência):
  `crypto.randomUUID()` → `crypto.getRandomValues()` (UUID v4, funciona em
  contexto inseguro) → fallback final. Usado no `EventBus.js` e no
  `toastStore.js` (remove o `Math.random` duplicado). Teste `uuid.test.js`.
- **Deploy** `deploy_frontend_dev`; validado no container: bundle com
  `getRandomValues` presente; página HTTP 200. Testes shared: 30 passaram.
- Nota: `npm run build` local conclui (`✓ built`), porém o processo do vite não
  retorna no shell — usar o `deploy_frontend_dev` (build no container) como
  validação real.

## Sessão anterior — pgvector (similaridade escolar) + topologia do ambiente

### Topologia do ambiente (IMPORTANTE — ler antes de conectar em DB)
- `ubatexu.lan` (192.168.0.42) é o **host** dos containers LXC; as portas do
  host fazem forward para os containers.
- Da nossa máquina só alcançamos o **host**, nunca o container direto. O acesso
  aos containers é via SSH pelos forwards do host (`~/.ssh/config`):
  - `backend.edumaps` → `ubatexu.lan:2031`
  - `database.edumaps` → `ubatexu.lan:2032`
  - (os containers compartilham o IP do host; só mudam as portas)
- Existem **dois** clusters Postgres, ambos com `edumaps_dev` (confirmado por
  `system_identifier` distinto):
  - **Antigo** — `database.dev`; seu Postgres é exposto pelo host em
    `ubatexu.lan:5432`. É para ele que aponta o `~/.pg_service.conf` local
    (`[edumaps]` → host=ubatexu.lan, user `devel`). Logo, **R/eduBR/testes
    locais batem nesse banco ANTIGO, não no do app**. `sqitch status` local
    (alvo `dev_super` → ubatexu.lan) também olha esse cluster antigo.
  - **Atual (app)** — container `database.edumaps` (IP LXC `172.19.198.3`); é o
    que o `backend.edumaps` (Perl + nginx/frontend) usa via `host=Database`
    (ver `edu_maps.conf` no container). Só é acessível por SSH (porta 2032).
- **Deploy de banco:** `rex -H database.edumaps deploy_db_dev` (roda o sqitch
  **dentro do container atual**). NÃO confundir com `sqitch deploy dev_super`
  (roda contra `ubatexu.lan:5432` = cluster ANTIGO; lá o pgvector nem está
  instalado e a migration fica undeployed). Foi um engano inicial desta sessão.
- Para o R/eduBR local enxergar o banco ATUAL do app seria preciso um **túnel
  SSH** pelo host, ex.:
  `ssh -N -L 127.0.0.1:55432:localhost:5432 root@database.edumaps`
  (serviço com host=127.0.0.1 port=55432 dbname=edumaps_dev user=edumaps
  password=change_me). **Decisão do usuário: deixar como está** (sem túnel, sem
  repontar `[edumaps]`) — ele testa manualmente.

### Entregue nesta sessão — pgvector para similaridade escolar
- **PR #64** (`feat/pgvector-curadoria`) → `main`, merge commit **`a7466ad`**
  (2026-09-16). Agrupou 10 commits: pgvector (`b3c537a` db, `ede1ad7` backend),
  `column_descriptions` (`75e23fd` db), personas/Tech Lead/índice e memória
  (`678b0dd`, `177901d`, `7a38724`, `783cc19`, `52ef321`, `4f21638`, `e8c28b1`).
  Branch deletada; `main` == `origin/main` == `a7466ad`.
- Migration `school_embedding` (`data_pipeline/deploy|revert|verify` + plan):
  `CREATE EXTENSION vector`; `analytics.school_embedding(co_entidade PK,
  embedding vector(6))`; backfill dos 6 scores de `clean.mv_escolas_scores`;
  índice HNSW `vector_cosine_ops`.
- Backend: `Schema::Result/ResultSet::SchoolEmbedding`
  (`similar_to($id, $limit, $municipio)`, cosseno `<=>`); `Task::SchoolEmbedding`
  (job Minion `refresh_school_embeddings`, registrado em `EduMaps.pm` em
  `EduMaps::Task::$_`); `School::Profile::panel_info` usa pgvector como caminho
  principal e mantém o `find_similar_schools` (Manhattan em memória) como
  **fallback**; teste `t/02-models/school/embedding.t` (skip se a tabela não
  existir no ambiente).
- Rexfile `deploy_db_dev`: pacote `postgresql-16-pgvector`.
- Deploy: `rex prepare` + `rex -H database.edumaps deploy_db_dev` +
  `rex -H backend.edumaps deploy_backend_dev` + restart de `edumaps-minion` e
  `edumaps-minion-analytics`.
- Validação no container `database.edumaps`: pgvector 0.8.6; **180.540**
  embeddings; índice `idx_school_embedding_hnsw`; API
  `GET /api/school/35007656/panel/info` retorna `similar_schools` via pgvector
  (distância do 1º vizinho `0.001484` = query direta); job
  `refresh_school_embeddings` → `finished` (`refreshed: 180540`).
- Testes: `t/02-models/school/profile.t` OK; `searching.t` falha **idêntica sem
  as mudanças** (pré-existente/data). O harness do repo (`Imports.pm`) exige
  **Perl 5.38** — o container tem 5.36, então os testes rodam só localmente.
- Tentativa de `sqitch deploy dev_super` (cluster ANTIGO, `ubatexu.lan:5432`)
  falhou: `extension "vector" is not available` (pgvector não instalado lá). Sem
  estado parcial (transação abortada; segue undeployed). Não instalar pgvector
  no cluster antigo — o app usa o container atual.
- Migration `column_descriptions` (`75e23fd`): 46 `COMMENT ON COLUMN` (PT-BR,
  foco em porquê/uso) para `school_embedding`, `event_store`, `mv_escolas_scores`,
  `censo_escolas` (geometry/nro_etapas), `school_indicators` (geometry/nro_etapas)
  e `mv_rede_escolas` (26); `cluster_*` (runtime) via `DO` condicional
  (`information_schema.columns`). Deploy via `rex prepare` + `deploy_db_dev`;
  validado: 0 colunas sem descrição nas 6 tabelas.

## Sessão anterior — LandPage, logo SVG e navegação

### Entregue (direto em `main`, sem PR) + deploy
- Commits: `4fbbd4d feat(frontend): landpage, logo e navegação` e
  `8072027 docs: deploy obrigatório no workflow`.
- **Deploy rodado** (Rex `backend/script/deploy/Rexfile`): `rex prepare` (3 hosts)
  + `rex -H backend.edumaps deploy_frontend_dev` — OK. Validado no container:
  `GET /` 200 e `GET /favicon.svg` 200 (build com "Ferramentas analíticas" no
  bundle). **Fix**: `/favicon.svg` não existia (404) e era referenciado no
  `index.html` e no `includeAssets` do PWA.

### O que foi feito
- **Logo** `src/shared/ui/components/Logo.svelte`: glifo SVG único (viewBox
  48×48) — pin de mapa + livro aberto + três barras ascendentes (mapas,
  educação, censo/análise). Props `size` e `variant` (`brand` azul p/ fundo
  claro; `light` pin branco p/ o nav). Sóbrio (azul `#1e40af` + branco), sem
  gradiente. `public/favicon.svg` = versão simplificada (pin + livro) para
  legibilidade a 16px.
- **LandPage** feature nova `src/features/home/` (`HomePage.svelte` + `index.js`
  + teste): hero com logo, tagline e CTAs (Buscar escola → `/escola/search`;
  Ver análises → `/cluster/geotag`) + 4 pilares (Mapas, Educação, Censo Escolar,
  Ferramentas analíticas).
- **Rotas/nav**: `routes.js` ganhou `/` → `HomePage`; removido o `$effect` de
  redirect `/`→`/about` no `App.svelte`; `NAV_LINKS` = Home · Busca Escola ·
  Análises · Sobre o Refactor; marca no nav com logo + "EduMaps".

### Testes
- `routes.test.js` (+2: `/` e `/cluster/geotag`) e `HomePage.test.js` (3).
  Suíte: **129/133** (4 falhas pré-existentes: `paginationStore` ×3,
  `SchoolRankingPage` ×1). `npm run build` OK.

### Convenção nova
- **AGENTS.md Workflow passo 4**: "Deploy (sempre)" — todo ciclo termina com o
  deploy via Rex, rodando de `backend/script/deploy` (`rex prepare` antes de
  qualquer task de código, pois `deploy_backend_dev` não faz rsync).

## Sessão anterior — Rótulos em linguagem natural e legenda clicável nos clusters

### Mergeado
- **PR #62** (`feat/cluster-rotulos-natural`) → `main`, merge commit **`b9cd252`**,
  merge em 2026-09-14. Commits: `4335430` (analysis), `b608d92` (backend),
  `1e1e82c` (frontend), `4f5564b` (docs: skill frontend-svelte), `fe06dd8`
  (docs: nota técnica 39 + regra de nota no workflow). Branch deletada; `main`
  == `origin/main` == `b9cd252`. **Working tree limpa.**

### Entregas
- **R (edumapsr)**: módulo `R/cluster-labels.R` (`.label_scale` com escala 2→
  baixa/alta, 3→baixa/média/alta, 4→muito baixa/baixa/alta/muito alta, 5→muito
  baixa…muito alta, **≥6→fallback inteiro** `Cluster 1..N` 1=baixo N=alto;
  `.cluster_scores` = média por feature min-max × polaridade; `.cluster_labels`);
  `analyze_cluster` lê `parameters$labeling` (`concept`/`gender`/`directions`) e
  gera `cluster_label`/`cluster_rank` em `tables$clusters` e `data`;
  `repository-postgres-cluster.R` grava as duas colunas in-place + `extra_metrics`
  (JSON). `DESCRIPTION` ganhou `cluster-labels.R` no `Collate`.
- **Backend**: `Presets.pm` com `concept`/`gender`/`directions` (única negativa:
  `prop_sem_especializacao` = −1); `request_cluster` injeta `labeling`;
  `Task::Clustering` repassa nos `parameters`; `Model::Cluster` expõe
  `cluster_label`/`cluster_rank` no GeoJSON + `cluster_summary` + rota
  `GET /api/cluster/summary`.
- **Frontend**: legenda com rótulo semântico e **clicável on/off por grupo**
  (`aria-pressed`, `hiddenIds` = `$state(new Set())` reatribuído); popup com
  rótulo; `ClusterSummaryTable.svelte` (rótulo + nº escolas + top indicadores);
  `getClusterSummary()`.

### Detalhes de implementação (importantes)
- `analytics.clustering_metadata.extra_metrics` é gravado pelo R como **ARRAY**
  `[{...}]` (não objeto) → no Perl normalizar (se ARRAY, pegar `->[0]`).
- JSON do banco vem utf8-flagged (`pg_enable_utf8=1`); decodificar com
  `$self->json->utf8(0)->decode(...)` (padrão do projeto — sem `utf8(0)`, "Média"
  quebra e o rótulo cai no fallback).
- Conceito/gênero por preset: infraestrutura "qualidade de infraestrutura" (f),
  docência "qualidade da docência" (f), desempenho "desempenho dos alunos" (m).

### Validação
- R: `test-cluster-labels.R` (12) + `test-cluster.R` verdes (`R CMD INSTALL` OK).
- Backend: `cluster.t` 10, `task.t` 19, `network/schools.t` 4 — verdes.
- Frontend: cluster-geotag 7/7; suíte 123/127 (4 pré-existentes). Build OK.
- E2E deploy (Ubatuba 3555406): infra k=3 → baixa/média/alta; desempenho
  k=3/2023 → baixo/médio/alto; infra k=6 → `Cluster 1..6`. `/api/cluster/summary`
  e GeoJSON com `cluster_label` OK.

### Convenções novas registradas
- **AGENTS.md Workflow passo 6**: gerar nota técnica (`notas_tecnicas_N.md` em
  `docs/new_ideas/implementations_ideas/`) ao fim de cada ciclo (1–2 PRs, 1–2 dias).
- **Skill `frontend-svelte`**: padrão de "marcadores acionáveis quando representam
  grupos" (legenda clicável) + dicas de teste (polling 1500ms → `timeout: 3000`).

## Sessão atual — Presets de indicadores na clusterização (censo + docentes + IDEB)

### Mergeado
- **PR #61** (`feat/presets-multitabela`) → `main`, merge commit **`cb5e8f4`**,
  merge em 2026-09-14. Commits: `08b891e` (db), `c42b58c` (backend),
  `779873a` (frontend). Branch deletada (remoto e local). `main` após FF =
  `cb5e8f4`.
- Fechamento: `03410cc` docs (memory), depois **`62aa757` chore: commit fontes
  pendentes e ignora artefatos R** — commitou os pendentes antigos
  (`EventBus/Middleware/SiopeTask.pm` info→error, `script/tasks/siope.pl`,
  `templates/osm/query/school.opq.ep`, `map_app/src/lib/js/city.js`) e
  gitignoreou `analysis/edumapsr/edumapsAnalytics.Rcheck/` e
  `edumapsAnalytics_*.tar.gz` (artefatos de R CMD check regeneráveis, não
  voltam a sujar o status). **Working tree limpa ao fim da sessão.**
- **Limpeza de branches obsoletas** (2026-09-14): removidas do remoto e local
  as mergeadas `feat/presets-multitabela`, `feat/cluster-geotag-map`,
  `feat/backend-analytics` e `dev/feat/frontend/toast`. Aprendizado: `git push
  origin --delete` com vários refs aborta se um deles não existir (refs já
  apagadas no PR merge ficam como "remote ref does not exist") — deletar um por
  vez. **Remanescentes com trabalho não mergeado (NÃO apagar sem acordo)**:
  `feat/deploy/docker` (`6c7d9ce` adapt edumaps for docker) e
  `fix/backend/schoolgrade` (`8d98de1` School code missing in School Grade).

### Entregas
- **db**: migration `school_indicators` (`deploy/revert/verify` + `sqitch.plan`):
  tabela denormalizada `clean.school_indicators` (censo + docentes + IDEB),
  com `col_description` (comments PT-BR) usados no autocomplete.
- **backend**: `EduMaps::Presets` (3 presets: infraestrutura, docência,
  desempenho; ordem fixa `@PRESET_IDS = qw(infraestrutura docencia desempenho)`;
  `INDICATORS_TABLE`); endpoints `GET /api/cluster/{presets,columns,years}`;
  `request_cluster` (POST /api/task/cluster) aceita `preset`/`ano_ideb` e valida:
  **400** p/ preset desconhecido e p/ preset `year_filter` sem `ano_ideb`; com
  preset força `schema=clean`, `table_name=school_indicators`,
  `id_column=co_entidade`; `Task::Clustering::_rebuild_indicators` faz
  TRUNCATE+INSERT na tabela para o `ano_ideb` escolhido (via `Mojo::Pg`,
  `->hash`/`->array` NÃO `->first`); `Model::Cluster` lê
  `clean.school_indicators` (existence check + `cluster_geojson_query`).
- **frontend**: `PresetSelector`, `FeatureSelect` (autocomplete com comments +
  tags de fonte `SOURCE_LABELS`/`featureLabel`), seletor de ano IDEB/SAEB;
  página cluster/geotag com preset default `infraestrutura`, guarda de ano p/
  desempenho, payload com preset/features/ano_ideb.

### Dados/descobertas
- **IDEB**: `clean.ideb_notas_escolas` tem múltiplos rows por `(id_escola, ano)`
  por etapa (814.448 linhas; 58.884 pares escola/ano; 84.555 escolas; 97.615 em
  2023) → o rebuild agrega por escola com `AVG(ideb)` entre etapas. `id_escola`
  é a coluna do IDEB (não `co_entidade`). Contagens do rebuild: total 214.192,
  com_docentes 178.473, com_ideb_2023 **68.923**, ideb_médio 5.14, lic_media 0.796.
- Censo escolar/docentes só têm `nu_ano_censo = 2025`; docentes join por
  `co_entidade + nu_ano_censo`; IDEB por `i.id_escola = e.co_entidade AND i.ano = ?`.
- **Ambiente duplo**: o container usa DB separado — `backend` conf conecta em
  `Database` LXC (`postgresql://edumaps:change_me@Database/edumaps_dev`), que é
  **diferente** do `edumaps_dev@ubatexu.lan` (devel). Migration aplicada via
  `sqitch deploy db:pg://edumaps:change_me@localhost/edumaps_dev` no
  `database.edumaps` (estava 2 changes atrás).
- Falhas pré-existentes do frontend seguem: `paginationStore ×3` e
  `SchoolRankingPage ×1` (rota `/escola/search` vs `/busca`). Cluster-geotag 6/6.

### Validação
- Testes backend: `cluster.t` 9, `task.t` 19, `network/schools.t` 4 — PASS.
- E2E no deploy: jobs Minion Ubatuba 3555406 — desempenho/2023 (job 5865)
  → rebuild 214.192 e clusters 1-5 (47/3/18/7/9 + 2 sem nota); infraestrutura
  (job 5866) sem ano → clusters 1/3/4. GeoJSON com `cluster_id` OK.
  `/api/cluster/presets|columns|years` OK. `edumaps-analytic.service` (backend)
  segue failed (legado; Plumber real roda em `analytic.edumaps:8000`, ativo).

## Sessão atual — Fix lite app nos scripts dev/entrypoint

- **Problema**: usuário reportou que a "App lite" `backend/edu_maps.pl`
  (Mojolicious::Lite, sem `/api/network`, `/api/task/cluster` e cluster geotag)
  subiu novamente na instância do backend. O fix anterior só corrigiu as units
  systemd no Rexfile; **`backend/dev_run.sh` (líneas 59-60) e
  `backend/docker-entrypoint.sh` (28,30) ainda iniciavam `edu_maps.pl`**
  (`morbo ./edu_maps.pl` e `./edu_maps.pl minion worker`) → qualquer subida via
  dev_run/entrypoint (manual ou Docker) voltava a expor a lite app.
- **Verificação nos containers**: `edumaps-web` segue correto — morbo em :3000 é
  `/opt/edumaps/backend/script/edumaps.pl` (sha256 == repo,
  `Mojolicious::Commands->start_app('EduMaps')`); `/api/network/3551702/summary`
  → 200; rota lite `/api/query-osm` → 404. Daemon local `127.0.0.1:3999`
  (classe app) intacto.
- **Fix**: `dev_run.sh` e `docker-entrypoint.sh` passam a usar
  `script/edumaps.pl` (morbo e worker). `bash -n` OK; sincronizado também em
  `/opt/edumaps/backend` no container.
- **Commit**: `edbdf3d fix(backend): dev scripts sobem classe app` — direto em
  `main` (sem PR), push para `origin/main` (a6acae7..edbdf3d) em 2026-09-14.
- **Obs.**: `edumaps-analytic.service` apareceu **failed** no backend.edumaps —
  ainda não investigado (usuário não pediu).

## Sessão anterior — Mapa de cluster por geotag (R + API + frontend)

### Mergeado
- **PR #60** (`feat/cluster-geotag-map`) → `main`, merge commit **`b290caa`**, merge em
  2026-09-14. Commits: `958b10e` (analysis), `877fb16` (backend), `9a224c6` (frontend).
- Deployado (as-is) e validado nos containers: `rex prepare` + restart
  `edumaps-web`/`edumaps-minion`/`edumaps-minion-analytics`/`edumaps-analytic` +
  `deploy_frontend_dev`. E2E no container: POST /api/task/cluster (Ubatuba
  3555406) → 202 → poll REST active→finished → GET /api/cluster/schools 200,
  78 features, cluster_ids [1,2,3].

### Bug de contrato: job_progress era SSE, frontend esperava JSON
- `GET /api/task/progress` usava `monitor_job` (SSE `text/event-stream`,
  `write_sse`) — frontends antigos (map_app) consomem via EventSource. A página
  nova (Svelte) fazia `fetch`+`json()` e parseava a stream → "Erro ao gerar os
  clusters." **Fix**: `Controller/Task.pm::job_progress` detecta `Accept`; sem
  `text/event-stream` retorna **JSON** `{state, error?}` por poll (state
  `inactive|active|finished|failed`; `failed` expõe `job.error // job.result`,
  com suporte a hashref `{error}`). EventSource legado permanece no caminho SSE.
  Job inexistente → 404.
- Teste: `Minion::Job->fail` em job `inactive` retorna **undef** (backend exige
  job `active`/dono worker). Para testar `failed` de forma determinística:
  `worker->register` + `worker->dequeue(0, {queues=>[...]})` (in-process) e
  depois `$job->fail(...)`. Fila descartável `zzz_progress_test` isola de
  workers de dev ao vivo (um worker local rodando consumia os jobs dos testes e
  marcava "Invalid arguments!").
- No dev local existe Postgres em `localhost:5432` (DB `edumaps`, user
  edumaps) — serviço pg `edumaps_local` do libpq. O Plumber **local** escrevia
  nele, mas o backend lê `edumaps_dev@ubatexu.lan` (serviço `edumaps`) →
  `cluster_id` nunca aparecia. Fix no `package.json` dev: o R sobe com
  `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps` (e `ACCEPT` prefixado com `env`, pois
  entr executa via execvp e não passa env de outros comandos do pipe). Nos
  containers o pg_service `edumaps_local` aponta pro Database, então não há
  mismatch lá.

### R analytics — robustez e filtro
- `analyze_cluster` ganhou `filter` (igualdade por coluna — ex. `{co_regiao:
  3, co_uf: 35, co_municipio: 3555406}`), suportado no api.json/endpoint.R e
  no `Client`/`Task::Clustering` (repassado ao motor). Backend converte
  `codigo_regiao/uf/ibge` → `co_regiao/co_uf/co_municipio`.
- Bug NA: kmeans com 2/86 linhas NA em Ubatuba → `NA/NaN/Inf in foreign
  function call (arg 1)`. `analyze_cluster` agora dropa linhas incompletas
  (`complete.cases`, alinhado com entity_ids), descarta colunas com variância
  zero e valida `nrow<2`, 0 features, `clusters >= n`. Erro do Plumber
  mascarava detalhe: `_post` do `Analytics::Client` concatenava `ARRAY(0x...)`;
  agora join de `ARRAY` de erros (`; `).

### Deploy: pacote reinstalado no container analytic
- `rex prepare` só rsync a **fonte**; o serviço `edumaps-analytic` roda
  `Rscript inst/plumber/run.R` com `library(edumapsAnalytics)` → as funções vêm
  do pacote **instalado** (site-library `/usr/local/lib/R/site-library`), que
  estava defasado (o mesmo NA bug aparecia no container). Redeploy do código R
  exige `R CMD INSTALL .` (env `R_LIBS` + `LC_ALL=C.UTF-8`) e `stop/start`
  (verificar MainPID). Container volume em 8000.

### Backend
- `POST /api/task/cluster` aceita corpo `application/json` (validação
  normalizada: `validator->validation` + `$v->input($input)`, gate `has_error`,
  `features` lido direto do array — `param` achata arrays). Form continua
  suportado.
- Novas rotas `GET /api/cluster/schools|regions|ufs|municipalities`
  (`EduMaps::Controller/Model::Cluster` + plugin API). `clustered_schools`
  lê coluna dinâmica `cluster_id` (criada pelo R via `ADD COLUMN IF NOT
  EXISTS`) via SQL raw + `bigquery json` → GeoJSON FeatureCollection.
- `frontend/edumaps`: página `/cluster/geotag` (cascata região→UF→município,
  12 indicadores default, kmeans/gmm/spectral/dbscan, polling 1.5s, mapa
  Leaflet cor por `cluster_id`), MSW + testes. `DEFAULT_FEATURES` valida
  contra schema — `qt_prof_docentes` não existe; usa `qt_prof_pedagogia`.

### Pendências / fora do escopo (não entraram no PR)
- `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (M), untracked:
  `analysis/edumapsr/edumapsAnalytics.Rcheck/`, `edumapsAnalytics_0.1.0.tar.gz`,
  `backend/script/tasks/`, `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`.
- Check "Workers Builds: edumaps" no GitHub **falha** e deve ser **desconsiderado**:
  a conta Cloudflare NÃO está configurada neste projeto (não há integração
  real; o build é órfão). Não é required → nunca bloqueia merge (estado
  UNSTABLE, não BLOCKED). PR #60 mergeou normalmente.
- Limitação legada do R: `/summary` com sub-análises (score_distributions,
  school_clusters) aceita mas não persiste (repo só faz full_summary).

## Sessão anterior — Deploy e2e do motor http (Plumber) nos containers

### Implantado e validado
- `rex prepare` + `deploy_analytics_worker_dev` (worker fila `analytics`
  ativo no backend) + `deploy_analytics_dev` no container analytic.
- Primeiro `deploy_analytics_dev` falhou: `R CMD INSTALL` sem `dbscan`,
  `mclust`, `kernlab` (deps de algoritmos de clustering). Corrigido no
  `Rexfile` (install.packages) — commit **`4ba80e9` feat(deploy): engine
  http padrao e deps dbscan mclust kernlab** (também flippa
  `analytics_engine: http` no template `files/edumaps_db.conf`).
- Container backend: `analytics_url => http://analytic:8000`, engine `http`
  (manual na config deployada). Serviços `edumaps-web`/`edumaps-minion`/
  `edumaps-minion-analytics` ativos.

### Correções no edumapsr (deploy)
- **`e0e9d56` fix(analysis): escopo do pacote no Plumber**:
  - `run.R` usava só `requireNamespace` → exports NÃO estavam na search path
    e os handlers do Plumber não achavam funções do pacote. Adicionado
    `library(edumapsAnalytics)` no branch do pacote instalado.
  - `analytics_db_connection()` é **interna (não exportada)** — qualificada
    com `edumapsAnalytics:::` no `endpoint.R` (3 chamadas: /cluster,
    /summary, /similarity/db).
  - `Sys.setlocale("LC_ALL", "C.UTF-8")` no run.R p/ silenciar warnings
    "cannot be translated to UTF-8" (strings marcadas como native no parse).
    Na prática, só removeu os warnings após re-instalar o pacote com
    `LC_ALL=C.UTF-8 R CMD INSTALL`.
- **`d885787` fix(analysis): serializa metricas com tabelas R em JSON**:
  - `analyze_city_summary` usava `table(data$dependencia)` em metrics; o
    repositório `persist_city_summary` serializava `result$metrics` direto
    com `jsonlite::toJSON` → **"No method asJSON S3 class: table"** → 500 em
    /summary. Correção na raiz: `as.list(table(...))` (lista nomeada).
  - `view-json.R::as_json_scalar` agora converte objects `table` em objetos
    JSON nomeados (defesa). Sem isso os testes de `/summary` quebrariam se
    alguma métrica voltasse a ser `table`.

### E2E validado (via curl nos containers)
- `POST http://analytic:8000/cluster` (staging.test_cluster, 500 escolas)
  → JSON com `data`, `metrics`, `tables`; persiste `cluster_id` na tabela e
  3 linhas em `analytics.clustering_metadata` (run_id `run_<ts>`).
- `POST /api/task/cluster` (backend, form-encoded) → job Minion **finished**
  (job 5858, fila `analytics`, worker dedicado). O server Plumber responde mas
  pode levar >120 s em tabelas grandes (kmeans sobre clean.escolas inteiro
  estourou timeout — usar tabela reduzida ou aumentar `analytics_timeout`).
- `POST /summary` (clean.escolas 3106200, full_summary) → 200, persiste em
  `analytics.city_school_analytics` (summary_data jsonb, distribuicao por
  dependência como objeto).
- `POST /similarity/db` (staging.test_cluster, k=5, gower) → 200, persiste em
  `analytics.similarity_pairs` (append por run).
- Limitação descoberta: `/summary` com `type=score_distributions`/
  `school_clusters` retorna 500 ("repository espera um resultado
  city_summary") — o repo só persiste `full_summary`; sub-análises
  (SKIPPED) não são persistidas. Endpoint aceita, mas não persiste.

### Descobertas de operação
- Serviço `edumaps-analytic` roda `Rscript inst/plumber/run.R` com
  `WorkingDirectory=/opt/edumaps/analysis/edumapsr` (FONTE rsyncada), NÃO o
  pacote instalado (site-library). Depois de `R CMD INSTALL` é obrigatório
  `systemctl stop/start` (só `restart` mantém MainPID antigo às vezes) e não
  esconder o erro: **verificar `systemctl show ... --property=MainPID`**.

## Sessão anterior — Migração das análises R::Pipe → Plumber (edumapsr), Fase 3 concluída

### Fase 1 completa (commits)
- **`d79d427` feat(analysis): endpoints plumber cluster/summary e repos** —
  edumapsr ganhou POST `/cluster`, `/summary`, `/similarity/db` + facades e
  repos S3 persistentes (staging cluster_id via temp table, upsert
  `city_school_analytics`, append `similarity_pairs`). 147 testes testthat PASS.

### Fase 2 completa (commits)
- **`5f110c6` feat(backend): connector Perl <-> Plumber**:
  - `EduMaps::Analytics::Client` — chamadas HTTP **síncronas** (`Mojo::UserAgent`
    bloqueante), endpoints `/cluster|summary|similarity/db|chart|health`.
  - Cache compartilhado `analytics.analysis_cache` com chave **canônica**
    (`JSON::PP->canonical` + `Mojo::Util::sha1_hex` de `{analysis, params,
    source_version}`), estável entre processos (hash ordering do Perl era
    aleatória por processo!). **Escopo do cache inclui dados afetam o resultado**:
    `/summary` keyed por `codigo_ibge+schema+parameters`; `/cluster` por
    `schema+table_name+id_column+features+parameters` (NÃO `output_schema`).
    Read-through p/ cluster e city_summary; similaridade (pares O(n²))
    **nunca é cacheada**.
  - Descobertas Mojo nesta versão (site_perl 5.42.0):
    - `Mojo::Util::sha1_hex` existe mas NÃO está em `@EXPORT_OK` — chamar
      **fully-qualified** (`Mojo::Util::sha1_hex(...)`), senão
      `use Mojo::Util qw(sha1_hex)` falha em `perl -c`.
    - `use Mojo::JSON qw(encode_json decode_json)` numa classe com
      `Mojo::Base -base, -signatures` dispara **prototype mismatch** — usar
      `use Mojo::JSON;` + chamadas `Mojo::JSON::encode_json(...)`.
    - `Mojo::Server::Daemon` embutido + `ua->get(...)->result` bloqueante NÃO
      funcionam no mesmo processo nesta versão (eventloop): para emular o
      serviço no teste, o server roda em um **fork** (loop dedicado) e o
      `port` chega por arquivo temp (`/tmp/user/1000/opencode/...`); polling de
      prontidão via `IO::Socket::INET`. Test2 usa `$?` p/ o exit code → após
      `waitpid` do filho (killed por TERM) é **obrigatório `$? = 0`**, senão o
      teste sai com exit 15.
  - **Plugin** `EduMaps::Plugin::Analytics` registrado no startup (`EduMaps::
      Plugin::Helpers` + `Analytics`); helper `analytics` (client singleton com
      `app` fraco). Config keys: `analytics_url` (default
      `http://analytic:8000`), `analytics_timeout` (300),
      `analytics_source_version` ('edumapsr-0.1.0'), `analytics_cache_enabled` (1).
      **TODO**: adicioná-las ao `edu_maps.conf` (não versionado) na F6.
  - Teste `backend/t/03-plugins/analytics.t` — **9 subtests PASS** (server fork,
    run_cluster/summary/similarity_db/health, croak em 500, chave canônica,
    escopo por codigo_ibge/table/features, read-through s/ DB = no-op).
  - Verificações: `perl -c` OK nos 3 arquivos; `t/01-app/basic.t` (boot da app)
    e `t/03-plugins` PASS.

### Fase 3 completa (commits)
- **`deedd23` feat(backend): tasks R com analytics_engine http|pipe**:
  - `EduMaps::Plugin::Analytics` ganhou `DEFAULT_ENGINE ('pipe')` e nova config
    key **`analytics_engine`** (`'http'` Plumber via Client | `'pipe'` legado),
    exposta pelo helper `$app->analytics_engine` (lida no register, default
    `pipe` — mantém prod e `t/05-tasks` estáveis).
  - `EduMaps::Task::Clustering`: dispatch por engine. HTTP →
    `$job->app->analytics->run_cluster({schema, table_name, id_column,
    features, parameters => {algorithm, clusters, eps, min_pts}})`. Validação
    ganhou campo opcional `features`. Pipe intacto (Rscript via R::Pipe).
  - `EduMaps::Task::Similarity`: HTTP → `run_similarity_db` (gower), com
    **falha explícita** p/ métricas não-gower no motor http (mensagem instrui
    usar `pipe`); pipe mantido p/ demais métricas.
  - `EduMaps::Task::CityAnalytics`: HTTP → `run_summary({codigo_ibge, schema,
    parameters => {type}})`. O contrato `{meta, cluster_info|similarity_info|
    analytics_info{r_meta}}` é preservado; `r_meta` = resposta JSON do endpoint
    (o serviço Plumber já persiste cluster_id/summary/pairs no banco).
  - Contrato de job preservado em todos os motores (query_args/inject_args
    iguais; só `r_meta` muda de origem: R::Pipe → HTTP).
  - Teste **`backend/t/05-tasks/analytics_engine.t`** — **5 subtests PASS**
    (server-fork emulando /cluster, /summary, /similarity/db):
    - `analytics_engine` helper reflete config; cluster via http engine
      (r_meta.analysis = 'cluster_kmeans', run_id do endpoint); similarity
      gower ok; similarity não-gower → job `failed` com mensagem; city_analytics
      via http (r_meta.analysis = 'city_summary').
    - Lição: `apply_city_analytics` enfileira na fila **'speculative'**
      (prioridade 0), que `minion->perform_jobs` NÃO processa (só fila
      'default') — no teste, enfileirar direto com
      `minion->enqueue(city_analytics => [$args])` para a fila padrão.
  - `perl -c` OK nos 4 módulos alterados.

### Fase 4 completa (commits)
- **`f195898` feat(data_pipeline): analytics.analysis_cache** — migration
  sqitch `analytics_analysis_cache` (`deploy/revert/verify` + `sqitch.plan`,
  dep `[schemas]`): tabela no schema `analytics` com PK `cache_key` (text,
  sha-1 canônico do Client), `analysis`, `params` jsonb, `payload` jsonb,
  `source_version`, `created_at`/`updated_at`/`expires_at` timestamptz;
  índices (analysis, source_version) e parcial em expires_at. Comentários PT-BR
  em todas as colunas. **Deployado e verificado em dev_super** (`edumaps_dev`);
  upsert real validado em psql com o mesmo SQL do `Client::_cache_write`.

### Fase 5 em aberto
- Rotas web `POST /api/task/{cluster,summary,similarity}`.

### Fase 5+6 completas (commits)
- **`0fcc56e` feat(backend): rotas web POST /api/task/{cluster,summary,
  similarity}**:
  - `EduMaps::Controller::Task` ganhou `request_cluster/request_summary/
    request_similarity` (padrão de `request_siope`: valida → enfileira →
    202 + `Location: /api/task/progress?job_id=X`).
  - Validações espelhadas nas tasks: cluster (table_name/id_column/schema/
    algorithm/clusters/eps/min_pts/features), summary (codigo_ibge 7 dígitos/
    analysis/schema), similarity (table_name/id_column/schema/metric — 5
    métricas, inclusive aitchison/dtw).
  - **Fila dedicada `analytics`**: rotas web enfileiram por
    `minion->enqueue(...)` direto em `{queue => 'analytics'}` — worker
    analítico separado do worker geral (Siope/OSM). `apply_*` seguem na fila
    default (t/05-tasks intactos). `/summary` NÃO usa `apply_city_analytics`
    (fila 'speculative' + CHI) por ser user intent.
  - Teste `backend/t/04-api/task.t` — 7 subtests PASS (202+job_id+Location+
    queue analytics p/ os 3; 400 p/ validações).
- **`7381eef` feat(deploy): worker fila analytics + pg_service.conf +
  config**:
  - systemd `files/edumaps-minion-analytics.service` + task Rex
    `deploy_analytics_worker_dev`: worker `minion worker -q analytics`.
  - `files/pg_service.conf` (deploy em `/root/.pg_service.conf`): serviços
    `[edumaps]` e `[edumaps_local]` — R codifica `service="edumaps_local"`
    por default/`EDUMAPS_ANALYTICS_DB_SERVICE`; antigamente o arquivo só
    tinha `[edumaps]` (conexão R falharia p/ `edumaps_local`).
  - `files/Renviron` + `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps_local`.
  - **Config `analytics_*`** adicionada ao template `files/edumaps_db.conf`
    (backend dos containers) e ao `backend/edu_maps.conf` local (não
    versionado): `analytics_url` (`http://analytic:8000`, env-overridable
    `ANALYTICS_URL`), `analytics_timeout` (300), `analytics_source_version`
    ('edumapsr-0.1.0'), `analytics_cache_enabled` (1), **`analytics_engine`
    ('pipe'** — OPCIONAL, trocar p/ 'http' p/ ativar o Plumber).
  - Validações: Rexfile syntax OK; suite verde (t/01-app, t/03-plugins,
    t/04-api, t/05-tasks/analytics_engine); **clustering.t (pipe) PASS** —
    motor legado intacto após F3.

### Estado
- F1–F6 concluídas e commitadas em `main`.
- **Aplicar no ambiente** (pendente de validação/acordo): rodar
  `rex prepare` (rsync) + `deploy_analytics_worker_dev` (novo worker) +
  `deploy_analytics_dev` (pg_service.conf/Renviron) no backend/analytic e, se
  for ativar Plumber, flippar `analytics_engine: http` na config dos
  containers.
- **Fase 6/7**: infra `pg_service.conf` + worker fila `analytics` + docs.

### Fora de commits (segue)
- WIP `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info→error).
- untrackeds: `backend/script/tasks/siope.pl`,
  `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`, e artefatos R CMD check
  (`analysis/edumapsr/edumapsAnalytics.Rcheck/`,
  `analysis/edumapsr/edumapsAnalytics_0.1.0.tar.gz`).
- Commit: hook post-commit quebrado (`GIT_DIR: unbound variable`) — esperado.

## Ciclo anterior — limpeza: gitignore + reorganização docs (concluído)

### Fechamento do ciclo anterior (2026-09-13)
- PR #57 mergeado em `main` (commit de merge `9361604`; branch
  `fix/deploy-backend-class-app` removida local e no remote). Ciclo de deploy
  encerrado após validação ponta a ponta nos containers.

### Limpeza — `.gitignore`
- Adicionados (artefatos de build/gerados e config local):
  `analysis/edumapsr/man/*.Rd` (roxygen2), `backend/cover_db/` (Devel::Cover),
  `data_pipeline/config/local.ini`.
- Apagado `backend/t/05-tasks/edumaps-analysis/similarity.t` (0 bytes).
- `frontend/*/node_modules` e `dist` já cobertos pelos `.gitignore` aninhados.

### Limpeza — reorganização de `docs/`
- **Estrutura nova**: `docs/archive/` (com `README.md` índice 1 linha/arquivo) e
  `docs/new_ideas/{implementations_ideas,concepts}`. Decisões do usuário:
  "recentes" = notas de 16-07 a 16-08; arquivar (não excluir) as datadas;
  `nvim.md` excluído; versionar os docs (eram untrackeds).
- **→ `new_ideas/implementations_ideas/`**: `notas_tecnicas_20` (score IQE),
  `_24` (Painel do Diretor), `_26` (plotly/ggplot2 via Perl), `_29` (EventBus
  frontend sem RxJS), `_32` (Stats::Model), `_34` (pré-computação especulativa).
- **→ `new_ideas/concepts/`**: `notas_tecnicas_17` (arquiteturas maduras),
  `_18` (similaridade por domínio).
- **→ `archive/`**: todas as demais notas (mais de 40) + idea antigas
  (`ideas.md`, `IA/*`, `analytics/*`), incluindo as 5 datadas
  (`deep.md`, `system_cloud_administration.md`, `random_forest.md`,
  `notebook-analises-censo-rankings.md`, `prompt/claude/clusterization.md`).
- **Atenção**: recuperei via container (`backend.edumaps:/opt/edumaps/docs`)
  7 arquivos apagados por engano do meu `rm -rf dev` (loop abortou por
  `mv dev/prompt`): `refactor.md`, `refactor_ui.md`, `testes.md`,
  `regressao_linear.md`, `system_cloud_administration.md`, `user_history_1.md`
  e `prompt/claude/clusterization.md`. Todos restaurados em `archive/dev/` com
  mtimes originais. Lição: `mv` de dir com loop tem que tolerar "dir not empty".
- **Ajustadas** referências: `.opencode/skills/r-analytics.md`
  (`docs/IA/clusters.md` → `docs/archive/IA/clusters.md`).

## Sessão anterior — Deploy/validação dos containers após remoção do submodule (concluída)

### Fechamento (2026-09-12)
- **Backend do container agora roda a classe `EduMaps`** (`script/edumaps.pl`)
  com todos os deps do `cpanfile` instalados (CHI, Strptime, RxPerl, Data::Fake,
  PDL, PDL::Stats::Kmeans etc. via cpanm/metacpan; PDL::Stats build OK no
  container). Units `edumaps-web`/`edumaps-minion` ativos; boot loga
  "EduMaps inicializado com sucesso [v0.001]".
- **DB do container atualizado**: faltava `analytics.mv_rede_escolas` (roda o
  `sqitch deploy` no banco do container — `rex -H database.edumaps
  deploy_db_dev`); MV populada (15.352 linhas). `/api/network/3551702/summary`
  passou de 500 (relation não existe) → 200 JSON com dados.
- **`/api/analytics/cities/search`**: endpoint espera param `q` (mapa
  `term => [qw/q query/]` do Model City via ctx params). O controller não
  validava ausência de `q` → 500 (`No value to wrap` na croak de
  `_wrap_percent`). Corrigido com validação `required('q','trim')` + regex de
  acentos e subteste novo (sem `q` → 400). `use utf8;` adicionado ao controller.
- **Validação ponta a ponta (container, direto :3000 e via nginx `Host:
  ubatexu.lan`)**: `/api/network/{summary,schools,performance,markers}` 200;
  `/api/network/123/summary` 404 (validação ibge OK); `cities/search?q=` 200
  (incl. acentos), sem `q` 400, `?term=` 400; `/api/city/suggestions?q=` 200;
  `/api/analytics/city/3551702/details` 404 (dado ausente — esperado); SPA
  nginx 200; `/analytic-api/health` e `openapi.json` 200; analytic (Plumber)
  responde `{"status":["ok"]}`.
- **PDL::Stats::Kmeans instalado em background no container** (logo
  `/tmp/pdl_install.log`, PID 4113) — concluído OK (PDL-2.106 + PDL::Stats).
- **Testes locais**: `t/04-api/{network,search-analytic,search-municipio,
  municipio}` ok. Falhas PRÉ-EXISTENTES (verificadas com stash, fora do escopo):
  `municipio.t` #8 OSM features (falta dado OSM) e `school/clustering.t`
  (mensagem do controller "Dados não encontrados..." ≠ "Não encontrado").
- **Commits nesta sessão** (branch `fix/deploy-backend-class-app` → PR):
  `fix(backend): completa deps no cpanfile`,
  `fix(backend): deploy usa script/edumaps.pl p/ app classe`,
  `fix(backend): valida param q em cities/search`,
  `fix(analysis): run.R aceita pacote instalado`,
  `fix(frontend): remove import uuid no toastStore`.
- **Atenção workflow**: `deploy_backend_dev` **não** roda rsync (é o `prepare`);
  em mudanças de código rodar `rex prepare` antes para o container pegar o
  working tree.

### Objetivo desta sessão
- Validar o deploy adaptado (Rex `backend/script/deploy/Rexfile`) após a remoção
  do submodule `analytics`, deixando backend/frontend/analytics funcionando
  de ponta a ponta nos containers LXC.

### Estado atual (em progresso)
- **Diagnóstico do backend FECHADO** — o deploy sobe **outra app** que não a que
  tem `/api/network`:
  - O serviço `edumaps-web` roda `edu_maps.pl` (app **Mojolicious::Lite** com
    rotas inline /api/city, /api/analytics, /api/school, map_svelte, tasks OSM/
    Siope) — **SEM `/api/network` e SEM `/api/city/suggestions`**.
  - As rotas novas vivem na **classe `EduMaps`** (`backend/script/edumaps.pl` →
    `Mojolicious::Commands->start_app('EduMaps')`), registradas via plugins
    (SchoolNetwork, City c/ `/suggestions`, School, Task, Rank). É o que
    `t/04-api/network/*` testa (`Test::Mojo->new('EduMaps')`) e o que o frontend
    novo chama (grep do SPA: `/api/network`, `/api/city/suggestions`,
    `/api/school/search|suggestions`, `/api/analytics/cities/search`).
- **`backend/cpanfile` está incompleto** p/ a classe app:
  - falta `CHI` (usado em `lib/EduMaps/Plugin/Helpers.pm:6`) → classe app NÃO
    boots no container (`Can't locate CHI.pm`).
  - falta `DateTime::Format::Strptime` (em
    `lib/EduMaps/Roles/Business/School/Finance.pm:5`) → `Model::City` não
    compila → `/api/analytics/cities/search` retorna 500
    (`Can't locate object method "search_for_complete"`).
  - Ambas estão instaladas local (perl do sistema); verificado também SHA do
    container == repo p/ os plugins API.
- Evidências: `carton exec perl edu_maps.pl routes` no container mostra a lista
  completa de rotas do Lite (sem network); grep `api/network/:codigo_ibge` na
  pág 404 = 0; boot do Lite loga `Error loading EduMaps::Model::City: Can't
  locate DateTime/Format/Strptime.pm` e `✓ Loaded: Model::SchoolNetwork`.
- 404 do `/api/network/3551702/*` no backend do container = rota inexistente
  (não é 500 nem controller). O antigo processo (841) também não tinha network.

### Decisão pendente (aguardando usuário)
- **Trocar alvo do deploy p/ a classe app** (`script/edumaps.pl`) + adicionar
  deps ao cpanfile + redeploy (plano proposto na sessão), **OU** registrar as
  rotas novas no Lite `edu_maps.pl`. Recomendado e alinhado aos testes: **classe
  app**. Observação: rotas legadas do Lite (/api/query-osm, /api/jobs/siope,
  map_svelte) não são usadas pelo frontend novo; SPA estático é servido pelo
  nginx (frontend deploy), não pelo backend.

### Plano proposto (aguardando OK do usuário)
1. `backend/cpanfile`: adicionar `CHI` e `DateTime::Format::Strptime`.
2. `backend/script/deploy/Rexfile`: apontar morbo **e** worker Minion para
   `script/edumaps.pl` (no lugar de `edu_maps.pl`).
3. `rex -H backend.edumaps deploy_backend_dev` (roda carton install ≈ contêiner
   reinstala deps, reescreve unit, reinicia) + restart do worker Minion.
4. Validar no container: `/api/network/3551702/{summary,markers,schools,
   performance}` (200), `/api/analytics/cities/search`, `/api/analytics/city/
   3551702/details`, `/api/city/suggestions`; SPA via nginx `Host: ubatexu.lan`.

### Deploy já rodado (esta sessão)
- `rex prepare` OK (3 hosts) — rsync do working tree (preserva mtime → **morbo
  não recarrega sozinho**; precisa `deploy_backend_dev`/restart explícito).
- `rex -H analytic.edumaps deploy_analytics_dev` OK (~15 min): pacote R
  `edumapsr`/`edumapsAnalytics` 0.1.0 instalado; Plumber 1.3.3;
  **`devtools` NÃO instala** no analytic (falha systemfonts/ragg — não é mais
  necessário em runtime). `edumaps-analytic` ACTIVE, porta 8000
  (`EDUMAPS_R_PORT=8000`), `openapi.json` HTTP 200 (/chart, /similarity).
- `rex -H backend.edumaps deploy_frontend_dev` OK após fix (abaixo). nginx
  serve o SPA via `Host: ubatexu.lan` (`/municipio/compare` 200).
- Backend `deploy_backend_dev` rodou mas ficou com 404/500 (causa acima:
  app errada + deps faltando).

### Correções locais FEITAS nesta sessão (NÃO commitadas ainda)
- `analysis/edumapsr/inst/plumber/run.R` — reescrito: usa o pacote instalado
  (`system.file("plumber/endpoint.R")`) com fallback `devtools::load_all`
  (antigo morria no container por falta de devtools). scp manual p/ container.
- `frontend/edumaps/src/shared/stores/toastStore.js` — removido import de
  `uuid` (não instalado); usa `crypto.randomUUID?.() || Math.random().toString(36)`.
  Build local `npm run build` OK; já replicado no container.
- WIP pré-existente segue intacto: `backend/lib/EduMaps/EventBus/Middleware/
  SiopeTask.pm` (1 linha); untrackeds `analysis/edumapsr/man/*.Rd`.

### Commits desta sessão (na ordem)
- `0b3bcf1` chore(deploy): adaptar Rexfile (frontend/edumaps, edumapsr,
  deploy_analytic_models & disable_frontend_vite removidos, POD 3 hosts).
- `0a8bb77` docs: atualizar memory + regra 5 do workflow (atualizar memory.md
  em todo PR/merge e commitar junto).

### Fatos do ambiente (descobertos/confirmados)
- Containers: `backend.edumaps`, `database.edumaps`, `analytic.edumaps`
  (hosts de rede `Backend`, `Database`, `analytic`). SSH OK da máquina local.
- Backend: node 22.22.3, nginx 1.22.1; morbo :3000 (`MOJO_MODE=development`,
  `MOJO_LISTEN=http://0.0.0.0:3000`, `MOJO_REVERSE_PROXY=1`); worker Minion
  `perl edu_maps.pl minion worker`; perl do container 5.36, carton exec via
  `/bin/carton`, deps em `/opt/edumaps/backend/local/lib/perl5`.
- Analytic: R 4.2.2, serviço em `files/edumaps-analytic.service`
  (WorkingDirectory=/opt/edumaps/analysis/edumapsr, `Rscript inst/plumber/run.R`,
  `EDUMAPS_R_PORT=8000`).
- `/opt/edumaps/analytics` (stale do antigo submodule) removido dos 3 containers.
- Observado **processo R `renv-watchdog`** (10:09) no backend container —
  provável lixo; pode ignorar por ora.
- Rex: binary `/home/itaipu/perl5/perlbrew/perls/perl-5.42.0/bin/rex`, rodar de
  `backend/script/deploy`. Rex `deploy_backend_dev` usa `carton install` + gera
  unit morbo via template (paths agora p/ `script/edumaps.pl`).

## Sessões anteriores — SchoolNetwork (backend)

### Escopo desta sessão
- Implementação full stack do **SchoolNetwork** (rede de escolas por município):
  backend + migration + página de comparação de redes `/municipio/compare`.

## Estado atual (final da sessão)
- Branch de trabalho `feat/backend/school-network` **mergeada em `main`** via
  **PR #56** (merge commit `62def60`) e **deletada** (remoto e local).
- Branch local/integração atual: **`main`** (tracking `origin/main`).
- Repo Github: `marcoarthur/edumaps`; `gh` autenticado como `marcoarthur`
  (protocolo SSH). Merge via **merge commit** `gh pr merge <n> --merge --delete-branch`.

### Commits desta sessão (na ordem)
- `8eda2f7` feat(backend): SchoolNetwork (Result/ResultSet RedeEscolas, Model,
  roles Profile/Analytic/Geo, Controller + Plugin API, registro em EduMaps.pm).
- `3b6c54a`, `aee26d9` docs: skills/AGENTS.md, docs do frontend.
- (work acumulado da branch na frente: EventBus, autocomplete, cache, middlewares,
  ranking, analytics/similarity — entrou junto no PR.)
- `be98345` feat(data_pipeline): etapas na `mv_rede_escolas`.
- `411c73f` feat(backend): summary com `total_etapas` e `media_etapas`.
- `45e2e9f` feat(frontend): página de comparação de redes por município.
- `dd99860` docs: workflow de PR e merge com `gh` → seção nova no `AGENTS.md`.
- **`62def60`** = Merge pull request #56 (feature completa na main).
- `9bd89c7` chore(analytics): remove submodule `analytics` deprecado
  (substituído por `analysis/edumapsr`).
- `07efdfc` chore: remove `.gitmodules` vazio (sem submodules restantes).

## O que foi entregue / estado
- [x] Migration Sqitch (`analytics_rede_escolas`) aplicada com sucesso no
      alvo `dev_super` (também aplicou pendentes `ranking_escolas` e
      `event_store`).
- [x] MV `analytics.mv_rede_escolas` populado: 15.352 linhas / 5.571 municípios.
  - Ex.: SP `3550308` rede federal: total_escolas=5, total_matriculas=3480,
    ideb_fund_i=6.50, ano_ideb=2023.
- [x] Migration `rede_escolas_etapas`: MVs agora expõem `total_etapas`
      (SUM de nro_etapas) e `media_etapas` (1 decimal). Aplicada no dev;
      validação via psql (sqitch verify lento).
- [x] Backend completo: Result/ResultSet `RedeEscolas`, Model `SchoolNetwork`,
      roles `Profile`/`Analytic`/`Geo`, Controller + Plugin API, registro em `EduMaps.pm`.
- [x] Testes modelo (`t/02-models/SchoolNetwork.t`) e API
      (`t/04-api/network/`) — **PASS**.
- [x] Frontend completa (feature `network-compare`):
  - Wrappers reativos de `@carbon/charts-svelte` (Radar/Line/BarChartGrouped/Donut)
    com ResizeObserver + polyfill em `vitest-setup.js`.
  - Página `/municipio/compare` (`frontend/edumaps/src/features/network-compare/`):
    banner por rede, KPIs, radar Perfil/Volume, barras agrupadas, donuts,
    timeline IDEB, tabela sortable, mapa Leaflet com `circleMarker` por rede
    + toggle de filtro; URL compartilhável `?codigo_ibge=`.
  - Entrada via SchoolSearchForm ("Comparar Redes do Município", pré-seleciona
    município) + autocomplete interno.
  - MSW handlers/fixtures com dados reais de Sertãozinho/SP (3551702).
- [x] Testes frontend: 18 novos (transformNetworkData, NetworkComparePage com MSW,
      smoke dos wrappers) — PASS. Build vite OK. 4 falhas pré-existentes não
      relacionadas (paginationStore ×3, SchoolRankingPage ×1).
- [x] Validação visual **aprovada** pelo usuário em
      `/municipio/compare?codigo_ibge=3551702`.
- [x] Submodule `analytics` (gitlab.com/marcoarthur/edumaps) **removido** da
      árvore — deprecado, substituído por `analysis/edumapsr`. Commit local
      `3de80d0` descartado; repo remoto no GitLab deixado intacto.

## Endpoints implementados
`/api/network/:codigo_ibge/{summary,schools,performance,markers}` (regex `\d{7}`):
- summary — rede por tipo de administração (federal/estadual/municipal/privada),
  agora com `total_etapas` e `media_etapas`
- schools — escolas do município + somas de matrículas
- performance — série IDEB/SAEB
- markers — GeoJSON FeatureCollection

## Correções feitas durante o ciclo (importantes)
1. `Geo.pm` (markers):
   - `not_null('me.geometry')` — `geometry` puro ficava ambíguo nos JOINs.
   - Propriedades do GeoJSON **qualificadas** (`me.municipio`, etc.) para evitar
     ambigüidade com o join de `municipio`.
   - Retorno com `encode('UTF-8', ...)` — necessário, pois `decode_json` do Mojo
     falha em strings utf8-flagged vindas do Postgres via `pg_enable_utf8`.
2. `Analytic.pm`: ResultSet não tem `each`; iterar com
   `->as_hash->get_all->each(sub { $_->{col} })`.
3. `Profile.pm` (schools):
   - `columns` com `-as` explícito nos SUMs (senão o alias não é gerado).
   - `limit` no lugar de `rows` (helper existente em SearchHelpers).
   - filtro `matricula.nu_ano_censo` no WHERE (não em `search_related`).
4. `Controller/SchoolNetwork.pm` (markers): usar
   `render(text => $result, format => 'json')` e não `render(json => ...)`
   (o retorno já é string GeoJSON; `render(json)` duplicava encoding —
   padrão seguido: `City` controller).
5. Testes: `maybe()` **não existe** no `Test2::Tools::Compare` (verificado).
   Substituído por asserts mais simples (`exists`). `number_gt` existe.

## Informações fornecidas pelo usuário (IMPORTANTE)
- **Rodar testes**: usar `prove -l` (equivale a `-I lib`) a partir de
  `backend/`, ou `yath` (runner mais moderno, preferido).
  Ex.: `prove -rl t/05-tasks` (o `-r` é recursivo).
  Sem `-l`, testes como `event_logger.t` falham com
  "Can't find application class EduMaps in @INC" — **não** é falha real.
- **Falhas restantes da suíte são previstas / pré-existentes** — os testes são
  complexos e dependem de serviços externos (R scripts, Siope scraping,
  schema `staging`, jobs gower/similarity). **Não modificar agora.**
  Há um ciclo futuro previsto de **cleanup da suíte** (não iniciar sem pedido).
- **Workflow do projeto** (registrado no AGENTS.md):
  plano → execução → aprovação → validação visual → PR + merge via `gh`
  (`gh pr create --base main` ... `gh pr merge <n> --merge --delete-branch`).
- **Autorização concedida de executar qualquer comando** neste ambiente de
  teste, inclusive via SSH da máquina local para os containers LXC
  (`backend.edumaps`, `database.edumaps`, `analytic.edumaps` — hosts de rede
  `Backend`, `Database`, `Analytic`).
- **Deploy**: Rex em `backend/script/deploy/Rexfile`, "as-is" (rsync do working
  tree). 3 containers: Backend (Perl + Minion + nginx/frontend estático),
  Database (PostgreSQL/PostGIS/Sqitch em `Database`), Analytic (R `edumapsr`,
  Plumber na porta 8000 via `EDUMAPS_R_PORT`). Frontend atual: `frontend/edumaps`
  (Svelte 5/Vite), não mais `frontend/map_app`.
- **Regra — rebuild dos containers Docker (somente no host `ubaxala`)**: sempre
  que houver merge em `main`, **rebuildar os containers Docker locais**
  (`docker compose up -d --build` no repo raiz) para sincronizar o ambiente
  local com o código novo. **Aplica-se APENAS ao `ubaxala`** (Stack Docker
  local: `db`/`sqitch`/`backend`/`frontend`/`minion`); nos demais hosts
  (`backend.edumaps`, `database.edumaps`, `analytic.edumaps`) essa regra
  **não se aplica** — lá o sync é via Rex (`rex prepare` + task de deploy).

## Comportamento / convenções do repo (descobertas)
- Idioma: PT-BR (comentários, docs e mensagens).
- Commit: `<type>(<scope>): <subject>` (máx. 50 chars, PT-BR). Scopes:
  `backend`, `frontend`, `data_pipeline`, `analytics` (= schema Postgres
  `analytics.mv_*`), `analysis`, `db`.
- Validações de formato de `codigo_ibge` invalid (`abc`, `123`, 8 dígitos)
  retornam **404** (convenção do `City`), não 400. 400 é só p/ params de query
  inválidos.
- `EduMaps::Schema::ResultSet::Base` compõe
  `EduMaps::Roles::DB::{PrettyPrint Formats SearchHelpers Scaling Stats Geo
  Joins Derived SQLUtils Aggregates ProcessedJob Pageable}`.
- ResultSet tem `as_hash`/`get_all` (Mojo::Collection), **não** tem `each` direto.
- `clean.ideb_notas_escolas.rede` e `clean.escolas.dependencia_administrativa`
  usam valores capitalizados: `Estadual/Federal/Municipal/Privada`.
  `clean.ideb_notas_escolas.etapa` ∈ `fundamental_i`, `fundamental_ii`,
  `ensino_medio`.
- Credenciais (dev): `PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel
  -d edumaps_dev`. Sqitch target: `dev_super`. Check "Workers Builds: edumaps"
  (deploy Cloudflare) falha em PRs — infran, não bloqueia merge (UNSTABLE).
- Frontend: `frontend/edumaps` (Svelte 5, Vite, Carbon, Leaflet, MSW, Vitest).
  Rotas em `src/app/routes.js`; `App.svelte` faz `matchRoute(router.path.split("?")[0])`.

## Pendências / fora do escopo desta sessão
- Falhas de teste PRÉ-EXISTENTES (não são regressões): `municipio.t` #8 (OSM
  features sem dado) e `school/clustering.t` (mensagem "Não encontrado").
- Mudanças NÃO commitadas da sessão atual:
- **Hook post-commit quebrado**: `.git/hooks/post-commit` linha 32
  `GIT_DIR: unbound variable` (assinatura de shell com `set -u` sem exportar
  GIT_DIR). O commit funciona; o hook erra depois. Não consertado (não pedido).
- Mudanças pré-existentes NÃO commitadas (mantidas fora de commits/PRs):
  - `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info → error)
  - untrackeds (fontes reais, commitar em ciclo próprio):
    `backend/script/tasks/siope.pl`,
    `backend/templates/osm/query/school.opq.ep`,
    `frontend/map_app/src/lib/js/city.js`.
  - Obs.: `analysis/edumapsr/man/*.Rd`, `backend/cover_db/` e
    `data_pipeline/config/local.ini` agora são GITIGNORADOS; `docs/*` foi
    versionado na reorganização (ciclo de limpeza).
- Próximo ciclo: cleanup da suíte de testes (quando o usuário pedir).

## Comandos úteis para retomar
```bash
cd /home/itaipu/Code/Data/leaflet/backend
prove -vl t/02-models/SchoolNetwork.t        # modelo
prove -vl t/04-api/network/                  # API
prove -rl t/05-tasks                         # (falhas previstas p/ análises R/Siope)

cd /home/itaipu/Code/Data/leaflet/frontend/edumaps
npm run test:run                             # vitest (18 testes da feature inclusos)
npm run build                                # build vite

# PR + merge
git push -u origin <branch>
gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
gh pr merge <n> --merge --delete-branch
```
