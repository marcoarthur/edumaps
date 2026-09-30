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

### Ambiente: `sqlite3` pode não existir (2026-09-30)

O binário `sqlite3` **não está instalado** no host local (`ubaxala`) — as
queries acima falham com `sqlite3: comando não encontrado`. Usar o módulo
`sqlite3` do Python (ou `DBD::SQLite` no perlbrew), sempre em **read-only**:

```bash
DB=~/Code/perl/DBIX/zotero.sqlite
python3 - <<'PY'
import sqlite3, os
db = os.path.expanduser("~/Code/perl/DBIX/zotero.sqlite")
c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)   # read-only garantido
cols = (113, 115, 116, 119, 121, 122, 125, 126, 127, 129)
for coll, iid, typ, title in c.execute(f"""
  SELECT c.collectionName, i.itemID, it.typeName,
    substr((SELECT v.value FROM itemData id JOIN itemDataValues v ON v.valueID=id.valueID
      WHERE id.itemID=i.itemID AND id.fieldID=(SELECT fieldID FROM fields WHERE fieldName='title')
      LIMIT 1),1,58)
  FROM items i JOIN itemTypes it ON it.itemTypeID=i.itemTypeID
  JOIN collectionItems ci ON ci.itemID=i.itemID JOIN collections c ON c.collectionID=ci.collectionID
  WHERE c.collectionID IN ({','.join(map(str, cols))}) ORDER BY c.collectionName, i.itemID"""):
    print(f"Z:{iid} [{coll}] {typ} :: {title}")
PY
```

> `perl -MDBD::SQLite` (1.78) também funciona como alternativa.

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

### 2026-09-30 — 3ª passada (lote de mobilidade, fecha a issue #123)

**T10 — o catálogo estava incompleto, e a lacuna que ele supostamente não tinha
solução tinha.** A 2ª passada registrou mobilidade como "a mais difícil, o padrão
é GTFS municipal não padronizado". Verificando as fontes com o mesmo rigor das
outras, apareceram **quatro bases nacionais**:

| Dimensão | Fonte | Chave |
|---|---|---|
| Fluxo de deslocamento | ANTT / MONITRIIP | par de municípios, mensal desde jan/2019, CC BY |
| Tráfego e risco | ANTT (SAT, acidentes, geodados) | trecho viário com coordenada, CC BY |
| Malha com volume | DNIT/INDE (SNV + VMDA) | trecho de rodovia, domínio público |
| Frota e sinistralidade | Transportes (RENAVAM, RENAEST) | município, mensal desde mai/2013 |

E o elo que fecha o ciclo: **isocronas OSRM/Valhalla** traduzem a malha do OSM
em "população alcançável a pé em 15/30/45 min" — que é **exatamente** a
interseção entre rede viária e malha censitária do IBGE, e **sem tocar em dado
de passageiro**. É a solução mais segura em LGPD para a lacuna 5.

**A correção honesta é que o problema nunca foi cobertura, foi publicação.** O
deslocamento escolar com **chave de escola** existe em **um único município
verificado** — o Recife publica vagas por unidade e por turno. O dado está nos
DETRANs e nas secretarias de educação e quase nunca é aberto. Isso inverte a
recomendação: não "piloto municipal com honestidade sobre a falta de cobertura",
mas "ingerir as quatro bases nacionais e usar o Recife como prova de
viabilidade".

**T11 — o teste que mais valeu foi o que deu errado.** O **PNCT**, que a issue
tratava como malha rodoviária aberta, tem página de download em **404**,
visualizador sem API e rodapé "Todos os Direitos Reservados". O caminho aberto
real — camada de modelagem de VMDA espelhada no **INDE**, em domínio público —
só apareceu por metadados de terceiro. **Sete correções** vieram do lote, e a
mais estranha é o **"Sistema de Informações sobre Demandas de Transporte"**,
que **não existe** com esse nome (o real é a SIMU/SIMOB da ANTP, sobre frota e
semáforo, de **2014**, publicada só em PDF).

