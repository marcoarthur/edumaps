# Nota técnica 150 — Ciclo dos tetos do IVET, F retomável, CI verde e o O(n²) do extrator

Esta nota fecha o ciclo de 2026-10-18 que começou no **lastro dos tetos** do IVET
(fila de revisão, §5) e terminou com **quatro PRs mergeados** — incluindo a
descoberta e correção de um bug de complexidade no extrator do bloco F que
condenava todos os recortes grandes de SP.

Issues de contexto: **#278** (bloco F), **#137** (IVET como produto versionado),
**#283** não é issue; **#268** (entorno, em curso).

## Entregas

| PR | Merge | Escopo |
|---|---|---|
| #281 | `ba178ff` | `docs`: lastro dos tetos (`ivet-coeficientes.md` §5, `ivet.md` §4.5.1/4.5.3, `fontes/meio-ambiente.md`, `ivet-card.yml`) |
| #282 | `8f5da5c` | `feat(backend)`: drive do F **retomável por região** (`mapbiomas_risco.sh` + `regioes_do_estado.pl` com 3º campo *pendentes*) |
| #283 | `5fcefe6` | `fix(ci)`: **`backend-tests` verde** de novo (verify como piso + `FindBin` no cpanfile) |
| #284 | `3b8b3c1` | `fix(backend)`: agregação do extrator F **O(n²) → O(n)** |
| `0c7ba22` | (direto) | `chore(tools)`: versiona o monitor de tarefas longas (`tools/notify/status_long_tasks.sh`) |

## 1. Lastro dos tetos (PR #281) — e a decisão que não se tomou

Os itens 2–4 da fila de revisão ganharam **§5 "Lastro dos tetos"**: tabela
componente × teto × p50/p90/p99 × fonte. Medido em `edumaps_dev`:

- **E homicídio**: p50 ≈ 0, **p90 = 46,3**, p99 = 103,5 (média municipal 2021–23).
- **D distância à UBS**: p50 = 0,54 km, **p90 = 7,25 km** (13,4% > 5 km);
  **D equipes/10 mil**: p50 = 3,30, p90 = 8,39.
- **C sinistros**: p90 = 429; **G autonomia**: p90 = 30,9.

Decisão de produto: **não alterar os tetos publicados** (8 em D, 50 em E) — a
leitura é declaradamente **relativa (≈ p90)**. Alternativas normativas ficam
registadas e não descartadas: **PNAB** (2,86–5,0 equipes/10 mil — o p50 medido,
3,30, cai exatamente na faixa), **OMS/PAHO** (> 10 homicídios/100 mil =
epidêmico), **Atlas da Violência 2026** (referência nacional 23,4).

**Sem limiar na literatura**: a distância de 5 km é convenção da própria view, e a
literatura de trânsito mede mortes, não sinistros. O teto de D (5 normativo) e de
E (40/25) segue **aberto na fila**, à espera de decisão — os números atuais ficam
enquanto isso.

**Lição de escopo**: `docs/funcionalidades/` **não** foi tocado neste ciclo. O IVET
não é capacidade exposta na UI (aparece só como contexto em
`InfluenciaPanel.svelte`); nenhum dos quatro PRs mudou capacidade de negócio.
Registrado como gap consciente, não como esquecimento.

## 2. F retomável (PR #282)

O drive por UF rodava a lista inteira e **não sabia o que já estava carregado** —
uma interrupção obrigava a recomeçar. Agora `regioes_do_estado.pl` emite um 3º
campo (**pendentes**) e `mapbiomas_risco.sh` **pula** a região completa. Foi o que
permitiu reiniciar o F de SP direto em Campinas, sem reprocessar os 13 blocos OK.

## 3. CI verde (PR #283) — duas falhas encadeadas

O `backend-tests` estava **vermelho há meses**, e a primeira falha **mascarava** a
segunda (o passo seguinte só roda se o anterior passar):

1. `verify/import_metadata_uniq_table_name.sql` esperava contagem **exata** de 31
   linhas; `mapbiomas_escola` e `mapbiomas_escola_risco` (posteriores) somam mais 2
   → 33. A asserção 3 virou **piso** (`n < 31`), que era o que o comentário já
   declarava. **Editar verify não muda `change_id`** (metadados: nome, `requires`,
   pai) → registry intacto, sem tocar `sqitch.plan`.
