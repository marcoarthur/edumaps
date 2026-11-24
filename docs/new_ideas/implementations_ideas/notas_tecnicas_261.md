# Nota técnica 261: a folha por fonte de recurso (Fundeb) (#553)

Achado QS-01 da quarta avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-24-p5-cacs-fundeb-ubatuba.md`,
o conselheiro do CACS-Fundeb de Ubatuba). Issue aberta com a aprovação do
developer; plano aprovado com as opções A1 e B1. Um PR: #555 (merge
`e18813c`).

## O problema

- **QS-01 (atrapalha).** O SIOPE declara, em cada pagamento, a parte paga
  com a parcela de 70% do Fundeb, a de 30% e a de outras fontes. A
  plataforma carregava as três (`salario_fundeb_max`, `salario_fundeb_min`,
  `salario_outros`), mas nenhuma tela as mostrava.
- É a pergunta central do conselho do Fundeb: quanto da folha saiu do
  Fundeb.

## Decisões

- **Sem carga nova nem change:** nos cinco município-ano carregados, as três
  partes somam exatamente o salário total. Basta agregar.
- **A1, painel e base:**
  - o resumo financeiro (`/api/school/:inep/finance`) ganhou `por_fonte`
    (`fundeb_70`, `fundeb_30`, `outras`, `total`, `nao_informado`), do mesmo
    recorte do painel: a escola ou o total da Secretaria;
  - o cartão "Por fonte de recurso" mostra o valor e o percentual de cada
    parte;
  - o bloco Remuneração da base ganhou `gasto_fundeb_70_ano`,
    `gasto_fundeb_30_ano` e `gasto_outras_fontes_ano`.
- **B1, em reais:** as três colunas somam o `gasto_pessoal_ano`, e a soma
  serve de conferência.
- **`nao_informado`:** se uma carga trouxer a fonte vazia, a sobra aparece
  como "Fonte não informada", e a soma continua fechando. Hoje é sempre 0.
- **O aviso, no cartão, no dicionário e nas ajudas:** não é a verificação do
  mínimo de 70% exigido em lei. Essa conta divide o gasto pela receita do
  Fundeb do município, que não está na plataforma (AN-12). O texto não
  afirma cumprimento nem descumprimento.
- **Reais inteiros na base (achado na validação):** com centavos, o
  formatador do CSV (`%.6g` para não inteiros) escrevia "1,13291e+06" e
  perdia precisão. As três partes passaram a ser arredondadas como o
  `gasto_pessoal_ano`: a soma fecha com até 2 reais de diferença (em
  Ubatuba, zero). Um teste barra a notação científica.

## Validação

- **Docker local:**
  - Secretaria de Taubaté, 2026: R$ 163,3 mi, 84,2% pela parcela de 70% e
    15,8% pela de 30%, com o cartão e o aviso na tela;
  - escola de Ubatuba (35070212): R$ 2,43 mi, tudo pela parcela de 70%;
  - base de Ubatuba: 47 escolas, as três partes somando o gasto em todas.
- **Testes:** Perl, 208 arquivos (Secretaria com a divisão, ausência sem
  ela, colunas da base, dicionário, sem notação científica); vitest, 1.420
  (o cartão, os percentuais, a Secretaria, `linhasPorFonte`). CI do PR
  verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #554 (a folha da Secretaria fora da soma da base) segue aberta.
