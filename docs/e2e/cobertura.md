# Cobertura E2E (browser real via CDP)

Fluxos e2e da SPA EduMaps em `http://ubatexu.lan:8080`. Para **cada feature**:
1. `browser_navigate` → rota correspondente;
2. carregar e assertar o conteúdo-chave;
3. interagir no fluxo principal (quando houver);
4. registrar `PASS`/`FAIL` (com data e observação).

**Legend**: · ainda não executado · 🟢 PASS · 🔴 FAIL · ⚪ planejado (pré-requisito ausente)

| # | Rota | Feature | Fluxo e2e (ação → assert) | Exige gestor/login? | Status |
|---|------|---------|---------------------------|--------------------|--------|
| 1 | `/` | home | Carregar → navbar + textos dos pilares | Não | ⚪ |
| 2 | `/about` | about | Carregar → página institucional do refactor | Não | ⚪ |
| 3 | `/municipio/compare` | network-compare | Digitar município (`Ubatuba`) → KPIs/radar/donuts/tabela + mapa | Não | ⚪ |
| 4 | `/escola/search` | schools | `municipio=Ubatuba` → "Buscar Escolas" → cards com INEP/telefone/Painel | Não | 🟢 2026-09-24 |
| 5 | `/escola/panel?inep=35245239` | schools | Carregar → etapas/infraestrutura/matrículas; "Painel financeiro →" | Não | 🟢 2026-09-24 |
| 6 | `/escola/ranking?inep=35011162` | schools | Carregar → info + ranking por indicador | Não (demo fallback) | ⚪ |
| 7 | `/escola/payroll?inep=35245239&date=2024-03` | schools | Carregar → tabela de profissionais (ou 404 amigável) | Não | ⚪ |
| 8 | `/escola/financeiro?inep=35245239` | schools | Carregar → gráficos linha/donut; bloco SIOPE só com sessão | Parcial (SIOPE) | ⚪ |
| 9 | `/cluster/geotag` | cluster-geotag | Cascata região→UF→município → presets → disparar job R → progresso → mapa | Não | ⚪ |
| 10 | `/gestor` | gestor | Login (email/senha) e cadastro (`?modo=cadastro`) | Não (tela de login) | ⚪ |
| 11 | `/gestor/painel?inep=35245239` | gestor | Carregar raio-x (matrículas/turmas/docentes/infra) | Não (público) | ⚪ |
| 12 | `/gestor/pesquisas?inep=...` | gestor | Listar pesquisas da escola; ações por estado (continuar/ver/excluir/copiar link) | Parcial (sessão p/ exibir) | ⚪ |
| 13 | `/gestor/pesquisas/nova?inep=...` | gestor | Wizard: criar perguntas → preview → publicar | Sim (sessão localStorage) | ⚪ |
| 14 | `/gestor/pesquisas/editar?id=...` | gestor | Wizard em edição; readonly se publicada | Sim | ⚪ |
| 15 | `/gestor/pesquisas/resultados?pesquisa=...` | gestor | Logar (401 → GestorLoginCard) → gráficos de barras + textos | Sim (gate forte) | ⚪ |
| 16 | `/chat/censo` | chat | Perguntar em NL ("quantas escolas em Ubatuba?") → job → SQL/resultado | Não | ⚪ |
| 17 | `/gestor/contatos?inep=...` | gestor | Login → CRUD contato + importar colagem | Sim | ⚪ |
| 18 | `/gestor/reunioes?inep=...` | gestor | Login → listar + filtros; nova reunião | Sim | ⚪ |
| 19 | `/gestor/reunioes/nova?inep=...` | gestor | Wizard 4 passos (quando→quem→aviso→pauta) | Sim | ⚪ |
| 20 | `/gestor/reunioes/:id` | gestor | Detalhe: dados + ata + anexos + transições de status | Sim | ⚪ |
| 21 | `/gestor/reunioes/:id/editar` | gestor | Wizard em edição | Sim | ⚪ |
| 22 | `/gestor/inventario?inep=...` | gestor | 4 abas (Censo/Recursos/Serviços/Fornecedores) + CRUD item | Sim | ⚪ |
| 23 | `/gestor/relacoes?inep=...` | gestor | Login → 4 abas (Relações/Agenda/Indicadores/Entidades) | Sim | ⚪ |
| 24 | `/gestor/relacoes/:id` | gestor | Detalhe: interações + tarefas + documentos | Sim | ⚪ |
| 25 | `/gestor/documentos?inep=...` | gestor | Login → árvore de pastas + upload versionado + auditoria | Sim | ⚪ |
| 26 | `/p/:token` | resposta | Carregar formulário público (sem navbar) → validar → enviar | Não (público) | ⚪ |
| 27 | `/config` | config | Login admin → árvore de categorias + editor da chave do Assistente do Censo (salvar/validar) | Sim (admin) | 🟢 2026-09-25 |

## Ordem sugerida de execução

Fase 1 — **públicas** (sem login): 1, 2, 4, 5, 6, 7, 8 (visão pública), 9, 11,
16, 26. Fase 2 — gestor (login real/credenciais do container): 10, 12–15,
17–25. Fase 3 — rede/compare: 3.

_Atualizar esta tabela a cada rodada; manter rastro de data + achados._