# Nota técnica 274: o Fundeb da folha inteira e a folha por município (#579, #580)

Achados QG-01 e QG-02 da quarta avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-24-p6-comparar-prefeituras.md`,
comparar a folha das prefeituras). Primeiro ciclo do **modo autônomo**
autorizado pelo developer em 2026-11-24, 18:50 ("execute de modo autonomo
até as 9h do proximo dia"; downloads liberados às 18:58; só ações
destrutivas bloqueiam): avaliação, issues, opções do plano e merges
decididos sem aprovação no chat, com CI verde e validação local antes de
cada merge. Dois PRs: #581 (merge `3742e36`) e #582 (merge `03e4ca0`).

## O problema

- **QG-01 (atrapalha).** A divisão por fonte (#553) existia por escola e,
  no painel, só quando a folha era toda da Secretaria. Onde há escolas e
  Secretaria, a folha inteira do município não tinha o percentual do
  Fundeb em lugar nenhum (Ubatuba: R$ 11,8 mi da Secretaria fora de
  qualquer divisão).
- **QG-02 (incomoda).** Os números da folha por município (fechamento,
  fontes, salário e piso da rede, carga) só existiam em frases na tela, uma
  UF por vez; o CSV da base é por escola.

## Decisões

- **#579, no fechamento:** `fechamento_folha` (#554) ganhou `por_fonte` da
  folha inteira (escolas, Secretaria e fora da lista). A frase do
  fechamento diz os percentuais e a parte sem fonte informada, quando
  houver. Ubatuba 2026: 94,5% pela parcela de 70%, 0,3% pela de 30%, 5,2%
  outras.
- **#580, um arquivo por UF:** `folha-municipios.csv?uf=` (26 colunas,
  uma linha por município e ano) e o dicionário próprio, montados com as
  mesmas funções da tela (`cobertura_siope`, `fechamento_folha`,
  `salario_rede`, o registro da carga). A #554 tinha escolhido não ter um
  arquivo por município quando havia um número só; agora são 26 colunas.
- **Os avisos vão para o dicionário:** o Fundeb não é a verificação do
  mínimo legal; o piso não é a verificação legal; a Secretaria pode ter
  pagamentos parciais; a carga fora de horas deixa o piso vazio.

## Um alarme do CI

- O backend-tests do merge do #581 falhou em `t/04-api/rede/acesso.t`
  (contas da rede: a listagem do admin não voltou 200). O arquivo passou 3
  vezes no local, o mesmo teste tinha passado no push anterior, e a nova
  rodada do job deu verde. Instabilidade de concorrência com `-j4`, sem
  relação com a mudança; o #582 só foi mergeado depois da nova rodada.

## Validação

- **Docker local:** a frase do fechamento de Ubatuba com a fonte; o CSV
  real de SP, MT e RO (cinco município-ano, com data e SHA-256 da carga de
  24/11/2026); o link e o dicionário na tela da base de MT.
- **Testes:** Perl, 211 arquivos; vitest, 1.455. CI dos dois PRs verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- `rede/acesso.t` instável sob `-j4`: observar; abrir issue se repetir.
