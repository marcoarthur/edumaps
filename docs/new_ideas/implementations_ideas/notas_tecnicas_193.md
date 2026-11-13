# Nota técnica 193: visão da rede

PRs #399 a #403 (2026-11-12 a 2026-11-13). Fecham a #394 a #398 e a história
#375 (épico #368). Spec em `docs/specs/2026-11-12-visao-da-rede.md`.
Continua as notas 190 a 192 (planos de gestão acompanháveis).

## O que foi construído

| PR | Issue | Entrega |
|---|---|---|
| #399 | #394 | Papel `rede`: conta por convite, vínculo concedido pelo admin, autorização por pedido |
| #400 | #395 | Custo executado na ação; cargo de quem emite o relatório |
| #401 | #396 | Painel da rede; relatório da escola pela rede, só leitura |
| #402 | #397 | Metas comparáveis por indicador oficial; sugestão de indicador na meta manual |
| #403 | #398 | Custo por fonte na rede, previsto × executado, consolidado e por escola |

## Decisões de design

### Conta de rede

- **A conta de rede é uma linha de `clean.gestores`.** Ela tem
  `access_role = 'rede'`, o código de escola reservado `0` e senha nula até o
  convite ser usado.
  - O login e a sessão são os do gestor: nenhum mecanismo novo de
    autenticação.
  - A separação está nos guardas:
    - `gestor#_require_sessao` (qualquer sessão: `me`, `logout`);
    - `_require_gestor` (recusa a rede);
    - `pesquisa#_require_gestor_escola`;
    - `gestor#_require_rede`.
- **O convite é um token de 32 bytes em base64url.**
  - Só o sha256 dele é guardado.
  - Vale uma vez, por 7 dias, e um convite novo invalida o anterior.
  - Ninguém além da pessoa conhece a senha: o admin copia o link, não uma
    senha.
- **Escola da rede = linha mais recente do Censo** com a dependência e o
  município de um vínculo ativo.
  - É conferida **a cada pedido** (`_escola_ok` → 403): revogar o vínculo
    corta o acesso na hora.
  - A escola municipalizada muda de rede com o Censo seguinte.
  - Índice novo em `censo_escolas (co_municipio)`.
- **Tabelas internas:** `rede_vinculos`, `rede_convites` e `rede_auditoria`
  ficam sem GRANT ao `edumaps_leitor`. Elas entram na lista de sensíveis do
  `leitor_grants.t`.

### Painel e metas comparáveis

- **O painel é calculado em lote.** O role `Gestor::RedePlanos` faz 4
  consultas por rede (planos, metas com a última medição, contagem de ações,
  evidências), e não uma por plano.
  - O andamento reaproveita `progresso_meta` e `_pl_agregar`, os mesmos do
    detalhe do plano.
  - Medido: 304 escolas em ~0,12 s no teste de carga do `painel.t`.
- **A rede só lê.** `plano_detalhe`/`plano_relatorio` ganharam
  `somente_leitura`, que pula a sincronização das medições oficiais. A rede
  não grava nada no plano da escola.
  - Custo: o valor oficial novo só entra quando a escola abre o plano
    (P2-RD-03).
- **Metas comparáveis:**
  - entram só as metas ligadas a indicador do catálogo, do plano vigente mais
    recente;
  - o andamento médio usa só as medidas (sem medida = null, nunca 0);
  - a base ajustada pela escola (`base_ajustada`, nota 192) é contada e
    marcada;
  - as metas manuais vão para uma contagem à parte.

### Custos

- **Uma função de custos só.** A soma por fonte do relatório da escola virou
  `_pl_custos(@acoes)`, função pura no `Planos.pm`, e a rede chama a mesma.
  - O `custos.t` compara o bloco de custos de uma escola no `/api/rede/custos`
    com o do relatório dela: a igualdade é um teste, não uma convenção.
- **Regras da soma:**
  - as canceladas ficam fora;
  - a fonte sem nenhum valor de um lado fica `null` (no previsto ou no
    executado);
  - ação sem valor conta em `n_acoes_sem_custo` e `n_acoes_sem_executado`,
    nunca como R$ 0.
- **Por escola**, o plano vigente que o painel mostra (o mais recente). O
  consolidado soma só esses planos. Os encerrados das escolas da rede vêm em
  `encerrados`, com o número de planos e de escolas. Rascunho não entra.

### Na escola

- **Cargo do emissor (#395):** o relatório recebe o id da sessão e mostra só
  o cargo do cadastro. Sem cargo, nada. Nenhum nome de pessoa a mais.
- **Sugestão de indicador (#397):** `sugerirIndicador` (frontend, por palavras
  da descrição) oferece o indicador oficial quando a meta manual lembra um
  deles. A meta passa a contar na comparação da rede.

## Frontend

- **Rotas novas:**
  - `/rede` (painel e custos);
  - `/rede/indicadores`;
  - `/rede/escolas/:inep/planos/:id/relatorio`, que reaproveita
    `PlanoRelatorio`;
  - `/rede/convite/:token` (pública, sem menu);
  - `/config/rede` (admin).
- **Menu:** o papel guardado no login é só uma dica de interface para mostrar
  "Rede". A autorização é sempre do servidor.
- **Seção de custos:** `RedeCustos.svelte` carrega à parte do painel. Uma
  falha nos custos não derruba o painel.

## Testes

- **Backend:**
  - `t/04-api/rede/acesso.t` (14 subtestes);
  - `painel.t` (11, com carga de 300 escolas);
  - `indicadores.t`;
  - `custos.t` (17 asserções);
  - mais as asserções de executado e cargo no `planos_relatorio.t`.
- **Frontend:** testes de tela para o painel (filtros, ordenação, custos), as
  metas comparáveis, o relatório pela rede, o convite e as contas de rede do
  admin.

## Avaliação e o que ficou

- **Avaliação das personas** em
  `docs/personas/publicos/avaliacoes/2026-11-13-visao-da-rede.md`; o
  fechamento por público, em `docs/personas/publicos/ciclos/2026-11-13-visao-da-rede.md`.
  - P2 passou a "adotaria, em piloto numa rede".
  - P1 mantém "adotaria".
- **Achados que viraram issue:**
  - P2-RD-01: custo por exercício (#404);
  - P2-RD-02: documento consolidado da rede (#405);
  - P2-RD-03: sincronização das medições oficiais em lote (#406);
  - P1-RD-01: aviso na tela do plano de que a secretaria o lê (#407,
    entregue no PR #408: aviso no plano e no relatório, fora da impressão, e
    dica de cargo no campo responsável).
- **P2-RD-04 (vínculo por regional):** só com uma rede estadual real.
- **Deploy LXC pendente**, com as changes desde o último deploy:
  - `planos_gestao`, `planos_indicadores`, `planos_alertas`,
    `planos_evidencias`, `planos_base_oficial`, `rede_acesso` e
    `planos_custo_executado`;
  - mais as do ANTT;
  - o backend, o minion e o frontend.
