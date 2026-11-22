# Nota técnica 244: escolas conveniadas na base e na comparação de redes (#518)

Achado QW-01 da trigésima segunda avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-creche-conveniada.md`).
Um PR: #519 (merge `35673b8`).

## O problema

- Com o bloco Matrículas (#516), a P4 mediu a oferta de creche das
  prefeituras de SP e achou um buraco: a oferta feita por convênio fica na
  rede privada, junto das particulares.
- **QW-01 (atrapalha).** SP tem 404 mil matrículas em creche em privadas
  conveniadas com a prefeitura, contra 580 mil na rede municipal (41%).
  Franca tem 0 na rede municipal e 7.758 em 78 conveniadas com creche. Nos
  71 municípios de 100 a 500 mil habitantes, a correlação de postos entre
  as duas medidas é 0,51 e 25 municípios andam 20 posições ou mais.
- A base não trazia a parceria nem a categoria da escola privada, e a
  comparação de redes não separava as conveniadas.

## Decisões

- **Bloco "Parceria com o poder público" na base** (`parceria`, depois de
  `matriculas`), do mesmo Censo da escola:
  - `parceria_poder_publico` (0/1, `in_poder_publico_parceria`);
  - `parceria_esfera` (Municipal, Estadual, Estadual e municipal);
  - `categoria_privada` (Particular, Comunitária, Confessional,
    Filantrópica).
  - Não filtra a rede: escolas públicas também declaram parceria (841
    municipais), e o dicionário diz para filtrar a rede privada.
- **Change `rede_escolas_conveniadas`** (nova, depois de
  `rede_escolas_creche_pre`; nenhuma change deployada foi editada):
  - recria `analytics.mv_rede_escolas` com `escolas_conveniadas`,
    `matriculas_creche_conveniada` e `matriculas_pre_conveniada`;
  - conveniada = privada com parceria municipal ou estadual e municipal
    (`tp_poder_publico_parceria IN (1, 3)`), a definição de "oferta da
    prefeitura";
  - o verify (`DO … RAISE`, por `pg_attribute`) falha se faltar coluna, se
    uma rede pública tiver conveniadas ou se as conveniadas passarem dos
    totais.
- **Comparação de redes:** as conveniadas continuam na rede privada (é a
  dependência administrativa do Censo); uma nota âmbar diz quantas são e
  quantas matrículas de creche e pré-escola têm, para somar à municipal. O
  link da base passa a levar o bloco `parceria`.
- **Ajuda:** o exemplo de Franca na base (com o filtro no R) e a pergunta
  "Por que as conveniadas ficam na rede privada?" na comparação de redes. A
  tela conta 82 conveniadas (todas), a ajuda diz que 78 delas oferecem
  creche.

## Validação

- **Sqitch no banco de fixtures:** deploy, verify, revert com
  `--to rede_escolas_creche_pre` e redeploy.
- **Docker local:** Franca, rede privada, 82 conveniadas, 7.758 matrículas
  em creche e 3.577 em pré-escola; a base de SP soma 404.650 em creche nas
  conveniadas com a prefeitura. Validação visual do developer.
- **Testes:**
  - Perl: `base_analise.t` (bloco, ordem e valores), `network/summary.t`
    (públicas com 0, conveniadas dentro dos totais); 202 arquivos e 1.775
    testes;
  - vitest: 1.376 testes;
  - CI do PR verde (Perl, R, vitest, build).

## Pendências

- No LXC: `deploy_db_dev` (a change nova), `deploy_backend_dev` e
  `deploy_frontend_dev`.
