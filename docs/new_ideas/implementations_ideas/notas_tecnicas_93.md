# Nota técnica 93 — Diagramas ER do modelo de dados (Mermaid + SVG) + validação contra o catálogo

**Data**: 2026-10-08
**Escopo**: docs-only — mapa Entidade-Relacionamento do estado atual do banco,
em `docs/diagramas/`.
**Issues**: sem issue associada (melhoria contínua da documentação estrutural).
**Commit**: `e0b4c61` (direto no `main`, excepção docs-only do AGENTS).

## Resumo

O repositório tinha as fontes do dado (fichas em `docs/analises/fontes/`) e a
introspecção do DBIC, mas **não tinha o modelo do banco em forma de diagrama**.
Entregue `docs/diagramas/`: 9 diagramas (1 visão geral em `flowchart` + 8
`erDiagram`), cada um em `.mmd` (fonte editável) e `.svg` (artefato de leitura),
cobrindo **88 entidades distintas** (77 `clean`, 11 `analytics`) e **142
arestas**.

O ponto central não foi desenhar, foi **não afirmar vínculos que não existem**.
Por isso o diagrama não saiu de nenhuma das duas fontes óbvias (as FKs do banco
ou a introspecção DBIX), e por isso a validação é um artefato versionado ao
lado dos `.mmd` — última execução: **6 checagens zeradas, `exit=0`**.

## Decisões de design

1. **Três fontes, cada uma respondendo por um tipo de rótulo.** Só as FKs dá
   errado porque o núcleo antigo (`escolas`, `censo_*`, `ideb`, `inep`, `inse`)
   **não tem uma única FOREIGN KEY** — medido nos dois sentidos: nenhuma FK
   *sai* dessas tabelas e nenhuma *entra*. O vínculo vive só no Perl. Só o DBIX
   dá errado no sentido inverso: as tabelas novas têm FK que o DBIC nem sempre
   declara. Ficou: **catálogo Postgres** (`pg_constraint`) → `[FK]`;
   **mineração do código dos Results** → `[DBIC]`;
   **`docs/analises/fontes*` + o corpo das views** → `[view]`, `[matview]`,
   `[chave]`, `[doc]`.

2. **Minerar o código-fonte em vez de perguntar ao objeto.** `relationship_info()`
   nesta versão do DBIC **não expõe a tipologia** (nem `relationship_type`,
   nem `_relationships($tipo)`), e o `cond` de `many_to_many` nem sempre é hash.
   O minerador faz varredura de parênteses balanceados sobre
   `backend/lib/EduMaps/Schema/Result/*.pm` → 63 relationships em 39 classes.

3. **Convenção sólido/tracejado, com prefixo obrigatório em cada aresta.**
   Sólido = vínculo que existe no modelo (FK / declaração no Perl / chave
   lógica); tracejado = vínculo que só existe numa consulta derivada
   (view/matview/proveniência). O prefixo (`[FK]`, `[DBIC]`, `[view]`,
   `[matview]`, `[chave]`, `[proveniencia]`, `[doc]`) torna a afirmação
   inspecionável à vista — e **verificável por script**, que foi o que a fez
   útil.

4. **`classDef view` em vez do estereótipo `<<view>>`.** O `erDiagram` do
   Mermaid não aceita `<<view>>`; o `classDef` com contorno tracejado dá o
   mesmo sinal visual sem quebrar o parse.

5. **A camada `raw.*` fica de fora** (4 objetos), citada no README. São
   tabelas terminais de staging, sem FK para o núcleo — desenhá-las só
   encheria o 01 e o 02 de arestas mortas.

6. **A validação é entregável, não procedimento.** `validacao/` (3 scripts)
   fica versionado porque o risco real deste documento é afirmar vínculo
   fantasma, e uma prova que ninguém consegue re-executar não é prova.

## Achados medidos (fora do escopo planeado)

1. **A validação apanhou quatro classes de erro reais na própria escrita** —
   é o número que justifica a decisão 6:
   - **4 entidades inventadas** que não existem no banco
     (`analytics.cobertura_ambiental`, `analytics.indice_risco`,
     `clean.entidades`, `clean.relatorios`) — removidas;
   - **2 rótulos `[FK]` falsos**: `isocrona_escolar → escolas` e
     `recife_transporte_escolar → escolas`. Não há FK **nem sequer classe
     `Result`** para as duas — o vínculo é só chave comum
     (`co_entidade = codigo_inep`), reclassificado para `[chave]`;
   - **1 rótulo `[DBIC]` falso**: `censo_escolas → inep_notas_desagregadas`
     não está declarado; a relação que existe é
     `Escolas.has_many notas → InepNotasDesagregadas`;
   - **2 arestas `[view]` em linha sólida** (02 e 07), fora da própria
     convenção do diagrama.
   Acresce **182 linhas de tipo** reescritas a partir do PG e **5 blocos de
   atributos** que faltavam em entidades citadas por aresta.

