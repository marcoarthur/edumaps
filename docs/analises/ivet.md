# IVET — fórmula, coeficientes e decisão de leitura

> **Issue**: #137 · **Escopo**: entregáveis 1 (fórmula documentada/versionada),
> 2 (decisão de leitura) e 3 (núcleo reprodutível da fórmula, `R/ivet.R`).
> **Versão da fórmula**: `ivet-v1.1` (histórico: `ivet-v1.0`) · **Data**: 2026-10-16.
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

## 4. Fórmula-alvo do IVET `ivet-v1.1` (territorial)

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
| **A. Escola** | infraestrutura, docentes, gestão, oferta, acessibilidade, tecnologia | B e C (reconciliar em um só) | **implementado** (dividido em 4 sistemas) |
| **B. Socioeconômico** | instrução + saneamento do setor censitário | `censobr`/IBGE (#123) | **implementado** (extração: arealização do setor, §4.5) |
| **C. Acesso/mobilidade** | isócrona escolar, distância-tempo | OSRM/Valhalla (#125) | **pendente** |
| **D. Saúde** | PeNSE (saúde escolar) | #127 | **pendente** (LGPD) |
| **E. Segurança** | BrazilCrime (município, célula ≥5) | #126 | **pendente** (LGPD) |
| **F. Meio ambiente/clima** | MapBiomas/exposição | #125/#241 | parcial |
| **G. Recursos** | SIOPE/SICONFI | catálogo #123 | parcial |

### 4.3 Pesos — regra de vigência

Enquanto as dimensões territoriais (C–E) não tiverem dado, **o IVET v1.1 não é
publicado como número**: publica-se apenas o bloco **A (escola)** com a
identidade declarada, e o IVET agregado fica **`NULL`** (ver a semântica `NULL`
= sem extração / `0` = sem resultado / `>0` = valor real, `#154`).

Regra de peso (v1.1, explícita e auditável):
- **peso igual entre dimensões disponíveis** (`W_j = 1`) — default reprodutível;
- qualquer ponderação diferente **exige justificativa registrada** (literatura
  IDEB/DEA, Zotero 10453/10454/10673/10456) e sobe a versão da fórmula
  (`ivet-v1.2`, …).
- **dimensão ausente não é 0**: entra como `NULL` e fica fora do denominador
  (não penaliza o território por falta de dado — mesma lógica do §4.3 e do #154).

### 4.4 O que isso resolve

- Cada coeficiente do bloco A passa a ter **uma** definição canônica (§3),
  reproduzível, em vez de quatro (§2).
- A leitura **territorial** (§1) torna o agregado um índice de *território com
  escola observada*, e não uma média de atributos do prédio.
- O número publicado fica **rastreável**: `ivet-v1.1` + versão do dataset de
  entrada (a chave de conteúdo do [#135](versionamento_datasets.md) já fixa a
  ponta `raw`; falta versionar o passo `raw`→`clean`→`analytics`).

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

| Componente | Coluna (banco) | Normalização | Papel (default v1.1) |
|------------|----------------|--------------|----------------------|
| analfabetismo | `pct_analfabeto` (15+) | proporção | componente (peso 1) |
| água sem rede | `pct_agua_sem_rede` | proporção | componente (peso 1) |
| esgoto inadequado | `pct_esgoto_inadequado` | proporção | componente (peso 1) |
| lixo inadequado | `pct_lixo_inadequado` | proporção | componente (peso 1) |
| sem banheiro | `pct_sem_banheiro` | proporção | componente (peso 1) |
| **saneamento** | — | média dos 4 acima (`ivet_agregar`) | componente (peso 1) |
| renda | `renda_per_capita` | `1 − clamp(renda / teto, 0, 1)` | calculado, **sem fonte por setor** (#238) |
| sem instrução | `pct_sem_instrucao` (25+) | proporção | calculado, **sem fonte por setor** |
| fundamental incompleto | `pct_fund_incomp` (25+) | proporção | calculado, **sem fonte por setor** |
| preto/pardo (equidade) | `pct_preto_pardo` | proporção | calculado, **fora** por omissão |

O default do bloco (**fórmula `ivet-v1.1`**) é `componentes =
c("analfabetismo", "saneamento")` — **instrução + saneamento**, a fonte que o
Censo 2022 por setor efetivamente publica (#238). O componente `saneamento` é a
média dos quatro indicadores disponíveis (`ivet_agregar`, `NA` fora — #154):
mede o domicílio, não o serviço isolado.

- **Teto de renda** (`IVET_TETO_RENDA`, default = 2 salários mínimos de jul/2022
  = R$ 2.424) é **parâmetro de produto**: mudá-lo exige registo e nova versão da
  fórmula (§4.3).
- **Direção**: `[0,1]`, maior = mais vulnerável (coerente com o nome do índice e
  o §1). Consequência para a reconciliação: o bloco **A** (scores 0–10 do sistema
  B, onde maior = melhor) precisa ser **invertido** para a mesma direção — é o
  follow-up da reconciliação B↔C (§6).
- **#154**: componente ausente entra como `NA` (fora do denominador), **nunca**
  como 0; sem nenhum componente a dimensão é `NA`. Por isso o bloco B usa
  `ivet_agregar()` e **não** `ivet_dimensao()` (§4.1, cujo `NA→0` vale para o
  bloco escolar, onde "não tem o recurso" é de facto 0).
- A proporção preto/pardo é calculada e exposta, mas fica fora da dimensão por
  omissão: tratá-la como componente de vulnerabilidade é decisão de **equidade**
  que exige justificativa registada (§4.3).
- **Disponibilidade do dado hoje (#238)**: a ingestão do setor
  (`EduMaps::Ingestion::Job::SetoresCenso2022`) carrega o básico (domicílios), a
  demografia, a cor/raça, a **alfabetização (15+)** e o **domicílio parte 2**
  (água/esgoto/lixo/banheiro) — os brutos `Agregados_por_setores_alfabetizacao` e
  `Agregados_por_setores_caracteristicas_domicilio2`. Renda (`rend_*`) e
  escolaridade 25+ (`esc_*`) continuam **`NULL` por decisão**: o Censo 2022 **não
  publica esses temas por setor** — não há ZIP a carregar. São mantidos no código
  apenas para outra fonte (ex.: renda municipal). Consequência medida por setor:
  `renda_per_capita`, `pct_sem_instrucao` e `pct_fund_incomp` seguem `NULL`
  (ausência, nunca 0 — #154); a dimensão B passa a ter dado real via
  `analfabetismo` e `saneamento`.


---

## 5. Reprodutibilidade

| Sistema | Como recalcular |
|---------|-----------------|
| A | `CREATE OR REPLACE VIEW` já deployada; `SELECT * FROM clean.censo_escolas_scores` |
| B | `REFRESH MATERIALIZED VIEW clean.mv_escolas_scores`; depois `bin/ranking.pl` + `refresh_ranking_escola.sql` |
| C | `EduMaps::Model::Domain::SchoolQuality->new(schema=>…, geo_tag=>codigo_ibge)->all_scores` |
| D | `$rs->with_all_scores` (hoje sem chamador) |

Para o IVET v1.1: recalcular A→B reconciliados, aplicar §4.1 e publicar só o
bloco A enquanto C–E forem `NULL`.

**Núcleo da fórmula como código (entregável 3, parte pronta).** A estrutura
`componente → dimensão → IVET` de §4.1/§4.3 vive como código R **puro** em
`analysis/edumapsr/R/ivet.R` (fórmula `ivet-v1.1`):

- `ivet_normalizar()` — binário/proporção/contagem (contagem sempre contra teto);
- `ivet_dimensao()` — média ponderada dos componentes (`undef`→0);
- `ivet_agregar()` — média das dimensões **disponíveis**, com a ausente fora do
  denominador;
- `ivet_v1()` — fórmula completa: publica o agregado **só** quando as dimensões
  territoriais mínimas (C–E) existem, senão `NA` + bloco escola;
- `ivet_dataset_version()` — lê a chave de conteúdo do
  [`datasets.lock.json`](versionamento_datasets.md) (#135) para carimbar a
  proveniência.

É a metade *determinística* do entregável: mesma entrada → mesma saída, sem
banco, coberta por `tests/testthat/test-ivet.R`.

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
`tests/testthat/test-ivet-socioeconomico.R`. **Falta** a reconciliação *de fórmula*
B↔C (decisão de produto — §6), a extração de C–G e o versionamento do passo
`raw`→`clean`→`analytics`.

---

## 6. Pendências e próximos entregáveis (#137)

| Entregável | Estado | Depende de |
|------------|--------|------------|
| 1. Fórmula documentada/versionada | **este documento** | — |
| 2. Decisão de leitura (territorial) | **decidida e registrada** (§1 + comentário na #137) | — |
| 3. Pipeline reprodutível em `analysis/edumapsr/` | **núcleo pronto** (`R/ivet.R`) + **extração do bloco B** (§4.5) | falta reconciliação B↔C, extração C–G e versionar `raw`→`clean`→`analytics` |
| 4. Critério de vigência e retreino | pendente | 3 |
| 5. Card do modelo (features, importance, métrica, data) | pendente | 3 |

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
  v1.1 ter as dimensões C–E).
- **Follow-ups** (não neste ciclo): remoção definitiva do código morto A/D;
  reconciliação *de fórmula* entre B e C — é decisão de produto (muda
  similaridade/ranking) e conflita com o alvo `ivet-v1.1`; alinhar o *fallback*
  em memória de `Profile` (sistema C) ao espaço canônico de B.


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
