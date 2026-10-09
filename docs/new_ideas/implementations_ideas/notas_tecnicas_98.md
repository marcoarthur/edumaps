# Nota técnica 98 — `sqitch verify` como gate que falha de facto (#160)

## Resumo

O `sqitch verify` já existia e já corria, mas **nunca falhava**: os
`data_pipeline/verify/*.sql` eram `SELECT` que devolvem `f` (ou 0 linhas), e o
Sqitch 1.6.1 só considera a verificação falhada quando o script **produz erro**.
O gate era decorativo. Este ciclo torna-o um gate real e liga-o ao CI.

- **20 verifies corrigidos**: 15 "furos" (`SELECT … WHERE <condição>` que
  devolvia `f`) migrados para `DO $$ … RAISE EXCEPTION $$`; 3 verifies
  **vacuosos** (`censo_gestor`, `censo_escolar_2025`,
  `analytics_municipios_consolidado`) ganham uma asserção que pode falhar;
  `rede_escolas_etapas` deixa de rebentar sempre; `raw_countries` passa a ser
  estrutural.
- **Gate no CI**: `db/fixtures/ci_db.sh` ganha o subcomando `verify`; o workflow
  `backend-tests` roda-o **depois do `up`** e antes da suíte Perl.
- **Escopo = os 19 medidos** (mínimo honesto). `analytics_esforco_fiscal_fundeb`
  ficou de fora porque **já** usava `DO … RAISE`: era falso-positivo da medição.
- Entrega: 1 commit, branch `fix/data_pipeline-verify-gate` → **PR #198**
  (merge `2159892`).

## Decisões de design

- **Sqitch 1.6.1 só falha com erro do próprio script**. O `verify` roda o
  SQL e só olha para o exit status; `SELECT 1 FROM …` que devolve `f` (ou zero
  linhas) é sucesso. Logo a única forma honesta de "verificar" é **levantar**
  (`RAISE EXCEPTION`), não devolver um booleano. Padrão de referência:
  `verify/analytics_ausencia_visivel.sql`.
- **Gate no banco fresco, não no registry de produção**. Um banco recém-deployado
  tem as changes **em ordem de plano**; o registry de produção tem ~45 erros
  *out of order* porque a change `import_metadata_fase0` foi movida depois de já
  estar deployada. Isso é um facto histórico do registry, não do código, e não é
  corrigível sem mentir ao Sqitch. Correr o gate sobre um banco fresco contorna o
  problema e mede o que interessa: o `verify/*.sql` do working tree.
- **`rede_escolas_etapas`: a causa era `information_schema`**. O verify falhava
  sempre com `division by zero` porque usava `information_schema.columns`, que
  **não lista colunas de materialized views**. A correção usa
  `pg_attribute`/`pg_matviews`. Lição geral: para verificar matviews, nunca usar
  `information_schema`.
- **`raw_countries` verifica estrutura, não conteúdo**. O verify original
  consultava a *foreign table* (FDW sobre GeoJSON remoto via `/vsicurl`), o que
  tornava o verify dependente de rede e instável no container. Passou a
  verificar apenas a **estrutura** local (existência da foreign table/colunas),
  que é o que a migration garante.
- **Não tocar em changes deployadas**. O `change_id` é o SHA-1 dos metadados
  (`requires` + id do pai), logo editar `deploy/`/`revert/` de uma change já
  deployada — ou reordenar o plano — quebra a cadeia em todas as bases. Este
  ciclo só tocou em `verify/*.sql` + infra de CI; **nenhuma change foi
  adicionada, removida ou reordenada**.
- **Tirar os falsos-positivos da medição da issue**. A medição inicial incluía
  verifies que já mordiam; mantê-los no escopo seria trabalho inútil e ofuscaria
  o que realmente mudou. `analytics_esforco_fiscal_fundeb` foi o caso provado.

## Medições

- **Gate completo, banco fresco**: `db/fixtures/ci_db.sh down && up && verify` →
  **exit 0**, **97 changes**, **0 falhas**.
- **Os migrados mordem**: medição negativa (com a condição invertida o
  `RAISE` dispara) e **mutação** (`DROP … CASCADE` do objeto verificado →
  `ERROR`); restauro → ok.
- **O próprio gate apanhou 4 asserções erradas copiadas do original**:
  1. `geography`/`geometry` são `USER-DEFINED` — `data_type` não serve para
     PostGIS, usa-se `udt_name`;
  2. assinatura de função inclui **nomes** dos argumentos em
     `pg_get_function_identity_arguments`;
  3. nullability de `clean.antt_acidente_trecho`: só `id_acidente`,
     `concessionaria`, `data_acidente`, `trecho` são `NOT NULL`;
  4. (idem tipo PostGIS na coluna de geometria).
- **Docs**: `AGENTS.md` (secção `sqitch verify` reescrita) e
  `db/fixtures/README.md` (subcomando `verify`).

## Deploy

- **Não realizado nesta sessão** — decisão do developer (2026-10-09). Ficou
  pendente `rex prepare` + `deploy_db_dev` + rebuild da imagem local `sqitch`.
- Como o ciclo só tocou `verify/` + infra de CI (nenhum schema nem loader), o
  merge em `main` já é o estado correto; o deploy só sincroniza os scripts de
  verificação para os hosts.
- **Nota operacional apanhada na preparação**: `deploy_db_dev` corre
  `ALTER ROLE edumaps_leitor … PASSWORD '$EDUMAPS_DB_PASS'` e o passo 7 usa
  `sqitch deploy db:pg://edumaps:$db_pass@…`. Sem `EDUMAPS_DB_PASS` no
  ambiente, o default (`change_me`) **quebraria a role leitora**; o login de
  teste `edumaps/senhaboa123` falhou, logo não havia credencial para correr a
  task em segurança. Motivo adicional para adiar o deploy.

## Incidentes e armadilhas de ferramenta

- **Harness, não repo**: o log do OpenCode registrou dois
  `AI.Error.InvalidRequest: Provider request failed with HTTP 400` (14:39 e
  16:06) — hiccup do provider do modelo **remoto** desta sessão. Sem efeito no
  merge (já tinha passado). O `~/.config/opencode/opencode.json` do ambiente
  usava `defaultProvider`/`defaultModel` (não existem no V2 → ignorados; a
  seleção é o campo `model`) e o provider `ollama` com `api`/`maxTokens` em vez
  de `settings.baseURL`/`limit`. A config foi **revertida ao original** a pedido
  do developer (manter o modelo remoto; Ollama local não é usado).
- **Revert defeituoso = falso "jamais morde"**: três verifies pareciam
  não-mordedores só porque os reverts que deviam criar a situação negativa não o
  faziam — `revert/censo_gestor.sql` dropa `gestor_escolar` e
  `revert/raw_populacao.sql` é no-op. A prova por mutação direta (`DROP …
  CASCADE`) é a única fiável; medir por revert mente.
- **Fora de escopo (follow-up)**: corrigir esses dois reverts defeituosos e
  decidir sobre os **~14 verifies restantes** que ainda usam o padrão
  `SELECT` não-mordedor.

## Pendências

- Deploy do #160 (ver acima) — quando o developer decidir.
- Follow-ups de revert (`censo_gestor`, `raw_populacao`) e os ~14 verifies.
- `sqitch verify` global no registry de produção continuará com os ~45
  *out of order* — facto histórico, documentado no `AGENTS.md`, não corrigível
  sem reverter a reordenação do `import_metadata_fase0`.
- Backlog aberto segue: #136 (git hooks), #167 (CGU), #168 (ANTT), #170 (loader
  MapBiomas, bloqueada por e-SIC).
