# IVET — fórmula, coeficientes e decisão de leitura

> **Issue**: #137 · **Escopo**: entregáveis 1 (fórmula documentada/versionada),
> 2 (decisão de leitura), 3 (núcleo reprodutível + extração dos blocos B/E/G),
> 4 (vigência/retreino, §4.6) e 5 (card do índice, §4.7).
> **Versão da fórmula**: `ivet-v1.2` (histórico: `ivet-v1.1`, `ivet-v1.0`) · **Data**: 2026-10-17.
> **Decisão de leitura**: **territorial (escola em contexto)** — ver §1.
> **Estado**: documento vivo. A composição do índice-alvo está fixada; os **pesos
> das dimensões territoriais** dependem de dado (#125–#127) e do versionamento
> de dataset (#135), e estão marcados como pendentes.
> **Reconciliação (código)**: o canônico **B** foi declarado na base e **A** e
> **D** foram postos em quarentena (`DEPRECATED`) — ver §3.1.

## 0. Resumo

O EduMaps **não tem hoje um único índice chamado IVET**, e o número que o gestor
consome **não é produzido por uma fórmula documentada**. Existem **quatro**
sistemas de score independentes, com definições sobrepostas e divergentes:

| # | Sistema | Onde | Produz | Status |
|---|---------|------|--------|--------|
| A | `clean.censo_escolas_scores` (view SQL) | `data_pipeline/deploy/scores_view.sql` | 11 scores, 0–10 | **morto** (sem consumidor) |
| B | `clean.mv_escolas_scores` (MV SQL) | `data_pipeline/deploy/escolas_scores.sql` | 6 scores, 0–10 | **canônico** (ranking/similaridade/cluster) |
| C | `EduMaps::Model::Indicator::School::*` (Perl) | `backend/lib/EduMaps/Model/Indicator/School/` | 8 indicadores, 0–1 | **vivo** (escolas semelhantes, perfil) |
| D | `CensoEscolas::_compute_score` (SQL-in-Perl) | `backend/.../ResultSet/CensoEscolas.pm` | 4 scores, 0–1 | **morto** (sem chamador) |

Nenhum dos quatro produz um **agregado único**. O IVET como número só existe
como conceito nos docs e como *stub que morre* no backend:

- `CensoEscolas::with_vulnerability_score` — `die "ainda não implementado"`
  (`ResultSet/CensoEscolas.pm:316`).
- `Controller::School::scores` — operador *yada-yada* `...` (a rota
  `/api/school/scores` existe e falha); `Roles::Business::School::Scores` tem
  implementação, mas **não é composta** por ninguém.

> **Consequência prática**: "o IVET que o gestor consome tem coeficientes com
> origem incerta" (issue #137) é literal. O que o gestor vê vem de **B** (via
> `analytics.ranking_escola` e `Rank::School`) e de **C** (via `Profile.pm`,
> para escolas semelhantes) — dois sistemas que nunca foram reconciliados.

---

## 1. Decisão de leitura — territorial (escola em contexto)

**Decidido em 2026-10-15** (issue #137, entregável 2): o IVET é um índice
**territorial**.

O que isso significa, e o que muda na leitura de **todos** os coeficientes:

- **A pergunta do índice é territorial**: *"onde a falta de acesso, a
  precariedade da infraestrutura e a insuficiência de recursos se sobrepõem no
  território onde a escola está?"* A escola é o **ponto de observação**, não a
  unidade que o índice mede.
- Os coeficientes passam a **descrever o entorno** (contexto, saúde, exposição a
  risco, mobilidade, meio ambiente) e deixam de ser lidos como atributos
  exclusivos do prédio escolar.
- As dimensões **escolares** já existentes (infraestrutura, docentes, gestão,
  etc. — sistemas B e C) **continuam existindo**, mas passam a ser *um bloco de
  contexto dentro do território* — não o índice inteiro.
- A leitura **territorial** é a que justifica priorização de investimento
  (obras, políticas de acesso, segurança), coerente com o problema central do
  projeto em `docs/analises/fontes_de_dados.md`.

Consequência de método: um índice territorial só tem sinal quando as dimensões
**de contexto territorial** existirem (saúde, segurança, conectividade,
mobilidade, meio ambiente — #125/#126/#127). É por isso que a promoção a produto
**não pode** acontecer antes de essas dimensões terem dado — ver §4.3.

---

## 2. Sistemas de score existentes (fórmulas exatas)

Convenções: `in_*` = indicador binário do Censo (0/1); `qt_*` = contagem;
`COALESCE(x,0)` = ausência tratada como 0. "Ordem" = ordem de agregação.

### 2.1 Sistema A — `clean.censo_escolas_scores` (view) · **morto**

Definição: `data_pipeline/deploy/scores_view.sql`. Todos terminam em
`ROUND( numerador / N * 10, 1 )` → escala **0–10**, um único nível de agregação.

| Score | Numerador (soma) | ÷N |
|-------|------------------|----|
| `score_infra_essencial` | `agua_potavel + agua_rede_publica + GREATEST(esgoto_rede_publica, esgoto_fossa_septica) + energia_rede_publica + lixo_servico_coleta` | 5 |
| `score_tecnologia` | `computador + internet + banda_larga + laboratorio_informatica + equip_lousa_digital + equip_multimidia` | 6 |
| `score_espacos` | `biblioteca + laboratorio_ciencias + quadra_esportes + patio_coberto + cozinha + refeitorio + auditorio + parque_infantil` | 8 |
| `score_acessibilidade` | `banheiro_pne + rampas + corrimao + sinalizacao + vao_livre + pisos_tateis + sala_atendimento_especial` | 7 |
| `score_apoio_multidisciplinar` | 7× `CASE WHEN qt_prof_X > 0` (psicólogo, fono, nutricionista, assist. social, trad. libras, bibliotecário, segurança) | 7 |
| `score_material_pedagogico` | 7× `in_material_ped_*` | 7 |
| `score_diversidade_oferta` | 8× `in_comum_*` / `in_profissionalizante` | 8 |
| `score_gestao_participacao` | `conselho_escolar + ass_pais + gremio + redes_sociais` | 4 |
| `score_internet_custom` | ponderado: `internet 3 + banda_larga 3 + lousa_digital 1 + laboratorio_informatica 3 + internet_aprendizagem 2 + acesso_internet_computador 1 + aces_internet_disp_pessoais 1 + internet_comunidade 2` | 16 |
| `score_acessibilidade_custom` | ponderado: `rampas 3 + elevador 2 + banheiro_pne 3 + sinal_sonoro 1 + pisos_tateis 2` | 11 |
| `score_support_staff_custom` | ponderado: `psicologo>0 3 + nutricionista>0 2 + bibliotecario>0 2 + coordenador>1 1 + assist_social>0 3` | 11 |

Os 3 últimos estão marcados no SQL como *"SCORES CUSTOMIZADOS DE VOCÊS"* —
pesos sem justificativa registrada. **Sem consumidor**: só existem as classes
`Schema::Result::CensoEscolasScores` e `Schema::ResultSet::CensoEscolasScores`.

### 2.2 Sistema B — `clean.mv_escolas_scores` (MV) · **canônico**

Definição: `data_pipeline/deploy/escolas_scores.sql`. Escala **0–10**,
`ROUND(..., 2)`. Cada sub-score é uma soma ponderada de componentes; **não há
agregação final** (os 6 scores vivem lado a lado). Base: escolas ativas
(`tp_situacao_funcionamento = 1`).

| Score | Fórmula (resumo) |
|-------|------------------|
| `score_capacidade_atendimento` | `0.4·10·(1 − (qt_mat_bas/qt_salas_utilizadas)/50) + 0.2·(etapas/7·10) + 0.2·(qt_mat_bas_int/qt_mat_bas·10) + 0.2·(alimentação?10:0)` |
| `score_infraestrutura` | `média( A,B,C,D )` onde A=5 colunas básicas, B=9 itens pedagógicos, C=5 de acessibilidade, D=5 de tecnologia (cada `÷N·10`) |
| `score_capacitacao_docente` | `0.3·sup_grad/quadro·10 + 0.3·pós/quadro·10 + 0.2·concurso/quadro·10 + 0.2·especializações/quadro·10` |
| `score_diversidade_discente` | `0.35·racial + 0.25·gênero + 0.20·PcD + 0.20·EJA` (cada bloco em 0–10) |
| `score_capacidade_gestora` | `0.3·qualificação + 0.2·especialização_gestão + 0.2·proporção_gestor_aluno + 0.2·colegiados + 0.1·acesso_meritocrático` |
| `score_sustentabilidade` | `(energia_renovável?10:0 + resíduos?10:0 + média(área_verde, área_plantio)·10 + educação_ambiental?10:0) / 4` |

Consumidores vivos:
`analytics.ranking_escola` (job `bin/ranking.pl`), `Model::Rank::School`
(`indicator_registry` — os 6 scores + IDEB), `SchoolEmbedding`/pgvector,
`View::ClusterEscola`, `Controller::Rank`.

### 2.3 Sistema C — `EduMaps::Model::Indicator::School::*` (Perl) · **vivo**

Base: `EduMaps::Model::Indicator` — `calculate` = **média ponderada** dos
componentes:

```
score = Σ(componente_i · peso_i) / Σ(peso_i)      # escala 1 → [0,1]
```

Normalização do componente (`clean_value`): `undef`/não-numérico → `0`; campos
`in_*` → *clamp* para `{0,1}`; *closures* devolvem razões (esperadas em `[0,1]`).
Saída com 4 decimais.

| Indicador | Nome | Componentes (peso) |
|-----------|------|--------------------|
| `ifs` | Infraestrutura Física e Saneamento | cozinha 1, energia 2, esgoto_rede 2, esgoto_fossa 1, banheiro 1, refeitório 1, água_potável 2 |
| `itd` | Tecnologia Digital | internet 1, banda_larga 1, wifi(`tp_rede_local≥2`) 1, dispositivo aluno 1, multimídia 1, lousa digital 1, `qt_dispositivos≥10` 1 |
| `ips` | Qualidade Pedagógica | 5 materiais 1 cada, pedagogo 2, psicólogo 2, (biblioteca ou bibliotecário) 2 |
| `ige` | Qualidade da Gestão | conselho 1, ass_pais_mestres 1, grêmio 1, proposta_pedagógica(própria/adaptada) 2, internet_adm 1, (gestão ou coordenador) 1 |
| `iai` | Acessibilidade e Inclusão | rampas 2, corrimão 2, pisos_táteis 2, sinal_visual 2, vão_livre 2, AEE 3, trad_libras 3, revisor_braille 3 |
| `ioc` | Integralidade e Oferta | creche..médio 6×1, EJA 1, profissionalizante 1, indígena/quilombola 1, atividade_complementar 1 |
| `iqd` | Qualificação Docente | `sup_grad/qt_doc 3`, `pós/qt_doc 2`, `qt_mat_bas/qt_doc 3` ⚠️ razão **>1**, fora de `[0,1]` |
| `ise` | Nível Socioeconômico | `(nível_ise − 1)/6`, peso 1 |
| `ran` | *dummy* randômico | gerador aleatório — **não é indicador** |

Usados por `SchoolQuality` (`build_feature_vector` = `[ifs,itd,ips,ige,iai,ioc]`)
→ `Profile.pm` (escolas semelhantes) e `CensoEscolas::with_all_scores`.
`IQD`/`ISE` só aparecem em teste (`t/02-models/indicators/quality.t`).

⚠️ `iqd` viola a premissa `[0,1]` (razão aluno/docente) — sinal de normalização
incompleta, a corrigir junto da promoção.

### 2.4 Sistema D — `CensoEscolas::_compute_score` (SQL-in-Perl) · **morto**

`_compute_score` monta `ROUND( Σ(peso·CASE) / Σpeso, 2 )` → **0–1**. Quatro
scores, expostos por `with_all_scores` (ordena `desc` pelos quatro), que **não é
chamado por ninguém**:

| Score | Pesos |
|-------|-------|
| `internet_score` | internet 3, banda_larga 3, laboratório_informática 3, internet_aprendizagem 2, internet_comunidade 2, acesso_internet_computador 1, aces_internet_disp_pessoais 1, lousa_digital 1 |
| `accessibility_score` | rampas 3, banheiro_pne 3, elevador 2, pisos_táteis 2, sinal_sonoro 1 |
| `support_staff_score` | psicólogo>0 3, assist_social>0 3, nutricionista>0 2, bibliotecário>0 2, coordenador>1 1 |
| `infrastructure_score` | biblioteca 2, lab_ciências 2, quadra 2, refeitório 2, cozinha 1, banheiro 1, água_potável 3, energia 2, salas>10 1, salas_climatizadas>5 2 |

### 2.5 Stubs e código morto (o "IVET" que não existe)

| Artefato | Comportamento | Nota |
|----------|---------------|------|
| `with_vulnerability_score` | `die "ainda não implementado"` | o único nome "vulnerabilidade" no código |
| `with_critical_infra_highlight` | `die` | idem |
| `with_highlight_badges` | `die` | idem |
| `with_extra_activities_score` | `die` | idem |
| `Controller::School::scores` | `...` (yada) | rota `/api/school/scores` existe e falha |
| `Roles::Business::School::Scores` | implementado, **não composto** | e com lógica invertida (`unless size==0`) |

---

## 3. Qual sistema é canônico

- **B (`clean.mv_escolas_scores`) é o canônico do produto.** É o único com
  consumidores vivos de produto (ranking, similaridade, cluster) e é o que
  alimenta o que o gestor vê (via `Rank::School`).
- **C** é a **camada de análise/feature** (similaridade e perfil) — legítima,
  mas sem fórmula reconciliada com B; há sobreposição direta (ex.: os dois têm
  "infraestrutura", "acessibilidade", "tecnologia", "gestão").
- **A** e **D** são **legado morto**: manter o código como referência histórica,
  mas **não** são fonte de verdade e não devem ser consumidos por código novo.
- **O IVET agregado não existe.** Definir a fórmula-alvo é o que a #137
  entregável 1 faz (§4).

### 3.1 Onde a decisão está fixada (código, não só doc)

- **B** — `COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores` declara "índice
  canônico do produto (#137)" (change `quarantine_censo_escolas_scores`).
- **A** — `COMMENT ON VIEW clean.censo_escolas_scores` marca **DEPRECATED** na
  própria base; as classes `Schema::Result{,Set}::CensoEscolasScores` levam o
  mesmo aviso.
- **C** — `Model::Domain::SchoolQuality` e `Model::Indicator` têm cabeçalho
  declarando "camada de análise, NÃO o índice canônico".
- **D** — `ResultSet::CensoEscolas::with_all_scores` e os 4 scores levam
  cabeçalho `DEPRECATED` (único consumidor restante: `sandbox/censo.pl`).


---

## 4. Fórmula-alvo do IVET `ivet-v1.2` (territorial)

### 4.1 Estrutura e ordem de agregação

Ordem fixada (de baixo para cima):

1. **Componente** — variável bruta (`in_*`, `qt_*`, taxa), normalizada para
   `[0,1]`.
2. **Dimensão** — média ponderada dos componentes: `d = Σ(c_i·w_i)/Σw_i ∈ [0,1]`.
3. **IVET** — média ponderada das dimensões: `IVET = Σ(d_j·W_j)/ΣW_j ∈ [0,1]`.

Normalização por componente (regra única, herdada do sistema C):
`undef`/não-numérico → `0`; binário `in_*` → `{0,1}`; proporção → `clamp(0,1)`;
contagem → `clamp(0,1)` pela razão contra um teto documentado (nunca crua — o
bug do `iqd` é justamente uma contagem crua).

### 4.2 Dimensões (blocos) e status

| Bloco | Dimensões | Fonte | Status |
|-------|-----------|-------|--------|
| **A. Escola** | infraestrutura, docentes, gestão, oferta, acessibilidade, tecnologia | B e C (**reconciliados**: B canônico, C opcional — §4.4.1) | **implementado** (um só: B canônico) |
| **B. Socioeconômico** | instrução + renda do responsável + saneamento do setor censitário | `censobr`/IBGE (#123, #238) | **implementado** (extração: arealização do setor, §4.5) |
| **C. Acesso/mobilidade** | exposição viária (sinistros RENAEST + frota RENAVM); isócrona pendente | #125 | **implementado** (proxy — §4.5.5; isócrona pendente) |
| **D. Saúde** | distância à UBS + cobertura de atenção básica | CNES + SISAB/PMMB (`analytics.acessibilidade_saude`) | **implementado** (mapeamento R, §4.5.3) |
| **E. Segurança** | BrazilCrime (município, célula ≥5) | #126 | **implementado** (mapeamento R, §4.5.1) |
| **F. Meio ambiente/clima** | MapBiomas/exposição | #125/#241/#255 | **parcial** (cobertura do solo por escola — §4.5.4; exposição a risco pendente) |
| **G. Recursos** | SIOPE/SICONFI | catálogo #123 | **implementado** (mapeamento R, §4.5.2) |

### 4.3 Pesos e critério de publicação

Enquanto as dimensões territoriais (C–E) não tiverem dado, **o IVET v1.2 não é
publicado como número**: publica-se apenas o bloco **A (escola)** com a
identidade declarada, e o IVET agregado fica **`NULL`** (ver a semântica `NULL`
= sem extração / `0` = sem resultado / `>0` = valor real, `#154`).

**Atualização (2026-10-18):** os três blocos mínimos — **C, D e E** — estão
extraídos (C como **proxy de exposição viária**, §4.5.5), então
`ivet_blocos_territoriais_minimos()` fica satisfeita e **o agregado do IVET é
publicável**. O que falta agora é **F-exposição** (ISH/declividade/queimada) e a
**isócrona** de C — que não bloqueiam o agregado.

> A **fundamentação dos coeficientes na literatura** (ficha por indicador, mapa
> "escolha de peso → referência", registro das divergências e fila de revisão)
> está em [`ivet-coeficientes.md`](ivet-coeficientes.md) (#139).

Regra de peso (v1.2, explícita e auditável):
- **peso igual entre dimensões disponíveis** (`W_j = 1`) — default reprodutível;
- qualquer ponderação diferente **exige justificativa registrada** (literatura
  IDEB/DEA, Zotero 10453/10454/10673/10456) e sobe a versão da fórmula
  (`ivet-v1.3`, …).
- **dimensão ausente não é 0**: entra como `NULL` e fica fora do denominador
  (não penaliza o território por falta de dado — mesma lógica do §4.3 e do #154).

### 4.4 O que isso resolve

- Cada coeficiente do bloco A passa a ter **uma** definição canônica (§3),
  reproduzível, em vez de quatro (§2).
- A leitura **territorial** (§1) torna o agregado um índice de *território com
  escola observada*, e não uma média de atributos do prédio.
- O número publicado fica **rastreável ponta a ponta**: carimba `ivet-v1.2`, o
  `dataset_version` (pin da entrada `raw`) **e** o `transform_version` (pin do
  código `raw`→`clean`→`analytics`), ambos do lockfile de datasets
  ([#135](versionamento_datasets.md)) — ver §4.6.

### 4.4.1 Bloco A — reconciliação B↔C (implementado)

**Decisão (produto, 2026-10-17)**: o bloco **A (escola)** é lido do **sistema B
canônico** (`clean.mv_escolas_scores`, §2.2/§3) e **invertido** para a direção do
IVET (vulnerabilidade: maior = pior, §4.1):

```
componente = 1 − clamp(score / 10, 0, 1)
```

O **sistema C** (`EduMaps::Model::Indicator::School::*`, §2.3) é a **camada de
análise** — legítima, mas **não** o índice canônico (§3). Na reconciliação, C
entra apenas como **refinamento opcional** (`*_c`), **fora do default**, para o
analista que precisar do grão que B agrega (`score_infraestrutura` junta
infraestrutura, pedagógico, acessibilidade e tecnologia):

| Componente | Fonte | Sistema | Papel |
|------------|-------|---------|-------|
| capacidade_atendimento | `score_capacidade_atendimento` | B | default |
| infraestrutura | `score_infraestrutura` | B | default |
| capacitacao_docente | `score_capacitacao_docente` | B | default |
| diversidade_discente | `score_diversidade_discente` | B | default |
| capacidade_gestora | `score_capacidade_gestora` | B | default |
| sustentabilidade | `score_sustentabilidade` | B | default |
| acessibilidade_c | `iai` | C | opcional |
| tecnologia_c | `itd` | C | opcional |
| oferta_c | `ioc` | C | opcional |
| qualificacao_docente_c | `iqd` | C | opcional (clampado) |

Mapeamento para as dimensões nomeadas no §4.2: *infraestrutura* → `score_infraestrutura`
(+ `score_sustentabilidade`); *docentes* → `score_capacitacao_docente`; *gestão* →
`score_capacidade_gestora`; **oferta** → `score_capacidade_atendimento` +
`score_diversidade_discente`; as `acessibilidade` e **tecnologia** do §4.2 vivem
**dentro** de `score_infraestrutura` (não separadas em B) — daí os opcionais
`acessibilidade_c`/`tecnologia_c` do sistema C.

- **Consumidores de B não mudam**: ranking, similaridade e cluster continuam
  lendo `clean.mv_escolas_scores` **intacto**; a reconciliação vive só no IVET.
- **`iqd`** viola `[0,1]` no sistema C (razão aluno/docente crua, §2.3); o
  componente `qualificacao_docente_c` o **clampa** — a correção mora na camada
  que o consome, sem tocar no indicador de origem.
- **Vazio ≠ zero (#154)**: score `NA` (escola inativa/sem dado) vira componente
  `NA` e fica fora do denominador; sem nenhum componente a dimensão A é `NA`.
- **Código**: `analysis/edumapsr/R/ivet-escola.R` (`ivet_bloco_escola()`,
  `ivet_bloco_escola_componentes()`, `ivet_componente_score()`,
  `ivet_componente_indicador()`); testes em `tests/testthat/test-ivet-escola.R` e
  contrato no card (`test-ivet-card.R`).

### 4.5 Bloco B — extração (arealização do setor censitário)

O bloco **B** é lido do **setor censitário do Censo 2022** arealizado sobre a
área de influência da escola ([`influencia.md`](influencia.md), Tier 3). A
extração tem duas metades:

- **Banco (geometria + arealização)** — changes `escola_entorno_socioeconomico`
  e `escola_entorno_socioeconomico_saneamento`:
  `clean.escola_entorno_socioeconomico` (grão escola × ano × raio) é populada por
  `clean.refresh_escola_entorno_socioeconomico()`. Cada setor que intersecta o
  buffer entra com **peso = área de interseção** (geodésica); o componente é a
  média ponderada dos setores. A ausência é **por célula** (#154): cada
  componente descarta do numerador e do denominador apenas os setores cuja sua
  variável-fonte está NULL (célula suprimida pelo IBGE). O flag do setor
  `supressao_celula_pequena` é o OR de dezenas de variáveis (~88% dos setores) e
  **não** é usado como gate; ele fica em `n_setores_suprimidos`/`cobertura_pct`
  como proveniência. O (re)preenchimento é feito pela task Minion
  `refresh_entorno_socioeconomico` (`backend/lib/EduMaps/Task/Entorno.pm`),
  pensada para rodar **uma UF por job** (a chamada global sobre o país é custosa;
  chunked é retomável).
- **Ingestão crua do setor** — change `censo2022_setor_instrucao_saneamento`:
  estende `EduMaps::Ingestion::Job::SetoresCenso2022` com os dois brutos que
  faltavam (alfabetização 15+ e `caracteristicas_domicilio2`, que traz água,
  esgoto, lixo e banheiro). O loader guarda as **contagens por categoria** (não
  um agregado "adequado/inadequado") — a classificação vive na arealização SQL,
  onde é auditável e versionada.
- **Fórmula (R puro)** — `analysis/edumapsr/R/ivet-socioeconomico.R`:
  `ivet_bloco_socioeconomico()` mapeia os componentes brutos para a dimensão B em
  `[0,1]`.

Componentes e direção (a dimensão mede **vulnerabilidade**: maior = pior):

| Componente | Coluna (banco) | Normalização | Papel (default v1.2) |
|------------|----------------|--------------|----------------------|
| analfabetismo | `pct_analfabeto` (15+) | proporção | componente (peso 1) |
| água sem rede | `pct_agua_sem_rede` | proporção | componente (peso 1) |
| esgoto inadequado | `pct_esgoto_inadequado` | proporção | componente (peso 1) |
| lixo inadequado | `pct_lixo_inadequado` | proporção | componente (peso 1) |
| sem banheiro | `pct_sem_banheiro` | proporção | componente (peso 1) |
| **saneamento** | — | média dos 4 acima (`ivet_agregar`) | componente (peso 1) |
| renda do responsável | `renda_resp_media` | `1 − clamp(renda / teto, 0, 1)` | componente (peso 1) |
| sem instrução | `pct_sem_instrucao` (25+) | proporção | calculado, **sem fonte por setor** |
| fundamental incompleto | `pct_fund_incomp` (25+) | proporção | calculado, **sem fonte por setor** |
| preto/pardo (equidade) | `pct_preto_pardo` | proporção | calculado, **fora** por omissão |

O default do bloco (**fórmula `ivet-v1.2`**) é `componentes =
c("analfabetismo", "renda", "saneamento")` — **instrução + renda do responsável +
saneamento**. A renda entrou no *default* em v1.2: há fonte por setor (produto
`Rendimento_do_Responsavel`, ver §4.5 e `fontes/socioeconomico.md`). O componente
`saneamento` é a média dos quatro indicadores disponíveis (`ivet_agregar`, `NA`
fora — #154): mede o domicílio, não o serviço isolado.

- **Teto de renda** (`IVET_TETO_RENDA`, default = 2 salários mínimos de jul/2022
  = R$ 2.424) é **parâmetro de produto**: mudá-lo exige registo e nova versão da
  fórmula (§4.3). Aplica-se à **renda do responsável** (`renda_resp_media`), que
  é o que o Censo 2022 publica por setor — não a uma renda per capita.
- **Direção**: `[0,1]`, maior = mais vulnerável (coerente com o nome do índice e
  o §1). Consequência para a reconciliação: o bloco **A** (scores 0–10 do sistema
  B, onde maior = melhor) é **invertido** para a mesma direção — implementado em
  §4.4.1.
- **#154**: componente ausente entra como `NA` (fora do denominador), **nunca**
  como 0; sem nenhum componente a dimensão é `NA`. Por isso o bloco B usa
  `ivet_agregar()` e **não** `ivet_dimensao()` (§4.1, cujo `NA→0` vale para o
  bloco escolar, onde "não tem o recurso" é de facto 0).
- A proporção preto/pardo é calculada e exposta, mas fica fora da dimensão por
  omissão: tratá-la como componente de vulnerabilidade é decisão de **equidade**
  que exige justificativa registada (§4.3).
- **Disponibilidade do dado hoje (#238, revisto a 2026-10-17)**: a ingestão do
  setor (`EduMaps::Ingestion::Job::SetoresCenso2022`) carrega o básico
  (domicílios), a demografia, a cor/raça, a **alfabetização (15+)**, o
  **domicílio parte 2** (água/esgoto/lixo/banheiro) e a **renda do responsável**
  (produto `Rendimento_do_Responsavel`, brutos
  `Agregados_por_setores_renda_responsavel`): rendimento médio (V06004) e mediano
  (V06006), com o nº de responsáveis (V06001) como peso. A escolaridade 25+
  (`esc_*`) continua **`NULL` por decisão**: o Censo 2022 **não publica esse tema
  por setor** — não há ZIP a carregar. Consequência medida por setor:
  `pct_sem_instrucao` e `pct_fund_incomp` seguem `NULL` (ausência, nunca 0 —
  #154); `renda_per_capita` também segue `NULL`, porque o produto é da **renda do
  responsável**, não per capita. A arealização expõe
  `renda_resp_media`/`renda_resp_mediana` (peso = nº estimado de responsáveis na
  interseção); a dimensão B usa `renda_resp_media`.


### 4.5.1 Bloco E — extração (segurança pública)

O bloco **E** é lido de `clean.brazilcrime_municipio` (SINESP, via pacote R
BrazilCrime; #126), grão **município × ano** — a escola é o ponto de observação e
o **município** onde ela está é o território observado (§1). A extração tem duas
metades, como o bloco B:

- **Banco** — as contagens por evento (`homicidio_doloso`, `latrocinio`,
  `lesao_corporal_seguida_de_morte`) já são carregadas com **supressão de célula
  pequena** (valores 1..4 ocultados; change `brazilcrime_*`). A escola entra por
  junção no município (`clean.malha_municipio` / `codigo_ibge`).
- **R puro** — o mapeamento contagem → componente em
  `analysis/edumapsr/R/ivet-seguranca.R`.

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| homicídio doloso | `homicidio_doloso` (contagem) | `clamp(taxa / 50)` | mais = + |
| latrocínio | `latrocinio` (contagem) | `clamp(taxa / 5)` | mais = + |
| lesão corporal seguida de morte | `lesao_corporal_seguida_de_morte` | `clamp(taxa/5)` | mais = + |

`taxa = contagem / população × 100.000` (`ivet_taxa_100k()`). O default do bloco é
`componentes = c("homicidio_doloso", "latrocinio", "lesao_corporal_seguida_de_morte")`.

- **Tetos** (`IVET_TETO_HOMICIDIO_DOLOSO = 50`, `IVET_TETO_LATROCINIO = 5`,
  `IVET_TETO_LESAO_CORPORAL_SEGUIDA_DE_MORTE = 5`, por 100 mil) são **parâmetros de
  produto** — calibrados no dev (média municipal 2021–2023: homicídio doloso p90 ≈
  46/100k; latrocínio e lesão seguida de morte são raros, p90 = 0). Mudá-los exige
  registro e nova versão da fórmula.
- **Denominador populacional**: a **população por ano** não existe hoje no banco —
  `clean.v_ibge_municipio_ano.populacao` está 100% `NULL`. A extração usa
  `clean.populacao_municipal` (snapshot) como denominador, documentado; a série
  anual é pendência de dado.
- **#154 (supressão ≠ 0)**: uma célula suprimida (contagem 1..4 ocultada pela
  fonte) vira material `NA` e **fica fora do denominador** da dimensão; uma
  contagem `0` publicada é `0` real. `ivet_taxa_100k(contagem, populacao,
  suprimido = TRUE)` força o `NA` quando o chamador tem o sinal por célula.
- **Código**: `ivet_bloco_seguranca()`, `ivet_bloco_seguranca_componentes()`,
  `ivet_taxa_100k()`, `ivet_componente_taxa()`, `ivet_componente_crime()`; testes em
  `tests/testthat/test-ivet-seguranca.R` e contrato no card (`test-ivet-card.R`).

### 4.5.2 Bloco G — extração (recursos fiscais)

O bloco **G** é lido de `analytics.esforco_fiscal_educacao` (SIOPE/SICONFI;
catálogo #123), grão **município × exercício**, também por junção no município da
escola. Os indicadores de recurso medem **"quanto maior, melhor"**, logo são
**invertidos** para a direção do IVET (`1 − clamp(valor/teto)`, como a renda do
bloco B):

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| FUNDEB por aluno | `fundeb_por_aluno` (R$/aluno) | `1 − clamp(x/10000)` | menor verba = + |
| despesa em educação por aluno | `despesa_educ_por_aluno` (R$/aluno) | `1 − clamp(x/15000)` | menos investido = + |
| autonomia fiscal | `autonomia_fiscal_pct` (%) | `1 − clamp(x/50)` | menos autonomia = + |

- O default é `componentes = c("fundeb_por_aluno", "despesa_educ_por_aluno",
  "autonomia_fiscal_pct")`.
- **`pct_receita_em_educ` não é usado**: está **corrompido** na tabela (valores
  fora de `[0,100]`), achado da medição no dev a 2026-10-17.
- **Tetos** (`IVET_TETO_FUNDEB_POR_ALUNO` = 10.000,
  `IVET_TETO_DESPESA_EDUC_POR_ALUNO` = 15.000, `IVET_TETO_AUTONOMIA_FISCAL_PCT` =
  50) calibrados pelo p90 municipal (≈ 9.336, 14.521 e 30,9%, respectivamente) e
  são parâmetros de produto.
- **#154**: valor `NULL` (município sem dado fiscal) vira componente `NA`, fora do
  denominador — nunca 0.
- **Código**: `ivet_bloco_recursos()`, `ivet_bloco_recursos_componentes()`,
  `ivet_componente_investimento()`; testes em `tests/testthat/test-ivet-recursos.R`
  e contrato no card.

### 4.5.3 Bloco D — extração (saúde)

O bloco **D** é lido de `analytics.acessibilidade_saude` (CNES + SISAB/PMMB; ver
[`fontes/saude.md`](fontes/saude.md) e a change `analytics_acessibilidade_saude_ubs`,
que corrigiu o filtro de tipos do CNES e a distância em graus). A view tem **uma
linha por escola**, mas o bloco **mistura dois grãos**: `dist_min_km_ubs` é da
escola; `n_ubs_municipio`, `ativas_ff`, `equipe_esf` e `efetividade_vagas_aps`
são do município (junção por `codigo_ibge`).

A **distância** mede "mais = pior" (pior acesso espacial) e entra **direta**; a
**provisão** de atenção básica mede "mais = melhor" e é **invertida** (como a
renda do bloco B e o bloco G):

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| distância à UBS | `dist_min_km_ubs` (km) | `clamp(dist/5)` | mais longe = + |
| cobertura de APS | `(equipe_esf + ativas_ff) / população × 1e4` | `1 − clamp(x/8)` | menos equipes = + |

- O default é `componentes = c("distancia_ubs", "cobertura_aps")`.
- **`cobertura_aps` da tabela NÃO é usada**: apesar do nome, a coluna carrega a
  **população** coberta do PMMB (pessoas), que pode passar de 100% da população
  (máx medido ≈ 25.421/10 mil). A cobertura usada é a razão de **equipes por 10
  mil habitantes** (`iv_saude_cobertura_aps` da ficha de saúde:
  `(Σ ativas_ff + equipe_esf) ÷ população × 10.000`).
- **Fora do default**: `presenca_ubs` (UBS por 10 mil hab; correlaciona 0,78 com
  `cobertura_aps` — duplicaria o sinal) e `efetividade_vagas_aps` (ocupação das
  vagas do PMMB; p50 = 98,8% — quase saturada). **`categoria_ivs` não entra**: é
  uma categoria de vulnerabilidade **social** do MS, que duplicaria o bloco B.
- **Tetos** (`IVET_TETO_DISTANCIA_UBS_KM` = 5, `IVET_TETO_COBERTURA_APS_POR_10K`
  = 8, `IVET_TETO_PRESENCA_UBS_POR_10K` = 8,
  `IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT` = 100) calibrados no dev a 2026-10-17
  (distância p90 = 7,25 km, com 5 km sendo o limiar "acesso difícil (>5 km)" da
  própria view; equipes/10 mil p90 ≈ 8,4; UBS/10 mil p90 ≈ 8,4) e são parâmetros
  de produto.
- **Denominador populacional**: `clean.populacao_municipal` (snapshot), o mesmo do
  bloco E (a população por ano não existe no banco — §4.5.1).
- **#154 (ausência ≠ 0)**: `dist_min_km_ubs` `NULL` vira componente `NA`, fora do
  denominador; `n_ubs_municipio = 0` é **zero real** (município sem UBS) e vira
  componente `1` (vulnerabilidade máxima).
- **Código**: `ivet_bloco_saude()`, `ivet_bloco_saude_componentes()`,
  `ivet_taxa_10k()`, `ivet_componente_distancia()`,
  `ivet_componente_cobertura_aps()`, `ivet_componente_presenca_ubs()`,
  `ivet_componente_efetividade_aps()`; testes em `tests/testthat/test-ivet-saude.R`
  e contrato no card.

⚠️ **O agregado continua `NA`.** Os blocos territoriais mínimos são **C+D+E**;
com **C (mobilidade)** ainda bloqueado (sem isócrona — §4.2), D fecha a extração
mas não torna o índice publicável.

### 4.5.4 Bloco F — extração (cobertura do solo)

O bloco **F** começa pela **cobertura do solo** — a dimensão que o MapBiomas
entrega pixel a pixel. A change `mapbiomas_escola` materializa
`clean.mapbiomas_escola` (grão escola × ano do Censo × ano do raster × raio ×
classe-folha) arealizando o **raster de 30 m da Coleção 11** sobre o buffer de
`clean.escola_influencia` (Tier 1, §8.2 de [`influencia.md`](influencia.md)).

- A **fração** de cada classe-folha (`fracao`, soma 1 por escola × ano × raio) é
  o dado bruto; a view `clean.v_mapbiomas_escola_grupos` reagrupa na taxonomia
  nível 1 (vegetação natural, agropecuário, urbano-infra, água, …) sem
  reprocessar. Componentes do IVET leem os grupos, não as 31 classes.
- **Direção**: a vegetação natural mede "mais = melhor" (mais amparo) e é
  **invertida** para vulnerabilidade (como a renda do bloco B); o antrópico
  entra direto. Os **pesos** e o recorte do bloco F são decisão de produto ainda
  em aberto — esta change entrega a **extração**, não o componente da fórmula.
- **#154 (ausência ≠ 0)**: buffer sem interseção com o raster fica **sem
  linha** — nunca 0 — e aparece no relatório de órfãos do job. Isso distingue
  "sem cobertura" de "zero de vegetação".
- **Fonte**: COG nacional `brazil_coverage-col11_<ANO>.tif` (Coleção 11,
  1985–2025, ~748 MB/ano, CC BY 4.0), pinado no job `MapBiomasEscola`; o ano é
  validado no intervalo. O raster **não** entra no banco (≈22 GB/ano
  descomprimido); a arealização lê o COG em *streaming* com `terra::extract` no
  host de ingestão e grava só as frações.
- **Código**: job `EduMaps::Ingestion::Job::MapBiomasEscola` + script
  `backend/templates/rscripts/ingestion/extract_mapbiomas_escola.R`; testes em
  `backend/t/05-tasks/mapbiomas_escola_loader.t`.

⚠️ **F não fecha o agregado.** O bloco F entra na fórmula só quando a **exposição
a risco** (ISH, declividade — §4.2) estiver extraída; e o agregado continua `NA`
enquanto **C (mobilidade)** estiver bloqueado (§4.2). Esta change é pré-requisito
de F, não a sua conclusão.

### 4.5.5 Bloco C — extração (mobilidade, proxy de exposição viária)

⚠️ **PROXY (decisão de produto, 2026-10-18).** A dimensão central de C é o
**acesso** — isócrona / distância-tempo —, e `clean.isocrona_escolar` está
**vazia**: depende de um motor de roteamento (OSRM/Valhalla) que não existe em
nenhum host. Enquanto isso, C é lido como **exposição viária** — o que a fonte de
facto entrega: os sinistros de trânsito do RENAEST (município) e a frota do
RENAVAM, em `analytics.mobilidade_escola` (grão municipal; a escola observa o
território do seu município).

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| risco de sinistros | `sinistros_12m` (RENAEST) | `clamp(taxa100k / 500)` | mais sinistros = + |
| exposição da frota | `renavam_total_frota` (RENAVM) | `clamp((frota / pop) / 1)` | mais frota = + |

- Default `componentes = c("risco_sinistros", "exposicao_frota")`.
- **Fora do default**: `sinistros_fatais_12m` (RENAEST) — está **0 em todas as
  escolas-município do dev**, é constante e não entra; `isocrona`, `antt_od` e
  `vmda` estão **vazios** (fontes ausentes) e entram quando existirem, no mesmo
  bloco, sem nova fórmula.
- **Tetos** (parâmetros de produto, calibrados no dev a 2026-10-18, por
  município): `IVET_TETO_SINISTROS_100K` = 500 (p50 ≈ 60, p90 ≈ 429, p99 ≈ 988);
  `IVET_TETO_FROTA_POR_HAB` = 1 (p90 ≈ 0,89).
- **#154**: sem o dado, o componente é `NA` e fica **fora** do denominador da
  dimensão; `0` real (sem sinistros / sem frota) é `0`.
- **Código**: `ivet_bloco_mobilidade()`, `ivet_bloco_mobilidade_componentes()`,
  `ivet_componente_risco_sinistros()`, `ivet_componente_exposicao_frota()`;
  testes em `tests/testthat/test-ivet-mobilidade.R` e contrato no card.

✅ **Com C, o agregado do IVET passa a ser publicável**: a regra
`ivet_blocos_territoriais_minimos()` (C+D+E) fica satisfeita — antes, C mantinha
o agregado em `NA`. O bloco continua um **proxy** de exposição viária até a
isócrona existir.

### 4.6 Vigência e retreino

Um número do IVET só vale como retrato do **presente** enquanto o dado de
entrada, o código da transformação e a fórmula não mudarem. A vigência compara o
resultado com o lockfile de datasets
([`versionamento_datasets.md`](versionamento_datasets.md)):

| Chave | Pina | Responde |
|-------|------|----------|
| `formula` | `ivet_versao()` | "a regra de cálculo mudou?" |
| `dataset_version` | a entrada `raw` (#135) | "os dados de origem mudaram?" |
| `transform_version` | o código `raw`→`clean`→`analytics` que o IVET lê | "o cálculo intermediário mudou?" |

- **`ivet_v1()`** carimba as três chaves (lê `dataset_version`/`transform_version`
  do lockfile quando recebe `lock_path`).
- **`ivet_vigencia(resultado, lock_path)`** devolve `vigente` (as três chaves do
  resultado conferem com o lockfile corrente) e `motivos` da não-vigência.
- **Gatilho de retreino**: `!vigente` ⇒ o número precisa ser **recalculado** antes
  de ser lido como retrato do presente. Operacionalmente: rode
  `bin/datasets_lock.pl --write` depois de uma carga e `--verify` contra a base
  (ver [`versionamento_datasets.md`](versionamento_datasets.md)); se o lockfile
  derivou, o número antigo deixou de valer.

O pin da transformação é o `sha256` da **definição** do objeto que materializa
cada camada derivada (função `refresh_*` ou matview) — muda o código, muda a
chave; os dados derivados não são hasheados linha a linha.

### 4.7 Card do índice

A ficha do índice vive **no mesmo lugar do código**, não num slide: o artefato
legível por máquina `analysis/edumapsr/inst/ivet-card.yml`, exposto por
`ivet_card()`. Ele declara fórmula, leitura, blocos, componentes dos blocos B, E
e G, teto de renda, proveniência e vigência — e é **contratual**:
`tests/testthat/test-ivet-card.R` falha se o card divergir de `ivet_versao()`,
`ivet_blocos()`, `ivet_bloco_socioeconomico_componentes()`, `IVET_TETO_RENDA` ou
dos componentes/tetos de E e G. Card e código não podem se separar.


---

## 5. Reprodutibilidade

| Sistema | Como recalcular |
|---------|-----------------|
| A | `CREATE OR REPLACE VIEW` já deployada; `SELECT * FROM clean.censo_escolas_scores` |
| B | `REFRESH MATERIALIZED VIEW clean.mv_escolas_scores`; depois `bin/ranking.pl` + `refresh_ranking_escola.sql` |
| C | `EduMaps::Model::Domain::SchoolQuality->new(schema=>…, geo_tag=>codigo_ibge)->all_scores` |
| D | `$rs->with_all_scores` (hoje sem chamador) |

Para o IVET v1.2: recalcular A→B reconciliados, aplicar §4.1 e publicar só o
bloco A enquanto C–E forem `NULL`.

**Núcleo da fórmula como código (entregável 3, parte pronta).** A estrutura
`componente → dimensão → IVET` de §4.1/§4.3 vive como código R **puro** em
`analysis/edumapsr/R/ivet.R` (fórmula `ivet-v1.2`):

- `ivet_normalizar()` — binário/proporção/contagem (contagem sempre contra teto);
- `ivet_dimensao()` — média ponderada dos componentes (`undef`→0);
- `ivet_agregar()` — média das dimensões **disponíveis**, com a ausente fora do
  denominador;
- `ivet_v1()` — fórmula completa: publica o agregado **só** quando as dimensões
  territoriais mínimas (C–E) existem, senão `NA` + bloco escola;
- `ivet_dataset_version()` / `ivet_transform_version()` — leem as chaves de
  conteúdo (entrada `raw` e transformação) do
  [`datasets.lock.json`](versionamento_datasets.md) (#135) para carimbar a
  proveniência;
- `ivet_vigencia()` — compara um resultado com o lockfile corrente (§4.6);
- `ivet_card()` — lê a ficha do índice (`inst/ivet-card.yml`, §4.7).

É a metade *determinística* do entregável: mesma entrada → mesma saída, sem
banco, coberta por `tests/testthat/test-ivet.R` e
`tests/testthat/test-ivet-card.R`.

**Bloco B — extração pronta (entregável 3, parte de extração).** A extração dos
componentes socioeconômicos existe nas três camadas descritas em §4.5: a
**ingestão crua** (`EduMaps::Ingestion::Job::SetoresCenso2022`, change
`censo2022_setor_instrucao_saneamento`), a arealização no banco
(`clean.escola_entorno_socioeconomico` +
`clean.refresh_escola_entorno_socioeconomico()`, changes
`escola_entorno_socioeconomico` e `escola_entorno_socioeconomico_saneamento`) e a
fórmula em R puro (`ivet_bloco_socioeconomico()` /
`ivet_bloco_socioeconomico_componentes()`, `analysis/edumapsr/R/ivet-socioeconomico.R`).
Cobertura: `backend/t/05-tasks/setores_censo_loader.t`,
`backend/t/escola_entorno_socioeconomico.t` e
`tests/testthat/test-ivet-socioeconomico.R`. A reconciliação *de fórmula* B↔C foi
**implementada** (§4.4.1).

**Blocos D, E e G — extração pronta (entregável 3).** O mapeamento R puro dos
blocos territoriais **D (saúde)**, **E (segurança)** e **G (recursos)** está em
`analysis/edumapsr/R/ivet-saude.R`, `R/ivet-seguranca.R` e `R/ivet-recursos.R`
(§4.5.3/§4.5.1/§4.5.2), com testes em `tests/testthat/test-ivet-saude.R`,
`test-ivet-seguranca.R` e `test-ivet-recursos.R` e contrato no card. **Faltam**
as extrações de **C** (mobilidade — bloqueado, sem isócrona) e **F** (meio
ambiente — só há proxy de cobertura do solo; a exposição a risco do §4.2 depende
de #241/#255). O versionamento do passo `raw`→`clean`→`analytics` está feito
(§4.6, [`versionamento_datasets.md`](versionamento_datasets.md)).

---

## 6. Pendências e próximos entregáveis (#137)

| Entregável | Estado | Depende de |
|------------|--------|------------|
| 1. Fórmula documentada/versionada | **este documento** | — |
| 2. Decisão de leitura (territorial) | **decidida e registrada** (§1 + comentário na #137) | — |
| 3. Pipeline reprodutível em `analysis/edumapsr/` | **núcleo (`R/ivet.R`) + bloco A reconciliado (§4.4.1) + extração dos blocos B (§4.5), C (§4.5.5), D (§4.5.3), E (§4.5.1) e G (§4.5.2) + pin `raw`→`analytics` (§4.6)** | falta a **exposição a risco do F** (ISH/declividade/queimada); **C é um proxy** de exposição viária (isócrona pendente); com C+D+E, **o agregado é publicável** |
| 4. Critério de vigência e retreino | **implementado** (`ivet_vigencia()`, §4.6) | — |
| 5. Card do índice | **implementado** (`inst/ivet-card.yml` + `ivet_card()`, §4.7) | — |

> **Gate dos blocos territoriais (B–F) e da #255 — resolvido**: a **metodologia
> da área de influência da escola** (buffer × setor × isócrona) foi **decidida**
> em [`influencia.md`](influencia.md) (`influencia-v1`, híbrida Tier 0–3,
> 2026-10-15). É o que permite a *extração* dos componentes territoriais; o
> núcleo da fórmula (entregável 3) **não** dependia dela.

Ações de código da reconciliação (executadas no ciclo do entregável 1+2):

- **B declarado canônico na base** e **A quarentenada** via `COMMENT`
  (change `quarantine_censo_escolas_scores`); **D** e **A** marcadas
  `DEPRECATED` no código; **C** declarada camada de análise (§3.1). O efeito é
  *uma* definição canônica (§3) em vez de quatro concorrentes (§2).
- **`with_vulnerability_score` continua `die`** (não implementar antes do IVET
  v1.2 ter as dimensões C–E).
- **`with_vulnerability_score` continua `die`** (não implementar antes do IVET
  v1.2 ter as dimensões C–E).
- **Reconciliação *de fórmula* B↔C — implementada** no IVET (§4.4.1): B é a
  fonte do bloco A; C é refinamento opcional. Os consumidores de B (ranking,
  similaridade, cluster) **não** foram alterados.
- **Follow-ups** (não neste ciclo): remoção definitiva do código morto A/D;
  alinhar o *fallback* em memória de `Profile` (sistema C) ao espaço canônico de
  B; ponderação registrada (sobe para `ivet-v1.3`).


---

## 7. Referências

- Issue **#137** · Dependências **#124** (Fase 0), **#134** (dicionário),
  **#135** (manifesto de hashes — [`versionamento_datasets.md`](versionamento_datasets.md)),
  **#125/#126/#127** (dimensões novas).
- `docs/analises/fontes_de_dados.md` — lacunas do IVET e plano de fontes (#123).
- `docs/personas/pesquisadora-educacional.md` → **P5** (pergunta territorial ×
  escolar, hoje respondida aqui).
- `docs/personas/tech-lead.md` → direção `[média]` "Promover RandomForest/índices".
- `docs/funcionalidades/analise/perfil-escola.md`, `ranking.md` — capacidades que
  consomem os indicadores.
- Zotero: **Z:10450** (RandomForest), **Z:10297** (índices para escolas).
