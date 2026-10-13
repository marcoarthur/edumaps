# Ingestão real das fontes das Fases 0–6: plano (#156)

**Issue:** #156 · **Data:** 2026-10-13 · **Status:** plano, à espera das decisões
do developer.
**Medição:** levantamento somente-leitura de 2026-10-13, no banco do
**produto** (`database.edumaps`/`edumaps_dev`), a partir do `backend.edumaps`.

## 1. A #156 está desatualizada

- **Os números de origem vieram da base errada.** O "4/28 com dado" foi medido
  em `127.0.0.1`/`database.dev`, não no produto.
- **Cargas reais feitas depois se perderam.** BrazilCrime (61 mil linhas),
  RENAEST (30 mil), RENAVAM (5,5 mil) e o de-para real foram carregados **só
  no Docker local**. O `pg_restore` de 2026-10-08 apagou tudo, e os ZIPs não
  foram guardados. É o risco de sobrescrita que a própria #156 apontava,
  agora consumado.
- **Cinco loaders foram escritos depois da issue:** SICONFI, IBGE,
  BrazilCrime, Transportes e de-para. A premissa de "só falta rodar" não vale
  mais. Oito tabelas **não têm loader nenhum**: setores, Censo 2022 por
  setor, CNES, SISAB, CGU, isócronas, VMDA e Recife.

**Estado no produto:** 7 entradas com linhas. Na prática, quase todas são
placeholders, views com indicador nulo ou só SP (SICONFI).

## 2. Achados críticos (transversais)

