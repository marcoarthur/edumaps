# Nota técnica 288: a folha e o Fundeb (#611)

Um PR: #613. Achado QE-02 da oitava avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-27-p2-conselho-fundeb.md`).
Fecha a rodada: os dois achados estão entregues (QE-01 na nota 287).

## O problema

- O conselho do Fundeb pergunta quanto da receita do Fundeb foi para a
  remuneração; o prefeito, se a adequação ao piso cabe. O painel dividia a
  folha por fonte, mas a receita do Fundeb não estava na plataforma: a
  resposta não saía nem com planilha.

## A fonte da receita (levantamento)

- **SICONFI, DCA, Anexo I-C** (Tesouro): receita bruta realizada do Fundeb
  (1.7.5.1) e da complementação da União (1.7.1.5), anual; o loader já
  existia (#193, `--arg dca`), mas a tabela estava vazia. O DCA de um ano
  sai até 30/4 do seguinte. Escolhida.
- API de transferências constitucionais do Tesouro (mensal, com o ano
  corrente): respondia "Serviço não encontrado" em 2026-11-27.
- Dados abertos do SIOPE no FNDE (receitas e o indicador dos 70% como o
  município declara): HTTP 500 no mesmo dia. Ficam para quando voltarem.

## Decisões (developer: as recomendadas do plano)

- **Ano com DCA:** parte da receita paga pela parcela de 70% (a remuneração
  declarada ao SIOPE) e a parte com a adequação ao piso (#605, em 13
  salários) somada.
- **Ano sem DCA:** diz que a receita não saiu e mede a adequação contra a
  receita do último ano publicado, com o ano dito.
- Só no painel da rede (a escola sem folha própria); objeto `fundeb` na
  resposta. O snapshot mais recente de cada conta vale.
- Avisos: folha com menos de 12 meses; não é a verificação legal (despesa
  liquidada, base sem toda a complementação, como a VAAR); fonte e data.
- A receita entra no catálogo de `/fontes` (`siconfi_fundeb`).
- Junto: a nota da folha completa no painel da rede ainda dizia que a lista
  só tinha a Secretaria (resto da #610); corrigida.

## Resultado

- Cuiabá 2025: R$ 457,2 mi pagos pela parcela de 70%, 77,8% da receita de
  R$ 588,0 mi; a adequação de 2025 (R$ 29,8 mil) não muda a parte.
- Cuiabá 2026: a adequação (~R$ 13,4 mi) equivale a 2,3% da receita de 2025.
- Carga local do DCA de MT: 138 municípios em 2025, 139 em 2024.

## Testes

- `t/04-api/school/finance_fundeb.t` (novo) e `fontes.t` (catálogo).
- Vitest: os textos do bloco e a nota corrigida.
- Uma falha de vitest em `ClusterGeotagPage` sob carga (com a suíte Perl em
  paralelo) passou sozinha; sem relação com a mudança.

## Pendente

- LXC: `deploy_backend_dev`, `deploy_frontend_dev` e a carga do SICONFI
  com `--arg dca` (roteiro).
- O DCA dos outros estados, a receita mensal do ano corrente e o indicador
  declarado ao SIOPE, quando as fontes voltarem.
