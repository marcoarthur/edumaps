# Diagramas Entidade-Relacionamento

Modelo de dados atual do EduMaps em **Mermaid** (`.mmd`) + **SVG**.
O `.mmd` é a fonte editável; o `.svg` é o artefato para leitura. Ambos são
versionados — um diagrama que não está aqui não existe na documentação.

> **Estado**: 89 entidades distintas (78 em `clean`, 11 em `analytics`),
> 142 arestas, 9 arquivos.

## Índice

| # | Arquivo | Escopo | Entidades | Arestas |
|---|---------|--------|-----------|---------|
| 00 | `00-visao-geral` | Índice dos diagramas (**flowchart**, não é ER) | — | — |
| 01 | `01-territorio` | Território e população: malha municipal, setores censitários, população, PIB, acessibilidade espacial | 12 | 16 |
| 02 | `02-censo-desempenho` | **Núcleo antigo**: Censo Escolar, IDEB, INEP, INSE e as matviews consolidadoras | 20 | 31 |
| 03 | `03-osm` | Features da base OpenStreetMap por escola/município e distâncias | 10 | 12 |
| 04 | `04-financeiro` | SICONFI (receita/despesa), transferências de educação, esforço fiscal | 8 | 11 |
| 05 | `05-mobilidade` | Isocronas, origem-destino, frota, capacidade das vias (VMDA), transporte escolar | 13 | 18 |
| 06 | `06-saude-meio-ambiente` | Acessibilidade da escola à UBS, cobertura MapBiomas, eventos INMET | 8 | 9 |
| 07 | `07-risco-seguranca` | Acidentes de trânsito, sinistros RENAEST, criminalidade municipal | 8 | 7 |
| 08 | `08-plataforma` | Gestão/comunidade: gestores, sessões, chat, documentos, inventário, pesquisas | 31 | 38 |

Chaves do modelo: **`codigo_ibge`** (município) e **`co_entidade` = `codigo_inep`**
(escola). `clean.escolas` **não** tem `codigo_ibge` — o vínculo escola↔município
é **espacial** (`ST_Contains`), e só aparece derivado em
`analytics.escolas_filtradas.municipio_ibge`.

## Legenda

### Estilo da linha

| Estilo | Significado |
|--------|-------------|
| **sólida** (`\|\|--o{`) | vínculo que existe no modelo: FOREIGN KEY no Postgres, relationship declarada no Perl, ou chave lógica de domínio |
| **tracejada** (`\|\|..o{`) | vínculo que só existe numa consulta derivada: coluna lida de uma view/materialized view, ou proveniência de carga |

### Prefixo do rótulo

| Prefixo | Arestas | Diz que… | Verificado contra |
|---------|---------|----------|-------------------|
| `[FK]` | 56 | há FOREIGN KEY real no Postgres | `pg_constraint` |
| `[view]` | 29 | a coluna vem de uma **view** | `pg_get_viewdef` |
| `[matview]` | 19 | a coluna vem de uma **materialized view** | `CREATE MATERIALIZED VIEW` na migration |
| `[DBIC]` | 18 | relationship declarada no Perl (`belongs_to` / `has_many` / `has_one` / `might_have`) | `backend/lib/EduMaps/Schema/Result/*.pm` |
| `[chave]` | 16 | chave comum lógica, **sem** FK imposta no banco | — |
| `[proveniencia]` | 3 | rastreio da carga (`import_metadata.table_name`) | — |
| `[doc]` | 1 | vínculo documentado em `docs/analises/` | — |

Variantes que refinam o mesmo significado: `[DBIC espacial]`, `[DBIC has_one]`,
`[DBIC has_many]`, `[DBIC might_have]`, `[FK via malha]`.

### Caixas

Caixa com **contorno azul tracejado e fundo claro** = view/materialized view
(`classDef view`); demais caixas = tabela. É a única diferença visual entre
tabela e objeto derivado — o Mermaid **não** aceita o estereótipo `<<view>>`
em `erDiagram`.

## Método: de onde vem cada afirmação

O diagrama pode ser gerado **só das FKs** — e erra, porque o núcleo antigo
(`escolas`, `censo_*`, `ideb`, `inep`, `inse`) **não tem uma única FOREIGN
KEY**: o vínculo existe apenas como `belongs_to`/`has_many` no Perl. Também
pode ser gerado **só da introspecção DBIX** — e erra, porque as tabelas novas
têm FK no banco que o DBIC nem sempre declara. Por isso as três fontes abaixo,
cada uma respondendo por um tipo de rótulo:

