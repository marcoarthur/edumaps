# Nota Técnica 85 — #154 corrigida, #153 resolvida, e o registry Sqitch reparado

**Data**: 2026-10-01
**Issues**: #154 (ausência ≠ zero), #153 (destino bloqueado)
**Artefatos**: `data_pipeline/deploy|verify|revert/analytics_ausencia_visivel.sql`, `sqitch.plan`
**Branch**: `fix/data/ausencia-visivel-nas-views` → `main`

---

## Contexto

A nota 84 fechou com um relatório que-media o estado das fontes novas e abriu
seis issues. A #154 era o achado mais grave: as views analíticas publicavam
`0` onde deviam publicar ausência de dado, para as **145.734 escolas** do país.

Este ciclo implementou a #154 e, no caminho para a deployar, descobriu que a
#153 tinha outra causa — e que o `sqitch deploy` estava partido em todos os
alvos por um motivo que tinha sido registado como "sem efeito colateral".

---

## #154 — três estados, não dois

O pedido era "não publicar `0` quando não há dado". A implementação simples —
trocar `COALESCE(x, 0)` por `x` — não chega ao objetivo. Motivo:

`0` e ausência são estados diferentes **do dado**, mas um valor único não
consegue representar os dois. Para distinguir "a fonte não tem snapshot" de
"a fonte tem snapshot e este município não tem oferta", é preciso contar os
registos da fonte. Daí o CTE `fontes`:

| Estado da fonte | Município | `acidentes_12m` |
|---|---|---|
| Sem snapshot | — | `NULL` (não avaliável) |
| Com snapshot | Sem acidentes | `0` (zero real) |
| Com snapshot | Com acidentes | `N` |

`status_isocrona` e `status_conexao_antt` ganharam o terceiro estado
`'fonte_vazia'`, para que nenhum consumidor tenha de inferir a causa a partir
do valor — que é o que produziu o defeito original.

### O relatório anterior exaggerou o mecanismo

Dizía que as "três views" faziam `COALESCE(x, 0)`. Lendo o SQL:

| View | `COALESCE`? | Mecanismo real | Defeituosa? |
|---|---|---|---|
| `mobilidade_escola` | sim, 3 colunas | `COALESCE(SUM(...), 0)` e `COUNT(...)` sobre conjunto vazio | sim |
| `acessibilidade_saude` | **nenhum** | `COUNT()` → 0; `CASE ... ELSE 'Sem UBS no município'` | sim, por outro caminho |
| `esforco_fiscal_educacao` | não | `LEFT JOIN` sem `COALESCE`, propaga `NULL` | **não** |

Consequência prática: em `acessibilidade_saude` remover o `COALESCE` não
resolveria nada, porque não há `COALESCE` nenhum. A correção tem de atuar
sobre a **causa** (a fonte estar vazia), não sobre a expressão.

`esforco_fiscal_educacao` ficou de fora por ser o **padrão de referência** do
que certo — está vazia e diz que está vazia.

### Fan-out: um defeito invisível enquanto não há dados

As views faziam **7 `LEFT JOIN` numa única query com um `GROUP BY` único**. Isso
é produto cartesiano: o número de linhas de cada fonte multiplica o das outras
seis, e como `COUNT(acidentes)` e `SUM(vmda)` eram calculadas nessa mesma
query, saíam multiplicadas.

Medido com dados sintéticos (6 acidentes e 1.500 VMDA reais):

| Métrica | Verdade | Definição anterior | Corrigida |
|---|---|---|---|
| `acidentes_12m` | 6 | **12** | 6 |
| `vmda_total_municipio` | 1.500 | **9.000** | 1.500 |

O fator varia por município, por isso não é corrigível por um fator de escala.
Este defeito é **invisível com tabelas vazias** — só aparece quando há carga, e
nunca houve carga real. É o tipo de erro que sobrevive a uma correção
superficial: "tirar o `COALESCE`" não tocaria nele.

