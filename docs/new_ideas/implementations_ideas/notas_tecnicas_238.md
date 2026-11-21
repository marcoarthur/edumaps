# Nota técnica 238: posição da escola com empate honesto (#506)

Achados RC-01 e RC-02 da vigésima sexta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-19-p4-posicao-escola.md`).
Um PR: #507 (merge `5f9a4bc`).

## O problema

- **RC-01 (atrapalha).** A posição da escola usa `RANK()`: as empatadas
  recebem a melhor posição. O percentil (T − N)/(T − 1) contava as
  empatadas como abaixo. Com sustentabilidade 0, 52.164 escolas apareciam
  "128.377º de 180.540, acima de 29%"; com aprovação de 100% nos anos
  iniciais, 14.508 escolas "1º, acima de 100%".
- **RC-02 (detalhe).** A posição do IDEB era calculada na hora sobre a
  tabela do IDEB, sem a situação no Censo (diferente da lista do #504), e
  nenhuma ajuda explicava a posição.

## Decisões

- **O empate entra no dado.** `analytics.ranking_escola` ganhou
  `empate_municipio/estado/nacional` (change nova `ranking_escola_empates`;
  nada foi editado nas changes já deployadas), preenchidas pelo
  `ranking.pl` com `COUNT(*) OVER (PARTITION BY <escopo>, <valor>)`.
- **"Acima de" conta só as de valor menor:**
  `abaixo = total − posição − empate + 1` e
  `percentil = abaixo / (total − 1)`. A escola deixa de contar a si mesma e
  as empatadas. A conta vive numa função só (`_escopo_posicao`) para a
  tabela pré-calculada e para o cálculo na hora. A resposta traz `empate` e
  `abaixo` em cada escopo.
- **A posição do IDEB só com escolas em funcionamento** no Censo mais
  recente (`JOIN` com `tp_situacao_funcionamento = 1`), no `ranking.pl` e
  no cálculo na hora, como a lista do #504. Os escopos município e estado
  vêm do Censo, não da tabela do IDEB.
- **O IDEB passou a ser pré-calculado** junto dos índices
  (`ranking.pl` sem `--source` faz os dois); o cálculo na hora segue como
  reserva.
- **Tela:** "Nº de T", "empatada com N escolas" quando o empate passa de
  1, e "Acima de X% das outras escolas", com uma dica no título "Posição".
  Ajuda nova `docs/ajuda/comunidade/posicao-da-escola.md`.

## Validação

- **Docker local** (após o `sqitch` e o `ranking.pl`):
  - 29422620, sustentabilidade 0: nacional 128.377º de 180.540, empatada
    com 52.164, 0% (era 29%); estado 10.779º de 16.106, empate 5.328;
    município 767º de 1.432, empate 666;
  - 29448913, aprovação 100%: 1º de 43.212, empatada com 14.399, 67%;
  - 29190231, IDEB anos iniciais: 1º de 247 no município (era 257).
- **Testes:**
  - Perl: `t/04-api/posicao_escola.t`, com empate, escola extinta e as duas
    rotas (na hora e tabela); 200 arquivos e 1.763 testes;
  - vitest: 1.366 testes;
  - CI do PR verde.

## Pendências

- No LXC: `deploy_db_dev` e depois `ranking.pl` sem `--source`; até lá as
  colunas de empate ficam vazias e a resposta trata o empate como 1.