| # | Achado | Impacto |
|---|---|---|
| T1 | **`data_pipeline/allowlist.yaml` tem as chaves `sources:` e `denied:` duplicadas.** O YAML::XS fica com a última: 8 fontes somem e a lista `denied` fica **vazia** | As 5 regras de LGPD (MONITRIIP-viagens, Bilhete Único, SISVAN, vacinação, CNES bruto) estão **inertes**. A task SIOPE provavelmente é rejeitada em produção. O teste passa porque usa YAML sintético. **Nenhum job de `Ingestion/` consulta o allowlist** |
| T2 | **A CLI não repassa argumentos ao job** (`CLI.pm:60`) | SICONFI só carrega SP, sem DCA e sem escolha de exercício; IBGE sem escolha de anos |
| T3 | **`upsert_metadata` só roda em caso de sucesso, com `UNIQUE(table_name)`** | Não há como registrar "não carregou, porquê" (entregável 4), e uma falha apagaria a proveniência da última carga boa |
| T4 | **Não existe política de preservação de `raw`** (ZIPs e CSVs) fora do banco | O restore de 08/10 apagou cargas sem volta; liga com a #135 (DVC) |
| T5 | **Defaults apontam para o banco errado** (`ubatexu.lan` → `database.dev`) | Medições e cargas podem ir parar fora do produto |
| T6 | **e-SICs talvez não protocolados** (`docs/admin/esic-requests.md` com protocolo e data em branco; #132 fechada como "protocolados") | INEP, Medidor, FNDE e Secretarias seguem bloqueados sem prova de pedido |

## 3. Reclassificação das fontes

**A — Carregável já** (operação + patch na CLI):
- SICONFI em malha nacional (`siconfi_receita`, `siconfi_despesa`, FUNDEB):
  1 req/s, horas por exercício (não medido). Corrigir o `row_count` e a
  metadata sobrescrita.
- BrazilCrime no produto: corrigir o dry-run, que sempre falha, e a licença
  sobrescrita pelo job.
- Transportes (RENAEST 522 MB / 2,7 GB descompactado; RENAVAM) no produto,
  com os ZIPs preservados. Substitui o de-para `auto_seed`.
- IBGE `ibge_agregados`: cerca de 11 mil GETs ao SIDRA. Sobrescreve
  `clean.dados_ibge`; comparar antes. O host está fora do allowlist efetivo.

**B — Loader novo, sem bloqueio externo:**
- CGU `transferencia_educ` pelo **ZIP mensal oficial, sem chave** (re-escopa
  a #167).
- `malha_setor_censitario` (GPKG de 1,49 GB) e `censo2022_setor` (CSVs
  temáticos do IBGE). Os comments dizem "e-SIC do INEP", o que está errado.
- `sisab_aps` (API PMMB): filtrar DSEI e normalizar o código IBGE.
- `cnes_estabelecimentos` (API com PII → sanitizar). **Licença CC BY-ND 3.0**
  precisa de decisão.
- `mapbiomas_cobertura`: COG público de 763 MB sem token (re-escopa a #170).
  Exige `sf`, que falta no backend e no analytic.
- ANTT (4 tabelas): reescrever o job. **O host está fora do ar hoje**; a OD
  exige supressão (< 10) por LGPD.
- `isocrona_escolar`: infraestrutura nova (OSRM/Valhalla, PBF de 2,1 GB, H3
  ausente).

**C — Bloqueado por terceiros:** INEP, Medidor, FNDE e Secretarias (e-SIC);
ANTT (host fora); VMDA (só há camada do ES + ADR jurídico); Recife (ODbL
share-alike, decisão jurídica).

**D — Fora do objetivo, ou justificar:** INMET (já justificado, #171); VMDA e
Recife se o jurídico vetar; isócronas se a infraestrutura não for aprovada.

## 4. Fases propostas

| Fase | Conteúdo | Saída |
|---|---|---|
| **P0 — Pré-requisitos** | T1 allowlist (corrigir + teste sobre o arquivo **real** + jobs validando contra ele); T2 `--arg` na CLI; T3 metadata de falha sem perder a última carga boa; T4 preservação de `raw` (decisão); T5 defaults; corrigir comments e URLs mortas | Issues pequenas, cada uma com PR |
| **P1 — Carga do que existe (A)** | SICONFI malha, BrazilCrime, Transportes, IBGE no produto, com `raw` preservado e relatório antes/depois (`new_data_sources.Rmd`) | Entregáveis 1–3 da #156 para essas fontes |
| **P2 — Loaders novos baratos (B1)** | CGU ZIP, setores + Censo 2022, SISAB | Fecha a parte fiscal e a de território |
| **P3 — Loaders caros ou com decisão (B2)** | CNES (licença), MapBiomas (`sf`), ANTT (host), isócronas (infraestrutura) | Por decisão |
| **P4 — Fechamento** | Justificar o que ficou em C/D no `import_metadata`; #158 (materializar as views); relatório final | Critério "28/28 ou justificado" |

## 5. Decisões necessárias (developer)

1. Ordem e escopo: P0 primeiro? Allowlist como correção urgente separada?
2. e-SICs: protocolados ou não? (ação administrativa do developer)
3. Onde guardar o `raw` (T4), e se o DVC (#135) entra antes.
4. CNES (BY-ND), isócronas (infraestrutura nova) e o tamanho das cargas
   nacionais em dev (horas de API).

## 6. Decisões do developer (2026-10-13)

1. **Ordem:** **fix urgente do allowlist** (issue própria) → **P0** (pré-requisitos) → cargas.
2. **e-SICs:** não confirmados. Fica um checklist em
   `docs/admin/esic-requests.md` com o texto de cada pedido pronto, e o
   developer confirma ou protocola. Até lá, INEP, Medidor, FNDE e Secretarias
   ficam como **bloqueados**.
3. **`raw`:** **disco do backend + manifesto**. Diretório fixo fora do
   `pgdata` (`/srv/edumaps/raw/<fonte>/<data>/`); o manifesto (URL, sha256,
   tamanho, data) vai para o `import_metadata`. O DVC (#135) vem depois,
   apontando para o mesmo lugar.
4. **B2 no plano:** **CNES** (carregar sanitizado e agregado, registrando a
   licença CC BY-ND 3.0 e a decisão sobre "derivado") e **MapBiomas** (COG
   público, `sf` no analytic). **ANTT** e **isócronas** ficam **fora do
   objetivo por ora**, justificados no `import_metadata` (o host da ANTT está
   fora do ar; as isócronas exigem infraestrutura nova). Podem voltar em
   issue própria.