A correção passou a **pré-agregar cada fonte ao seu grão** (município ou
escola) e a eliminar o `GROUP BY` único. Não é um extra de limpeza: é o que
torna distinguível zero real de ausência, porque no `GROUP BY` conjunto o `0`
do `COUNT` e o `NULL` do join chegam misturados na mesma linha.

### O teste de regressão tem de morder, e foi provado que morde

O `sqitch verify` deste repositório **nunca falha**. Os `verify/*.sql`
existentes terminam em `SELECT 1 FROM ...`, e o Sqitch dá `ok` a um script que
devolve `f` — só um **erro** falha. Medido contra Sqitch 1.6.1 num sandbox
descartável:

```
Verifying local
  * teste_verifica .. ok      # <-- "ok" com a asserção a devolver false
```

Ou seja: um teste de regressão escrito à forma existente **passaria com o
defeito presente**. Era exactamente isso que a issue pedia para não acontecer.

Por isso `verify/analytics_ausencia_visivel.sql` tem 20 asserções em
`DO $$ … RAISE EXCEPTION $$`. E o teste foi verificado nos **dois sentidos**:

- contra a definição corrigida → 20 asserções passam, `EXIT=0`;
- contra a definição antiga → `Errors: 1`, com a mensagem a apanhar as
  **145.734** escolas afetadas.

Três das 20 protegem o **sentido inverso** — com a fonte carregada, município
sem oferta tem de dar `0`, não `NULL`. Sem elas, a correção seria fácil de
"resolver" apagando todos os zeros, e o relatório passaria a esconder
municípios inteiros em vez de os descrever.

Contrato de colunas preservado (31 + 16 = 47), o que permitiu
`CREATE OR REPLACE VIEW` e portanto um `revert` que restaura a definição
anterior — incluindo o defeito, e isso está escrito no próprio ficheiro para
ninguém o usar por engano.

---

## #153 — a causa diagnosticada estava errada

O relatório dizia: *"`pgvector` ausente em `ubatexu.lan`; `school_embedding`
falhou 7× entre 2026-09-16 e 2026-09-30"*.

As 7 falhas são reais. A conclusão é que não.

### Dois contentores, mesmo hostname

Em `ubatexu.lan` correm **dois** contentores de base de dados, e ambos se
identificam como `Database`:

| Contentor | SSH (porta) | IP | Acedido por | `pgvector` | Changes |
|---|---|---|---|---|---|
| `database.edumaps` | 2032 | `172.19.198.3` | **o backend real** | disponível | 89 |
| `database.dev` | 2026 | `172.31.51.4` | o target Sqitch `dev_super` | **ausente** | 42 |

Nada resolve `database.edumaps` por DNS — os dois nomes vivem no `~/.ssh/config`
com portas diferentes. É por isso que a confusão passa despercebida.

A confirmação que não depende de configuração nenhuma é o serviço ligado:

```bash
ssh root@backend.edumaps 'ss -tnp | grep :5432'   # → 172.19.198.3:5432
```

`ubatexu.lan:5432` — que é o target `dev_super` e o default de
`backend/edu_maps.conf` — é `database.dev`: uma base que ninguém usa e que
nunca passou pelo `deploy_db_dev` (que instala `pgvector`, Rexfile linha 452).
Em `database.edumaps`, `school_embedding` tem **1 deploy e 0 falhas**.

Portanto **o relatório mediu a base errada**, e a recomendação de "instalar
`pgvector` no servidor de dev" apontava para o alvo errado.

A lição de método: um default em `edu_maps.conf` é uma hipótese sobre onde o
serviço fala. Sem confirmar contra o processo em execução, medir contra a
hipótese produz um relatório inteiro errado — inclusive a causa raiz e a
recomendação.

---

## O bloqueio real — `change_id` do Sqitch é irreversível

O `rex -H database.edumaps deploy_db_dev` falhou com:

```
Cannot find change f931403e7969ba9232b73e7b2bcf6ec05639d87d
(analytics_esforco_fiscal) in sqitch.plan
```

