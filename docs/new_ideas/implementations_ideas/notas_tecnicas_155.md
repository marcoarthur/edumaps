# Nota técnica 155 — isócrona escolar: do Valhalla auto-hospedado ao componente de acesso do IVET

O bloco **C (acesso/mobilidade)** do IVET foi entregue em 2026-10-18 como
**proxy de exposição viária** porque `clean.isocrona_escolar` estava vazia:
isócrona exige um motor de roteamento e não havia nenhum. Esta nota registra o
ciclo que **construiu a infraestrutura, carregou o piloto do ES e fez o acesso
entrar na fórmula** — o critério 2 da issue **#278**, que fecha a issue (o
critério 1, exposição a risco/F, fechou no ciclo da nota 154).

Issues de contexto: **#278** (exposição a risco + isócrona), **#137** (IVET
como produto versionado), **#154** (ausência ≠ 0), **#255** (piloto ES do F).

## Entregas

| PR / commit | Escopo |
|---|---|
| **PR do branch** | `366cee0` `feat(data_pipeline)` coluna `resolucao_h3` · `b4d5c74` `feat(db)` piloto de isócrona do ES · `69db3f5` `feat(analytics)` `acesso_isocrona` no bloco C · `3c52633` `docs(analytics)` isócrona no bloco C · `a578c34` `fix(analytics)` acesso chega como numeric |

## 1. A infraestrutura não existia — e ficou fora do repo

Um motor de roteamento **não pode virar dependência de deploy**: os hosts LXC
não têm Docker e uma instância pública (demo) não tem SLA. A arquitetura
adotada é a que a própria fonte recomenda: **extrair o tileset uma vez e
auto-hospedar em container** no host local `ubaxala`:

- extract `sudeste-latest.osm.pbf` (822 MB) → **`es.osm.pbf`** (191 MB, bbox
  -42,0/-21,5/-39,6/-17,7) via `osmium`;
- **173 tiles** (90 MB) construídos com `valhalla_build_tiles`;
- container `valhalla-es` (Valhalla **3.5.1**) servindo `tcp://0.0.0.0:8002`.

Tudo em `~/Code/Data/osm/` (fora do repositório); o repo guarda o **método**,
não o binário: `db/isocrona/README.md` tem o roteiro de reprodução. O que vai
ao versionamento é o pipeline (`extrair_isocronas.py`, `carregar.sql`,
`piloto_es.sh`) — e a **proveniência** da carga (`tileset_origin`,
`engine_version` medido em `GET /status`) fica gravada na tabela, para o dado
ser auditável mesmo com a infra fora do repo.

> ⚠️ **O config do Valhalla precisa de `tcp://`**, não `ipc://` — o serviço
> simplesmente não sobe com o formato errado e o erro não é óbvio.

## 2. Resolução da grade: medida, não chutada

A arealização da população por célula H3 exige escolher a resolução **antes**
de rodar: r9 demais para o carro (10–15 mil células/escola), r7 de menos para
o pé. A sonda `sonda_h3.py` mediu a distribuição de células por isócrona:

| isócrona | resolução | km²/célula | células/escola |
|---|---|---|---|
| 15 min a pé | **r9** | ~0,105 | 18–25 |
| 45 min de carro | **r7** | ~5,16 | 76–313 |

A coluna **`resolucao_h3`** foi criada por change nova
(`isocrona_escolar_resolucao_h3`, registry 131) porque cada linha declara a
sua resolução — e porque o comentário antigo do schema dizia "r10 ≈ 1 km",
que é **falso** (r10 ≈ 15 ha). A resolução é parâmetro do dado, não do
consumidor.

## 3. Arealização: como a população vira número honesto

```
populacao_grade = Σ_setor pop_total × (área da interseção / área do setor)
```

Setor censitário é a **unidade do dado** (Tier 3 de
`docs/analises/influencia.md`); a célula é a geometria. As bordas são onde o
`#154` vive:

- setor **sem** `pop_total` não contribui (ausência, não zero);
- se **nenhum** setor intersectado tem população conhecida, a célula fica
  **`NULL`** — não 0;
