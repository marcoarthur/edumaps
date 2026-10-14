# Nota técnica 125 — #240: atribuir as UEx do PDDE ao município pelo CNPJ

Continuação direta da nota 124 (fechamento da #156). A #156 deixou uma
pendência medida: **R$ 535 mi de PDDE pagos a Unidades Executoras (UEx) que
o arquivo da CGU não liga a nenhum município**.

## O problema

O PDDE (ação 0515) vai para a UEx — caixa escolar, conselho, APM,
associação de pais e mestres —, que tem CNPJ próprio. O CSV da CGU traz, por
linha, o `CÓDIGO MUNICÍPIO SIAFI`; para as UEx de PDDE esse campo vem
**vazio**. Sem ele, e sem o CNPJ da prefeitura (que não é o da UEx), o loader
não conseguia resolver o município e as linhas caíam em `cgu_orfaos.csv` com
o motivo `pdde_sem_siafi`.

Números do relatório real (CGU 2025):

| Motivo | Grupos | Valor |
|---|---|---|
| `pdde_sem_siafi` | 24.529 | R$ 534,87 mi |
| `pdde_siafi_sem_correspondencia` | 34 | R$ -1,54 mi |
| `municipio_sem_cnpj_nem_siafi` | 1 | R$ 0,14 mi |

Os R$ 535 mi são ~27% da tabela `transferencia_educ` inteira — não é ruído.

Havia também um caso que parecia de outra família: a **APAE-DF** caiu como
órfã porque o de-para SIAFI→IBGE é **derivado das próprias linhas de
prefeitura**, e o Distrito Federal (SIAFI 9701) não tem prefeitura na base —
logo o DF inteiro ficou fora do mapa derivado. Resolver o DF e resolver as UEx
sem SIAFI eram o mesmo problema.

## A decisão: CNPJ → município, com cache

Fonte escolhida pelo developer entre as alternativas (tabela estática
linha-a-linha, bulk da RFB, API por CNPJ): **API por CNPJ com cache
persistido**.

- **BrasilAPI** (`/api/cnpj/v1/{cnpj}`), primária, e **Minha Receita**
  (`/{cnpj}`), fallback. Ambas servem os dados abertos da Receita Federal e
  devolvem `codigo_municipio_ibge` (validado: o `codigo_municipio` delas é
  igual ao código SIAFI da CGU).
- Cache em `clean.cnpj_municipio` (migration `cnpj_municipio`). **Só CNPJs
  resolvidos entram** — nada de cache negativo: uma falha definitiva pode
  vir a resolver depois, e reconsultar alguns poucos por carga é barato.
- Throttle de 0,2 s e retry com backoff. Medição de rajada (30 chamadas sem
  sleep): 29/30 HTTP 200 e uma falha transitória — sem rate-limit declarado,
  mas retry é obrigatório.
- Um erro **4xx (exceto 429)** é resposta definitiva ("não está na base",
  não aborta).
- Falha de rede (5xx/429/timeout) é retentada **em cada fonte** e, esgotada,
  passa à **fonte seguinte**. Um CNPJ que **nenhuma** fonte responde vira
  **órfão** (`pdde_cnpj_nao_resolvido`) e **não** entra no cache (a próxima
  execução tenta de novo). Só uma **rajada** (`max_falhas_seguidas`, 30) de
  falhas seguidas morre alto — aí as fontes estão fora e orfanar em massa
  seria mentir.

> **A primeira versão estava errada e a carga real expôs.** O `_tentar`
> morria na falha persistente da **primária**, sem chegar ao **fallback**, e
> uma indisponibilidade transitória da BrasilAPI (upstream 503 → 5xx)
> derrubou a carga inteira já no **primeiro** CNPJ. Corrigido no PR #245
> (fallback a sério + guard de rajada). Detalhe na secção \"O que a carga real
> ensinou\".

## Ordem de resolução (em `CGU.pm`)

Por linha de PDDE não-estadual:

1. pelo `CÓDIGO MUNICÍPIO SIAFI` (de-para derivado, como antes);
2. senão, pelo **CNPJ da própria UEx** (provedor + cache);
3. senão, órfão — com o motivo certo:
   - `pdde_siafi_sem_correspondencia` (tinha SIAFI e não casou),
   - `pdde_cnpj_nao_resolvido` (CNPJ consultado e não encontrado),
   - `pdde_sem_siafi` (sem SIAFI e sem CNPJ para tentar).

O nome do município, nas UEx resolvidas por CNPJ, vem da própria API — é o
que cobre o **DF** (5300108), ausente do SICONFI `/entes` (esfera M).

## Duas armadilhas do caminho de execução

**1. A fase de CNPJ é longa e o watchdog lê travamento.** Resolver ~24,5 mil
CNPJs a ~0,9 s cada é **~6 h**. O `Runner` tem `stall_timeout` de 600 s e
considera "progresso" ficheiros em `data/ingestao` + contadores de
`import_metadata`/`dados_ibge`/`ibge_agregados`. Durante a fase de CNPJ nada
disso muda → `[STALL]` e o job morre.

Correção: o provedor grava **linha a linha** (não em lote no fim) e a
contagem de `clean.cnpj_municipio` entra na assinatura de progresso. Dois
ganhos: o watchdog vê progresso, e um job que morra a meio **não perde o
cache** (a próxima execução retoma de onde parou).

**2. A tabela de cache não é uma "fonte".** Ela não entra em `tabelas()` nem
ganha `import_metadata` próprio — é enriquecimento interno, documentado por
`COMMENT`. O verify de `import_metadata_fontes_p0` só olha tabelas nomeadas,
então não esbarra nela.

## Validação

- **Migration:** `db/fixtures/ci_db.sh up` + `verify` (banco limpo) — deploy
  e verify da `cnpj_municipio` **ok**; `verify` global `Verify successful`.
- **Amostra real:** 400 CNPJs de UEx retirados de `cgu_orfaos.csv`
  (`pdde_sem_siafi`), resolvidos pela API: **400/400 (100%)**, R$ 9,09 mi da
  amostra — acima do critério de aceite (≥ 99%).
- **Cadeia completa com cache:** 8 CNPJs resolvidos contra um Postgres real,
  gravados em `clean.cnpj_municipio`; a segunda passada resolve **sem
  rede** (0 s).
- **Testes:** `t/02-models/cnpj_municipio.t` (11 casos: primária, fallback por
  404, fallback por **falha transitória**, não-encontrado, retry, CNPJ que
  nenhuma fonte responde vira órfão, **rajada de falhas morre alto**, formato
  inválido, cache hit/miss, allowlist), `t/05-tasks/cgu_loader.t` (inclui o
  caminho novo do resolver e um `run` ponta a ponta com o provedor dublê),
  `t/02-models/allowlist_real.t` — **PASS**.

## O que a carga real ensinou

A primeira execução real (2026-10-14, produto, `cgu` 2025) **falhou**. Não por
bug de dado, mas por **robustez**: ela morreu no **primeiro** CNPJ.

O CNPJ `00000049000144` devolveu 5xx persistente na BrasilAPI **e** na Minha
Receita. O `_tentar` foi desenhado para morrer nisso — \"rede/5xx esgotado =
morre alto\" — e morria **antes** de tentar o fallback. Uma indisponibilidade
transitória (a BrasilAPI embrulha um 503 do upstream como 500) derrubou uma
carga de horas no primeiro item. Repetido minutos depois, o mesmo CNPJ
respondeu **200 OK** (São Paulo): era transitório, não determinístico.

Duas correções:

1. **O fallback passou a ser usado de facto.** Esgotados os retries numa
   fonte, tenta-se a seguinte; um 4xx continua definitivo.
2. **Guard de rajada** (`max_falhas_seguidas`): um CNPJ isolado que ninguém
   responde vira órfão e **não** derruba a carga; só uma sequência de 30
   falhas seguidas morre — o sinal de indisponibilidade real.

O mesmo padrão vale para qualquer fonte comunitária sem SLA: **o item
problemático não pode matar o lote**. A distinção entre \"este aqui não existe\"
e \"as fontes estão fora\" tem de estar no código, não na esperança.

## Notas de operação

- A **primeira** execução real paga as ~6 h (popula o cache). As seguintes
  resolvem só os CNPJs novos — tipicamente poucos por mês.
- Fontes comunitárias: se uma cair, a outra responde; o allowlist declara as
  duas (`brasilapi_cnpj`, `minhareceita_cnpj`).
- O CSV de órfãos passa a ter `pdde_cnpj_nao_resolvido`: é a lista curta do
  que **nem os dados abertos da RFB** souberam responder.