O Sqitch calcula o `change_id` de uma change como SHA-1 dos seus metadados, e
esses metadados incluem a lista `requires` **e o `change_id` do pai** (a change
anterior no plano). Logo:

- mudar uma dependência declarada numa change já deployada **muda o seu id**;
- mover uma change já deployada de posição **também muda** (o pai muda);
- e ambos em **cascata** para todo o resto do plano.

**Isto foi feito no ciclo anterior.** `a13718c` editou `requires` de 10 changes
já deployadas; `83a77c5` moveu `import_metadata_fase0` no plano. E o
`memory.md` da altura registou que a operação era *"reordenação do plano,
reexecutável por `sqitch deploy`, sem efeito colateral a corrigir"*.

**Não era verdade.** Divergências medidas:

| Alvo | Changes divergentes |
|---|---|
| Docker local (`127.0.0.1`) | **71 de 88** |
| `database.dev` (`ubatexu.lan:5432`) | **25 de 42** |
| `database.edumaps` (backend real) | **59 de 76** |

O `sqitch rewrite --set` — a ferramenta que isto resolveria em duas linhas —
**não existe** no Sqitch 1.6.1 instalado.

### Reparação sem reexecutar um único deploy script

1. `sqitch deploy --log-only` contra uma base descartável: regista as 89 changes
   **sem executar os scripts**, logo com os `change_id` que o plano calcula;
2. `UPDATE sqitch.changes SET change_id = … WHERE change = …` nos alvos reais.
   As FKs de `dependencies` e `tags` têm `ON UPDATE CASCADE` e propagam
   sozinhas; só `events` — que não tem FK para `changes` — exige update
   separado.

Backups dos registries tirados antes de tocar em qualquer um. Verificado depois
em todos: **0 violações FK**, `0` eventos incoerentes, e `sqitch status` a
responder. Deploy completo em `database.edumaps` logo a seguir: **89 de 89**,
com `--verify` a passar.

### Dívida que fica

**`sqitch verify` global dá 45 "Out of order".** `import_metadata_fase0` foi
deployada a 2026-09-30 e depois movida para antes no plano; as 45 changes entre
as posições ficam fora de ordem no histórico. Não é corrigível sem reverter a
reordenação — e corrigi-lo exigiria reescrever `events.requires`, ou seja,
**mentir sobre o que foi aplicado e quando**. Registado como dívida, não
reparado.

Soma-se ao facto de os `verify` não mordem: **não há gate fiável de migração
neste repositório**. Um pipeline sem gate é o mesmo problema da #154 um nível
acima — um teste que não falha não é um teste. Os `verify` antigos não foram
tocados neste ciclo: corrigi-los exige medir primeiro quantos estão a falhar de
forma latente, e isso não se descobre lendo-os.

---

## Regras registadas em `AGENTS.md`

Três secções novas, todas derivadas do que foi medido acima e não do que se
supunha:

1. **A tabela dos dois contentores** de base de dados, com o comando de
   confirmação que não depende de DNS nem de config.
2. **Proibição de editar `requires` ou reordenar changes já deployadas.** Dependência
   nova entre changes deployadas resolve-se com uma change nova.
3. **O comportamento real do `sqitch verify`** — não falha em asserção falsa,
   e o global dá 45 "Out of order".

---

## O que fica para o próximo ciclo

| Prioridade | Item |
|---|---|
| 🔴 | **#155** — de-para RENAEST verdadeiro (`fuzzy_match_renaest.py` nunca correu) |
| 🔴 | **#156** — ingestão real (agora desbloqueada: o destino tem schema) |
| 🟡 | **Dívida nova** — tornar o `sqitch verify` gate fiável; medir antes de mexer |
| 🟡 | **Dívida nova** — `raw_countries` exige rede externa no deploy |
| ⚪ | **#158** — materializar as views (`mobilidade_escola` agrega sobre 670 MB) |