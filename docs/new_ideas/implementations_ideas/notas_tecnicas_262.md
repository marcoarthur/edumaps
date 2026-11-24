# Nota técnica 262: o fechamento da folha na base de análise (#554)

Achado QS-02 da quarta avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-24-p5-cacs-fundeb-ubatuba.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #556 (merge `af9a75a`).

## O problema

- **QS-02 (incomoda).** A base tem uma linha por escola do Censo, e a soma
  delas não dá o total que o município declara ao SIOPE. Nada dizia a
  diferença: um conselheiro que soma a base acha milhões "sumidos".
- Em Ubatuba (2026), R$ 67,7 mi declarados e R$ 55,6 mi nas escolas.

## Decisões

- **As quatro somas que fecham:** `fechamento_folha` (`EduMaps::BaseAnalise`)
  dá, por município e ano da UF:
  - `total`, o declarado;
  - `escolas_base`, nas escolas do Censo em funcionamento (a lista da base);
  - `secretaria`, no código 99999999, sem escola;
  - `fora_total` e a lista `fora` (código, nome do SIOPE, valor): escolas
    que o SIOPE declara e a lista do Censo não tem.
- **No que a tela já recebe:** o fechamento entra em cada ano da cobertura
  da folha da UF (`folha.municipios[].anos[].fechamento`). Sem rota nova.
- **A1, tela e ajuda:** o bloco Remuneração diz por que a soma não é o total
  e fecha a conta por município do recorte (só o escolhido, com município).
  A planilha continua com uma linha por escola.
- **A escola fora da lista, com o código e o nome do SIOPE:** em Ubatuba, a
  35659605 "JOSE LIBORIO - SEU FRANCA EM" não existe em nenhum Censo
  carregado. Parece a "EM JOSE LIBORIO" da base (sem folha) com código
  novo, mas a plataforma não afirma: mostra os dois lados.
- **Cada escola arredondada antes de somar:** o total pode diferir do
  declarado em centavos a poucos reais (Ubatuba: R$ 67.696.410 contra
  R$ 67.696.408,85). A soma das partes sempre dá o total.
- **B1, o acento da rota do município:** `/api/city/:ibge/payroll/overall`
  devolvia "SÃ£o Paulo". O banco estava certo; o modelo já devolve o JSON
  em bytes UTF-8, e o `render(text => …)` codificava de novo. Passou a
  `render(data => …)`. Não precisou da função de mojibake da #536.

## Validação

- **Docker local:** a tela da base de Ubatuba com a conta fechada (escolas,
  Secretaria e a escola fora da lista); Taubaté com tudo na Secretaria; a
  rota do município com "São Paulo".
- **Testes:** Perl, 209 arquivos (o fechamento e a rota); vitest, 1.425
  (`fraseFechamento`, `reaisCurto`, a tela com a UF e com o município). CI
  do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- QS-01 e QS-02 da P5 resolvidos; segue aberto o AN-12 (sem a receita do
  Fundeb e sem comparação de gasto).
