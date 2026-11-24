# Nota técnica 264: os meses da folha por escola e da Secretaria (#558)

Achado QT-02 da terceira avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-24-p2-folha-fundeb-cuiaba.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #560 (merge `820fec0`).

## O problema

- **QT-02 (incomoda).** A cobertura da folha dizia "2026: 6 meses, 168
  escolas" em Cuiabá. Contava qualquer mês com algum valor numa escola.
- De março em diante, o município declarou quase tudo no código da
  Secretaria (99999999): R$ 295,9 mi de R$ 354,2 mi. Em março, R$ 0,3 mi
  nas escolas e R$ 54,6 mi na Secretaria.
- Na base, 134 escolas tinham `meses_folha` = 2: a frase da cobertura, sozinha,
  enganava.

## Decisões

- **B1, pela maior parte do valor:** cada mês é da escola ou da Secretaria
  conforme onde está a maior parte do valor declarado. Fevereiro de 2026
  continua por escola (R$ 31,8 mi contra R$ 19,1 mi). Pelo número de
  registros, Cuiabá daria o mesmo.
- **`meses` conta só os meses por escola:** a cobertura ganhou
  `meses_escola` e `meses_secretaria`, e `meses` passou a ser o número de
  meses por escola (Cuiabá 2026: de 6 para 2). Ano sem nenhuma escola
  (Taubaté) continua com os meses da Secretaria. O ano padrão da base
  (`siope_padrao_uf`) segue esse número; em MT continua 2025.
- **O texto:** "2026 (por escola só em janeiro e fevereiro; de março a
  agosto, só o total da Secretaria; junho incompleto; 168 escolas)". Uma
  função só (`textoAnoFolha`) para a tela da base e `/fontes`; sequências de
  3 ou mais meses viram intervalo.
- **A1, o painel da escola:** um aviso diz os meses em que a folha da
  escola não aparece porque o município declarou só o total da Secretaria.
  No painel da própria Secretaria, não aparece.

## Validação

- **Docker local:** o painel da EMEB Zeferino (Cuiabá) em 2026 com o aviso
  acima dos gráficos que param em fevereiro; `/fontes` com Cuiabá 2026 por
  escola só em janeiro e fevereiro, e os outros municípios iguais.
- **Testes:** Perl, 209 arquivos (mês dividido com a maior parte na escola,
  mês com um centavo na escola, a cobertura e o painel); vitest, 1.435. CI do
  PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- QT-01 e QT-02 da P2 resolvidos. Segue a conferência, no SIOPE, de
  setembro e outubro de 2025 em Cuiabá (download com permissão).
