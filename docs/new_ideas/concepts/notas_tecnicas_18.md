# Similaridades

Boa pergunta — dá pra generalizar bastante esse padrão. O script que você fez tem duas escolhas de design que valem a pena separar: **(1) que variáveis entram no perfil** e **(2) qual métrica de distância normaliza e combina essas variáveis**. Hoje você usa Z-score + Euclidiana, que é ótimo pra variáveis contínuas e razoavelmente independentes — mas olhando o schema de vocês (INSE, IDEB, SIOPE, OSM, acessibilidade, censo escolar) tem casos onde essa combinação não é a mais adequada, e é exatamente aí que "usar o poder do R" ganha sentido (fazer isso em SQL puro fica feio ou impossível).

## Modelos de similaridade que fazem sentido no seu domínio

**1. Similaridade pedagógica entre escolas**
Perfil: notas IDEB (`IdebNotasEscolas`), taxa de aprovação/distorção idade-série, INSE (`Inse`). Mesmo conceito Z-score + Euclidiana do seu script, só que por escola em vez de município. Isso complementa (não substitui) o clustering que vocês já têm — o cluster te dá "grupo", a similaridade contínua te dá "quão perto dentro do grupo", útil pra ranking de "escolas parecidas com a escola X".

**2. Similaridade de porte/estrutura escolar**
Matrículas por etapa, número de docentes, turnos — dados que já usam no `test_cluster` do pipeline de clustering. Mesma métrica, população diferente.

**3. Similaridade de trajetória temporal (essa é onde o R realmente compensa)**
Em vez de comparar um "ponto no tempo" (médias de 2025), comparar a **série histórica** — evolução do IDEB, crescimento de matrículas, variação salarial ano a ano. SQL não faz isso bem; R tem o pacote `dtw` (Dynamic Time Warping), que alinha séries de tamanhos/ritmos diferentes e mede o quão parecida é a *trajetória*, não só o valor atual. Dois municípios podem ter o mesmo salário médio hoje mas trajetórias de crescimento completamente diferentes — Euclidiana simples não pega isso, DTW pega.

**4. Similaridade de uso do solo (OSM)**
`OsmLanduse` te dá proporções de área urbana/industrial/verde/rural por município — isso é **dado composicional** (as proporções somam 100%). Euclidiana em proporções brutas é estatisticamente enviesada (viola a suposição de independência: se uma categoria sobe, as outras obrigatoriamente descem). O R tem pacotes bons pra isso: `compositions` (transformação log-ratio/Aitchison) ou distância de Bray-Curtis (`vegan::vegdist`), ambas padrão em ecologia pra esse exato problema de "proporções que competem entre si".

**5. Similaridade de composição de gasto público (SIOPE)**
Mesmo raciocínio do item 4: proporção do orçamento em educação/saúde/infra também é composicional. Dois municípios podem gastar valores absolutos muito diferentes mas ter *padrões de alocação* parecidos (ou o oposto) — Aitchison/Bray-Curtis de novo é mais correto que Z-score+Euclidiana.

**6. Similaridade de acessibilidade/cobertura territorial**
`EstatisticasAcessibilidade` / `MetricasAcessibilidadeMunicipios` misturam variáveis contínuas (distância média) com possivelmente categóricas (zona urbana/rural, tipo de malha viária). Pra mistura de tipos, Z-score+Euclidiana não serve — o R tem `StatMatch::gower.dist()` ou `cluster::daisy(metric="gower")`, que é o padrão pra dados mistos (é literalmente o que fariam pra alimentar um k-medoids/PAM em vez de kmeans).

**7. Similaridade de "correlação interna" (Mahalanobis em vez de Euclidiana)**
Um ajuste fino pro seu script atual, sem trocar de variáveis: se salário médio e carga horária forem correlacionados entre si (plausível), a distância Euclidiana em Z-score "conta duas vezes" essa correlação. `stats::mahalanobis()` no R corrige isso considerando a matriz de covariância. Vale mais como refinamento do que como uma similaridade nova.

## Como eu integraria isso na infra que vocês já têm

Dado que vocês já têm `EduMaps::Analysis::R::Pipe` + `clustering_utils.R` rodando scripts R via Minion, faria muito sentido um **`EduMaps::Task::Similarity`** paralelo ao `Task::Clustering`, com a mesma filosofia: um `algorithm`/`metric` (`euclidean_zscore`, `mahalanobis`, `gower`, `dtw`, `aitchison`) despachando pra funções R equivalentes num `similarity_utils.R`, escrevendo o resultado numa tabela `analytics.<entidade>_similaridade` com o mesmo formato de par (`entidade_1`, `entidade_2`, `distancia`, `similaridade`) que seu script SQL já usa — só que calculado em R em vez de SQL puro, o que abre a porta pras métricas 3–6 que SQL não faz bem.

Quer que eu desenhe esse `Task::Similarity` + o primeiro `similarity_utils.R` (começando por Gower, já que cobre o caso mais geral — mistura de tipos — e os outros casos particulares como Euclidiana/Mahalanobis são casos especiais dele)?