2. `backend/cpanfile` não declarava **`FindBin`**, usado por
   `script/ingestao/regioes_do_estado.pl` (que entrou no PR #280) — só apareceu
   porque o inventário de dependências nunca era alcançado enquanto o verify
   falhava.

**Lição**: um gate vermelho **encobre** os defeitos dos passos seguintes; cada
correção pode expor a próxima. Validar com o CI completo, não só o passo corrigido.

## 4. O bug O(n²) do extrator (PR #284) — o achado do ciclo

A run do F de SP morria **em Campinas**, sempre. O sintoma era bom demais para ser
ignorado: o R ficava em **99% de CPU sem I/O nenhum** por minutos.

### Diagnóstico

- **Modelo empírico**: os 13 blocos concluídos ajustavam quase perfeitamente
  `t = 86,5 + 0,00264·n²` (118→124s, 444→623s, 485→727s). Um termo **quadrático**
  no número de escolas.
- **Extrapolação**: 1875 escolas → **~9.400s (2,6h)**, contra
  `stall_timeout = 3600s` → o bloco **nunca** completaria; cada bloco grande
  queimaria 3–4 tentativas (~4h) e seguiria como `FALHOU`.
- **Cache do GDAL**: a extração via `/vsicurl` já tinha terminado (`rchar`
  congelado em 19 MB) — o processo estava em **código puro de R**.
- **Backtrace (gdb)**: só frames `libR` (`Rf_translateChar` / `Rf_applyClosure`) —
  strings, não terra/GDAL. Fechava o caso: `chave(d) == k` **dentro** do `lapply`.

### Causa

```r
ids <- unique(chave(d))
linhas <- lapply(ids, function(k) {
  dd <- d[chave(d) == k, , drop = FALSE]   # paste0 de ~13M linhas POR ESCOLA
```

`chave(d)` recomputava `paste0()` sobre **todas** as linhas para **cada** uma das
1875 escolas: `O(n² · pixels)`. Para blocos pequenos, invisível; para grandes,
horas de CPU e GC churn (RSS 2,6 GB).

### Correção

```r
chaves <- chave(d)
ids <- unique(chaves)
idx <- split(seq_len(nrow(d)), chaves)     # O(linhas), uma vez

linhas <- lapply(ids, function(k) {
  dd <- d[idx[[k]], , drop = FALSE]        # O(linhas da chave)
```

### Validação

- **Equivalência exata** (`identical()`) velho vs novo em dados sintéticos: 300
  chaves com NA/peso 0, chave só de `solo`, `peso = 0`, e `d` vazio.
- **Escala**: velho 0,14/0,39/**1,20s** vs novo 0,07/0,15/**0,28s** (K=100/200/400).
  O velho é ∝ K·n (≈0,2 µs/op); o novo é linear (≈14 µs/linha).
- **Medido em produção depois do fix**: **Campinas OK em 233s** — 40× menos que a
  previsão quadrática, e **15× abaixo** do stall. CI verde em 13m05s
  (run `39150832549`).

### Deploy e retomada

`rex prepare` + `deploy_backend_dev`; md5 do template confere
local↔`backend.edumaps`; imagens locais `backend`/`minion` reconstruídas. F
reiniciado com log em `>>` (preserva o histórico que o monitor de status lê) e
retomou direto em Campinas — **17 OK / 0 FALHOU** no primeiro snapshot.

## 5. Monitor de tarefas longas (versionado)

O pedido do developer neste ciclo foi **status a cada 20 min** no Telegram
enquanto as tarefas longas rodassem. O loop nasceu em `/tmp/opencode/status_loop.sh`
e agora é **`tools/notify/status_long_tasks.sh`** (`main` direto — ferramenta
local, não deployável): `ativo=1` se **ao menos uma** tarefa roda; encerra quando
as duas param; o README ganhou uso e o **aviso de fuso** (hosts `*.edumaps` em
**UTC**, host local em **UTC-3** — timestamps ~3h à frente, o que quase rendeu uma
investigação falsa de loop morto).

## Pendências

- **#268 (entorno)**: 25/27 UF; faltam **SP** (em execução) e **TO**. Só fechar ao
  terminar.
- **F de SP**: run retomada em background; blocos grandes agora são viáveis.
  Próximo insumo para o item 5 da fila (componentes/pesos do F).
- **Tetos D/E**: decisão em aberto (relativo p90 × normativo) — nada muda até o
  developer decidir.
- **Mobilidade (bloco C, isócrona)**: bloqueada por infra de roteamento (sem
  OSRM/Valhalla; `clean.isocrona_escolar` vazia).
- **Fila de follow-up do stall**: o detector segue sem ver progresso **dentro** de
  fases longas do R (heartbeat de fases é a evolução natural se algum recorte maior
  voltar a passar de 3600s).