1. **Catálogo do Postgres** — `pg_class`, `pg_attribute`, `pg_constraint`
   (`validacao/gera_catalogo.sh`). Responde por: entidades, colunas, tipos e
   todo o prefixo `[FK]` (71 FKs no banco).
2. **Código dos Results DBIC** — mineração do fonte com varredura de
   parênteses balanceados (`validacao/minerador_relacoes.pl`). Responde por
   `[DBIC]` (63 relationships em 39 classes `Result`). Não se usou
   `relationship_info()`: **esta versão do DBIC não expõe a tipologia**
   (`relationship_type` / `_relationships($tipo)`), e o `cond` de
   `many_to_many` nem sempre é hash — daí ler o código em vez de perguntar ao
   objeto.
3. **Documentação de fontes e as definições das views** —
   `docs/analises/fontes_de_dados.md`, as fichas em `docs/analises/fontes/`
   (granularidade escolar > municipal > estadual) e o corpo de cada
   `CREATE VIEW` / `CREATE MATERIALIZED VIEW` nas migrations. Responde por
   `[view]`, `[matview]`, `[chave]` e `[doc]`: são vínculos interpretados,
   não impostos.

### O que não está nos diagramas

- **`raw.*`** (4 objetos: `escolas_raw`, `inep_raw`, `populacao_raw`,
  `populacao_faixas_raw`) — camada de *staging*, sem FK para o núcleo; citada,
  mas não desenhada.
- **13 objetos de `clean`/`analytics`**, por motivo:
  - *infraestrutura de jobs/framework* (4): `clean.minion_locks`,
    `clean.minion_schedules`, `clean.minion_workers`, `clean.mojo_migrations`
    (`clean.minion_jobs` **entra** no diagrama 08 porque carrega o nome da
    tabela de cada carga, em `args`);
  - *camada de ML* (7): `analytics.analysis_cache`,
    `analytics.city_school_analytics`, `analytics.clustering_metadata`,
    `analytics.school_embedding`, `analytics.view_escolas_ml`,
    `analytics.view_escolas_ml_spatial`, `clean.school_indicators`;
  - *referência* (2): `clean.countries`, `clean.censo_data_dictionary`.
- **Colunas**: cada bloco lista só as colunas que sustentam o relacionamento
  (PK/FK e as chaves do domínio) — não é um dicionário de colunas. Todos os
  tipos e nomes listados, porém, são reais e verificados.

> Curiosidade: `clean.censo_data_dictionary` **é** um dicionário de dados do
> Censo, com `is_fk`, `fk_target_table` e `fk_target_column` — ou seja, a
> própria base documenta vínculos que não estão impostos como FK. É essa a
> razão de existir do método de três fontes acima.

## Anomalias medidas

Registradas aqui porque afetam quem for ler o modelo — nenhuma delas foi
"corrigida" por este documento, elas são o estado real:

1. **`InepNotasDesagregadas.escola` é auto-referente e usa coluna inexistente.**
   Declara `belongs_to(..., 'InepNotasDesagregadas', { 'foreign.cod_inep' => ... })`,
   mas a tabela não tem `cod_inep` (reais: `id_escola`, `codigo_ibge`, `ano`,
   `rede`, `sg_uf`, …). O vínculo que **existe** é
   `Escolas.notas → InepNotasDesagregadas` (`id_escola` ↔ `codigo_inep`) — é
   o que está desenhado no diagrama 02.
2. **`MvMunicipiosConsolidado.municipio` aponta para o diretório errado.**
   O destino é `EduMaps::Schema::ResultSet::MunicipiosSp` (classe de
   *ResultSet*), e não `…::Result::MunicipiosSp`. Verificado em runtime: essa
   classe-alvo **não expõe `result_source`**. Os outros 12 vínculos com
   município usam a forma curta `MunicipiosSp`.
3. **Duas classes `Result` apontam para tabelas que não existem** em nenhum
   schema: `AnaliseCoberturaEscolar` → `analise_cobertura` e `ClusterEscola`
   → `metricas`. (`Country` → `clean.countries` **existe** e é resolvida pelo
   `search_path`; não é anomalia.) Não aparecem nos diagramas por isso.

### Lacunas de modelagem (não são erros, são decisões ausentes)

