# Nota Técnica 84 — Relatório de saneamento das fontes novas pós-#123

**Data**: 2026-10-01
**Issue de origem**: #123 (matriz de priorização de fontes abertas)
**Artefato**: `analysis/reports/new_data_sources.Rmd`
**Branch**: `docs/analise/relatorio-novas-fontes-dados` → `main`

---

## Contexto

Entre `886b571` (fase 0) e `add5331` (fase 6) foram criados **28 objetos
novos** em `clean.*` e `analytics.*`. Havia **nenhum** artefato que medisse o
quanto dessa escada foi de fato percorrida — o acervo contava com a
documentação de *design* (fichas em `docs/analises/fontes/`, `COMMENT ON
TABLE` nas migrations) mas não de *estado*.

Este relatório fecha essa lacuna: não reimplementa nada, **mede**.

---

## Entregue

| Seção | Conteúdo |
|-------|----------|
| 1–2 | Inventário das 28 entradas: fonte, licença, granularidade, lacuna do IVET atendida, **enfoque analítico** e regra obrigatória de privacidade |
| 3 | Método e conexão (cache chaveado por `banco@host:porta`) |
| 4 | Estado de carga: linhas, colunas, bytes, nº de colunas 0% nulas vs 100% nulas |
| 5 | **Perfil de todas as colunas** de todos os objetos: tipo, NOT NULL, nº e **% de nulos** (série de tabelas A1–A28) |
| 6 | Sanity check — 6 achados, 3 de severidade alta |
| 7–8 | O que dá para usar hoje; plano de correção em 6 passos |

---

## Os 3 achados de severidade alta

### 6.1 — `zero` confundido com `nulo` nas views analíticas

`analytics.acessibilidade_saude` e `analytics.mobilidade_escola` fazem
`LEFT JOIN` contra tabelas vazias e preenchem as colunas numéricas com
`COALESCE(..., 0)`. Resultado, para as **145.734 escolas** do país:

- `n_ubs_municipio = 0` com **1 único valor** e `classificacao_acesso =
  'Sem UBS no município'` — a view **afirma** que não há UBS no município.
  Falso: `clean.cnes_estabelecimentos` está vazia.
- `acidentes_12m = 0`, `sinistros_12m = 0`, `vmda_* = 0` — todos com **1
  único valor**. Lê-se como "zero acidentes", quando o correto é "sem dado".

O detalhe instrutivo: as views **já têm** colunas de status explícito
(`status_isocrona = 'sem_isocrona'`, `status_conexao_antt =
'sem_conexao_antt'`) que fazem exatamente a distinção certa. O defeito é de
**consistência interna** — as colunas de status foram bem desenhadas e as
numéricas ao lado não seguem o mesmo princípio.

**Impacto:** qualquer indicador construído sobre essas colunas publicaria
"mapa de segurança viária perfeita" e "sem acesso à saúde" com aparência de
dado real.

### 6.2 — `renaest_localidade_municipio` é placeholder, não de-para

5.573 linhas, **zero nulos**, `match_type`/`match_score`/`validated_by`/`dt_carga`
com **1 único valor cada**. É uma auto-junção do IBGE (cada município mapeado
para si mesmo, `validated_by = 'auto_seed'`). O `COMMENT ON TABLE` promete
`exact/fuzzy/manual`; `fuzzy` e `manual` **nunca ocorreram**.

**Falha silenciosa:** o join por `(localidade, uf)` faz localidades RENAEST
que coincidem com nome de município casarem (corretamente) e todas as outras —
bairros, distritos — **desaparecerem sem log e sem erro**.

### 6.3 — 24 de 25 tabelas ausentes no banco de dev nominal

O serviço `edumaps` do `~/.pg_service.conf` (padrão do `backend/edu_maps.conf`)
aponta para `ubatexu.lan`, onde existem **1 de 25** tabelas novas e **0 de 3**
views.

**Causa raiz (verificada):** `pgvector` não está disponível nesse servidor.
Sqitch aborta no primeiro change que falha, e `school_embedding` falhou **7
vezes** entre 2026-09-16 e 2026-09-30. Tudo que vem depois dele no
`sqitch.plan` nunca foi aplicado. `import_metadata_fase0` aparece antes no
plano e é a única das fases que passou — daí "1 de 25".

