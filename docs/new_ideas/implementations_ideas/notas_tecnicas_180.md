# Nota técnica 180: análise de cidade lê o censo em `clean`

PR #355 (2026-11-08). Lote 4 da limpeza das falhas antigas (notas 177 a 179):
`t/05-tasks/city_analyticis.t`.

## Bug de produto: schema padrão `staging`

O job `city_analytics` usava `staging` quando ninguém informava o schema. O
`/summary` do serviço analítico lê `<schema>.censo_escolas`, e o censo fica em
`clean` (também o padrão do próprio `/summary`). Numa instalação nova o
`staging` não tem essa tabela, então o resumo da cidade pela rota
`POST /api/task/summary`, que não manda schema, sempre falhava. Agora o padrão é
`clean`; quem passar `schema` continua sendo atendido.

Num ambiente cujo `staging` guarde uma cópia antiga do `censo_escolas`, o
resumo sem schema passa a ler a fonte atual (`clean`), não a cópia.

## Sub-análises no motor HTTP

`score_distribution` e `school_clusters` não existem no `/summary`, que só
calcula o resumo completo. A rota da API já as recusava; o job, chamado
diretamente, executava e devolvia o resumo completo como se fosse a
sub-análise. No motor HTTP o job agora falha com a mesma mensagem da rota. O
motor legado (`R::Pipe`) não mudou.

## Teste

`city_analyticis.t` seguia o contrato do `R::Pipe` (`status => 'SUCCESS'`),
mas os três ambientes usam o motor HTTP. Agora:

- é pulado se `analytics_engine` não for `http`;
- confere `analysis = city_summary`, `metrics.total_escolas` igual à contagem
  do censo e `persisted`, além da linha em `analytics.city_school_analytics`;
- o caso sem schema confere que o resumo leu o censo em `clean`;
- as sub-análises falham com a mensagem certa.

Contra o código antigo, os subtestes de defaults e de sub-análises falham.

O teste desliga o cache compartilhado do cliente analítico: com ele, um resumo
já calculado volta do cache sem chamar o R, e a linha que o teste apaga não é
regravada. É o mesmo efeito em produção, só que inofensivo lá: a linha só some
se alguém a apagar.

## Resultado

Suíte local: 5 → 4 falhas, todas do grupo E (rede: `municipio.t`, `osm.t`,
`siope.t`; expectativas contraditórias: `network/schools.t`). No banco limpo do
CI o teste continua pulado (`skip_r`).