- **Meio ambiente e criminalidade não têm view consolidadora.** Nenhuma das
  **16 views/materialized views** de `clean`/`analytics` lê
  `mapbiomas_cobertura`, `inmet_alerta`, `inmet_bdmep` ou
  `brazilcrime_municipio` (0 ocorrências nas definições). Por isso as quatro
  aparecem como **folhas** no 06 e no 07: aresta de entrada só de
  `malha_municipio`, nenhuma de saída. As views que esses dois diagramas de
  facto têm nascem de outras bases — `analytics.acessibilidade_saude` de
  `censo_escolas` + `cnes_estabelecimentos` + `sisab_aps`, e
  `analytics.mobilidade_escola` de acidentes/OD/isocronas/frota/VMDA. O leitor
  das quatro é o relatório R `analysis/reports/new_data_sources.Rmd`.
- **Estado de carga medido** no banco de desenvolvimento:
  `brazilcrime_municipio` com **61.192 linhas**; `mapbiomas_cobertura`,
  `inmet_alerta` e `inmet_bdmep` **vazias (0 linhas)**.
- **`cnes_estabelecimentos` e `sisab_aps` não têm FK** para `malha_municipio`,
  ao contrário das demais tabelas novas: a ligação é por `codigo_municipio`
  resolvida na ingestão (`[chave]` no diagrama 06).
- **`isocrona_escolar` e `recife_transporte_escolar` não têm FK para
  `escolas`** — só a chave comum `co_entidade = codigo_inep`. Não há sequer
  classe `Result` para elas.
- **`analytics.mobilidade_escola` junta acidentes a trechos só na view**
  (`t.trecho = a.trecho`), sem FK entre `antt_acidente_trecho` e
  `antt_trecho_geodados`.
- **`renaest_sinistro.codigo_ibge` vem da própria fonte** (ficheiro
  `Acidentes` da RENAEST); o de-para `renaest_localidade_municipio` (mesmo
  ficheiro `Localidade`) é que fornece `localidade`/`uf` e decide se a linha
  entra. A aresta `[doc]` do 07 regista essa dependência de nome, não uma FK.
- **O de-para RENAEST não faz fuzzy matching nem validação humana**:
  resolve pelo `codigo_ibge` da própria fonte, validado contra a malha;
  `match_type` rotula apenas a grafia (`exact`/`fuzzy`) e `manual` nunca
  ocorreu. As localidades que não resolvem têm destino explícito em
  `clean.renaest_localidade_nao_resolvida` (#155).

## Regenerar os SVG

```bash
cd docs/diagramas
for f in *.mmd; do
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "${f%.mmd}.svg"
done
```

O `mermaid-cli` renderiza localmente via Puppeteer, sem depender de serviço
externo — o passo é reproduzível offline. Uma falha de gramática é isolada por
arquivo: o loop continua e só o `.mmd` problemático não produz SVG.

## Validar

A validação existe porque o risco real deste documento é **afirmar um vínculo
que não existe**. Ela prova, para os 8 diagramas ER:

1. toda entidade existe numa relação do Postgres;
2. toda coluna de cada bloco existe naquela relação;
3. o tipo declarado é o tipo real;
4. toda entidade de aresta tem bloco de atributos no **mesmo** arquivo;
5. todo `[FK]` corresponde a uma FOREIGN KEY do catálogo;
6. todo `[DBIC]` corresponde a uma relationship declarada no Perl.

```bash
# 1. gera os insumos (consultas de catálogo + leitura dos .pm; nada escreve no banco)
sh docs/diagramas/validacao/gera_catalogo.sh /tmp/catalogo

# 2. valida (sai com código != 0 se algo falhar)
perl docs/diagramas/validacao/valida.pl \
     --colunas  /tmp/catalogo/colunas.txt \
     --fks      /tmp/catalogo/fks.txt \
     --relacoes /tmp/catalogo/relacoes.tsv
```

Ao **acrescentar** uma tabela aos diagramas, use também `--normalizar` para
reescrever os tipos a partir do catálogo e refaça o commit dos `.mmd`:

```bash
perl docs/diagramas/valida.pl --normalizar \
     --colunas /tmp/catalogo/colunas.txt --fks /tmp/catalogo/fks.txt \
     --relacoes /tmp/catalogo/relacoes.tsv
```

Resultado da última execução: **6 checagens zeradas, `exit=0`**, e nenhuma
aresta fora da convenção sólido/tracejado × prefixo.

## Manutenção

- Mudou uma funcionalidade que cria/remove tabela ou view → atualize o
  diagrama correspondente **e** os números do índice acima (é o passo 3 do
  Workflow em `AGENTS.md`).
- Antes de commitar, rode a validação. Ela é a garantia de que o diagrama não
  virou opinião.
