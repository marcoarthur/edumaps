# Nota técnica 285: a folha que não se compara ao ano anterior (#604)

Um PR: #608. Achado QD-02 da sétima avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-26-p2-custo-do-piso.md`).

## O problema

- Cuiabá tem 6 abaixo do piso em 2025 e 1.559 em 2026. A rede não mudou
  tanto: o município passou a declarar ao SIOPE, no total da Secretaria, a
  maior parte do magistério (os pagos só ali foram de 60 para 3.141; o
  magistério declarado, de 3.485 para 6.578). A tela mostrava os dois anos
  como comparáveis, e "de 6 para 1.559" é a leitura errada que ela induzia.

## Decisões (developer: as recomendadas do plano)

- **Critério pelo volume, não pela contagem do piso:** não se compara
  quando o magistério declarado cresce 50% ou mais, ou cai um terço ou mais,
  ou a parte dos pagos só no total da Secretaria muda 20 pontos ou mais. A
  mudança na contagem abaixo do piso pode ser real e não entra no critério.
- **Ano em curso:** a queda só conta com o ano tão completo quanto o
  anterior (meses, sem dezembro): um ano pela metade tem menos gente.
- **Sem migração:** o volume sai de `analytics.mv_salario_rede_md` (soma das
  pessoas, as sem escola e o máximo de meses), numa CTE própria, sem o join
  do piso (vale para todo ano). A comparação é feita no Perl, entre as
  chaves `cod6|ano` e `cod6|ano-1` que `salario_rede` já devolve; por isso
  aparece em todos os que a usam (painel, lista, base, CSV).
- **Limiares em variáveis do pacote** (`$QUEBRA_RAZAO`, `$QUEBRA_PONTOS`) e
  ditos na ajuda: só há 4 municípios com folha no banco local, e o critério
  não foi calibrado em dado real.
- **Texto neutro:** diz o que mudou e "pode ser uma mudança na forma de o
  município declarar ao SIOPE, e não na rede"; não afirma a causa. Traz a
  contagem abaixo do piso do ano anterior, para o número não ser lido solto.
- **Onde:** os dois painéis (o da escola também mostra a rede), a lista do
  ano, a base de análise e a coluna `comparavel_ano_anterior` da folha por
  município (sim, não, vazio sem o ano anterior).

## Testes

- `t/04-api/folha_quebra_ano.t` (novo, INEP `60060401`): três anos de um
  município fictício e cada limiar.
- Vitest: o texto (`utils.test.js`), os dois painéis, a lista e a base.

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
