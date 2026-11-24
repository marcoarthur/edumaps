# Nota técnica 265: o gasto da folha só dos meses completos (#561)

Achado QM-01 da trigésima oitava avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-24-p4-folha-por-aluno.md`, o
gasto com pessoal por aluno em Cuiabá). Issue aberta com a aprovação do
developer; plano aprovado com as opções A1 e B1. Um PR: #562 (merge
`d669c24`).

## O problema

- **QM-01 (atrapalha).** A base marcava os meses incompletos
  (`meses_folha_incompletos`, #557), mas o gasto vinha só somado no ano.
  Não dava para anualizar.
- O viés não é aleatório. Em Cuiabá 2025, 53 das 83 escolas só de educação
  infantil perdem setembro e outubro inteiros (a folha delas é só de
  auxiliares), e as de fundamental mantêm 12 meses sem os auxiliares
  nesses dois. A comparação do gasto por aluno entre as duas saía
  enviesada.
- A saída da ajuda era a folha mês a mês do painel: uma tela por escola.

## Decisões

- **A1, duas colunas na base:** `meses_completos` (os meses com folha da
  escola fora dos incompletos do município) e
  `gasto_pessoal_meses_completos` (o gasto só deles). Anualizar:
  `gasto × 12 ÷ meses`. Sem arquivo novo, uma linha por escola.
- **Sem mês incompleto, as colunas repetem o ano:** a conta vale igual em
  todo município, sem caso especial no código de quem usa.
- **O mesmo critério da #557:** a conta da folha de cada escola
  (`$SQL_FOLHA`) junta os meses incompletos de `$SQL_MESES` pelo município
  e pelo número do mês. Para isso, o bloco dos meses passou para antes de
  `$SQL_FOLHA`, e `_mes_num($coluna)` gera o número do mês para qualquer
  coluna.
- **B1, só o gasto e os meses:** as médias por mês continuam como estavam;
  o dicionário e a ajuda dizem que elas incluem os meses incompletos.
- **Dezembro entra quando está completo:** com o 13º, o anualizado fica um
  pouco acima de 12 meses "normais". A ajuda avisa.

## Validação

- **Docker local, Cuiabá 2025:**
  - as 114 escolas com 12 meses ficam com 10 completos; as 53 com 10, com 10;
  - EMEB Zeferino: R$ 5.021.449 no ano, R$ 4.308.886 em 10 meses;
  - mediana por aluno, anualizada: educação infantil de R$ 14.668 para
    R$ 17.602; fundamental de R$ 6.671 para R$ 6.922.
- **Testes:** Perl, 209 arquivos (maio incompleto: 6 meses, 5 completos,
  R$ 48.000 e R$ 46.000; sem mês incompleto, igual ao ano; sem folha,
  vazio); vitest, 1.435. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev`.
- Conferir no SIOPE setembro e outubro de 2025 de Cuiabá (download com
  permissão).