- escola cujo ponto **não tem rede de ruas** (`400` do Valhalla) **não vira
  linha nenhuma**: sem dado, sem linha.

Medido no piloto: 97,3% das células com população; **19.546 células** `NULL`
por setor sem dado; **0 de 2.897 escolas** sem rede.

## 4. O piloto do ES, em números

`bash db/isocrona/piloto_es.sh` faz o ciclo ponta a ponta: exporta via `ssh`
(host local não alcança o Postgres do LXC) → pede as isócronas (8 threads) →
arealiza → carrega → resume. Resultado (2026-10-19):

| medida | valor |
|---|---|
| escolas | **2.897 de 2.897** (universo do IVET no ES, 100%) |
| linhas | 711.815 (15 min: 44.836 ≈ 15 células/escola; 45 min: 666.979 ≈ 224) |
| Σ pop a pé 15 min | p50 **4.325** · p90 **19.871** · p99 **40.590** · máx 60.984 |
| Σ pop de carro 45 min | p50 168.496 · p99 1.765.458 |

A coluna de **45 min já está extraída e armazenada mas fora da fórmula**:
entra quando o componente de transporte vier, no mesmo bloco e sem nova
fórmula — o esforço de roteamento já foi pago.

**Limitação a lembrar na expansão**: 45 min de carro cruza a fronteira
(MG/BA) e só os setores do ES estão carregados — células de borda ficam com
`populacao_grade = NULL`. Afeta só a coluna de 45 min (hoje inerte).

## 5. Como o acesso entrou na fórmula

`acesso_isocrona` entra **invertido** — mais população alcançável = menos
vulnerabilidade —, a mesma convenção da renda no bloco B:

```
acesso_isocrona = 1 − clamp(pop_acessível_15min / 40.000, 0, 1)
```

- **Default do bloco C** passa a `c(risco_sinistros, exposicao_frota,
  acesso_isocrona)`. Fora do piloto o acesso é `NA` e cai **fora do
  denominador** (#154): as 177k escolas sem isócrona não são penalizadas, e o
  C delas continua igual ao do proxy.
- **Teto 40.000 = p99 do piloto** (provisório, como os tetos do #255):
  recalibrado na expansão nacional, registrado no card e no
  `ivet-coeficientes.md` §5.1.
- O SQL (`c_isocrona`) soma `populacao_grade` a 15 min **do snapshot mais
  recente** e faz `LEFT JOIN` — escola sem linha chega `NULL`, nunca 0.

Validação **no produto** (`analytic.edumaps`, 2026-10-20): percentis do painel
batem com o piloto (4.325/19.871/40.590); acesso presente em **2.897 escolas
do ES e 0 fora**; bloco C médio ES **0,6263** vs resto **0,3634**; painel
nacional com 145.732 escolas publicáveis.

## 6. Duas armadilhas capturadas (uma por teste, uma por medição)

1. **`sum()` sobre INTEGER devolve BIGINT → `integer64` no R.** O caminho de
   produção não sofria (`ivet_blocos_linha` converte o escalar), mas a coluna
   do painel virava bomba: `quantile()`/`summary()` em `integer64` voltam
   **lixo em silêncio** (medido: p50 = 2e-320). Corrigido com
   `(...)::double precision` no SQL + asserção no teste (`a578c34`).
2. **Nunca rodar `revert/*.sql` via `psql -f`.** Durante a change da
   `resolucao_h3`, o revert foi executado como script e **dropou a coluna de
   verdade**; restaurada reaplicando o deploy. O revert do Sqitch é
   transacional e com alvo (`sqitch revert <t> --to <change>`) — um `.sql` de
   revert avulso não tem contexto nem rollback.

## 7. Próximos passos (fora deste ciclo)

- **Expansão por UF** (MG e BA são os próximos naturais: o extract de ES já
  está recortado do Sudeste) e **recalibração do teto** no conjunto nacional.
- **Componente de transporte** (45 min) usando a coluna já carregada.
- A isócrona **não é ainda capacidade de produto** (`docs/funcionalidades/`
  não mudou): é insumo do IVET. Quando o gestor puder ver a própria isócrona,
  nasce a capacidade — e aí entra a regra LGPD de agregação de
  `influencia.md`.
