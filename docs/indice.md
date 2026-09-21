# Índice do acervo — EduMaps

> Mapa vivo dos artefatos do projeto, mantido pela persona
> [Tech Lead](personas/tech-lead.md). Une dois acervos:
> - **`docs/`** — artefatos **duráveis** (notas técnicas, conceitos, relatórios).
> - **Zotero** (`~/Code/perl/DBIX/zotero.sqlite`, coleção `EduMaps` id 113) —
>   log de **exploração**: links de conversas de IA, notas, literatura, anexos.
>
> **Convenção de rastreio**: item Zotero = `Z:<itemID>` (ex.: `Z:11766`).
> **Status**: 🟢 ativo · 🟡 parcial · 🔴 arquivado/superado.
> Atualizado pelo Tech Lead a cada passada (última: 2026-09-16).

## Legenda das fontes Zotero

- `webpage`/`blogPost` = link de conversa de IA (DeepSeek/ChatGPT/Claude) —
  **efêmero**; o valor durável costuma estar nas **notas filhas**.
- `note` = nota/análise escrita (durável em conteúdo, presa ao Zotero).
- `journalArticle`/`thesis`/`videoRecording` = literatura de apoio.

---

## 1. Backend Perl / Infra
- 🔴 `docs/archive/dev/refactor.md`, `refactor_ui.md` — pré-refactor (frontend `map_app`), superado por `frontend/edumaps`.
- 🟢 `docs/archive/dev/system_cloud_administration.md` — administração/infra (Rex, serviços).
- 🟡 `docs/archive/dev/testes.md` — estratégia de testes (parcial vs suíte atual).
- 🟢 Z:6891 `EduMaps Backend Perl` · Z:6939 `EduMaps Desenvolvimento` · Z:11591 (nota: Relatório de Refatoração do Backend).
- ⚪ Subcoleção Zotero `backend` (125) **vazia**.

## 2. Dados / PostGIS
- 🟢 `docs/archive/IA/datapipeline.md` — pipeline de dados.
- 🟢 `docs/archive/notebook-analises-censo-rankings.md` — análises de censo/rankings.
- 🟡 Z:8236 `EduMaps GIS` · Z:9439 `EduMaps Análise dos Dados` · Z:9892 `Dicionário de Dados Tabela_Escolas.csv (Censo 2025)` (Google Sheets).
- 🔴 **PgVector/similaridade vetorial** (`Z:11766`) — sem doc/código (oportunidade).

## 3. Analytics / R / ML
- 🟢 `docs/archive/IA/random_forest.md` · `docs/archive/dev/regressao_linear.md`.
- 🟢 `docs/archive/analytics/eda/formacao_desempenho.Rmd` · `docs/archive/analytics/questions.md`.
- 🟢 Pacote `analysis/edumapsr` (`edumapsAnalytics`) + personas eduBR.
- 🟢 Z:9454 `Ecossistema R para Modelagem` · Z:10450 `Desenvolvimento de Modelo RandomForest` · Z:10297 `Construção de índices para escolas`.
- 🟢 Z:10324 (nota: integração do módulo R Analytics) · Z:11770 (nota: dicionário CadÚnico) · Z:11930 (nota: "O Espectro do Confundimento").

## 4. Frontend / UI (Svelte 5 · Leaflet)
- 🔴 `docs/archive/dev/refactor_ui.md` — superado por `frontend/edumaps`.
- 🟢 `docs/new_ideas/implementations_ideas/notas_tecnicas_39.md` — landpage + logo + navegação.
- 🟢 `docs/new_ideas/*` — notas de implementação de UI/clusters.
- 🟢 Z:10100 (nota: aprendizados em Svelte) · Z:7453 `EduMaps Visualizações Investigações`.

## 5. Deploy / DevOps
- 🟢 `backend/script/deploy/Rexfile` (código) — fonte de verdade do deploy.
- 🟡 `docs/archive/dev/system_cloud_administration.md` — plano antigo de Rex/CMDB.
- 🟢 Z:7372 `EduMaps Estratégia de Deploy` · Z:9931 `Git Hooks e padrões de código` · Z:10097 `Home DVC (Data Version Control)`.

