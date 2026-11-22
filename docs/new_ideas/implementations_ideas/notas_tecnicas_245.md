# Nota técnica 245: a soma das conveniadas como teto e o código R completo (#520)

Achados QV-01 e QV-02 da trigésima terceira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-oferta-conveniadas.md`).
Um PR: #521 (merge `53e811e`).

## O problema

- Com o bloco "Parceria com o poder público" (#519), a P4 refez pela base a
  oferta pública de creche dos 645 municípios de SP. Os números batem com
  o banco; a conta tropeça em dois pontos de texto.
- **QV-01 (detalhe).** O Censo marca a **escola** conveniada, não a
  **vaga**: uma conveniada pode ter alunos pagantes. A ajuda falava em
  matrículas "custeadas pelas prefeituras", e a nota da comparação de redes
  mandava somar "para a oferta pública". Em SP, 155 conveniadas da
  categoria Particular têm 9.844 matrículas em creche (2,4% das
  conveniadas), o caso mais provável de mistura.
- **QV-02 (detalhe).** A ajuda parava no `subset` das conveniadas. O
  `merge` padrão do R, o passo seguinte natural, fica só com os municípios
  que têm conveniadas: 271 dos 645 em SP.

## Decisões

- **Teto dito nos três lugares:**
  - dicionário de `parceria_poder_publico`: "não a vaga", "o máximo da
    oferta conveniada (um teto)" e a categoria Particular;
  - nota da comparação de redes: "Somadas às da rede municipal, dão o
    máximo da oferta pública: o Censo marca a escola conveniada, não a
    vaga.";
  - ajudas da base e da comparação de redes, sem "custeia".
- **Código R numa seção própria da ajuda** ("Oferta de creche com as
  conveniadas no R"), com a soma por município, o `merge` com
  `all.x = TRUE`, o vazio trocado por 0 e a creche por mil habitantes.
  Fora da lista porque o python-markdown do site de ajuda não mostra bloco
  de código cercado dentro de lista aninhada.
- **Sem migração:** os comentários da MV já diziam "matrículas nas escolas
  conveniadas".
- **Ponto de cuidado:** uma descrição do dicionário não leva `;`. O CSV
  real cita o campo, mas o leitor simples dos testes o parte, e o teste
  pegou isso.

## Validação

- **Código R da ajuda,** extraído da página e rodado sobre a base de SP do
  backend local: 645 municípios e Franca com 21,2 por mil habitantes.
- **Docker local:** nota de Franca com o texto novo; validação visual do
  developer.
- **Testes:**
  - Perl: `base_analise.t` (o dicionário diz o teto e não diz "custeia");
    202 arquivos e 1.775 testes;
  - vitest: 1.376 testes;
  - CI do PR verde (Perl, vitest, build).

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev` (sem change nova).
