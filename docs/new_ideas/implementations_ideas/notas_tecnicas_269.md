# Nota técnica 269: meses em vez de competências no painel (#568)

Achado P1-FL-02 da segunda avaliação da P1
(`docs/personas/publicos/avaliacoes/2026-11-24-p1-folha-da-escola.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #570 (merge `160794d`). Só frontend e ajuda.

## O problema

- **P1-FL-02 (incomoda).** O painel financeiro dizia "Competências com
  dados" e "Competência mais recente". "Competência" é o mês de referência
  da folha, palavra da contabilidade; a diretora entende "meses".
- As categorias somavam 59 pessoas e o cartão dizia 57, sem explicar que
  quem está em duas categorias conta nas duas.

## Decisões

- **B1, todo texto que a pessoa lê:** o painel ("Meses com folha"; "No
  último mês (ago/2026)"), a folha detalhada ("para este mês") e as ajudas.
  A ajuda de financeiro e folha diz que o SIOPE chama o mês de
  "competência", para quem vier do sistema. Comentários e nomes no código
  ficam.
- **A1, a nota da soma só quando ela passa do total:** "Quem está em mais
  de uma categoria conta em cada uma: a soma (59) passa do total de
  profissionais (57)." Onde fecha, nada.

## Validação

- **Docker local:** o painel da EM Tancredo Neves (35070212) com os textos
  novos, sem "competência" na tela, e a nota de 59 contra 57.
- **Testes:** vitest, 1.441. CI do PR verde.

## Pendências

- No LXC: `deploy_frontend_dev`.
- Os dois achados da segunda rodada da P1 estão entregues; continua a
  observação do botão de imprimir no painel.
