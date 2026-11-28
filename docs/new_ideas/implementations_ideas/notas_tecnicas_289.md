# Nota técnica 289: a porta do painel da rede e o ano no endereço (#614, #615)

Dois PRs: #616 (#614) e #617 (#615, empilhado sobre o #616 e retargetado
para o `main` antes do merge do pai). Achados QF-01 e QF-02 da nona
avaliação da P2 (`docs/personas/publicos/avaliacoes/2026-11-27-p2-porta-da-rede.md`).
Fecha a rodada: os dois achados estão entregues.

## O problema

- O painel da rede (total, partes, piso, a folha e o Fundeb) só abria pelo
  painel de uma escola municipal fora da folha do SIOPE: 4 das 171 em
  Cuiabá. O perfil da rede não tinha a parte financeira, e o painel de uma
  escola com folha própria citava o "painel da rede" sem link (QF-01).
- O ano escolhido não ia para o endereço, e o `ano` do endereço não era
  lido: o link mandado ao conselho abria no ano mais recente (QF-02).

## Decisões (developer: as recomendadas do plano)

- **Pelo município:** `GET /api/city/:codigo_ibge/finance` monta o mesmo
  painel da rede (o `financial_summary` aceita `codigo_ibge`, com o resumo
  do SIOPE do município no lugar do da escola), mais `/finance/anos` (leve,
  para o perfil) e `/payroll/rede`. Município sem folha → 404; ano sem
  folha → 400. Sem migração.
- **Página `/municipio/financeiro`:** o painel com o município no título e,
  no lugar de "não desta escola", como o município declarou no ano; o ano
  no endereço desde o começo.
- **As portas:** cartão no perfil da rede (só com folha carregada); link no
  painel de cada escola da rede municipal e no aviso do cartão por fonte; a
  escola sem folha própria mantém o painel inline e ganha o link.
- **#615:** o painel da escola lê e escreve o ano no endereço; ano sem
  folha abre o mais recente, com aviso; a folha do mês volta ao painel no
  ano da competência.

## Resultado

- Cuiabá 2025 pelo município: R$ 489.472.996,81, 10.557 pessoas, 77,8% do
  Fundeb, igual ao painel da rede pela escola; ~1,3 s.
- `?inep=51091194&ano=2025` abre 2025; `?ano=2019` abre 2026 com o aviso.

## Testes

- Perl: a rota pelo município em `finance_rede.t` e `finance_fundeb.t`
  (igual à da escola, 400/404, anos, folha do mês). Um IBGE de teste
  (6006109) caía no mesmo município pelos 6 dígitos; trocado por 6006129.
- Vitest: `MunicipioFinanceiroPage.test.js` (novo), os links do painel, do
  perfil (MSW do `/finance/anos`) e da folha; o ano no endereço do painel
  da escola.

## Pendente

- LXC: `deploy_backend_dev` e `deploy_frontend_dev` (roteiro).
