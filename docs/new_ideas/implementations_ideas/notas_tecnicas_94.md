# Nota técnica 94 — De-para RENAEST declara o que é e não-resolvidas têm destino (#155)

**Data**: 2026-10-08
**Escopo**: fix — feature do loader `Transportes` (RENAVAM + RENAEST).
**Issues**: [#155](https://github.com/marcoarthur/edumaps/issues/155).
**PR**: [#194](https://github.com/marcoarthur/edumaps/pull/194) (merge commit `9477aa5`).
**Commits**: `eee403d` (data_pipeline), `29bc3e5` (backend), `b657743` (docs).

## Resumo

A issue #155 pedia, entre outras coisas, que as localidades RENAEST que não
resolvem para a malha IBGE deixassem de desaparecer em silêncio, e que a
declaração (`COMMENT`) da tabela `clean.renaest_localidade_municipio` parasse
de prometer algo que ela não é. O diagnóstico (sessão anterior) já tinha
mostrado que a premissa original da issue envelheceu: desde o commit `45709de`
(#169) o loader resolve pelo `codigo_ibge` que a própria fonte RENAEST publica
no ficheiro `Localidade`, apaga a semente `auto_seed` e grava proveniência.
Faltava o que a issue pedia nos entregáveis 3–5:

- **Destino explícito para não resolvidas** — nova tabela
  `clean.renaest_localidade_nao_resolvida`, alimentada pelo loader com o
  motivo (`codigo_fora_da_malha`, `codigo_sentinela`, `sem_nome_ou_uf`);
- **`validated_by`/`validated_at` coerentes** — os `COMMENT` passam a dizer que
  `validated_by` é `fonte_renaest` em todas as linhas, que `validated_at` é
  NULL e que `manual` nunca ocorreu;
- **`COMMENT` verdadeiro** — sai a mentira "Construído por fuzzy matching +
  validação humana".

O script `data_pipeline/scripts/fuzzy_match_renaest.py` (match por nome +
validação humana que nunca existiu) foi removido junto com o `README` e o
`requirements.txt` — decisão do developer, seguida sem implementar.

## Decisões de design

1. **Uma change Sqitch, não duas.** O "declarar o que é" (COMMENT) e o "dar
   destino ao que não resolve" (tabela nova) são as duas metades da mesma
   correção da #155; revert é atômico. Change `renaest_depara_declaracao`,
   append no fim do plano, `requires: renaest_localidade_municipio`.

2. **`verify` que morde.** O `SELECT 1 FROM …` (padrão dos verify antigos do
   repositório) **nunca falha** no Sqitch 1.6.1 — uma query que devolve `f`
   conta como sucesso. O verify da change usa `DO … RAISE EXCEPTION`, no
   modelo de `analytics_ausencia_visivel`, e foi provado que morde: plantada
   uma linha `codigo_fora_da_malha` com código existente na malha, o verify
   falha com a mensagem.

3. **Nada de semente de proveniência.** A primeira versão da change fazia um
   `INSERT` em `clean.import_metadata` para a tabela nova — isso quebrou o
   verify de `import_metadata_uniq_table_name`, que fixa a contagem em 31
   linhas ("a deduplicação não pode ter comido a tabela toda"). A proveniência
   da tabela derivada não existe antes de ela ser derivada: o loader a regista
   via `upsert_metadata` na primeira carga. Não se parte uma change alheia.

4. **Classificador puro.** `classificar_depara($localidade)` não toca na base:
   decide o que casa (exact/fuzzy pelo código validado contra a malha) e o que
   não casa (com motivo), e `ingerir_depara` só persiste. Foi o que permitiu o
   teste unitário com mocks puros (MockDBH/MockStorage/MockSchema), no estilo
   do resto de `transportes_loader.t`.

5. **Não-resolvidas idempotente por snapshot.** O insert das não-resolvidas
   substitui o conjunto do snapshot (`DELETE … WHERE dt_snapshot = ?` antes),
   senão uma re-corrida deixaria para trás uma localidade já resolvida. O
   de-para em si continua upsert por `(localidade, uf, dt_snapshot)`.

6. **Mapa ER acompanha a verdade.** O diagrama 07 afirmava (incorrectamente)
   `match_type "exact, fuzzy ou located"` e que o `codigo_ibge` do sinistro
   era "preenchido pelo de-para" — o código vem do ficheiro `Acidentes` da
   própria RENAEST; o de-para fornece `localidade`/`uf` e decide se a linha
   entra. Corrigido no 05/07 + README + `docs/funcionalidades/`, e a entidade
   nova entrou como bloco no 07. Validador ER: 6 checagens zeradas, SVGs
   re-renderizados.

## Medições (estado do dado)

- `clean.renaest_localidade_municipio`: 5570 linhas, `match_type` exact 5560 /
  fuzzy 10, `validated_by` = `fonte_renaest` em todas, `validated_at` NULL em
  todas (nenhuma validação humana já aconteceu).
- `clean.renaest_sinistro`: 30647 linhas / 564 localidades /
  2018-01-01..2026-04-30 / 1 snapshot; **0** sinistros sem `codigo_ibge`,
  **0** códigos fora da malha, **0** de-para órfão.
- A tabela nova é criada vazia; o loader a alimenta na próxima carga
  (`codigo_sentinela`/`sem_nome_ou_uf`/`codigo_fora_da_malha` — hoje só o
  último teria algo, e seria 0 no estado medido).

## Pendência registada (follow-up)

- **Queda de sinistros `sem_nome`**: em `agregar_acidentes`, um sinistro cujo
  `codigo_ibge` não está no índice de nomes do de-para é contado (`sem_nome`)
  e **não é persistido**. No estado medido são 0, mas o descarte continua
  silencioso além do log. Ficou registado na #155 como follow-up.

## Deploy e validação

- `prove -l t/05-tasks/transportes_loader.t` → PASS (12 testes) com
  `env -u PERL5LIB` (host `ubaxala`).
- CI do PR ("Perl contra o banco de fixtures") → pass (10m46s).
- `sqitch verify` da change nova: ok no Postgres local e no LXC
  `database.edumaps`; verify morde com linha plantada.
- Deploy: `rex prepare` + `deploy_db_dev` (database.edumaps) +
  `deploy_backend_dev`/`deploy_minion_dev` (backend.edumaps) — md5 do loader
  host = local; `edumaps-web`/`edumaps-minion` activos.
- Imagens locais `sqitch`, `backend`, `minion` reconstruídas (disco do Docker
  cheio a meio do build — `docker builder prune -af` liberou 7,5 GB; retomado
  com sucesso). Stack local serve o código novo.