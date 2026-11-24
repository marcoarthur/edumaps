# Nota técnica 273: o aviso do mês incompleto com a carga (#576)

Achado QH-02 da quinta avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-24-p5-piso-cuiaba.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #578 (merge `7a839fa`).

## O problema

- **QH-02 (incomoda).** O aviso do mês com a folha pela metade (#557) dizia
  "pode ser a declaração do município ao SIOPE ou a carga" mesmo depois da
  recarga de 24/11/2026 (#564) ter mostrado que a planilha do SIOPE traz
  setembro e outubro de 2025 de Cuiabá assim. O auditor precisava escrever
  "o SIOPE publica assim", e a tela ainda deixava a dúvida.

## Decisões

- **O que o registro prova:** a folha e o registro da carga trocam na
  mesma transação (#564). Com a carga registrada, os dados são os da
  planilha baixada naquela data, e um mês incompleto já veio assim.
- **A1, sem ir além:** "a falta está na fonte, e não na carga". Não diz se
  foi a declaração do município ou o processamento do SIOPE.
- **B1, os três lugares:** o aviso do painel (com a data), a cobertura
  ("incompletos já na planilha do SIOPE") e o dicionário de
  `meses_folha_incompletos`. Sem registro, o texto de antes.
- **`cargas_folha`:** a leitura do registro passou para uma função só,
  usada pela cobertura e pelo painel (`carga_folha`).

## Validação

- **Docker local:** o painel da EMEB Zeferino (Cuiabá 2025) com "A planilha
  do SIOPE baixada em 24/11/2026 traz estes meses assim"; `/fontes` com "já
  na planilha do SIOPE" em Cuiabá e Taubaté.
- **Testes:** Perl, 211 arquivos; vitest, 1.452. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`; lá, as cargas ficam
  sem registro até a próxima recarga, e o aviso mantém o texto de antes.
- QH-01 e QH-02 da P5 entregues.