**T12 — o método se auto-verificou num caso difícil.** A ficha do **CKAN do
Recife** somou **16 pontos** e era a melhor do lote: única granularidade escolar,
melhor API (DataStore com SQL, sem auth). Foi rebaixada para `[média]` **por
consistência** com o BCB, porque aceitar ODbL aqui seria trapacear no método —
o rebaixamento do BCB não pode depender de a fonte ser chata. A diferença com o
**OSM** (também ODbL, já ingerido) ficou escrita na ficha: lá a obrigação já
existe, aqui criaria do zero. **Escrever essa diferença vale mais que a
prioridade em si**, porque é o que impede o próximo de "resolver" a incoerência
achando que é um erro.

**T13 — duas descobertas operacionais com custo de projeto:**
- **Overpass tem rate limit verificado de 2 slots simultâneos.** A extração
  atual, se paralelizada, seria bloqueada → fila com repetição espaçada e
  persistência do bruto em disco.
- **OSRM/Valhalla públicos são servidores de demonstração, sem SLA.** Como as
  isocronas são o indicador mais defensável da lacuna, virou **requisito de
  arquitetura**: extrair o *tileset* uma vez e **auto-hospedar** os roteadores.

**T14 — caso-limite de LGPD, que generaliza a Fase 0.** O conjunto **SPTRANS
"Créditos Eletrônicos do Bilhete Único — Usuário"** é **CCZero** — o degrau mais
alto de liberdade de uso — e ainda assim é **nível individual**, com saldo por
usuário. Cruzado com escola e horário, reconstrói o trajeto de um aluno. O
caso-limite vale mais que a regra: **licença aberta não anula risco LGPD**, e a
allowlist de endpoints da Fase 0 tem de cobrir *todas* as fontes, não só a API do
SUS.

**Veredito da 3ª passada: aprova com ressalva de método.** O acervo está
completo quanto a fontes; a ressalva é que a priorização depende de duas
decisões jurídicas ainda abertas (ODbL do Recife e a contradição de licença da
camada do INDE) que estão **escritas, não escondidas**.

### 2026-09-30 — 2ª passada (catálogo de fontes abertas, issue #123)

**T6 — o acervo tinha um buraco de metadado, não de conteúdo.**
A direção de 16/09 que mais pesou nesta passada: os *dados* do EduMaps já eram
amplos, mas **nada no acervo registrava quais fontes foram descartadas e por
qué**. Um índice que só lista o que existe não ajuda a decidir o que não
construir. O catálogo de fontes (`docs/analises/fontes_de_dados.md` +
`fontes/`) preenche exatamente isso: **61 candidatas avaliadas, 21 `[alta]`, e
um registro explícito do que saiu** — com motivo, não por omissão.

**T7 — o que a verificação em profundidade mudou no plano (achados que contrariam
o enunciado da issue).**
- **Segurança é a lacuna mais barata de fechar** — `BrazilCrime` (CRAN) é um
  `library()`, nacional e municipal. Mas é também a de **maior risco ético**:
  dado de ocorrência policial é dado sensível por natureza, e o acesso via SINESP
  é restrito. Cheap *e* delicado não é contraditório, é a definição do caso.
- **Conectividade é a lacuna mais difícil** — e a única sem solução verificada em
  todo o catálogo. A leitura inicial de que *"mobilidade também não tem solução"*
  estava **errada**: ver a 3ª passada, que a overturnou.
- **O BCB usa ODbL share-alike** → materializar série no Postgres do EduMaps
  abriria a base sob copyleft. **Descartado por licença, não por mérito.**
- **DATASUS publica microdado individual sem mitigação** — *verificado em payload
  de produção*, não inferido. Isso não é nota de rodapé: é **requisito de
  arquitetura** (allowlist de endpoints no pipeline), porque um erro de URL hoje
  baixaria dado sensível de menor para o banco de dev.
- **FNDE é inacessível a cliente não-browser** (SPA sem SSR + CKAN 401). Três
  fontes dependem disso e foram rebaixadas por **acesso**, não por valor.
