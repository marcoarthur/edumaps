# Nota técnica 251: taxa de atendimento da educação infantil (#533)

Achado QP-01 da avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-23-p2-relatorio-conselho.md`).
A issue foi aberta sozinha, com o developer ausente. O download do IBGE e o
plano (opções A1 e B1) foram aprovados por ele. Um PR: #534 (merge
`9aea643`).

## O problema

- **QP-01 (atrapalha).** A meta 1 do PNE pede a taxa de atendimento: creche
  para 50% das crianças de 0 a 3 anos e pré-escola para todas as de 4 e 5.
  A plataforma só dava matrículas por habitante.
- As faixas de 5 anos de `clean.populacao_municipal` vinham de um CSV sem
  fonte nem ano. Elas não separam 0–3 de 4–5 e não têm as faixas de 25 a 29
  e de 90 a 94 anos (em Franca, somam 325.006 contra 365.494).

## Decisões

- **Fonte:** SIDRA, tabela 9514 do Censo Demográfico 2022 (população por
  sexo, idade e forma de declaração), ambos os sexos e todas as formas.
- **A1, idade simples:** o total, as 21 faixas de 5 anos e as idades de 0 a
  17 anos, por município. As idades de 6 a 17 servem para taxas do
  fundamental e do médio depois.
- **Onde gravar:** em `clean.ibge_agregados`, a tabela longa do IBGE que já
  existia e estava vazia (`tabela_id` 9514, variável 93, com a idade do
  SIDRA em `classificacao`). A visão `clean.populacao_idade` soma as idades
  por etapa: 0 a 3, 4 e 5, 6 a 14 e 15 a 17.
- **Job `IBGEPopulacaoIdade`:**
  - herda do job do PIB a leitura e a carga do formato longo;
  - faz 5 requisições (`n6/all`, 8 categorias por vez, para caber no
    limite de valores do SIDRA);
  - "-" vale zero (convenção do IBGE), e "..." e "X" ficam vazios;
  - antes de gravar, confere em todo município que as faixas somam o total
    e que as idades de 0 a 4 somam a faixa. Aborta também com código ou
    nome de categoria desconhecido, ou com menos de 5.500 municípios;
  - o bruto é preservado, e `--arg csv=` relê o bruto sem baixar de novo.
- **B1, faixas antigas:** ficam como estão (o IVET as lê), com o comentário
  dizendo a origem desconhecida, as faixas que faltam e onde está a fonte
  nova.
- **Três taxas na comparação de redes:** a issue pedia a rede municipal e
  a municipal com as conveniadas (teto, #520). Entrou também a de todas as
  redes, porque a meta do PNE conta as matrículas de todas.
- **Base:** `populacao_0_3` e `populacao_4_5` no bloco Porte. A coluna pode
  ter fonte própria no dicionário, então o ano é 2022 e o link é o da
  tabela do SIDRA, e não a estimativa de 2025 do bloco. Entrou também a
  coluna de versão `ano_populacao_idade`.

## Validação

- **Carga no Docker local:** 222.800 registros de 5.570 municípios em
  30 s, somando 203.080.756 habitantes. Franca tem 15.862 crianças de 0 a
  3 anos e 9.094 de 4 e 5.
- **Tela (Franca):**
  - creche: 58,0% em todas as redes, 0,0% na municipal e 48,9% com as
    conveniadas;
  - pré-escola: 93,2%, 36,4% e 75,7%.
- **R da ajuda na base de SP:** 645 municípios. Com as conveniadas, 304
  chegam aos 50% da creche e 171 aos 100% da pré-escola.
- **Sqitch:** deploy, verify, revert (devolve os comentários antigos) e
  redeploy no banco do CI.
- **Testes:** Perl, 1.828 testes; vitest, 1.385; CI do PR verde (Perl, R,
  vitest e build).

## Pendências

- No LXC: `deploy_db_dev`, backend e frontend, e depois a carga
  `IBGEPopulacaoIdade` (roteiro, §6, passo 4).
- Taxas do fundamental e do médio (6 a 14 e 15 a 17 já estão na visão),
  se algum público pedir.
