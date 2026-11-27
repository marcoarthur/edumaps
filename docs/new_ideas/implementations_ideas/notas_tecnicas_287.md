# Nota técnica 287: o painel da rede com toda a folha (#610)

Um PR: #612. Achado QE-01 da oitava avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-27-p2-conselho-fundeb.md`).

## O problema

- Escola municipal sem folha própria no SIOPE abria o painel da rede, que
  somava só o código da Secretaria (sem escola) e dizia "os números abaixo
  são o total da rede". Cuiabá 2025: R$ 17,1 mi no painel contra R$ 489,5
  mi declarados por escola; 2026: R$ 295,9 mi contra R$ 354,2 mi.
- O texto do motivo dizia que o SIOPE não detalha a folha por escola no
  município, mesmo em anos em que detalha.

## Decisões (developer: as recomendadas do plano)

- **A rede é o município inteiro:** escolas, total da Secretaria e escolas
  fora da lista do Censo, pelo código do município; outras redes seguem
  fora (#422). O total é o mesmo da folha por município da base.
- **As partes ditas à parte:** escolas da lista do Censo (em funcionamento
  no ano mais recente), Secretaria e fora da lista; o gráfico de custo
  mensal ganha a linha da Secretaria.
- **O motivo conforme o ano:** por escola em todos os meses, misto (quais
  meses em cada lugar) ou só na Secretaria, contado pelos meses declarados.
- **A folha do mês da rede:** rota nova `/payroll/rede`, com o lugar de
  cada registro (coluna "Onde") e filtro escolas/Secretaria; a marca do
  piso usa a mesma regra (`piso_pessoas` aceita escola nula).
- **Desempenho:** pessoas contadas agrupando por pessoa antes de contar
  (cerca de 3× mais rápido que `COUNT(DISTINCT (cpf, nome))`); partes por
  CTE com `EXISTS` no Censo. Painel da rede em ~1,2 s, somando a rede
  inteira (antes 0,6–1,7 s só com a Secretaria).
- Sem migração; nada com CPF ou nome vai para `analytics`.

## Resultado

- Cuiabá 2025: R$ 489.472.996,81, declarado por escola (167 escolas).
- Cuiabá 2026: R$ 354.211.028,41 (R$ 58,3 mi nas escolas, R$ 295,9 mi na
  Secretaria, R$ 28 mil fora da lista); jan–fev por escola, mar–ago só na
  Secretaria.
- Folha de fev/2026 da rede: 12.202 registros (5.726 escolas, 6.476
  Secretaria).

## Testes

- `t/04-api/school/finance_rede.t` (novo): série, partes, caso do ano,
  escola com folha própria inalterada, folha da rede (404 e 400).
  `finance_secretaria.t` e o subteste da #422 em `finance_ausencia.t`
  passam à regra nova.
- Vitest: os textos do motivo, a frase das partes, o link da folha da rede,
  a coluna "Onde" e o filtro.

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
- #611 (a folha cabe no Fundeb?), que começa por levantar a fonte da
  receita do Fundeb por município.
