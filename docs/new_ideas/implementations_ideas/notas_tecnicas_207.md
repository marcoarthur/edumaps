# Nota técnica 207: porte no ranking de redes e base de análise (#439)

Achados RV-05 e RV-02 da reavaliação P4/P6
(`docs/personas/publicos/avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`).
Dois PRs, o segundo empilhado sobre o primeiro:

| PR | Achado | Merge |
|---|---|---|
| #442 | RV-05 porte do município no ranking de redes | `514f93b` |
| #443 | RV-02 base de análise por escola | `6230eab` |

## Decisões de produto (developer, 2026-11-16)

- A base de análise é **pública** e sai **uma UF por vez**. A base nacional,
  as séries históricas e o acesso por API ficam para a assinatura de dados.
- **Só CSV.** Parquet ficaria para a API: exigiria uma dependência nova no
  backend.
- O porte usa as **classes de tamanho da população do IBGE** (até 5 mil,
  5–10, 10–20, 20–50, 50–100, 100–500 mil, mais de 500 mil). Não usa faixas
  de matrícula.

## #442: porte no ranking de redes

- `EduMaps::Porte` (no #443; no #442 as classes ficavam no modelo) guarda as
  sete classes. O limite superior entra na classe: 5.000 habitantes conta como
  "até 5 mil". `case_sql($expr)` gera o `CASE`, sempre a partir de uma
  expressão do código.
- `redes_municipais` junta `clean.populacao_municipal` e devolve
  `populacao`, `porte`, `portes` e `populacao_fonte`.
- **O filtro `porte` entra no CTE `elegiveis`**, antes do `RANK`, dos quintos
  de INSE e do salto atípico (calculado em Perl sobre as linhas). Assim, o
  ranking é entre redes do mesmo porte, e não a lista do estado filtrada
  depois. A contagem de "fora por poucas escolas" também respeita o porte.
- Porte sem rede devolve 200 com a lista vazia: é um resultado, não um erro.
  A tela diz "Nenhuma rede neste recorte".
- **Ano da população.** `clean.populacao_municipal` não tem coluna de ano.
  A carga é o `pop_2025_mun.csv` (`data_pipeline/deploy/raw_populacao.sql`),
  então a base nova `ibge_populacao` do catálogo de fontes declara o período
  fixo 2025, como a malha. A tela e o dicionário leem o ano do catálogo.
- Medido: MG, IDEB anos iniciais, 302 redes, todas com porte; 89 na faixa de
  10 a 20 mil, mesma contagem com e sem o filtro. Nacional com porte: 0,43 s.

## #443: base de análise

- **Não lê `clean.school_indicators`.** Aquela tabela é esvaziada
  (`TRUNCATE`) e refeita a cada agrupamento, e o IDEB dela é a média entre
  etapas do ano do último agrupamento. A base lê as tabelas de origem:
  - `clean.censo_escolas`, no ano mais recente e só as escolas com
    `tp_situacao_funcionamento = 1`;
  - `censo_docentes`, com as mesmas fórmulas de docência do agrupamento;
  - `ideb_notas_escolas`, pivotada por etapa em colunas largas
    (`max(...) FILTER (WHERE etapa = ...)`, restrita à UF);
  - `inse`, na edição mais recente;
  - `populacao_municipal`.
- **Catálogo único.** `EduMaps::BaseAnalise` declara os blocos, e cada coluna
  tem nome, expressão SQL, descrição e indicação de número. Desse catálogo
  saem o `SELECT`, a lista da tela (sem SQL), o cabeçalho e o dicionário.
  Não há segunda lista para divergir.
- **Versão dos dados:**
  - colunas `ano_censo` (sempre), `ano_ideb`, `ano_inse` e `ano_populacao`
    (quando o bloco entra), no fim de cada linha;
  - os anos também vão no nome do arquivo
    (`base-analise-SP-censo2025-ideb2023-inse2023.csv`).
- **Dicionário** (`/api/base-analise/dicionario`): coluna, descrição, bloco,
  fonte, ano e o link oficial do catálogo de fontes. Cumpre o pedido de "link
  das fontes" sem linhas de comentário no CSV.
- **Formato:** `;`, BOM e vírgula decimal, como o CSV do agrupamento.
  - Correção no caminho: o `%.6g` transformava a população de São Paulo em
    `1,2e+07`. Agora inteiro sai inteiro.
  - Ausência é célula vazia: a escola sem a etapa não ganha zero.
- **Achado na validação:** `aprovacao_si_4` está em percentual (21,7 a 100) e
  não de 0 a 1, como diz o comentário da coluna em `school_indicators`. A
  descrição da base diz "em %".
- **Tela `/base-analise`:**
  - recorte (UF; município e rede opcionais), com o total de escolas do
    recorte;
  - blocos e edição do IDEB;
  - downloads por `<a download>`, com o nome do arquivo vindo do servidor;
  - a URL guarda as escolhas;
  - escolher município de outra UF troca a UF;
  - links na Home, em `/fontes` e na página de Análises ("sem agrupar, use a
    base de análise").
- Medido: SP com todos os blocos, 30.817 escolas (igual ao total), 47
  colunas, 6 MB em 2,7 s.

## Validação

- Perl `-j4`: 193 arquivos, 1708 testes. vitest: 152 arquivos. Suítes
  completas em cada branch e CI verde nos dois PRs.
- Navegador na stack local, depois do rebuild: ranking com porte (MG); base de
  análise com ES, depois Vitória da Conquista (BA, 246 escolas); download da
  base e do dicionário pelos links da tela.
- PR empilhado: o #443 foi redirecionado para `main` antes do merge do #442
  com `--delete-branch`.

## Deploy

Backend e frontend, sem migração: entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
