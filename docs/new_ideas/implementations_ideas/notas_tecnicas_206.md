# Nota técnica 206: versão dos dados no CSV do agrupamento (#438)

Achado RV-03 da reavaliação P4/P6
(`docs/personas/publicos/avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`).
Um PR: #441 (merge `8ce6730`).

## O problema

Desde a #428, cada execução do agrupamento guarda a versão dos dados em
`parametros.dados` (ano e carga do Censo e do IDEB), e a caixa **Universo**
a mostra. O CSV (`/api/cluster/execucoes/:run_id/csv`, #427) não a trazia:
guardado, o arquivo só tinha o `run_id` no nome, e a execução vence em 90
dias. A pesquisadora (P4) perdia a referência da base.

## A mudança (só no backend, `Controller/Cluster.pm`)

- **Colunas `ano_censo` e `ano_ideb` no fim de cada linha**, com o mesmo valor
  em todas. No fim, e não perto do INEP, para não mudar a posição das
  colunas que já existiam (quem lê por índice segue lendo certo).
- **Nome do arquivo com a versão:**
  `agrupamento-censo2025-ideb2023-<run_id>.csv`. Ano ausente sai do nome; sem
  nenhum, o nome é o de antes.
- **Execução antiga, sem `dados`:** mesmas colunas, vazias. O formato do
  arquivo não depende da idade da execução.
- Só ano de **4 dígitos** entra (`/^\d{4}$/`): um valor inesperado no jsonb
  não chega ao `Content-Disposition`.
- **Sem linha de comentário** no topo (`# versão …`): quebraria `read.csv`,
  pandas e o Excel. A data de carga fica só na caixa Universo; no arquivo o
  ano basta para citar a fonte.
- O frontend não muda: o link "Baixar CSV" usa `download` sem valor, e o
  navegador grava com o nome do `Content-Disposition` (mesma origem).

## Validação

- `t/04-api/cluster_execucoes.t`: cabeçalho, valores e nome com a versão, e
  um subteste com execução sem `dados`. Contra o código antigo: 2 de 6
  subtestes falham. Suíte Perl `-j4`: 192 arquivos, 1701 testes; CI verde.
- Stack local com as imagens reconstruídas (md5 e ID das imagens
  conferidos): execução antiga → nome antigo e colunas vazias; execução nova
  (desempenho, ES, IDEB 2023) → `agrupamento-censo2025-ideb2023-run_….csv`,
  1172 escolas, todas com `2025;2023`.

## Deploy

Só backend: entra no LXC com o roteiro `docs/admin/deploy-lxc-2026-11-16.md`
(passo do agrupamento).
