# Nota técnica 137 — #264/#137: mecanismo de refresh do entorno (bloco B) e a materialização do bloco B

Esta nota cobre o **mecanismo** que faltava para o bloco B (socioeconômico) do
IVET sair do `NA` no produto: materializar, de forma **rastreável e repetível**,
as camadas `clean.escola_influencia` e `clean.escola_entorno_socioeconomico`.
PR **#265** (merge `d72727d`); issue tracker **#264**.

## Contexto

As camadas de Tier 1/Tier 3 existiam (NT_135/NT_136), e a função
`clean.refresh_escola_entorno_socioeconomico(p_raios, p_co_entidades)` já existia.
O que faltava era o **mecanismo operacional**: a influência tinha o gêmeo
`refresh_influencia`, mas o **entorno só era (re)materializado por SQL manual** —
nenhuma task, nenhuma forma de disparar por UF ou por escola. Por isso o produto
tinha a camada **vazia** e o bloco B saía `NA`.

## O que foi feito

### Task Minion — `backend/lib/EduMaps/Task/Entorno.pm`

Espelha `Influencia.pm`; registra `refresh_entorno_socioeconomico` e um helper.
Quatro ramos, por argumento:

| args | SQL |
|---|---|
| `{raios}` | `refresh_escola_entorno_socioeconomico(<raios>)` |
| `{raios, co_entidades}` | `refresh_escola_entorno_socioeconomico(<raios>, <ids>)` |
| `{uf}` | monta os `co_entidade` **no banco** (`array_agg … WHERE sg_uf = ?`) |
| default | `refresh_escola_entorno_socioeconomico()` |

O ramo `{uf}` evita trafegar dezenas de milhares de INEPs por argumento — a lista
é construída no próprio Postgres. Registro do plugin em `EduMaps.pm`; teste de
wiring em `backend/t/05-tasks/entorno.t`.

### Custo real e a decisão de execução

A arealização é **a chamada mais cara do projeto até aqui**. Medições isoladas de
amostras de 800 escolas (produto `database.edumaps`, 4 cores, 7 GB,
`shared_buffers`=128 MB):

| amostra | tempo | s/escola |
|---|---|---|
| SP (urbano denso) | 5 m 37 s | 0,42 |
| MA | 1 m 14 s | 0,092 |
| BA | 41 s | 0,051 |
| nacional (primeiras 800) | 37 s | 0,046 |

O custo varia ~9× entre regiões (densidade de setores por buffer). Descartei, por
medição, os atalhos usuais: **`jit` on/off** e
`max_parallel_workers_per_gather` 0/2 **não mudam**; `work_mem` 4 MB vs 256 MB
**não muda**; precomputar `area_inf`/`area_setor` economiza só ~6% — o gargalo é
`ST_Intersection` × `ST_Area(geography)` **por par**, e o plano faz *hash join*
com *seq scan* dos 468.097 setores a cada chamada.

**Decisão operacional**: driver **sequencial, maior UF primeiro** (SP é o poste de
~3 h), progresso em arquivo (retomável) — porque **3 UFs em paralelo é ~3× mais
lento** que sequencial (contenda medida: MA 882 s e BA 1746 s concorrentes vs
~506 s e ~550 s isolados). Projeção do país: **~5–6 h**.

### Influência global

`clean.refresh_escola_influencia()` no produto → **470.448 linhas** (156.816
escolas com geometria × 3 raios), 58 s, 353 MB. Esse é o entregável do Tier 1,
concluído.

## Estado

- Código mergeado (#265) e deployado (`deploy_backend_dev` + `deploy_minion_dev`;
  md5 confere no container).
- Influência: **completa** no produto.
- Entorno: materialização em background; validar ao fim
  `count = 470.448` e `count(DISTINCT co_entidade) = 156.816`.

## Pendências

- Terminar/conferir o lote do entorno (#264).
- O bloco B continua `NA` **enquanto** (a) a materialização não terminar e
  (b) o loader não carregar renda/instrução (#238). Esta fatia resolve só o
  lado do **mecanismo/dados arealizados**.