- **Catorze itens do enunciado da issue não existem ou mudaram de nome** (7 aqui,
  7 no lote de mobilidade): `ibge7`,
  `geodesobr`, `RRPP`, `CNTramas`, `PDL Educationis`, `SIGESC`, `Novo PAC da
  CGU`; e `PNCT`→`PNATE`, `GESAC`→modalidade do Wi-Fi Brasil, `PRODES/DETER`
  são do **INPE** e não do IBAMA, `SISLIC` **exige login** (não é dado aberto).
- **Achado que abre a lacuna 1 sem custo**: o **Atlas do IDHM** publica ~120
  indicadores municipais com dimensões **SAÚDE** e **VULNERABILIDADE** já
  calculadas — contorna o item mais caro do plano (acesso difícil ao DATASUS).
- **Achado que resolve ingestão**: a **Base dos Dados** entrega Censo Escolar
  **2007–2022 em BigQuery**; e a **malha do setor censitário** (via `geobr`/
  `censobr`, desde 1960) permite sair do valor municipal uniforme — que é a maior
  simplificação atual do IVET.
- **Censo Escolar do INEP vai de 1995 a 2025** (confirmado nesta passada; a
  alegação inicial do levantamento estava certa) — mas a URL de 2025 tem
  **underscore extra** (`..._2025_.zip`). ETL ingênuo quebra só naquele ano.
- **Licença do INEP continua não verificada** (só o rodapé CC BY-ND do portal,
  que cobre conteúdo do site, não os dados) → é o **único** motivo pelo qual o
  lote educação inteiro fica fora de `[alta]`. Uma única e-SIC resolve quatro
  fichas.

**T8 — prioridades que mudaram de lugar por causa do catálogo.**
- **[alta] nova — saúde via `CNES` + `DATASUS/SISAB`**: a oferta de saúde em
  **ponto** (coordenada) é o que torna o bloco cartografável, e não existia.
- **[alta] nova — contexto municipal via IBGE**: SIDRA + malhas + setor
  censitário somam 52 pontos e são a base de quase todo o resto.
- **[alta] nova — dimensão fiscal via `tesouror` (SICONFI)**: o IVET não tinha
  nenhuma dimensão orçamentária municipal.
- **[média] `DVC` (Zotero 10097) subiu de relevância**: com 21 fontes de alta
  prioridade e 8 domínios, versionar datasets deixa de ser conveniência.
- **[alta] confirmado — dicionário de dados (Zotero 9892)**: Base dos Dados e
  MCP-Brasil entregam dicionário pronto; falta padronizar o do INEP.
- **[baixa] confirmado — similaridade/PgVector** espera: só ganha valor depois
  que o IVET tiver as novas dimensões (contexto, saúde, conectividade). Não é
  mais a primeira direção do backlog.
- **Xadrez honesto**: **`GeoBr`/Censo por setor** e **Atlas/IDHM** são as duas
  entradas com melhor relação custo/benefício do catálogo inteiro, e nenhuma
  delas era fonte antes desta passada.

**T9 — índice atualizado.**
`docs/indice.md` ganhou a **seção 12** (análises e catálogo de fontes) e teve a
numeração corrigida: havia **duas seções "## 11."** (`Funcionalidades` e
`Clientes`), agora 11/12/13. Registrado porque índice com número repetido
quebra qualquer link por âncora e é o tipo de erro que sobrevive anos.

