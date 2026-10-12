# Nota técnica 114 — Assistente de Relatório, Fases 0 e 1 (PR #220)

## Resumo

O `edumapsAnalytics` passou a **consumir o `eduBR`** para um novo assistente:
o gestor escolhe um recorte (escola, município, UF, macro-região) e um tema e
recebe um **relatório em seções** redigido pelo LLM do painel a partir de dados
estruturados. Issue #219 (segue aberta), PR #220 (merge `c62d730`). Plano:
`docs/specs/2026-10-12-assistente-relatorio-plano-inicial.md`; execução:
`…-assistente-relatorio.execucao.md`.

## Decisões de design

- **Gestor tratado como pesquisador** (developer): persona
  `pesquisadora-educacional` do eduBR, a única com ferramentas territoriais.
  A `gestora-escolar` só tem ferramentas de **uma escola**. Quando o pesquisador
  for modelado, ele fica com as análises profundas, e o gestor volta a um
  conjunto enxuto. O catálogo já tem `profundidade` para isso.
- **Roteiro fixo por tema, LLM só redige:** o adapter chama as ferramentas do
  eduBR (`ToolDef` chamado como função, envelope JSON
  `dados/metadados/erro`) e o LLM recebe um JSON enxuto. Isso dá
  reprodutibilidade, custo previsível e testes sem LLM. O system prompt é
  `eduBR::prompt_persona()` mais um complemento de linguagem para o gestor.
- **Seções estruturadas** (`texto | indicadores | tabela | grafico`) em vez de
  markdown ou HTML. O frontend renderiza com componentes próprios
  (`TextoMarkdown` seguro e Carbon Charts), sem HTML de terceiros.
- **LLM do painel** (`chat_config()`/`chat_llm()`), não o `chat_edubr()`:
  uma configuração só para os dois assistentes. `provider = mock` para
  testes. Falha do LLM → as seções de dados saem com resumo determinístico.
- **Independência:**
  - o eduBR fica em `Suggests` + `Remotes` do edumapsAnalytics;
  - no deploy, é instalado do GitHub em **commit fixo** (RemoteSha no Rexfile e
    no Dockerfile);
  - nada foi escrito no repositório eduBR; os achados sobre ele ficam
    registrados aqui.
- **Lacunas do eduBR resolvidas no adapter:**
  - `docentes_rede` sempre com `colunas` (sem isso, bate no limite de
    caracteres e devolve 3 linhas);
  - município filtrado dentro da UF (`n = 1000`), porque as ferramentas
    agregadas não filtram um município;
  - respostas truncadas são refeitas em fatias, por rede e localização.
- **Erros:** 400 para pedido inválido; os erros
  `conexao`/`limite_excedido`/`parametro_invalido` do eduBR viram 500, para o
  Perl não guardar em cache um relatório quebrado; `sem_dados` vira aviso.

## Correções relevantes

- **Cache de análises que nunca ligou:** `Analytics::Client::_db` testava
  `$app->can('pg')`, mas `pg` é helper, então o cache ficava sempre desligado.
  A tabela `analytics.analysis_cache` estava vazia em dev desde `5f110c6`.
  Corrigido via `renderer->get_helper('pg')`. O cache de 24 h passa a valer
  para todas as análises cacheáveis (Assistente do Censo, cluster, perfis),
  com aprovação do developer.
- **`censo-dictionary.R` fora do `Collate`:** o `R CMD INSTALL` falhava assim
  que o pacote precisava ser reinstalado. Isso ficava escondido pelo marcador
  md5 do Rex.
- **Texto do LLM:** o modelo usava ponto decimal e citava o nome interno da
  ferramenta. Agora o pacote de dados para o LLM sai **arredondado pelo
  formato** da seção e **sem o nome da ferramenta**, e o prompt pede o padrão
  brasileiro. Corrigir só o prompt não bastou: o LLM copia o que vê.

## Validação

- **Fase 0:** ferramentas da fase 1 medidas em dev (0,1–5 s por chamada).
- **Testes:**
  - R: 28 arquivos / 1085 asserções;
  - backend: 103 / 676, só falhas antigas;
  - frontend: 101 / 779.
- **E2E 14/14** com o Gemini real, de 5 a 13 s por relatório e 1,6 s quando
  vem do cache. Validação visual do developer.

## Pendências e lições

- **Cache:** a chave não inclui a versão do prompt nem do pacote; uma mudança
  de texto só aparece depois de 24 h ou de limpar o cache.
- **Reinício do R:** jobs que pegam o reinício do serviço falham, sem nova
  tentativa.
- **Lentidão:** `redes_territorio` por região leva de 30 a 40 s.
- **Achado para o eduBR:** um filtro por código de município em
  `redes_municipio`/`ideb_agregado`/`docentes_rede` eliminaria as fatias.
- **PWA:** logo depois de um deploy do frontend, o service worker pode servir
  o bundle antigo (tela em branco até recarregar).
- **Lição:** no R, `n = 5` casa parcialmente com um parâmetro `nome` de função
  auxiliar. Use nomes de parâmetro com ponto (`.ferramenta`) em wrappers com
  `...`.
