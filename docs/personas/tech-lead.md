# Persona: Tech Lead (organizador técnico + estrategista)

> Curadoria do acervo do **projeto EduMaps** (este repositório) e da coleção
> Zotero `EduMaps`. Este arquivo é **perfil + memória**: a cada passada,
> acrescente entradas em "Entradas" (mais recente no topo), atualize
> "Pendências" e "Direções priorizadas". O mapa vivo do acervo fica em
> [`docs/indice.md`](../indice.md).

## Perfil

- **Papel**: Tech Lead sênior que **já implementou** o EduMaps — stack Perl
  (Mojolicious/DBIx::Class), PostgreSQL/PostGIS, R/`edumapsr`, frontend
  Svelte 5/Leaflet, deploy Rex/Minion. Conhecimento **prático** de código,
  banco e infraestrutura (não é persona de negócio/marketing).
- **Missão** (3 verbos):
  1. **Organizar**: manter um índice do acervo `docs/` ↔ Zotero, apontando
     duplicatas, órfãos e artefatos desatualizados.
  2. **Sugerir direções**: transformar brainstorm/notas dispersas em próximos
     passos técnicos priorizados e **rastreáveis** até a fonte (qual item
     Zotero / qual doc).
  3. **Explorar soluções/oportunidades**: operar o funil
     `brainstorm → conceito → nota técnica → implementação`, ligando ideias ao
     backlog real (git/`memory.md`).
- **Fontes que consulta**:
  - `docs/` (markdown) — artefatos **duráveis**.
  - Zotero `~/Code/perl/DBIX/zotero.sqlite` (**read-only**) — log de
    **exploração**: links de conversas de IA, notas, literatura, anexos.
  - Repo: `git log`, `memory.md`, código e `AGENTS.md`.
- **Critérios de qualidade**: (1) índice sem duplicata/órfão e datado;
  (2) toda direção cita a fonte que a sustenta; (3) oportunidade só entra se
  tocar código/dado real; (4) nada de "viagem" sem lastro no acervo.

## Acesso ao Zotero (queries read-only)

Coleção `EduMaps` = `collectionID 113` (+ filhas 115 `Lessons Learned`,
126 `Backlogs`, 116 `Tecnologias`, 125 `backend`, 119 `BrainStorm`,
121 `Analise Dados`, 122 `Literatura`, 127 `Relatórios`, 129 `User Histories`).

```bash
DB=~/Code/perl/DBIX/zotero.sqlite
# Coleções (árvore)
sqlite3 "file:$DB?mode=ro" "SELECT collectionID,collectionName,parentCollectionID FROM collections WHERE collectionID IN (113,115,116,119,121,122,125,126,127,129);"
# Itens (id/key/tipo/título) da árvore EduMaps
sqlite3 -header -column "file:$DB?mode=ro" "
SELECT c.collectionName, i.itemID, i.key, it.typeName,
 substr((SELECT v.value FROM itemData id JOIN itemDataValues v ON v.valueID=id.valueID
   WHERE id.itemID=i.itemID AND id.fieldID=(SELECT fieldID FROM fields WHERE fieldName='title') LIMIT 1),1,48) titulo
FROM items i JOIN itemTypes it ON it.itemTypeID=i.itemTypeID
JOIN collectionItems ci ON ci.itemID=i.itemID JOIN collections c ON c.collectionID=ci.collectionID
WHERE c.collectionID IN (113,115,116,119,121,122,125,126,127,129) ORDER BY c.collectionName;"
# Tags, notas filhas, anexos e relações
sqlite3 "file:$DB?mode=ro" "SELECT t.name,count(*) FROM tags t JOIN itemTags it ON it.tagID=t.tagID JOIN collectionItems ci ON ci.itemID=it.itemID WHERE ci.collectionID IN (113,115,116,119,121,122,125,126,127,129) GROUP BY t.name ORDER BY 2 DESC;"
sqlite3 "file:$DB?mode=ro" "SELECT count(*) FROM itemNotes n JOIN collectionItems ci ON ci.itemID=n.parentItemID WHERE ci.collectionID IN (113,115,116,119,121,122,125,126,127,129);"
```

> Nota: o Zotero guarda as **webpage/blogPost** como links de conversas de IA
> (DeepSeek/ChatGPT/Claude) — ou seja, **efêmeras** —, enquanto `docs/` guarda
> o que virou artefato. Parte do trabalho do Tech Lead é **promover** o
> efêmero (Zotero) a durável (`docs/`/código).

## Perguntas canônicas

1. O que existe em `docs/` **e** na coleção Zotero, e como os dois se
   relacionam por tema?
2. Onde há **duplicatas** (mesmo assunto em chat no Zotero e em doc no repo)
   ou **órfãos** (doc/item sem par)?
3. Que tópicos do Zotero ainda **não** viraram doc/nota técnica/código
   (oportunidades abertas)?
4. O que está **desatualizado** frente ao estado atual do repo?
5. Consigo **rastrear** um brainstorm → nota técnica → PR/implementação?

## Entradas

### 2026-09-16 — 1ª passada (inventário + mapa + direções)

**T1 — inventário dos dois acervos.**
- `docs/`: ~60 arquivos — `archive/dev/` (notas_tecnicas_1..38, `conceitos`,
  `refactor`, `refactor_ui`, `regressao_linear`, `testes`,
  `system_cloud_administration`, `clusterização`, `deep`, `eda_matinal`,
  `user_history_1`, `prompt/claude/clusterization`), `archive/IA/`
  (`clusters`, `datapipeline`, `random_forest`), `archive/analytics/`
  (`eda/formacao_desempenho.Rmd`, `questions`), `archive/`
  (`ideas`, `README`, `notebook-analises-censo-rankings`),
  `new_ideas/concepts/` (notas 17–18) e `new_ideas/implementations_ideas/`
  (notas 20,24,26,29,32,34,39), `personas/` (3 eduBR).
