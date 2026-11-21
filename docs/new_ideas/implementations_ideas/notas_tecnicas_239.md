# Nota técnica 239: ranking de redes só com escolas em funcionamento (#508)

Achado RB-01 da vigésima sétima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-20-p4-refazer-ranking-redes.md`).
Um PR: #509 (merge `9a06f49`).

## O problema

- **RB-01 (atrapalha).** O valor da rede no ranking de redes era a média das
  escolas da tabela do IDEB marcadas como municipais na edição, sem cruzar
  com o Censo. Entravam escolas paralisadas, extintas, fora do Censo mais
  recente ou hoje de outra rede.
- A base de análise e a lista de escolas (#504) só têm as escolas em
  funcionamento, e a rede delas vem do Censo. Quem baixava a base para
  refazer a conta não chegava ao mesmo número: 17 das 348 redes da BA (IDEB
  anos iniciais 2023).
- Mário Campos/MG ficava em 216º de 302 por uma escola paralisada com IDEB
  3,0.

## Decisões

- **A mesma regra da lista e da base.** Revê a decisão da nota 237 ("o
  ranking de redes não mudou"). As escolas são as em funcionamento
  (`tp_situacao_funcionamento = 1`) na rede municipal (`tp_dependencia = 3`)
  do Censo mais recente; a rede, o município e a UF vêm do Censo. A coluna
  `rede` da tabela do IDEB não conta mais: a escola municipalizada depois
  da edição entra, a que virou estadual sai.
- **Tudo com a mesma regra:** a média, o número de escolas, o INSE, a
  variação nas mesmas escolas (a escola da edição atual em funcionamento, a
  da anterior com o dado), as redes fora pelo mínimo e o destaque do
  município.
- **O que saiu fica dito:**
  - `escolas_fora`, por rede e no total do recorte: as escolas municipais
    na tabela do IDEB com o indicador na edição que não estão mais em
    funcionamento na rede municipal;
  - `ano_censo`, o Censo da regra. As duas colunas vão no CSV, e a nota da
    tabela diz quantas saíram.
- **A linha do IDEB** da comparação de redes não mudou: é uma série por
  edição, e a escola que fechou depois continua na edição em que teve nota.

## Validação

- **Docker local (IDEB anos iniciais 2023):**
  - BA: as 347 redes se refazem pela base de análise (média, escolas,
    INSE, variação e escolas da variação), sem nenhuma diferença;
  - Mário Campos/MG: de 216º de 302 (média 5,68) para 68º de 298 (6,35, 4
    escolas, 1 fora);
  - Brasil: 3.056 redes, 150 escolas fora de funcionamento.
- **Testes:**
  - Perl: `t/04-api/ranking_recorte.t` com as escolas das redes no Censo e
    um subtest com paralisada, fora do Censo, hoje estadual, municipalizada
    e a rede que cai abaixo do mínimo; 200 arquivos e 1.764 testes;
  - vitest: 1.367 testes;
  - CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`, sem change de banco.
