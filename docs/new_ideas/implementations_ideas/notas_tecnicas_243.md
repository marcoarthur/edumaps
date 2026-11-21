# Nota técnica 243: matrículas na base e creche/pré na comparação de redes (#516)

Achados QX-01 e QX-02 da trigésima primeira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-oferta-municipios.md`).
Um PR: #517 (merge `f90fa5b`).

## O problema

- A P4 quis responder à primeira pergunta do perfil dela ("municípios de
  porte e região semelhantes têm oferta parecida?") com a educação infantil,
  nos 182 municípios de 10 a 20 mil habitantes da BA.
- **QX-01 (atrapalha).** A base de análise não trazia o número de
  matrículas, só as etapas oferecidas (0 ou 1) e proporções sobre as
  matrículas. Contar escolas que oferecem creche engana: correlação de
  postos de 0,36 com as matrículas; Mirante e São José do Jacuípe têm 3
  escolas com creche cada, e 106 e 329 matrículas.
- **QX-02 (detalhe).** A comparação de redes juntava creche e pré-escola
  (metas diferentes no PNE) e não tinha arquivo para baixar.

## Decisões

- **Bloco "Matrículas" na base** (`@MATRICULAS` em `EduMaps::BaseAnalise`):
  - 10 colunas de `clean.censo_matriculas`, pelo mesmo `nu_ano_censo` da
    escola: `mat_basica` (total), `mat_creche`, `mat_pre`, `mat_ai`,
    `mat_af`, `mat_medio`, `mat_profissional`, `mat_eja`, `mat_especial` e
    `mat_integral`;
  - `LEFT JOIN` só quando o bloco é pedido;
  - o dicionário diz que as etapas não somam o total (a profissional repete
    matrículas do médio; especial e integral atravessam as etapas) e que o
    vazio é escola sem linha de matrículas, enquanto 0 é 0.
- **Change `rede_escolas_creche_pre`** (nova, depois de
  `rede_escolas_ativas`; nenhuma change deployada foi editada):
  - recria `analytics.mv_rede_escolas` com `matriculas_creche`
    (`qt_mat_inf_cre`) e `matriculas_pre` (`qt_mat_inf_pre`);
  - `matriculas_infantil` fica, para quem já a usa;
  - o verify (`DO … RAISE`, por `pg_attribute`) falha se faltar uma das
    colunas ou se creche + pré não somarem a infantil.
- **Comparação de redes:**
  - os eixos de etapa trocam "Infantil" por "Creche" e "Pré-escola";
  - o link "Baixar as escolas deste município (base de análise)" abre a
    base com a UF, o município e os blocos `etapas,matriculas`. Exportar a
    própria comparação ficou de fora: a base já é o arquivo, com uma linha
    por escola.
- **Ajuda:** seção "Matrículas" na base, com o exemplo Mirante × São José do
  Jacuípe, a soma por município no R (`aggregate`) e a ressalva de que a
  taxa de atendimento pede a população por idade, que não está carregada.

## Validação

- **Sqitch no banco de fixtures:** deploy, verify, revert com
  `--to ranking_escola_empates` e redeploy.
- **Docker local:** Mirante 106 e São José do Jacuípe 329 matrículas em
  creche pela base; Salvador, rede municipal, 8.328 + 14.285 = 22.613 da
  infantil. Validação visual do developer.
- **Testes:**
  - Perl: `base_analise.t` (bloco e ordem dos blocos), `network/summary.t`
    (creche + pré = infantil); 202 arquivos e 1.773 testes;
  - vitest: 1.374 testes;
  - CI do PR verde (Perl, R, vitest, build).

## Pendências

- No LXC: `deploy_db_dev` (a change nova), `deploy_backend_dev` e
  `deploy_frontend_dev`.
- A taxa de atendimento fica fora até haver população por idade carregada.