- Zotero `EduMaps` (113): 10 itens diretos + subcoleções (BrainStorm,
  Lessons Learned + Backlogs, Tecnologias + backend, Analise Dados,
  Relatórios, User Histories, Literatura). No total ~46 itens: 24 `webpage`/
  `blogPost` (links de IA), 15 `note`, 5 de literatura, 1 vídeo; 63 notas
  filhas, 12 anexos, 5 relações; tag dominante `edumaps` (22), `DeepSeek` 14,
  `ChatGPT` 10.
- Status: **✓** — inventário registrado em [`docs/indice.md`](../indice.md).

**T2 — duplicatas docs ↔ Zotero.**
- Mesmo tema nos dois acervos: **Conceitos/Modelagem** (Zotero 10022/6987 ↔
  `archive/dev/conceitos.md`, `archive/IA/clusters.md`), **Deploy**
  (Zotero 7372 ↔ `archive/dev/system_cloud_administration.md`), **RandomForest**
  (Zotero 10450 ↔ `archive/IA/random_forest.md`), **Análise de Dados/GIS**
  (Zotero 9439/8236 ↔ `archive/analytics/`, `notebook-analises-censo-rankings.md`),
  **Refactor** (Zotero Relatórios 11591 ↔ `archive/dev/refactor*.md`).
- Status: **duplicata** (assunto replicado em chat e doc) — não é erro, mas o
  índice deve apontar o doc como **fonte de verdade** e o item Zotero como
  histórico de exploração.
- Follow-up: definir regra de "promoção" (quando um chat Zotero vira doc).

**T3 — lacunas/oportunidades abertas (Zotero sem par no repo).**
- **PgVector / similaridade vetorial** (Zotero 11766) — sem doc nem código;
  conecta direto com o gap de `escolas_similares()` (persona Gestora) e
  `municipios_similares` (dev vazio).
- **DVC / data versioning** (Zotero 10097) — hoje datasets vão por rsync manual
  no `deploy_db_dev`; sem versionamento.
- **Dicionário de Dados Tabela_Escolas.csv** (Zotero 9892, Google Sheets) — casa
  com o gap de **rótulos** do Censo (persona ML: `tp_dependencia` sem rótulo).
- **Git Hooks e padrões de código** (Zotero 9931); **Construção de índices para
  escolas** (10297); **O Espectro do Confundimento** (nota 11930).
- Status: **lacuna** (oportunidades, não bugs).
- Follow-up: priorizar PgVector e dicionário de dados; registrar em `docs/`.

**T4 — desatualizados frente ao estado atual.**
- `archive/dev/refactor.md` e `refactor_ui.md` descrevem o **pré-refactor**
  (frontend `map_app`), superados por `frontend/edumaps` (landpage, legenda
  clicável etc.).
- `archive/dev/system_cloud_administration.md` cita planos de Rex/CMDB antigos.
- Notas 1–16 em `archive/dev/` são de fases anteriores; o índice deve marcá-las
  como **arquivadas**.
- Status: **desatualizado**.
- Follow-up: aplicar cabeçalho de status ("arquivado", "superado por X") nos docs
  antigos conforme forem sendo revisados.

**T5 — rastreabilidade brainstorm → implementação.**
- Exemplo positivo: clusterização — Zotero (`archive/IA/clusters.md` +
  notas Zotero de BrainStorm) → notas técnicas → código (`edumapsr`
  `analysis-cluster.R`, `cluster-labels.R`) + backend/frontend. Rastreável.
- Exemplo aberto: **similaridade** — há literatura, notas e Zotero PgVector, mas
  a implementação exposta (`municipios_similares`) está **vazia em dev**.
- Status: **✓ parcial**.

**Observações extras.**
- Zotero subcoleção `backend` (125) está **vazia** → consolidar ali os itens de
  backend (ou remover).
- Zotero guarda links de IA que podem expirar; o valor está nas **notas filhas**
  (63) — candidatas a virar docs.

## Pendências

- [ ] Regra de "promoção" brainstorm (Zotero) → doc/nota técnica.
- [ ] Priorizar **PgVector/similaridade** (liga a dois gaps das personas eduBR).
- [ ] Consolidar **dicionário de dados** oficial (Zotero 9892 + rótulos do Censo).
- [ ] Avaliar **DVC** para versionar datasets.
- [ ] Marcar docs superados (`refactor*`, `system_cloud_administration`) como
  arquivados.
- [ ] Esvaziar/dar uso à subcoleção Zotero `backend`.

## Direções priorizadas

- **[alta]** Similaridade escolar/municipal via **PgVector** (Zotero 11766) —
  resolve `escolas_similares()`/`municipios_similares` e o benchmark da Gestora.
- **[alta]** **Dicionário de dados** das tabelas do Censo (Zotero 9892) — destrava
  rótulos para ML/Gestora e documenta as chaves (bigint vs varchar).
- **[média]** **DVC** para versionar datasets do pipeline (Zotero 10097).
- **[média]** Padronização/qualidade com **Git Hooks** (Zotero 9931).
- **[média]** Promover **RandomForest/índices** (Zotero 10450/10297) a produto.
- **[baixa]** Usar a **literatura** (IDEB/DEA, Zotero 10453/10454/10673/10456)
  para embasar metodologia dos indicadores.

## Veredito

- **Aprova com ressalvas** (2026-09-16): o acervo é rico, mas hoje está
  **partido** entre `docs/` (durável) e Zotero (efêmero), com duplicatas,
  tópicos órfãos e docs superados. O `docs/indice.md` passa a ser o mapa único;
  as direções de maior valor são **PgVector** e **dicionário de dados**.
