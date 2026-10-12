# Execução — Assistente de Relatório (#219)

> **Documento de execução** (resultados da Fase 0, decisões, contratos por onda,
> WBS e log), companheiro do plano
> [`2026-10-12-assistente-relatorio-plano-inicial.md`](./2026-10-12-assistente-relatorio-plano-inicial.md).

- **Issue:** [#219](https://github.com/marcoarthur/edumaps/issues/219)
- **Branch:** `feat/assistente-relatorio`
- **Princípios:**
  - três trilhas com diretórios disjuntos: T-R `analysis/edumapsr/`, T-P
    `backend/` (exceto o Rexfile), T-F `frontend/`;
  - os subagentes só escrevem código e testes; git, Rexfile, deploy e a
    verificação independente ficam com o coordenador;
  - o repositório **eduBR é somente-leitura**: nada é escrito lá; achados
    sobre ele são registrados aqui.

## Fase 0 — Viabilidade (2026-10-12) ✅

- **Ambiente:** host `analytic.edumaps`, R 4.2.2 (Debian bookworm), `ellmer`
  0.5.0.
  - O `eduBR` foi instalado do commit `2dc9af9` (`git archive` do clone local,
    sem escrever nele; o mesmo commit está no GitHub público
    `marcoarthur/eduBR`).
  - Dependências que faltavam: `dbplyr`; `parsnip` e `broom` (Suggests do
    eduBR, exigidos por `tendencia_ideb_regiao`).
- **Conexão:** `service = edumaps_leitor` (role somente-leitura) →
  `edumaps_dev` no `database.edumaps`. **Todas as ferramentas da fase 1
  responderam**:

  | Ferramenta | Recortes testados | Tempo |
  |---|---|---|
  | `catalogo` | — | ~30 ms |
  | `municipios` | SP, BA | 0,2–0,6 s |
  | `ideb_agregado` | uf; regiao por rede; municipio (SP, BA) | 0,3–1,2 s |
  | `redes_municipio` | SP; Nordeste/Municipal | ~0,3 s |
  | `docentes_rede` | uf; regiao; municipio (BA) | 1–2,3 s |
  | `perfil_gestor` | uf/gestor; regiao/escola | ~5 s |
  | `tendencia_ideb_regiao` | fundamental_i | 1,6 s |
  | `perfil_escola` | 35038751 | 1,2 s (13 warnings R a investigar) |
  | `ideb` | SP/Campinas | 0,1 s |

- **Lacunas:**
  - `docentes_rede` sem `colunas` devolve 3 linhas, porque bate no limite de
    12 mil caracteres por resposta. O roteiro deve pedir só as colunas
    necessárias.
  - `ideb_agregado` e `redes_municipio` não filtram **um** município. O roteiro
    pede o nível município dentro da UF (`n` até 1000) e filtra o código no
    adapter.
  - `perfil_escola` com INEP inexistente → `sem_dados` (esperado).
- **Ledger e limites** funcionaram (`max_linhas` reduzido, truncamento
  sinalizado em `aviso`).

## Decisões (developer, 2026-10-12)

1. **Gestor tratado como pesquisador:** persona `pesquisadora-educacional`
   (plano v1.1).
2. **Entrega:** **seções estruturadas** (JSON por seções, renderizadas por
   componentes Svelte e Carbon Charts).
3. **Orquestração:** **roteiro fixo por tema**; o LLM **só redige** a partir
   dos resultados. Como o LLM não chama ferramentas, o adapter chama as
   ferramentas do eduBR, e o prompt da persona (`eduBR::prompt_persona`) mais
   o complemento de linguagem servem de system prompt.
4. **LLM:** o configurado no **painel do EduMaps**
   (`integrations.assistant_censo.*`, via `chat_config()`/`chat_llm()`), com
   provider `mock` para testes.
5. **Deploy do eduBR:** **GitHub em commit fixo** (`marcoarthur/eduBR@2dc9af9`).
6. **eduBR em `Suggests`** do edumapsAnalytics (decisão técnica do
   coordenador). O pacote continua instalável sem o eduBR, e sem ele o
   `/report` responde erro claro (independência nos dois sentidos).

## Contrato da onda 1 (congelado)

### Catálogo de temas (fase 1)

| id | Título | Níveis | Ferramentas (roteiro) | Opções |
|---|---|---|---|---|
| `ideb_territorio` | IDEB do território | municipio, uf, regiao | `ideb_agregado` (território e o nível de cima para comparação) | `etapa` (fundamental_i*, fundamental_ii, ensino_medio), `rede` (opcional) |
| `redes_territorio` | Redes de ensino | municipio, uf, regiao | `redes_municipio` | `rede` (opcional) |
| `docentes_territorio` | Professores | municipio, uf, regiao | `docentes_rede` (com `colunas`) | `rede` (opcional) |
| `gestores_territorio` | Perfil dos gestores escolares | uf, regiao | `perfil_gestor` | `rede` (opcional) |
| `tendencia_ideb` | Tendência do IDEB | regiao | `tendencia_ideb_regiao` | `etapa`, `rede` (opcional) |
| `minha_escola` | Minha escola diante do município e do estado | escola | `perfil_escola` | — |

`*` = default. Os valores de `rede` seguem o eduBR (Municipal, Estadual,
Federal, Privada, `publica`). A T-R pode ajustar opções e ferramentas do
roteiro ao que as ferramentas realmente aceitam, **reportando** o desvio.

### Recorte (`geotag`)

`{nivel, codigo}`:
- `municipio`: código IBGE de 7 dígitos;
- `uf`: sigla com 2 letras maiúsculas;
- `regiao`: `N|NE|SE|S|CO`;
- `escola`: INEP de 8 dígitos, **só a escola do próprio gestor** (o Perl
  garante).

O R resolve o `nome` do recorte.

### R — Plumber (`inst/plumber/endpoint.R`)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/report/temas` | `?nivel` (opcional) | `200 {temas: [{id, titulo, descricao, niveis[], profundidade:"descritiva", opcoes:{etapa?:[..], rede?:[..]}}]}` |
| POST | `/report` | `{geotag, tema, opcoes?, contexto:{cod_inep}, config:{provider, model, url, api_key}}` | `200 ReportResult` · `400 {error}` (tema/nível/geotag/opção inválidos, eduBR ausente) · `500` |

**ReportResult**
```json
{
  "titulo": "IDEB do território — Campinas (SP)",
  "gerado_em": "2026-10-12T12:00:00Z",
  "recorte": { "nivel": "municipio", "codigo": "3509502", "nome": "Campinas", "uf": "SP" },
  "tema":    { "id": "ideb_territorio", "titulo": "IDEB do território" },
  "secoes": [
    { "id": "resumo", "tipo": "texto", "titulo": "Resumo", "markdown": "..." },
    { "id": "kpis", "tipo": "indicadores", "titulo": "...",
      "itens": [ { "rotulo": "IDEB 2023", "valor": 6.1, "formato": "decimal1",
                   "referencia": { "rotulo": "SP", "valor": 6.3 } } ] },
    { "id": "tabela_x", "tipo": "tabela", "titulo": "...",
      "colunas": [ { "id": "rede", "rotulo": "Rede", "formato": "texto" } ],
      "linhas": [ { "rede": "Municipal" } ], "nota": "..." },
    { "id": "grafico_x", "tipo": "grafico", "grafico": "barras", "titulo": "...",
      "x": { "id": "ano", "rotulo": "Ano" },
      "series": [ { "id": "ideb", "rotulo": "IDEB" } ],
      "dados": [ { "ano": 2023, "ideb": 6.1 } ] },
    { "id": "leitura", "tipo": "texto", "titulo": "Como ler", "markdown": "..." }
  ],
  "fontes":   [ { "ferramenta": "ideb_agregado", "descricao": "...", "edicao": "IDEB 2023", "escopo": "municípios de SP", "n": 645 } ],
  "avisos":   [ { "tipo": "truncado", "mensagem": "..." } ],
  "rastreio": { "provedor": "gemini", "modelo": "...", "llm": "ok", "versao_edubr": "0.0.0.9000", "chamadas": 2, "duracao_ms": 3100 }
}
```

- **Tipos de seção:** `texto` | `indicadores` | `tabela` | `grafico`
  (`grafico` ∈ `barras` | `linhas`).
- **Formatos:** `texto`, `inteiro`, `decimal1`, `decimal2`, `percentual`
  (fração 0–1).
- **Texto:** markdown **simples** (parágrafos, `##`, listas, `**negrito**`),
  compatível com o `markdownSimples.js`. Sem HTML, links ou imagens.
- **Redação pelo LLM:** as seções `resumo` (primeira) e `leitura` (última).
  O LLM recebe os dados já estruturados (JSON enxuto), cita edição, recorte e
  `n`, não faz contas e não afirma causalidade.
- **Falha do LLM não derruba o relatório:** as seções de dados saem;
  `rastreio.llm = "indisponivel"`, aviso `{tipo:"llm"}` e um resumo
  determinístico curto no lugar.
- `provider = "mock"` → texto determinístico (testes e e2e).
- **Avisos:** os `aviso`/`truncado`/`erro` dos envelopes viram `avisos`; as
  colunas omitidas não aparecem.
- **Sem PII:** só dados que passaram pelas ferramentas do eduBR.

### Perl — gestão (Bearer + posse do `cod_inep`)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/gestor/:cod_inep/relatorios/recorte-padrao` | — | `200 {escola:{cod_inep, nome}, municipio:{codigo, nome}, uf:{codigo, nome}, regiao:{codigo, nome}}` (de `clean.censo_escolas`; `codigo` da região em `N\|NE\|SE\|S\|CO`) |
| GET | `/api/gestor/:cod_inep/relatorios/temas` | `?nivel` | `200 {temas:[…]}` (proxy do R `/report/temas`, com cache) |
| POST | `/api/gestor/:cod_inep/relatorios` | `{geotag:{nivel,codigo}, tema, opcoes?}` | `202 {job_id}` · `400` (formato; `escola` ≠ escola do gestor; tema fora do catálogo do nível) · `401/403` |
| GET | `/api/gestor/:cod_inep/relatorios/jobs/:job_id` | — | `200 {state: "inactive"\|"active"\|"finished"\|"failed", progress?, result?: ReportResult + {cache_hit}, error?}` · `404` (job de outro gestor ou de outra task) |

- **Task Minion** `relatorio_gerar`, na fila `analytics`, com args
  `{gestor_id, cod_inep, geotag, tema, opcoes}`.
- A `config` LLM vem de `AppConfig->chat_llm_config`, como no `chat_ask`.
- `Analytics::Client->run_report` faz POST em `/report`, com cache de 24 h. A
  chave é `{geotag, tema, opcoes, config_version}`, sem a `api_key`.
- `run_report_temas` faz GET em `/report/temas`, com cache.
- Erro 400 do R → job `failed` com a mensagem; outros erros → mensagem
  genérica.

### Frontend

- **Rota `/gestor/relatorios`** (`RelatoriosPage`), no mesmo padrão de sessão
  das páginas de gestor (`fetchMe` + `GestorLoginCard`):
  - **seletor de recorte** com padrão vindo do `recorte-padrao` e opção de
    escolher outro, pela cascata `/api/cluster/regions|ufs|municipalities`,
    convertendo para o formato do `geotag`;
  - **temas do nível** (`/temas?nivel`), com as opções do tema;
  - **"Gerar relatório"**, com polling do job a cada 1,5 s.
- **`RelatorioView`** renderiza as seções:
  - `SecaoTexto` com `TextoMarkdown`;
  - `SecaoIndicadores`, cartões com valor e referência;
  - `SecaoTabela`, tabela acessível com os formatos;
  - `SecaoGrafico`, com Carbon Charts (wrappers de
    `shared/ui/components/charts` ou equivalentes; o stub de teste já existe);
  - rodapé com **fontes** e **avisos**, e o selo "do cache" quando
    `cache_hit`.
- **Link** "Relatórios" na navegação do gestor (painel/listas).

## WBS

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| R1 | T-R | Adapter eduBR (`edubr_source`, chamada de ferramenta, envelope → dados/avisos/fontes) | 🟢 |
| R2 | T-R | Catálogo de temas + roteiros dos 6 temas + seções | 🟢 |
| R3 | T-R | Redação LLM (persona + complemento; mock; degradação) | 🟢 |
| R4 | T-R | Plumber `/report` e `/report/temas` + `api.json` + testes testthat + Dockerfile com o eduBR fixado | 🟢 |
| P1 | T-P | Client `run_report`/`run_report_temas`, task `relatorio_gerar`, rotas e recorte-padrão + testes | 🟢 |
| F1 | T-F | `RelatoriosPage`, seletor de recorte, temas, `RelatorioView` e seções + MSW + testes | 🟢 |
| C1 | coord. | Rexfile (eduBR fixado + `dbplyr`/`parsnip`/`broom`), verificação, deploy | 🟢 |

Onda 2: e2e em dev, docs funcionais, nota técnica e PR.

## Log de decisões

- **2026-10-12 — Fase 0 aprovada** pelos resultados acima. A Fase 1 começa com
  a branch `feat/assistente-relatorio`.
- **2026-10-12 — Desvios da T-R aceitos:**
  - **`rede` por tema:** `ideb_territorio` e `tendencia_ideb` não aceitam
    `publica` (o eduBR não aceita); não há opção `ano` (IDEB 2023, Censo 2025).
  - **Tendência:** `tendencia_ideb` também chama `ideb_agregado` por edição,
    para o gráfico de linhas.
  - **Comparação com o nível de cima:** município → UF → região → Brasil,
    conforme a ferramenta.
  - **Campos opcionais a mais:** `recorte.municipio` (nível escola) e
    `formato` nas seções `grafico`.
  - **Erros:** 400 com `tipo: "invalid_request"`; erros
    `conexao`/`limite_excedido`/`parametro_invalido` do eduBR → 500 (o Perl
    não guarda em cache); `sem_dados` vira aviso.
  - **Limites do relatório:** `max_linhas` 1000, `max_chamadas` 40,
    `max_linhas_total` 60000; ao LLM só vai um JSON enxuto (≤ 9 mil
    caracteres, 20 linhas por tabela).
  - **Fatias:** respostas truncadas são refeitas por rede/localização.
  - **Lentidão:** `redes_territorio` é o tema lento (região SE: 28 s).
  - **Achado sobre o eduBR** (só registro): um filtro por código de município
    em `redes_municipio`/`ideb_agregado`/`docentes_rede` eliminaria as fatias.
- **2026-10-12 — Desvios da T-P aceitos:**
  - fila configurável (`relatorio_queue`);
  - `cache_hit` booleano;
  - `Location` no 202;
  - erros HTTP do cliente R viram exceção estruturada (o texto continua o
    mesmo);
  - 502 se o R falhar ao validar o tema;
  - `opcoes` validadas só no R.
- **2026-10-12 — ⚠️ Correção fora do escopo (T-P):** o cache
  `analytics.analysis_cache` **nunca funcionou no app real**. O
  `Client::_db` testava `$app->can('pg')`, mas `pg` é helper, não método;
  desde `5f110c6` a tabela ficava vazia (confirmado em dev: 0 linhas). Com a
  correção, o cache de 24 h passa a valer para **todas** as análises
  "cacheáveis" (Assistente do Censo, cluster, summary, school_profile,
  network_profile, evolution). Comportamento novo a validar com o developer.
- **2026-10-12 — T-F:**
  - o nível inicial é o município da escola;
  - `etapa` sem valor vazio, `rede` com "Todas";
  - opções aceitas como string ou `{valor, rotulo}`;
  - polling com `setInterval`;
  - gráfico com descrição `sr-only` e tabela com os mesmos dados;
  - link "Relatórios" no painel, nas listas e nos envios.

## Verificação independente (coordenador, onda 1)

- **JSON real do R** (integração no `analytic`, provider mock) conferido
  contra o contrato e o frontend: chaves, tipos de seção, fontes, rastreio.
- **R** (no `analytic`, cópia limpa da branch): 28 arquivos / 1075
  asserções, **0 falhas**, 11 pulados (banco de teste).
- **Perl:** 103 arquivos / 676 testes. Só falhas antigas: `City.t`,
  `domain/quality.t`, `indicators/quality.t`, `indicators_quality.t`,
  `03-plugins/analytics.t`, `04-api/municipio.t`, `04-api/network/schools.t`
  (as duas últimas citadas no AGENTS.md).
- **Frontend:** 101 arquivos / 779 testes; `vite build` OK.
- **Rexfile:** a instalação fixada do eduBR rodou no `analytic` (instala e,
  na segunda vez, pula).

## Onda 2 (coordenador)

- **Deploy em dev:**
  - `deploy_analytics_dev`, que instala o eduBR fixado e o pacote;
  - `deploy_backend_dev`, `deploy_minion_dev`,
    `deploy_analytics_worker_dev`, `deploy_frontend_dev`;
  - imagens locais `analytic`, `backend`, `minion` e `frontend` reconstruídas.
- **E2E 14/14** com o Gemini real: rodada em `docs/e2e/cobertura.md`.
- **Correções do e2e:**
  - `censo-dictionary.R` no `Collate` (o deploy quebrava a reinstalação);
  - texto do LLM em pt-BR, sem jargão; números arredondados pelo formato e sem
    nome de ferramenta no pacote de dados para o LLM;
  - espaços dos separadores na tela.
- **Pendências registradas:**
  - a chave do cache de relatórios não inclui a versão do prompt nem do
    pacote;
  - jobs falham durante o reinício do R (sem nova tentativa);
  - `redes_territorio` é lento por região (até ~30–40 s);
  - um filtro por município nas ferramentas do eduBR eliminaria as fatias
    (achado para o mantenedor do eduBR).
- **Docs:** capacidade nova `analise/relatorios-territorio.md` e o índice.

---

# Fase 2 — Aprofundamento

- **Branch:** `feat/relatorio-fase2`.
- **Trilhas:** T-R (`analysis/edumapsr/`) e T-F (`frontend/`). O Perl não
  muda: o catálogo vem do R e as rotas existentes já cobrem os temas novos.

## Decisões (developer, 2026-10-12)

1. **Temas:** IDEB escola a escola, Infraestrutura × IDEB, Histórico da minha
   escola e Escolas parecidas com a minha.
2. **Regressão com especificação fixa por tema:** o gestor escolhe só a UF, a
   etapa e a rede.
3. **Leitura da regressão:** simplificada e visível; a parte técnica
   (coeficientes, erros, p-valores, R², n) fica recolhida.

## Contrato da Fase 2 (congelado)

### Ferramentas

- As ferramentas dos temas da escola (`serie_ideb_escola`, `scores_escola`,
  `resumo_escola`, `escolas_similares`) são só da `gestora-escolar` no eduBR.
  Por isso o adapter monta as ferramentas com `persona = NULL` e escolhe por
  nome: é o **complemento B** do plano.
- O system prompt do LLM continua com a persona pesquisadora e o complemento.

### Temas novos (`profundidade`)

| id | Título | Níveis | Ferramentas (roteiro) | Opções | Profundidade |
|---|---|---|---|---|---|
| `ideb_escolas` | IDEB escola a escola | municipio | `municipios` (nome pelo código) + `ideb` (UF + nome do município, edição 2023) | `etapa`*, `rede` | profunda |
| `infraestrutura_ideb` | Infraestrutura e IDEB | uf | `regressao_escolas` (especificação fixa abaixo) | `etapa`* (→ desfecho `ideb_fund_i`/`ideb_fund_ii`/`ideb_medio`), `rede` | profunda |
| `historico_escola` | Histórico da minha escola | escola | `serie_ideb_escola` + `scores_escola` (+ `resumo_escola` se útil) | — | descritiva |
| `escolas_parecidas` | Escolas parecidas com a minha | escola | `escolas_similares` (n = 10, `publica` = true) | `etapa` (opcional) | descritiva |

**Especificação fixa** do `infraestrutura_ideb`:
- desfecho: IDEB 2023 da etapa;
- preditores: `in_biblioteca`, `in_internet`, `in_laboratorio_informatica`,
  `docentes`, `matriculas`;
- `cuts = "localizacao"`;
- modelo linear;
- só escolas ativas.

A T-R confere no eduBR que esses nomes existem e ajusta, **reportando**
qualquer mudança. Os rótulos ao gestor ficam em pt-BR (ex.: "Biblioteca",
"Internet", "Laboratório de informática", "Nº de professores",
"Nº de matrículas").

### Extensões do ReportResult (todas opcionais e retrocompatíveis)

- **Seção nova `associacoes`** (leitura simplificada da regressão):
  ```json
  { "id": "associacoes", "tipo": "associacoes", "titulo": "O que anda junto com o IDEB",
    "itens": [ { "rotulo": "Biblioteca", "corte": "Urbana", "direcao": "maior",
                 "seguranca": "alta", "n": 8123 } ],
    "nota": "Associação, não causa: ..." }
  ```
  - `direcao` ∈ `maior | menor | sem_relacao_clara` (sinal da estimativa;
    `sem_relacao_clara` quando p ≥ 0,05);
  - `seguranca` ∈ `alta` (p < 0,01) | `media` (p < 0,05) | `baixa`;
  - `corte` é opcional.
- **Seção `tabela` com `"recolhida": true`:** o frontend a mostra dentro de
  `<details>` ("Ver detalhes técnicos"). É usada para coeficientes e métricas.
- **Linha de `tabela` com `"_destaque": true`:** o frontend destaca a linha,
  por exemplo a escola do gestor na lista do `ideb_escolas`. Essa chave não é
  coluna.
- **Aviso fixo `{tipo: "associacao"}`** em todo relatório de regressão.

### Regras

- **`ideb_escolas`:**
  - lista as escolas do município com o IDEB da etapa (nome, rede, IDEB),
    ordenadas por IDEB;
  - indicadores: escolas com nota, mediana e intervalo (mínimo e máximo),
    calculados de forma **determinística** no R;
  - quando a escola do gestor (`contexto.cod_inep`) está na lista, a linha
    leva `_destaque` e um indicador mostra a posição dela ("3ª de 21");
  - gráfico de barras por faixa de IDEB.
- **`infraestrutura_ideb`:**
  - resumo;
  - `associacoes`;
  - tabela recolhida de coeficientes (termo, estimativa, erro, p-valor, corte);
  - tabela recolhida de métricas por corte (n, R², R² ajustado);
  - fontes com `n`.
- **`historico_escola`:** gráfico de linhas do IDEB por edição e etapa,
  indicadores dos scores (0–10) e tabela da série.
- **`escolas_parecidas`:** tabela das escolas (nome, município/UF, rede); a
  similaridade entra se a ferramenta devolver.
- **LLM:**
  - recebe os dados já arredondados, como na Fase 1;
  - nos temas `profunda`, o complemento do prompt reforça "associação, não
    causa", "cite o n" e "não ranqueie como julgamento de qualidade";
  - na lista de escolas, o LLM **não** cita nomes de escolas, salvo a do
    próprio gestor.
- **Sem PII:** só nomes e códigos de escola (dado institucional) e
  agregados.

### Frontend

- `SecaoAssociacoes`: cartões ou lista com seta/ícone de direção, selo de
  segurança (alta/média/baixa) com texto, corte e n, e a `nota`.
- `SecaoTabela`: suporta `recolhida` (`<details>`) e `_destaque` (linha
  realçada e acessível, com sufixo "(sua escola)" para leitores de tela).
- Tipos de seção desconhecidos são ignorados sem quebrar a tela
  (compatibilidade).
- Os temas novos aparecem pelo catálogo; nenhuma mudança de rota.

## WBS (Fase 2)

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| R5 | T-R | Complemento B no adapter + 4 roteiros + seções novas + catálogo com `profundidade` | 🟢 |
| R6 | T-R | Regras de prompt dos temas profundos + testes (ferramentas falsas) + integração real no `analytic` | 🟢 |
| F2 | T-F | `SecaoAssociacoes`, tabela `recolhida`/`_destaque`, tipos desconhecidos tolerados + fixtures + testes | 🟢 |
| C2 | coord. | Verificação, deploy, e2e, docs, PR | 🟢 |

## Log — Fase 2

- **2026-10-12 — Desvios da T-R aceitos:**
  - **Rede no `infraestrutura_ideb`:** `publica` (padrão), Municipal,
    Estadual ou Federal; **sem Privada**.
    - A regressão conta todas as escolas ativas da UF: SP com todas as redes
      dá 30.817, acima do teto absoluto do eduBR (30.000).
    - `max_amostra` subiu para 30.000.
    - Recorte acima do teto → 400, pedindo uma rede específica.
  - **`escolas_parecidas`:** também chama `resumo_escola`, para nome, rede e
    etapa ofertada. Etapa não ofertada → 400. Linhas escola × etapa
    agregadas por escola.
  - **Coeficientes:** estimativa, erro e p-valor saem em formato `texto`, com
    3 algarismos significativos e "< 0,001". Os formatos numéricos zerariam
    efeitos pequenos.
  - **Campos extras opcionais:**
    - `texto` no item de posição ("7ª de 11");
    - seções `kpis_ideb` (`historico_escola`) e `kpis` (`escolas_parecidas`).
  - **Nomes de escola:** os de terceiros **não vão ao LLM** nos temas com
    lista; a escola do gestor vai.
- **2026-10-12 — Ajustes do coordenador:**
  - `escolas_parecidas` pede **20 linhas** e fica com até **10 escolas
    distintas** (com `n = 10`, a escola 35038751 rendia 7);
  - os avisos deixam de levar o prefixo `[ferramenta]`, também na tela;
  - tabelas com mais de 25 linhas rolam dentro da própria caixa, com
    cabeçalho fixo (São Paulo capital tem 1.128 escolas).
- **2026-10-12 — T-F:** `{#each}` das seções indexado pela posição; o aviso
  `associacao` aparece só no topo; textos dos selos a validar.
- **Verificação (coordenador):**
  - R: 29 arquivos / 1360 asserções / 0 falhas (no `analytic`,
    `LC_ALL=C.UTF-8`);
  - frontend: 101 / 794, build OK;
  - Perl: relatórios 2 arquivos / 23 testes.
- **Achado para o eduBR** (só registro): um argumento `filtro` em
  `regressao_escolas` (ex.: só escolas que ofertam a etapa) reduziria o
  recorte abaixo do teto.
- **2026-10-12 — Onda de integração da Fase 2 (coordenador):**
  - **Pilha de 64 MB no serviço R:** `LimitSTACK=64M` na unit e
    `ulimits.stack` no compose. O `escolas_similares` estourava os 8 MB dentro
    do Plumber.
  - **Catálogo expõe `padroes`:** a opção sem padrão vira "Todas" no frontend.
    Corrige a etapa forçada em `escolas_parecidas`.
  - **Fontes sem nome de ferramenta** no rodapé.
  - **`edumapsAnalytics` 0.2.0 e `analytics_source_version` =
    `edumapsr-0.2.0`.** É o mecanismo existente para invalidar o cache. Regra
    anotada no `edumaps_db.conf`: subir junto com o `Version` do pacote
    sempre que o R mudar.
  - **E2E com o Gemini real:** 13/13 pela API e 11/11 na tela; rodada em
    `docs/e2e/cobertura.md`.

---

# Fase 3 — Relatório rico e exportável

- **Branch:** `feat/relatorio-fase3`.
- **Trilhas:**
  - T-P: `data_pipeline/` + `backend/` (migration + rotas);
  - T-F: `frontend/`.

  O R não muda.

## Decisões (developer, 2026-10-12)

1. **Exportação:**
   - **PDF pela impressão do navegador**, com CSS de impressão e o botão
     "Imprimir / salvar PDF";
   - **Markdown**, gerado no **frontend** a partir do ReportResult. Uma
     implementação só serve o relatório atual e os salvos.
2. **Histórico:** **salvar quando quiser**. Os salvos ficam numa lista e
   podem ser reabertos sem custo de LLM e excluídos.
3. **Retenção:** **até o gestor excluir**, ou até a conta ser removida
   (cascade). Os relatórios só têm dados públicos e agregados.
4. **Reabrir:** **fotografia** do que foi gerado (com data) mais o botão
   "Gerar de novo com os dados atuais".

## Contrato da Fase 3 (congelado)

### Migration

Change nova `relatorios_salvos`, anexada ao fim do plano, com o mesmo estilo
de verify em gate:

```sql
CREATE TABLE clean.relatorios_salvos (
  id           bigserial PRIMARY KEY,
  gestor_id    bigint NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
  cod_inep     bigint NOT NULL,
  job_id       bigint NOT NULL,                 -- job Minion de origem (dedupe)
  tema_id      text   NOT NULL,
  tema_titulo  text   NOT NULL,
  nivel        text   NOT NULL CHECK (nivel IN ('escola','municipio','uf','regiao')),
  codigo       text   NOT NULL,
  recorte_nome text,
  opcoes       jsonb  NOT NULL DEFAULT '{}'::jsonb,
  titulo       text   NOT NULL,
  conteudo     jsonb  NOT NULL,                 -- ReportResult (fotografia)
  gerado_em    timestamptz NOT NULL,            -- ReportResult.gerado_em
  created_at   timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (gestor_id, job_id)
);
CREATE INDEX idx_relatorios_salvos_gestor ON clean.relatorios_salvos (gestor_id, created_at DESC);
```

### Perl — gestão (Bearer + posse do `cod_inep`)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/gestor/:cod_inep/relatorios/salvos` | `{job_id}` | `201 {salvo}` (novo) · `200 {salvo}` (já salvo: mesmo `job_id`) · `404` (job inexistente, de outro gestor ou de outra task) · `409` (job não terminou com sucesso) |
| GET | `/api/gestor/:cod_inep/relatorios/salvos` | `?page&per_page` (20, máx. 100) | `200 {items: [resumo], total, page, per_page}` (mais recentes primeiro) |
| GET | `/api/gestor/:cod_inep/relatorios/salvos/:id` | — | `200 {salvo + relatorio}` · `404` |
| DELETE | `/api/gestor/:cod_inep/relatorios/salvos/:id` | — | `200 {ok:1}` · `404` |

- **O conteúdo vem do resultado do job no servidor** (`job->info->{result}`),
  **nunca do cliente**, para evitar adulteração. Os `args` do job dão
  `geotag`, `tema` e `opcoes`; o resultado dá `titulo`, `tema.titulo`,
  `recorte.nome` e `gerado_em`. O `cache_hit` não é gravado.
- **Escopo:** só os salvos do **próprio gestor** (`gestor_id` da sessão).
  Outro gestor da mesma escola não vê.
- **Resumo:**
  ```json
  { "id": 7, "titulo": "...", "tema": {"id": "...", "titulo": "..."},
    "recorte": {"nivel": "municipio", "codigo": "3555406", "nome": "Ubatuba"},
    "opcoes": {"etapa": "fundamental_ii"}, "gerado_em": "...Z", "salvo_em": "...Z" }
  ```
- **Detalhe:** o resumo mais `relatorio` (o ReportResult gravado).

### Frontend

- **Ações no `RelatorioView`** (opcionais por prop):
  - **"Imprimir / salvar PDF"**: chama `window.print()`. Antes de imprimir,
    abre os `<details>` técnicos (`beforeprint`) e depois restaura
    (`afterprint`).
  - **"Baixar Markdown"**: gera no cliente, por uma função pura
    `relatorioParaMarkdown(relatorio)`, com título, recorte e data, cada
    seção (texto; indicadores em lista; tabelas em markdown, respeitando os
    formatos pt-BR e sem colunas `_*`; gráficos como a tabela dos dados;
    associações em lista com direção, segurança e n), avisos e fontes. O
    nome do arquivo é `relatorio-<tema>-<recorte>-<data>.md`, com slug.
  - **"Salvar relatório"**: só quando há `job_id` e o relatório não é
    salvo. Faz POST e, ao concluir, mostra "Salvo" com link para a lista.
- **CSS de impressão:**
  - esconde a navegação do app, o formulário de recorte e tema e os botões;
  - imprime título, recorte, data, todas as seções, as tabelas técnicas
    abertas, os avisos e as fontes;
  - gráficos legíveis em A4;
  - quebra de página evitada dentro de cartões e tabelas pequenas.
- **Rota `/gestor/relatorios/salvos`** (`RelatoriosSalvosPage`): lista
  paginada (título, tema, recorte, data em que foi gerado, data em que foi
  salvo), "Abrir" e "Excluir" (`ConfirmDialog`).
- **Rota `/gestor/relatorios/salvos/:id`:** `RelatorioView` da fotografia,
  com um aviso "Fotografia de <data>: os números são os daquela data", as
  ações de imprimir e Markdown, "Excluir" e **"Gerar de novo com os dados
  atuais"**.
  - "Gerar de novo" leva a `/gestor/relatorios` com o recorte, o tema e as
    opções preenchidos por query (`nivel`, `codigo`, `nome`, `tema`, `etapa`,
    `rede`) e dispara a geração.
  - A `RelatoriosPage` passa a aceitar esse preenchimento por query,
    inclusive um recorte fora da escola do gestor, mostrado como "Recorte:
    <nome>" com a opção de trocar.
- **Links:** "Meus relatórios" na `RelatoriosPage` e na navegação do gestor.

## WBS (Fase 3)

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| P2 | T-P | Migration `relatorios_salvos` + 4 rotas + testes | 🟢 |
| F3 | T-F | Ações (imprimir, Markdown, salvar), CSS de impressão, páginas de salvos, "gerar de novo" por query + testes | 🟢 |
| C3 | coord. | Verificação, deploy, e2e, docs, PR | 🟢 |

## Log — Fase 3

- **2026-10-12 — Desvios da T-P aceitos:**
  - 400 para `job_id` inválido;
  - 409 também para resultado de job inválido;
  - fallbacks de `tema_titulo`/`titulo`/`gerado_em` (este cai na hora em
    que o job terminou);
  - paginação permissiva (valores inválidos voltam ao padrão, máx. 100);
  - `Location` no POST;
  - a resposta do POST traz o resumo **sem envelope** `{salvo}`. O cliente
    aceita as duas formas.
  - **Migration no CI:** `ci_db.sh` não tem deploy incremental; a T-P usou o
    contêiner `sqitch` na rede do CI. Verify, revert e deploy OK.
- **2026-10-12 — T-F:**
  - o `beforeprint` abre **todos** os `<details>` (inclusive a tabela de
    dados dos gráficos) e o `afterprint` restaura;
  - o "Salvo" é igual para 201 e 200;
  - no nível escola vindo da query, vale sempre o INEP do próprio gestor;
  - a query `gerar=1` dispara uma vez e é removida; sem sessão, fica
    guardada até o login.
- **Verificação (coordenador):**
  - `ci_db.sh verify`: `relatorios_salvos .. ok`;
  - backend: 102 / 690, só as 7 falhas antigas;
  - frontend: 105 / 863, build OK.
- **2026-10-12 — Integração da Fase 3 (coordenador):**
  - deploy de banco, backend, minion e frontend;
  - imagens locais `sqitch`, `backend`, `minion` e `frontend`;
  - E2E 21/21 com download real de Markdown e PDF via `printToPDF`;
  - correção: o formato da seção passou a valer nos dados do gráfico.
  - **Pendência:** eixo percentual dos gráficos.