**Veredito da passada: aprova.** O acervo tinha as peças; faltava o registro do
que **não** usar. Agora tem.

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
- [ ] **e-SIC/Fala.BR ao INEP** — licença de uso do Censo Escolar, IDEB, ENEM e
  painel do PNE. Única pendência que bloqueia 4 fichas de `[alta]`
  (issue #123, pendência 1 do lote educação).
- [ ] **e-SIC ao MEC/NIC.br** — CSV + dicionário de dados do Medidor Educação
  Conectada. A metodologia de agregação já está publicada na aba "Dados" do
  portal: é a ação de maior retorno do catálogo.
- [ ] **e-SIC ao FNDE** — URL de download + dicionário do Novo PAC/Proinfância e
  do PNATE (o portal atual é SPA inacessível a cliente).
- [ ] **Allowlist de endpoints no `data_pipeline`** antes de qualquer job de
  saúde — a API do SUS publica microdado individual sem mitigação
  (verificado em payload).
- [ ] Avaliar **DVC** para versionar datasets — prioridade elevada pela #123.
- [ ] Consolidar **dicionário de dados** oficial (Zotero 9892 + rótulos do Censo).
- [ ] Marcar docs superados (`refactor*`, `system_cloud_administration`) como
  arquivados.
- [ ] Esvaziar/dar uso à subcoleção Zotero `backend`.
- [ ] Decidir governança LGPD/CEP antes de qualquer uso da **PeNSE** (dado
  sensível de menor) — é a única fonte do catálogo que exige decisão
  institucional, não técnica.

## Direções priorizadas

- **[alta]** **Ingerir contexto municipal e sub-municipal do IBGE** (SIDRA +
  malhas + Censo por setor censitário) — 52 pontos somados, habilitadora de
  quase todo o resto do catálogo, e é o que tira o IVET do valor municipal
  uniforme (issue #123).
- **[alta]** **Bloco de saúde via `CNES` + `DATASUS/SISAB`** — oferta em ponto
  (coordenada) + efetividade de APS em chave IBGE; torna a saúde cartografável
  sem tocar em dado individual.
- **[alta]** **Dimensão fiscal municipal via `tesouror`/SICONFI** — o IVET não
  tinha nenhuma dimensão orçamentária.
- **[alta]** **Dicionário de dados** das tabelas do Censo (Zotero 9892) — destrava
  rótulos para ML/Gestora e documenta as chaves (bigint vs varchar).
- **[média]** **Conectividade e segurança** — segurança tem o único caminho
  reproduzível (BrazilCrime); conectividade depende de e-SIC. Baratas em custo,
  delicadas em ética.
- **[média]** **DVC** para versionar datasets do pipeline (Zotero 10097) — sobe
  de conveniência a necessidade com 21 fontes de alta prioridade.
- **[média]** Padronização/qualidade com **Git Hooks** (Zotero 9931).
- **[média]** Promover **RandomForest/índices** (Zotero 10450/10297) a produto.
- **[baixa]** **Similaridade escolar/municipal via PgVector** (Zotero 11766) —
  **rebaixada nesta passada**: o valor depende de o IVET ter as novas dimensões;
  fazer antes é afinar um índice incompleto.
- **[baixa]** Usar a **literatura** (IDEB/DEA, Zotero 10453/10454/10673/10456)
  para embasar metodologia dos indicadores.

## Veredito

- **Aprova com ressalva de método** (2026-09-30, 3ª passada): o acervo de fontes
  está completo — **61 fontes verificadas, 21 `[alta]`, nenhuma com campo não
  confirmado**. A ressalva é que a priorização depende de **duas decisões
  jurídicas abertas** (ODbL do Recife, contradição de licença da camada do INDE),
  ambas **escritas** na ficha de cada fonte. Lição da passada: a lacuna de
  mobilidade foi declarada "sem solução" na 2ª passada e tinha **quatro bases
  nacionais** — o erro foi de *escopo de verificação*, não de método.
- **Aprova** (2026-09-30, 2ª passada): o acervo tinha as peças e faltava o
  registro do que **não** construir. O catálogo de fontes (#123) fecha essa
  lacuna de metadado, e a verificação em profundidade corrigiu sete itens do
  próprio enunciado. Índice com numeração duplicada corrigido.
- **Aprova com ressalvas** (2026-09-16): o acervo é rico, mas hoje está
  **partido** entre `docs/` (durável) e Zotero (efêmero), com duplicatas,
  tópicos órfãos e docs superados. O `docs/indice.md` passa a ser o mapa único;
  as direções de maior valor são **PgVector** e **dicionário de dados**.