---

## Decisões de projeto do relatório

1. **Consulta ao vivo, não números embutidos** — o relatório mede o estado real
   e é reexecutável. Snapshot congelado envelheceria e daria falsa confiança.
2. **Cache chaveado por `banco@host:porta`** — alternar entre o banco local e o
   de dev não pode cruzar resultados, e as conclusões mudam entre eles.
3. **Nunca embute credencial** — só `EDUMAPS_DB_*` ou
   `EDUMAPS_REPORT_PG_SERVICE`. O `.Rmd` é versionado.
4. **Perfil em passagem única com `to_jsonb`** + `LEFT JOIN` de `pg_attribute`
   sobre a relação. Um `CROSS JOIN` devolveria **zero linhas para tabela
   vazia** e a tabela sumiria do relatório — que era exatamente o bug da
   primeira versão (só 6 de 28 objetos apareciam).
5. **`% nulos` de tabela vazia é `NA`, não `0`** — a distinção entre "não há
   dado para medir" e "não há nulos" é o ponto do relatório.
6. **Série de tabelas separada (`A1`–`A28`)** para os perfis de coluna não se
   misturarem com a série principal `1`–`16`.

---

## Decisões herdadas que o relatório confirma como corretas

- `clean.malha_municipio`: **7 de 7 colunas com 0% de nulos**, 5.573 geometrias
  distintas, SRID 4674. A única entrada nova integral e usável hoje.
- Proveniência das cargas das fases 0–6: **completa** (URL, licença e data nas
  23 entradas novas).
- Desenho de granularidade/LGPD declarado nas migrations (H3 em vez de escola
  isolada, supressão de célula pequena, `classificacao = 'realizada'`) está
  correto **no schema** — mas não verificável enquanto as tabelas estiverem
  vazias.

---

## Pendências apontadas pelo relatório (não executadas aqui)

1. **Desbloquear schema**: instalar `pgvector` no servidor de dev, ou mover
   `school_embedding` para o fim do `sqitch.plan`, e rodar `sqitch deploy`.
2. **Tornar ausência visível**: substituir `COALESCE(x, 0)` por `x` nas views,
   ou exigir filtro no consumidor. Adicionar teste de regressão *"tabela-fonte
   vazia não pode produzir `0` na view"*.
3. **Rodar `data_pipeline/scripts/fuzzy_match_renaest.py`** (ainda não
   executado) e substituir o seed; registar localidades não resolvidas em
   tabela própria.
4. **Fechar proveniência**: 9 cargas antigas sem URL/licença/data; duplicata de
   `censo_data_dictionary` em `import_metadata`; resolver **GPL-3 vs MIT** do
   BrazilCrime antes de qualquer distribuição.
5. **Materializar** `mobilidade_escola`/`acessibilidade_saude` quando houver
   dado (hoje recalculam agregação sobre `censo_escolas`, 670 MB).

---

## Nota de processo

As correções de ordem do `sqitch.plan` (`a13718c`, `83a77c5`, `812f36d`) que
destravaram o CI foram enviadas **direto para `main`**, sem branch → PR → merge,
contrariando a regra do `AGENTS.md` para `fix`. Não existe registro de PR para
elas.

**Encerrado em 2026-10-01**: exceção concedida pelo developer, sem PR
retroativo — a mudança é de ordenação do plano Sqitch, reexecutável por
`sqitch deploy` e sem efeito colateral a corrigir. **Não é precedente:** o
`AGENTS.md` passou a exigir o procedimento de contingência (avisar, comentar no
PR/issue do trabalho, abrir PR retroativo) para qualquer push direto futuro.

---

## Notas Técnicas Relacionadas

- `analysis/reports/new_data_sources.Rmd` — o relatório
- `docs/analises/fontes_de_dados.md` — a matriz da #123 que originou as fases
- `docs/new_ideas/implementations_ideas/notas_tecnicas_83.md` — e-SICs (#132)
- `memory.md` — estado do ciclo