## 6. Conceitos / Modelagem
- 🟢 `docs/archive/dev/conceitos.md` · `docs/archive/IA/clusters.md` · `docs/archive/dev/clusterização.md`.
- 🟢 Z:10022 `EduMaps Conceitos` · Z:6987 `EduMaps Modelagem` · Z:9563 `EduMaps Conceitos Matemáticos` · Z:6739 `Projeto EduMaps`.
- 🟢 `docs/archive/dev/user_history_1.md` · notas Zotero `User Histories` (Z:12006 ranking+cluster, Z:12037 busca de escolas similares).

## 7. Curadoria eduBR (personas)
- 🟢 `docs/personas/pesquisadora-educacional.md` · `especialista-ml.md` · `gestora-escolar.md` · `tech-lead.md`.
- 🟢 Repo separado `~/Projects/eduBR` (pacote R) — objeto de curadoria.

## 8. Notas técnicas (série)
- 🔴 `docs/archive/dev/notas_tecnicas_1..16.md` — fases anteriores (**arquivadas**).
- 🟢 `docs/archive/dev/notas_tecnicas_{19,21,22,23,25,27,28,30,31,33,35,36,37,38}.md` e `notas_tecnicas.md`.
- 🟢 `docs/new_ideas/concepts/notas_tecnicas_{17,18}.md` · `docs/new_ideas/implementations_ideas/notas_tecnicas_{20,24,26,29,32,34,39}.md`.

## 9. Literatura (Zotero)
- 🟢 Z:10454 `A sensibilidade do Ideb a variáveis educacionais` · Z:10673 `Assessing the educational performance of different Brazilian…` · Z:10456 (tese: DEA/IDEB) · Z:11901 (vídeo: SAIA/SAEB e Censo — Aula 3) · Z:10453.

## 10. Backlogs / Relatórios (Zotero)
- 🟢 Z:11110 `Backlog dos Assuntos diários` · Z:11558 `Gemini e DeepSeek Backlogs` · Z:9347 `Lessons Learned (Technical)` · Z:10466 `Sandbox - EDA notas vs etapas` · Z:9998 `Estudos e Pesquisas` (INEP/FUNDEB).
- 🟢 Notas `Relatórios` (Z:11591, Z:11887, Z:12069, Z:12155, Z:12329) — relatórios de commits/refatoração.

## 11. Funcionalidades (catálogo)
- 🟢 `docs/funcionalidades/` — catálogo de **funcionalidades** de alto nível,
  por módulo (`busca`, `analise`, `gestor`, `comunidade`, `plataforma`) +
  índice/síntese em `docs/funcionalidades/README.md`. Mantido no Workflow
  (passo "Documentação funcional").

---

## Duplicatas (mesmo tema nos dois acervos)
| Tema | `docs/` | Zotero |
|------|---------|--------|
| Conceitos/Modelagem | `archive/dev/conceitos.md`, `archive/IA/clusters.md` | Z:10022, Z:6987, Z:9563 |
| Deploy | `archive/dev/system_cloud_administration.md` | Z:7372 |
| RandomForest | `archive/IA/random_forest.md` | Z:10450 |
| Análise de Dados/GIS | `archive/analytics/*`, `notebook-analises-censo-rankings.md` | Z:9439, Z:8236 |
| Refactor | `archive/dev/refactor*.md` | Z:11591 |

> Regra: o **doc** é a fonte de verdade; o item Zotero é histórico de exploração.

## Lacunas / oportunidades abertas
- **PgVector / similaridade** (`Z:11766`) — sem doc/código; casa com `escolas_similares()`/`municipios_similares`.
- **Dicionário de dados** (`Z:9892`) — falta versão durável; destrava rótulos do Censo.
- **DVC / data versioning** (`Z:10097`) — datasets hoje por rsync manual.
- **Git Hooks / padrões** (`Z:9931`), **índices para escolas** (`Z:10297`), **confundimento** (`Z:11930`).
- Subcoleção Zotero `backend` (125) vazia.

## Desatualizados / a arquivar
- `archive/dev/refactor.md`, `archive/dev/refactor_ui.md` (pré-refactor).
- `archive/dev/system_cloud_administration.md` (plano antigo).
- `archive/dev/notas_tecnicas_1..16.md` (fases anteriores).