2. **Três anomalias no código DBIC** (registradas no README, não corrigidas):
   (a) `InepNotasDesagregadas.escola` é **auto-referente** e usa
   `foreign.cod_inep`, coluna que **não existe** na tabela (as reais são
   `id_escola`, `codigo_ibge`, `ano`, `rede`, `sg_uf`, …);
   (b) `MvMunicipiosConsolidado.municipio` aponta para
   `EduMaps::Schema::ResultSet::MunicipiosSp` — classe de **ResultSet**, não
   de Result. Verificado em runtime: **não expõe `result_source`**; os outros
   12 vínculos com município usam a forma curta `MunicipiosSp`;
   (c) `AnaliseCoberturaEscolar` → `analise_cobertura` e `ClusterEscola` →
   `metricas` são tabelas **inexistentes em qualquer schema**.
   ⚠️ **`Country` NÃO é anomalia**: `clean.countries` existe e o nome não
   qualificado resolve pelo `search_path` (que inclui `clean`) — contava-se
   como a terceira pendurada, e estava errado.

3. **Meio ambiente e criminalidade não têm view consolidadora.** Nenhuma das
   **16 views/materialized views** (9 `v` + 7 `m`) de `clean`/`analytics` lê
   `mapbiomas_cobertura`, `inmet_alerta`, `inmet_bdmep` ou
   `brazilcrime_municipio` (0 ocorrências nas definições). Por isso são
   **folhas** no 06 e no 07. Estado de carga medido: `brazilcrime_municipio`
   com **61.192 linhas**, os outros três **com 0 linhas**. ⚠️ O relatório R
   (`analysis/reports/new_data_sources.Rmd`) ainda descreve `brazilcrime` como
   "vazia" — está desatualizado face ao banco.

4. **Duas armadilhas de ferramenta no próprio validador** (ambas produziram
   falso positivo em massa antes de serem corrigidas): `pg_constraint` com
   `::regclass::text` **omite o schema** quando ele está no `search_path`,
   então o par origem/destino não batia com `clean.tabela`; e nos registros
   `REL` do minerador a classe-alvo é `$f[4]`, não `$f[3]` (`$f[3]` é o tipo).

## Entregas

| Artefato | Conteúdo |
|----------|----------|
| `docs/diagramas/00..08-*.mmd` | 9 diagramas — 88 entidades, 142 arestas |
| `docs/diagramas/*.svg` | os 9 renderizados (`@mermaid-js/mermaid-cli`) |
| `docs/diagramas/README.md` | índice, legenda, método (3 fontes), o que ficou de fora, anomalias e lacunas medidas, roteiros de regeneração e validação |
| `docs/diagramas/validacao/gera_catalogo.sh` | gera `colunas.txt`, `fks.txt` e `relacoes.tsv` (consultas de catálogo + leitura dos `.pm`; não escreve no banco) |
| `docs/diagramas/validacao/minerador_relacoes.pl` | minera as relationships a partir do código-fonte dos Results |
| `docs/diagramas/validacao/valida.pl` | as 6 checagens + `--normalizar` (reescreve tipos a partir do catálogo) |

## Testes e validação

- **6 checagens, `exit=0`**: entidades existem · colunas existem · tipos batem
  com o PG · toda entidade de aresta tem bloco no mesmo arquivo · todo `[FK]`
  tem FOREIGN KEY em `pg_constraint` · todo `[DBIC]` tem relationship declarada
  no Perl. Catálogo: **4721 colunas, 71 FKs, 63 relationships**.
- **Convenção checada à parte**: nenhuma aresta fora do par
  sólido/tracejado × prefixo (56 `[FK]`, 29 `[view]`, 19 `[matview]`,
  18 `[DBIC]`, 16 `[chave]`, 3 `[proveniencia]`, 1 `[doc]` = 142).
- **Render**: os 9 `.mmd` produzem SVG; nenhum `.mmd` está mais novo que o seu
  `.svg`.
- **`--normalizar` é idempotente** (segunda execução: 0 reescritas, `md5` dos 9
  arquivos inalterado).
- Não há testes a rodar: ciclo **docs-only**, sem artefato de código e,
  portanto, **sem deploy**.

## Pendências

- Regenerar e revalidar sempre que o schema mudar — roteiro no
  `docs/diagramas/README.md` (Manutenção).
- `clean.censo_data_dictionary` guarda `is_fk`, `fk_target_table` e
  `fk_target_column`: é um **dicionário de FKs não impostas**, candidato a
  fonte adicional da checagem 5 (hoje só `pg_constraint` é consultada).
- As duas `Result` penduradas (`AnaliseCoberturaEscolar`, `ClusterEscola`) e a
  `belongs_to` auto-referente do `InepNotasDesagregadas` continuam abertas —
  registadas aqui, sem correção.
- `minion_jobs` só guarda 7 tarefas de análise/analytics (218 linhas), portanto
  **não serve de evidência** sobre jobs de ingestão — não usar esse caminho
  para afirmar quem carregou o quê.
