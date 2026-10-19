# Nota técnica 153 — a leitura crua do entorno nas cartelas da área de influência

O painel "Área de influência (IVET)" já desenhava os anéis de 500 m / 1 km /
2 km, mas a cartela de cada anel dizia apenas **qual era a finalidade
metodológica** daquele raio — informação sobre o método, não sobre o lugar. O
usuário quis o inverso: **o que existe naquele anel**, lido da mesma fonte que
alimenta o bloco B do IVET, em texto corrido no próprio mapa.

A entrega fecha isso, restrita à escola do gestor (LGPD), mantendo as três
regras do projeto intactas: **ausência não é zero (#154)**, **o IVET não é
materializado no banco**, e a **mobilidade (C) / isócrona seguem `NA`**.

Issues de contexto: **#255** (camada de influência), **#137** (IVET como
produto versionado), **#154** (ausência ≠ 0).

## Entregas

| PR / commit | Merge | Escopo |
|---|---|---|
| **#287** | `08c7f15` | 3 commits: `33aca3a` `feat(backend)`, `03f122f` `feat(frontend)`, `eee2f7b` `docs` |

## 1. A cartela deixou de falar do método

O trabalho anterior já tinha dado ao anel uma cartela (`L.divIcon`,
`interactive: false`) com o raio e a área. Este ciclo troca o **conteúdo**, não
a mecânica:

```
500 m
5.362 hab · 6.867 hab/km²
0,7808 km²
```

A terceira linha (área, `πr²`) fica; a **finalidade metodológica saiu da
cartela** — decisão explícita do usuário — e passou a ser o texto da **legenda
do painel**, que é onde ela faz sentido: explica o método uma vez, para todos
os anéis, em vez de repetir a mesma frase em três balões sobrepostos ao mapa.

Corolário útil dessa separação: **cartela = leitura (varia por anel), legenda
= método (varia por coluna)**.

## 2. `entorno_por_raio()`: a leitura por anel no backend

`EduMaps::Model::Influencia` ganhou `entorno_por_raio()`, que lê
`clean.escola_entorno_socioeconomico` (Censo 2022 arealizado na área de
influência) para os três raios e devolve um hash por `raio_m`. `status()` o
anexa em `properties.entorno` de cada anel do GeoJSON.

**Decisão de contrato: expor o objeto inteiro** (população, densidade, renda,
instrução, saneamento, `cobertura_pct`, `n_setores`, `versao`), não só os dois
campos que hoje aparecem na tela. O custo é umas dezenas de bytes por anel; o
ganho é que **trocar o indicador exibido vira mudança só de frontend**, sem
nova rodada de deploy de backend.

Duas proteções, ambas testadas:

- **Ausência ≠ 0 (#154).** Sem linha no entorno, ou componente sem insumo, o
  valor é `null` — nunca `0`. `cobertura_pct` **não** é gate de presença: a
  escola 32000030 tem `cobertura_pct=0.0` com `pop_total=6`, e uma leitura de
  6 habitantes é informação, não ausência.
- **Degraçamento.** `_tem_tabela_entorno()` consulta `to_regclass`; se a change
  do entorno não estiver aplicada, a API responde sem `entorno` em vez de
  rebentar. O endpoint continua de pé em base desatualizada.

## 3. `entornoLabel()` — a formatação é onde o zero cru mata a usabilidade

Todo o texto da cartela é função pura em
`frontend/edumaps/src/features/gestor/constants/influencia.js`
(`ringCartela`, `entornoLabel`, `formatCount`, `formatDensity`), testável sem
DOM e sem mapa.

O detalhe que merece registro: **densidade `0` crua seria lida como ausência**
(exatamente a inversão que #154 proíbe). Por isso a regra:

- abaixo de 10 hab/km² → **1 casa decimal** (`4,3 hab/km²`);
- acima → **0 casas** (`6.867 hab/km²`);
- `null` → `—` (nunca `0`).

Escala também no mapa: `CARTELA_W` 210 → 240 px para a linha de três partes
não estourar.

## 4. Validação

- **Backend**: `prove -vl t/04-api/gestor/influencia.t` — 6 subtestes PASS,
  incluindo o novo "leitura do entorno socioeconômico por raio", que insere
  linhas sintéticas e asserta `entorno: null` no anel **sem** linha. Suíte
  `t/04-api/gestor` 13/14 (a exceção, `finance_siope.t`, falha no `main`
  limpo — dependência de fila do Minion).
- **Frontend**: `vitest` `src/features/gestor` 44/48 arquivos;
  `influencia.test.js` 10/10. As 4 falhas são de upload multipart e
  reproduzem no `main` limpo (reproduzidas com `git stash`).
- **API real** (500 m 5362/6867,39 · 1 km 20039/6416,18 · 2 km 68556/5487,59).
- **CDP headless** no painel do gestor: 3 cartelas com a leitura,
  `overlaps: []`, `clipped: false`; desligar o anel de 1 km → 2 cartelas e 2
  anéis. Depois **validação visual aprovada pelo developer**.
- **CI do PR**: verde (Perl contra banco de fixtures + vitest).

## 5. Higiene do ciclo

- Conta descartável de validação `validador.ivet@edumaps.local` (gestor 53) e
  suas sessões **removidas** de `clean.gestores` / `clean.sessoes` /
  `clean.session_tracking` antes do merge; a API volta a responder `401` com o
  token antigo, o que confirma a guarda `_gestor_inep_ok`.
- `node_modules/` órfão criado por um `npx vitest` rodado da raiz do repo
  (sem `package.json` na raiz) foi removido — working tree limpa.

## Pendências herdadas

- **F nacional** do bloco F rodando em `backend.edumaps` (PID 2905753): ao fim,
  **calibrar os tetos provisórios** (fogo=1, carbono=500) → nova change/versão.
- Bloco **C (mobilidade/isócrona)** segue `NA`: sem motor OSRM/Valhalla,
  `clean.isocrona_escolar` vazia.
- Filas #168 (reduzir escopo), #138 (reavaliar após IVET congelar), Fila 6
  (Z:10454).
