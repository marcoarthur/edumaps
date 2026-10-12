# Nota técnica 117 — Assistente de Relatório: ciclo completo (Fases 0–4)

## Resumo

O **Assistente de Relatório** (issue #219) é o primeiro assistente do EduMaps
construído sobre o pacote `eduBR`. O gestor escolhe um recorte (a própria
escola, um município, um estado ou uma macro-região) e recebe um **relatório
em seções** (indicadores, tabelas, gráficos e texto) montado de forma
determinística a partir das ferramentas do eduBR e **redigido** pelo LLM do
painel. O relatório pode ser exportado (PDF e Markdown), salvo e reaberto como
fotografia. Na Fase 4, os assistentes passaram a ser **declarados em YAML**: o
"Relatório por tema" reproduz as Fases 1–3 e a **EDA do município** é um
relatório exploratório completo, em capítulos, com resumo geral. Criar um
assistente novo é escrever um YAML, sem código R.

Esta nota consolida o **ciclo inteiro** (Fases 0–4) e substitui, como
referência única, a leitura em sequência das notas 114, 115 e 116, que
continuam válidas como registro de cada fase. Fontes:
`docs/specs/2026-10-12-assistente-relatorio-plano-inicial.md` (plano v1.1) e
`docs/specs/2026-10-12-assistente-relatorio.execucao.md` (contratos e logs de
todas as fases).

## Linha do tempo

| Fase | Issue / PR / merge | Nota | Entrega |
|---|---|---|---|
| 0 — Viabilidade | #219 (spike, sem PR próprio) | 114 | eduBR instalado no `analytic` (commit `2dc9af9`), todas as ferramentas da fase 1 respondendo contra `database.edumaps` pelo `edumaps_leitor` (0,1–5 s por chamada); lacunas documentadas |
| 1 — MVP | #219 · PR #220 · `c62d730` | 114 | adapter do eduBR, 6 temas descritivos, `/report` e `/report/temas`, task Minion `relatorio_gerar`, rotas do gestor, página `/gestor/relatorios`; correção do cache de análises que nunca ligava |
| 2 — Aprofundamento | #219 · PR #221 · `0184bf2` | 115 | 4 temas (IDEB escola a escola, infraestrutura × IDEB, histórico da escola, escolas parecidas), complemento B, seção `associacoes`, tabelas recolhidas, `_destaque`, catálogo com `profundidade`/`padroes` |
| 3 — Rico e exportável | #219 · PR #222 · `f00e548` | 116 | PDF pela impressão do navegador, Markdown no cliente, relatórios salvos (`clean.relatorios_salvos`), fotografia + "gerar de novo" |
| 4 — Generalização | #219 · PR a abrir (Fase 4) | 117 | assistentes declarativos em YAML (`relatorio`, `eda_municipio`), modo composto com capítulos e redação geral, seletor de assistente, salvos com assistente |

Branches: `feat/assistente-relatorio` (Fases 0–1), `feat/relatorio-fase2`,
`feat/relatorio-fase3`, `feat/relatorio-fase4`.

## Arquitetura final

```
eduBR (ferramentas semânticas, envelope dados/metadados/erro; somente-leitura)
  └─ adapter (edumapsAnalytics): tooling por pedido, limites, fatias,
     envelope → dados / avisos / fontes
       └─ roteiros por tema: chamadas fixas às ferramentas, cálculo
          determinístico (posição, mediana, faixas, associações)
            └─ seções tipadas (indicadores, tabela, gráfico, associações)
                 └─ redação LLM (só resumo e leitura; JSON enxuto e arredondado)
                      └─ Plumber: /report, /report/temas, /report/assistentes
                           └─ Perl: rotas do gestor → Minion (fila analytics)
                              → Analytics::Client (cache 24 h em analysis_cache)
                                └─ SPA: /gestor/relatorios, RelatorioView,
                                   impressão/Markdown, "Meus relatórios"
```

- **eduBR como fonte, não como dependência dura.** Fica em `Suggests` (+
  `Remotes`) do `edumapsAnalytics`, sempre chamado como `eduBR::…`. Sem o
  eduBR o pacote instala e o `/report` responde erro claro. Nada do EduMaps é
  escrito no repositório eduBR; os achados sobre ele ficam registrados aqui.
- **Adapter** (`edubr_source`): a única porta de entrada para o eduBR. Abre a
  conexão somente-leitura (`service = edumaps_leitor`) por pedido, monta o
  tooling, aplica os limites (`max_linhas` 1000, `max_chamadas` 40,
  `max_linhas_total` 60000, `max_amostra` 30000, `timeout_s` 30) e converte
  os envelopes. Contorna as lacunas do eduBR: `docentes_rede` sempre com
  `colunas`; município filtrado dentro da UF (`n` até 1000), porque as
  ferramentas agregadas não filtram um município; respostas truncadas refeitas
  em fatias por rede e localização.
- **Roteiros por tema:** cada tema do catálogo tem um roteiro fixo de
  chamadas. O LLM **não chama ferramentas**.
- **Redação:** o system prompt é `eduBR::prompt_persona("pesquisadora-educacional")`
  mais um **complemento de linguagem** para o gestor (pt-BR simples, padrão
  numérico brasileiro, sem causalidade, citar edição, recorte e `n`). Nos
  temas profundos o complemento reforça "associação, não causa" e "não
  ranqueie como julgamento". Cada assistente pode acrescentar o próprio
  `prompt_complemento`.
- **Persona e complemento B:** a persona é a `pesquisadora-educacional` (a
  única com ferramentas territoriais). As ferramentas de escola
  (`serie_ideb_escola`, `scores_escola`, `resumo_escola`, `escolas_similares`)
  são só da `gestora-escolar`; o adapter as cria com `persona = NULL` e as
  escolhe por nome, sem alterar o eduBR.
- **LLM do painel:** `chat_config()`/`chat_llm()` (`integrations.assistant_censo.*`),
  a mesma configuração do Assistente do Censo; `provider = mock` para testes e
  integração. Falha do LLM não derruba o relatório: as seções de dados saem,
  com resumo determinístico, `rastreio.llm = "indisponivel"` e aviso
  `{tipo: "llm"}`.
- **Assistentes YAML (Fase 4):** um arquivo por assistente em
  `inst/assistentes/<id>.yml`, carregado e validado pelo R. O adapter e os
  roteiros **não mudaram de interface**; o código novo foi o carregador, a
  execução do modo composto e a redação geral.

### Catálogo de temas (estado final)

| id | Título | Níveis | Profundidade |
|---|---|---|---|
| `ideb_territorio` | IDEB do território | municipio, uf, regiao | descritiva |
| `redes_territorio` | Redes de ensino | municipio, uf, regiao | descritiva |
| `docentes_territorio` | Professores | municipio, uf, regiao | descritiva |
| `gestores_territorio` | Perfil dos gestores escolares | uf, regiao | descritiva |
| `tendencia_ideb` | Tendência do IDEB | regiao | descritiva |
| `minha_escola` | Minha escola diante do município e do estado | escola | descritiva |
| `ideb_escolas` | IDEB escola a escola | municipio | profunda |
| `infraestrutura_ideb` | Infraestrutura e IDEB | uf | profunda |
| `historico_escola` | Histórico da minha escola | escola | descritiva |
| `escolas_parecidas` | Escolas parecidas com a minha | escola | descritiva |

### Assistentes (estado final)

| id | Título | Modo | Níveis | Conteúdo |
|---|---|---|---|---|
| `relatorio` | Relatório por tema | `tema` | municipio, uf, regiao, escola | os 10 temas; reproduz as Fases 1–3 |
| `eda_municipio` | EDA do município | `composto` | municipio | capítulos: Redes de ensino → Professores → IDEB do município → Escolas do município pelo IDEB → Minha escola no município (opcional); opção `etapa` (padrão anos iniciais); `max_chamadas` 80 |

## Contrato final do ReportResult

```json
{
  "titulo": "…", "gerado_em": "2026-10-12T12:00:00Z",
  "assistente": { "id": "eda_municipio", "titulo": "EDA do município", "modo": "composto" },
  "recorte": { "nivel": "municipio", "codigo": "3555406", "nome": "Ubatuba", "uf": "SP" },
  "tema": { "id": "eda_municipio", "titulo": "EDA do município" },
  "capitulos": [ { "id": "redes_territorio", "titulo": "Redes de ensino", "tema": "redes_territorio" } ],
  "secoes": [ { "id": "resumo", "tipo": "texto", "markdown": "…" },
              { "id": "redes_territorio-…", "capitulo": "redes_territorio", "tipo": "tabela", "…": "…" },
              { "id": "leitura", "tipo": "texto", "markdown": "…" } ],
  "fontes": [ { "descricao": "…", "edicao": "IDEB 2023", "escopo": "…", "n": 645 } ],
  "avisos": [ { "tipo": "truncado", "mensagem": "…" } ],
  "rastreio": { "provedor": "gemini", "modelo": "…", "llm": "ok", "versao_edubr": "…", "chamadas": 2, "duracao_ms": 3100 }
}
```

**Tipos de seção:**

| Tipo | Campos | Fase |
|---|---|---|
| `texto` | `markdown` simples (parágrafos, `##`, listas, negrito; sem HTML, links, imagens) | 1 |
| `indicadores` | `itens[{rotulo, valor, formato, referencia?{rotulo, valor}, texto?}]` | 1 (`texto`, ex. "7ª de 11", na 2) |
| `tabela` | `colunas[{id, rotulo, formato}]`, `linhas[]`, `nota?`, `recolhida?`; linha com `_destaque` | 1 (`recolhida`/`_destaque` na 2) |
| `grafico` | `grafico` ∈ `barras`/`linhas`, `x`, `series[]`, `dados[]`, `formato?` (na seção) | 1 |
| `associacoes` | `itens[{rotulo, corte?, direcao, seguranca, n}]`, `nota` | 2 |

- **Formatos:** `texto`, `inteiro`, `decimal1`, `decimal2`, `percentual`
  (fração 0–1). O formato de gráfico vem na **seção** e vale também para a
  tabela de dados (`serie.formato ?? secao.formato`).
- **`associacoes`:** `direcao` ∈ `maior | menor | sem_relacao_clara` (sinal da
  estimativa; `sem_relacao_clara` com p ≥ 0,05); `seguranca` ∈ `alta`
  (p < 0,01) | `media` (p < 0,05) | `baixa`. Todo relatório de regressão leva o
  aviso fixo `{tipo: "associacao"}`.
- **Capítulos (Fase 4, opcionais e retrocompatíveis):** `assistente` vem
  também no modo tema; no composto, `tema` = `{id, titulo}` do assistente
  (para histórico e salvos), `capitulos[{id, titulo, tema}]`, cada seção de
  capítulo leva `capitulo` e um id prefixado `<capitulo>-<id>`; `resumo`
  (primeira) e `leitura` (última) são gerais, sem `capitulo`. Os textos por
  capítulo não são gerados (o roteiro roda com a redação desligada). `fontes`
  e `avisos` são a união dos capítulos; os avisos de capítulo levam o título
  como prefixo; capítulo que falha vira `{tipo: "capitulo"}` e não derruba a
  EDA (se todos os territoriais falham, o primeiro erro sobe).
- **Tipos desconhecidos** são ignorados pelo frontend sem quebrar a tela.

**Erros:** 400 (`invalid_request`: tema, nível, geotag, opção ou assistente
inválidos; eduBR ausente; recorte acima do teto da regressão); os erros
`conexao`/`limite_excedido`/`parametro_invalido` do eduBR viram 500 (o Perl não
guarda em cache); `sem_dados` vira aviso.

## Modelo de dados

- **`clean.relatorios_salvos`** (change `relatorios_salvos`, Fase 3): `gestor_id`
  (FK para `clean.gestores` com `ON DELETE CASCADE`), `cod_inep`, `job_id`,
  `tema_id`, `tema_titulo`, `nivel` (CHECK escola/municipio/uf/regiao),
  `codigo`, `recorte_nome`, `opcoes` jsonb, `titulo`, `conteudo` jsonb (o
  ReportResult, fotografia), `gerado_em`, `created_at`; `UNIQUE (gestor_id,
  job_id)` para dedupe; índice `(gestor_id, created_at DESC)`.
- **`assistente`** (change `relatorios_salvos_assistente`, Fase 4): `text NOT
  NULL DEFAULT 'relatorio'`. Salvos antigos ficam como "Relatório por tema".
  O título do assistente nos salvos é derivado do `conteudo`, sem coluna
  própria.
- **`analytics.analysis_cache`:** cache de 24 h do `Analytics::Client`. A chave
  do relatório é `{geotag, tema, opcoes, config_version}` sob
  `report_<assistente>`, sem a `api_key`, e inclui `analytics_source_version`.
  O `cache_hit` é devolvido na resposta do job e **não** é gravado nos salvos.
- Os jobs ficam no Minion (`relatorio_gerar`, fila `analytics`, args
  `{gestor_id, cod_inep, geotag, tema, opcoes, assistente}`).

## Decisões de design (e o porquê)

**Fases 0–1**
- **Gestor tratado como pesquisador** (developer): a `pesquisadora-educacional`
  é a única persona com recortes territoriais. Quando o pesquisador for
  modelado, ele fica com as análises profundas; o catálogo já tem
  `profundidade` e o assistente tem `publico` para essa separação.
- **Roteiro fixo por tema, LLM só redige** (developer): reprodutibilidade,
  custo previsível e testes sem LLM. O agente livre ficou para quando houver
  perguntas exploratórias.
- **Seções estruturadas** (developer), não markdown nem HTML pré-renderizado:
  UX integrada e acessível, sem HTML de terceiros na SPA, componentes Svelte e
  Carbon Charts.
- **LLM do painel**, não `chat_edubr()`: uma só configuração para os dois
  assistentes e menos acoplamento à configuração do eduBR.
- **eduBR em `Suggests` + commit fixo** (developer/coordenador):
  independência nos dois sentidos e build reprodutível.
- **Dados ao LLM arredondados pelo formato e sem nome de ferramenta:** só
  corrigir o prompt não bastou; o LLM copia o que vê.

**Fase 2**
- **Regressão com especificação fixa** (developer): desfecho IDEB 2023 da
  etapa; preditores biblioteca, internet, laboratório de informática, número
  de professores e de matrículas; corte por localização; modelo linear; só
  escolas ativas. O gestor escolhe só UF, etapa e rede. **Só redes públicas**
  (SP com todas as redes tem 30.817 escolas, acima do teto absoluto de 30.000
  do eduBR).
- **Leitura simplificada e técnico recolhido** (developer): a seção
  `associacoes` traduz sinal e p-valor em direção e segurança; coeficientes e
  métricas ficam em tabelas recolhidas. Coeficientes em `texto` com 3
  algarismos significativos ("< 0,001"), porque os formatos numéricos zerariam
  efeitos pequenos.
- **Posição da escola calculada no R**, de forma determinística (empates
  dividem a posição), com nota de que posição não é julgamento.
- **Catálogo com `padroes`:** opção sem padrão vira "Todas" na tela (corrigiu
  a etapa forçada em escolas sem anos iniciais).
- **Escolas parecidas:** pede 20 linhas e fica com até 10 escolas distintas
  (a ferramenta devolve escola × etapa).

**Fase 3**
- **PDF pela impressão do navegador** (developer): sem pandoc/LaTeX no
  contêiner e sem endpoint novo; o PDF é o que a tela mostra (CSS de
  impressão A4, `<details>` abertos no `beforeprint` e restaurados no
  `afterprint`).
- **Markdown no cliente** (`relatorioParaMarkdown`, função pura): uma
  implementação para o relatório atual e para os salvos; gráficos saem como a
  tabela de dados.
- **Salvar quando quiser, retenção até o gestor excluir** (developer), com
  cascade na remoção da conta.
- **Fotografia + "gerar de novo"** (developer): reabrir não custa LLM; o
  "gerar de novo" usa preenchimento por query (`nivel`, `codigo`, `nome`,
  `tema`, opções, `assistente`, `gerar=1`), que também serve para links
  diretos.

**Fase 4**
- **Segundo assistente = EDA do município** (developer), composto por
  capítulos que são temas já existentes, mais um resumo geral.
- **Um YAML por assistente, sem código R** (developer). YAML inválido é
  ignorado com log e não derruba os outros.
- **Uma única chamada de LLM para a EDA inteira**, a partir de um payload
  enxuto por capítulo (≤ 18 mil caracteres, linhas por tabela reduzidas
  progressivamente; resumo de até ~300 palavras): custo e latência
  previsíveis e um texto coerente, em vez de N resumos soltos.
- **Ordem da EDA da estrutura para os resultados:** redes → professores →
  IDEB → escolas → minha escola. "Minha escola" só entra quando a escola do
  gestor fica no município pedido; a comparação é por nome normalizado + UF,
  porque o eduBR não devolve o código do município da escola.
- **Opções do assistente sobrepõem as fixas dos capítulos que as aceitam**
  (a `etapa` escolhida vale para os capítulos de IDEB); `opcoes.<x>.valores`
  omitido = interseção dos valores aceitos pelos capítulos.
- **Seletor de assistente** (developer) no topo da página; só aparece com 2
  ou mais assistentes; o padrão é omitido nos pedidos; se a lista falhar, a
  página cai em "Relatório por tema". Salvos, exportação e "gerar de novo"
  continuam iguais.

## Segurança e LGPD

- **Sem PII:** só dados que passam pelas ferramentas do eduBR (que removem
  endereço, telefone, CEP e CNPJ); `perfil_gestor` é agregado; o adapter não
  usa `exportar()` nem funções de domínio fora do tooling. Os relatórios têm
  só dados públicos e agregados, além de nomes e códigos de escola (dado
  institucional). Conferido em todas as rodadas de e2e.
- **Sessão:** todas as rotas exigem Bearer e posse do `cod_inep` (401/403). O
  nível `escola` só aceita a escola do próprio gestor (400 caso contrário); o
  `cod_inep` do contexto vem da sessão, não do cliente. Job de outro gestor ou
  de outra task → 404.
- **Conteúdo salvo vem do servidor:** o POST de salvar recebe só o `job_id`; o
  conteúdo é lido do resultado do job, com a mesma checagem de posse, e
  **nunca** do corpo da requisição (o e2e enviou conteúdo adulterado, que foi
  ignorado). Os salvos são visíveis só para o próprio gestor.
- **Nomes internos:** nem o LLM, nem os avisos, nem o rodapé de fontes
  mostram nomes de ferramenta.
- **Nomes de terceiros fora do LLM:** nos temas com lista de escolas, o LLM
  recebe só a escola do gestor (`sua_escola: true`) e não cita outras.
- **Saneamento do texto do LLM:** markdown simples, sem HTML, links ou
  imagens, renderizado pelo `TextoMarkdown` seguro.

## Infraestrutura e lições

- **eduBR fixado por RemoteSha** (`marcoarthur/eduBR@2dc9af9`) no Rexfile e no
  Dockerfile; a instalação é idempotente (na segunda vez, pula). Spike e
  build feitos de `git archive` no scratchpad, sem escrever no clone.
- **`Collate`:** `censo-dictionary.R` fora do `Collate` quebrava o `R CMD
  INSTALL` na reinstalação do deploy (escondido pelo marcador md5 do Rex).
- **Pilha de 64 MB no Plumber:** `escolas_similares` estourava os 8 MB só
  dentro do Plumber; `LimitSTACK=64M` na unit e `ulimits.stack` no compose.
- **Versão do pacote = versão do cache:** subir o `Version` do
  `edumapsAnalytics` **e** `analytics_source_version` (`edumaps_db.conf`)
  juntos sempre que o R mudar (0.2.0 na Fase 2, 0.3.0 e 0.3.1 na Fase 4). Sem
  isso, uma mudança fica escondida por até 24 h de cache.
- **Cache que nunca ligou** (Fase 1): `Analytics::Client::_db` testava
  `$app->can('pg')`, mas `pg` é helper; corrigido, o cache de 24 h vale para
  todas as análises cacheáveis, com aprovação do developer.
- **Service worker:** logo após um deploy do frontend, o primeiro
  carregamento pode vir do bundle antigo (tela em branco até recarregar).
  Reapareceu na Fase 4; já conhecido.
- **Integração pelo endpoint:** testar pelo Plumber, não só pela função
  (`pkgload`), porque o ambiente do servidor difere (pilha, Collate). Na Fase 4
  a integração da trilha R já foi feita por um Plumber de uma cópia.
- **Saneamento de HTML** (Fase 4): a regex gananciosa `<[^>]+>` engolia o texto
  entre comparações ("4,5 < 4,7 … > 4") e truncava o resumo da EDA; agora só
  remove o que parece tag (`</?[A-Za-z][^<>\n]*>`).
- **R:** `n = 5` casa parcialmente com um parâmetro `nome` de função auxiliar;
  em wrappers com `...`, usar nomes com ponto (`.ferramenta`).
- **Driver CDP de e2e** (Perl, Chrome `:9222`): o Mojo limita mensagens de
  WebSocket a 256 KB (`max_websocket_size`); captura de 2200 px falha (usar
  1600); PDF por `Page.printToPDF`; downloads reais por
  `Browser.setDownloadBehavior`; esperar o recorte padrão (assíncrono) antes
  de clicar; um caso por aba; token de sessão de teste ≤ 64 caracteres.
- **Migration no CI:** `ci_db.sh` não tem deploy incremental; usar o
  contêiner `sqitch` na rede do CI.

## Testes e validação por fase

| Fase | R (arquivos / asserções) | Backend (arquivos / testes) | Frontend (arquivos / testes) | E2E (Gemini real) |
|---|---|---|---|---|
| 0 | ferramentas da fase 1 medidas em dev (0,1–5 s) | — | — | — |
| 1 | 28 / 1085 | 103 / 676 (só falhas antigas) | 101 / 779 | 14/14, 5–13 s por relatório, 1,6 s do cache |
| 2 | 29 / 1374 | relatórios 2 / 23 | 101 / 795 | 13/13 pela API e 11/11 na tela |
| 3 | — (R sem mudança) | 102 / 690 (só falhas antigas) | 105 / 864 | 21/21, com download de Markdown e PDF via `printToPDF` |
| 4 | 30 / 1591, 0 falhas | 102 / 697 (só falhas antigas) | 106 / 899 | 22/22 |

- As "falhas antigas" do backend são `City.t`, `domain/quality.t`,
  `indicators/quality.t`, `indicators_quality.t`, `03-plugins/analytics.t`,
  `04-api/municipio.t` e `04-api/network/schools.t`.
- Migrations: `relatorios_salvos` (verify, revert e deploy no CI) e
  `relatorios_salvos_assistente` (verify ok).
- **Fase 4, e2e:** assistentes listados; EDA em nível UF → 400; assistente
  desconhecido → 400; EDA de Ubatuba com 5 capítulos, incluindo "Minha escola
  no município" (~34 s a frio, 1,6 s do cache); seções gerais resumo e
  leitura; etapa escolhida sobrepondo a fixa dos capítulos; EDA salva com
  assistente; Relatório por tema intacto; tela com seletor, sumário com
  âncoras e `h2` por capítulo; Markdown com sumário, `##` por capítulo e `###`
  por seção; PDF; salvos com selo; "gerar de novo" refaz a EDA. Critério de
  aceite da generalização: um terceiro assistente de teste (`panorama_uf`,
  só YAML) gera relatório sem código novo.
- Validação visual do developer nas Fases 1–3.

## Como criar um novo assistente

1. **Escolher os temas.** Um assistente só combina temas que já existem no
   catálogo (tabela acima). Tema novo exige um roteiro em R; isso é outro tipo
   de mudança.
2. **Escrever o YAML** em `analysis/edumapsr/inst/assistentes/<id>.yml`. O
   `id` é igual ao nome do arquivo e segue `[a-z0-9_]+`. Exemplo (o assistente
   de teste `panorama_uf`):

   ```yaml
   id: panorama_uf
   titulo: Panorama do estado
   descricao: Gestores, IDEB e infraestrutura do estado, com a sua escola quando ela fica no estado.
   publico: [gestor, pesquisador]     # perfis que veem o assistente
   modo: composto                     # tema (gestor escolhe um tema) | composto (capítulos fixos)
   niveis: [uf]                       # compatível com o nível de cada tema
   capitulos:                         # modo composto; no modo tema use `temas: [ids]`
     - { tema: ideb_territorio,     titulo: "IDEB do estado" }
     - { tema: gestores_territorio, titulo: "Gestores escolares" }
     - { id: infra, tema: infraestrutura_ideb, titulo: "Infraestrutura e IDEB", opcoes: { rede: publica } }
     - { tema: minha_escola,        titulo: "Minha escola", recorte: escola }   # opcional: só se a escola fica no recorte
   opcoes:                            # escolhas do gestor; sobrepõem as fixas dos capítulos que as aceitam
     etapa: { valores: [fundamental_i, fundamental_ii], padrao: fundamental_ii }
   prompt_complemento: |              # acrescentado ao system prompt da redação geral
     ## Panorama do estado
     - ...
   limites: { max_chamadas: 50 }      # sobrepõe os limites do adapter (capítulos dividem a sessão do eduBR)
   ```

   - Obrigatórios: `id`, `titulo`, `descricao`, `publico`, `modo`, `niveis`, e
     `temas` (modo tema) ou `capitulos` (modo composto).
   - `capitulos[].id` é opcional (padrão = `tema`, único no assistente);
     `opcoes.<x>.valores` omitido = interseção dos valores dos capítulos.
3. **Validar.** O carregador confere campos, `id`, existência dos temas e
   compatibilidade de níveis; um YAML inválido é ignorado com log. Há um teste
   para cada YAML do pacote; acrescentar o novo e rodar o testthat. Para
   experimentar sem tocar no pacote, os diretórios da opção
   `edumapsAnalytics.assistentes_dirs` ou de `EDUMAPS_ASSISTENTES_DIRS` também
   são lidos (o primeiro `id` carregado vence).
4. **Versionar e publicar.** Subir o `Version` do `edumapsAnalytics` e o
   `analytics_source_version` juntos, e fazer o deploy do `analytic`
   (`deploy_analytics_dev`, imagem local `analytic`). O backend e o frontend
   não mudam: a lista vem de `/report/assistentes`, filtrada por `publico`
   contendo `gestor`; o seletor aparece sozinho.
5. **Documentar** a capacidade em `docs/funcionalidades/analise/relatorios-territorio.md`.

## Pendências e próximos passos

- **Desempenho da EDA:** ~25–34 s por município, puxado pelas fatias de redes
  e docentes no eduBR. `redes_territorio` por região leva 30–40 s.
- **Eixo percentual** dos gráficos vai de 0 a 1 (só visual; tabela correta).
- **Paginação** de listas grandes (São Paulo capital: 1.128 escolas).
- **Reinício do R:** jobs que pegam o reinício do serviço falham, sem nova
  tentativa.
- **Redação dos selos** de segurança das associações, a validar com uso real.
- **Achados para o eduBR** (só registro; o repositório é somente-leitura):
  - filtro por código de município em `redes_municipio`/`ideb_agregado`/`docentes_rede`
    (eliminaria as fatias);
  - argumento `filtro` em `regressao_escolas` (ex.: só escolas que ofertam a
    etapa), para reduzir o recorte abaixo do teto;
  - código do município na saída de `perfil_escola`/`resumo_escola` (hoje a
    EDA compara por nome + UF).
- **Perfil pesquisador:** modelar a categoria no cadastro. O catálogo já tem
  `profundidade` e os assistentes já têm `publico`; falta o perfil, as
  permissões e os limites maiores.
- **Convergência** com o Assistente do Censo, em aberto desde o plano.
