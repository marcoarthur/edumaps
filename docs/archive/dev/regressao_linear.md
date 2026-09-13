Abaixo está o script R que utiliza os scores da view `clean.mv_escolas_scores` para prever o IDEB observado (ano 2023) para cada etapa de ensino (`fundamental_ii` e `ensino_medio`). O código carrega os dados diretamente do PostgreSQL, ajusta modelos de regressão linear separados por etapa, avalia o desempenho e gera as predições.

```r
# ============================================================================
# Modelo preditivo do IDEB 2023 usando scores do Censo Escolar (EduMaps)
# Etapas: fundamental_ii e ensino_medio
# ============================================================================

# Carregar pacotes necessários
library(RPostgreSQL)
library(dplyr)
library(DBI)
library(ggplot2)

# ----------------------------------------------------------------------------
# 1. Conexão com o banco de dados (ajuste os parâmetros conforme seu ambiente)
# ----------------------------------------------------------------------------
con <- dbConnect(
  PostgreSQL(),
  service = "edumaps"
)

# ----------------------------------------------------------------------------
# 2. Query: junção dos scores com o IDEB 2023
# ----------------------------------------------------------------------------
query <- "
SELECT 
  s.nu_ano_censo,
  s.co_entidade,
  s.score_capacidade_atendimento,
  s.score_infraestrutura,
  s.score_capacitacao_docente,
  s.score_diversidade_discente,
  s.score_capacidade_gestora,
  s.score_sustentabilidade,
  i.ideb_observado,
  i.etapa
FROM clean.mv_escolas_scores s
INNER JOIN clean.ideb_notas_escolas i
  ON s.co_entidade = i.id_escola
  AND s.nu_ano_censo = i.ano
WHERE i.ano = 2023
  AND i.ideb_observado IS NOT NULL
  AND i.etapa IN ('fundamental_ii', 'ensino_medio')
"

dados_raw <- dbGetQuery(con, query)
dbDisconnect(con)

# Verificar estrutura
glimpse(dados_raw)

# ----------------------------------------------------------------------------
# 3. Limpeza e preparação
# ----------------------------------------------------------------------------
# Remover linhas com NA em qualquer score ou no IDEB (já filtramos IDEB not null)
dados_clean <- dados_raw %>%
  filter(
    !is.na(score_capacidade_atendimento),
    !is.na(score_infraestrutura),
    !is.na(score_capacitacao_docente),
    !is.na(score_diversidade_discente),
    !is.na(score_capacidade_gestora),
    !is.na(score_sustentabilidade)
  )

# Lista de preditores
preditores <- c(
  "score_capacidade_atendimento",
  "score_infraestrutura",
  "score_capacitacao_docente",
  "score_diversidade_discente",
  "score_capacidade_gestora",
  "score_sustentabilidade"
)

# ----------------------------------------------------------------------------
# 4. Função para treinar, avaliar e predizer para uma etapa
# ----------------------------------------------------------------------------
treinar_e_predizer <- function(dados_etapa, etapa_nome, train_frac = 0.8) {
  cat("\n========== ETAPA:", etapa_nome, "==========\n")
  cat("Número total de escolas:", nrow(dados_etapa), "\n")
  
  # Divisão treino/teste
  set.seed(123)
  n_train <- floor(train_frac * nrow(dados_etapa))
  idx_train <- sample(seq_len(nrow(dados_etapa)), n_train)
  
  train <- dados_etapa[idx_train, ]
  test  <- dados_etapa[-idx_train, ]
  
  # Fórmula do modelo
  formula <- as.formula(paste("ideb_observado ~", paste(preditores, collapse = " + ")))
  
  # Regressão linear
  modelo <- lm(formula, data = train)
  
  # Resumo do modelo
  cat("\n--- Resumo do modelo (treino) ---\n")
  print(summary(modelo))
  
  # Predições no teste
  predicoes <- predict(modelo, newdata = test)
  
  # Métricas de desempenho
  residuos <- test$ideb_observado - predicoes
  rmse <- sqrt(mean(residuos^2))
  r2 <- cor(predicoes, test$ideb_observado)^2
  
  cat("\n--- Desempenho no conjunto de teste ---\n")
  cat("R-quadrado:", round(r2, 4), "\n")
  cat("RMSE:", round(rmse, 4), "\n")
  
  # Retorna modelo + predições para todas as escolas (opcional)
  predicoes_todas <- predict(modelo, newdata = dados_etapa)
  
  # Gráfico: valores observados vs preditos (teste)
  plot_df <- data.frame(
    observado = test$ideb_observado,
    predito = predicoes
  )
  p <- ggplot(plot_df, aes(x = observado, y = predito)) +
    geom_point(alpha = 0.6) +
    geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed") +
    labs(
      title = paste("Modelo -", etapa_nome),
      x = "IDEB observado",
      y = "IDEB predito"
    ) +
    theme_minimal()
  print(p)
  
  # Retorna lista com modelo, predições e métricas
  return(list(
    modelo = modelo,
    predicoes_treino = fitted(modelo),
    predicoes_teste = predicoes,
    predicoes_todas = predicoes_todas,
    rmse = rmse,
    r2 = r2,
    dados = dados_etapa
  ))
}

# ----------------------------------------------------------------------------
# 5. Executar para cada etapa
# ----------------------------------------------------------------------------
resultados <- list()

etapas <- c("fundamental_ii", "ensino_medio")
for (etp in etapas) {
  dados_etapa <- dados_clean %>% filter(etapa == etp)
  if (nrow(dados_etapa) > 20) {  # mínimo de observações para treinar
    resultados[[etp]] <- treinar_e_predizer(dados_etapa, etp, train_frac = 0.8)
  } else {
    cat("Etapa", etp, "tem apenas", nrow(dados_etapa), "escolas. Modelo não treinado.\n")
  }
}

# ----------------------------------------------------------------------------
# 6. (Opcional) Exportar predições para todas as escolas (incluindo as usadas no treino)
# ----------------------------------------------------------------------------
# Para cada etapa, adicionar as predições ao dataframe original
dados_clean <- dados_clean %>%
  mutate(
    pred_ideb_fundamental_ii = NA_real_,
    pred_ideb_ensino_medio = NA_real_
  )

for (etp in names(resultados)) {
  pred_vec <- resultados[[etp]]$predicoes_todas
  idx <- which(dados_clean$etapa == etp)
  dados_clean$pred_ideb_fundamental_ii[idx] <- ifelse(etp == "fundamental_ii", pred_vec, NA)
  dados_clean$pred_ideb_ensino_medio[idx] <- ifelse(etp == "ensino_medio", pred_vec, NA)
}

# Salvar predições em CSV
write.csv(dados_clean, "predicoes_ideb_2023.csv", row.names = FALSE)
cat("\nArquivo 'predicoes_ideb_2023.csv' salvo com as predições.\n")

# ----------------------------------------------------------------------------
# 7. Exemplo de visualização da importância dos preditores (coeficientes padronizados)
# ----------------------------------------------------------------------------
if (length(resultados) > 0) {
  for (etp in names(resultados)) {
    modelo <- resultados[[etp]]$modelo
    coef_df <- data.frame(
      preditor = names(coef(modelo))[-1],
      coeficiente = coef(modelo)[-1]
    )
    cat("\nCoeficientes do modelo (", etp, "):\n", sep = "")
    print(coef_df)
    
    # Gráfico de barras dos coeficientes
    p_coef <- ggplot(coef_df, aes(x = reorder(preditor, coeficiente), y = coeficiente)) +
      geom_bar(stat = "identity", fill = "steelblue") +
      coord_flip() +
      labs(title = paste("Coeficientes do modelo -", etp),
           x = "Preditores", y = "Coeficiente (impacto no IDEB)") +
      theme_minimal()
    print(p_coef)
  }
}
```

### Instruções de uso:

1. **Pré‑requisitos**:  
   - Pacotes R: `RPostgreSQL`, `dplyr`, `DBI`, `ggplot2` (instale com `install.packages()`).  
   - Acesso ao banco de dados PostgreSQL com as tabelas `clean.mv_escolas_scores` e `clean.ideb_notas_escolas`.  
   - Ajuste as variáveis de ambiente ou substitua diretamente os parâmetros de conexão (`host`, `dbname`, etc.).

2. **O que o script faz**:  
   - Conecta ao banco e extrai os scores e o IDEB 2023 para as escolas que possuem ambos os registros.  
   - Separa os dados por etapa de ensino (`fundamental_ii` e `ensino_medio`).  
   - Para cada etapa, treina um modelo de regressão linear utilizando os seis scores como preditores e avalia em um conjunto de teste (20% dos dados).  
   - Gera gráficos de dispersão (observado vs. predito) e de coeficientes.  
   - Salva um arquivo CSV com as predições para todas as escolas.

3. **Interpretação dos resultados**:  
   - O **R‑quadrado** no teste indica o poder preditivo dos scores (quanto maior, melhor).  
   - **RMSE** mostra o erro médio das predições na escala original do IDEB (0 a 10).  
   - Coeficientes positivos indicam que maiores scores contribuem para um IDEB mais alto.

4. **Possíveis melhorias**:  
   - Incluir variáveis de controle como `sg_uf` ou `rede` (se disponíveis na tabela de IDEB).  
   - Testar outros algoritmos (floresta aleatória, XGBoost).  
   - Realizar validação cruzada para estimativa mais robusta.  
   - Utilizar dados de anos anteriores (ex.: 2021) para treinar e prever 2023.

Caso o ano 2023 não esteja disponível nos scores, substitua a condição `i.ano = 2023` por `i.ano = 2021` ou o ano mais recente com dados. O modelo pode ser reajustado para qualquer ano com dados de IDEB e censo coincidentes.


# Resultados para fundamental II

## Avaliação do modelo regressivo para `fundamental_ii`

O modelo linear ajustado para o IDEB observado em 2023 (etapa fundamental II) usando os seis scores apresenta os seguintes resultados principais:

| Métrica | Valor |
|---------|-------|
| **R² ajustado** | 0,1268 |
| **RMSE** (no treino, erro padrão residual) | 0,8416 |
| **Número de escolas** | 30.970 (treino ~80%) |

### Interpretação dos coeficientes

| Preditores | Coeficiente | p-valor | Significado prático |
|------------|-------------|---------|---------------------|
| `score_infraestrutura` | 0,2302 | < 0,001 | **Maior impacto**: aumento de 1 ponto no score → +0,23 no IDEB |
| `score_capacidade_gestora` | 0,0509 | < 0,001 | Impacto positivo moderado |
| `score_capacidade_atendimento` | 0,0313 | < 0,001 | Impacto pequeno, mas significativo |
| `score_sustentabilidade` | 0,0273 | < 0,001 | Pequeno impacto positivo |
| `score_diversidade_discente` | 0,0246 | < 0,001 | Pequeno impacto positivo |
| `score_capacitacao_docente` | 0,0003 | 0,898 | **Não significativo** (praticamente zero) |
| Intercepto | 2,373 | < 0,001 | IDEB base quando todos scores = 0 |

### Principais conclusões

1. **Poder preditivo modesto** – Os seis scores explicam apenas ~12,7% da variância do IDEB. Isso era esperado, pois o IDEB é influenciado por fatores externos (nível socioeconômico dos alunos, qualidade do ensino anterior, políticas estaduais/municipais, etc.) que não estão diretamente representados nos scores de infraestrutura e gestão.

2. **Infraestrutura é o preditor mais forte** – Escolas com melhor infraestrutura (salas, laboratórios, acessibilidade, tecnologia) tendem a ter IDEB mais alto. O coeficiente de 0,23 é substancial: uma escola com score de infraestrutura 10 (vs 0) teria, em média, 2,3 pontos a mais no IDEB, mantendo os demais scores constantes.

3. **Capacitação docente não mostrou efeito** – O p-valor alto sugere que, dentro deste conjunto de dados, a variável `score_capacitacao_docente` não está linearmente associada ao IDEB. Possíveis razões:
   - A formação docente (superior, pós, especialização) é bastante homogênea entre escolas (pouca variação).
   - O efeito da qualificação docente sobre o IDEB pode ser indireto ou não linear.
   - A variável pode estar correlacionada com infraestrutura (multicolinearidade), mascarando seu efeito.

4. **Gestão e atendimento contribuem positivamente**, embora com magnitude menor.

### Limitações e próximos passos

- **Adicionar variáveis de controle** – Incluir o Índice de Nível Socioeconômico (INSE) da escola, porte (número de alunos), localização (urbano/rural) e dependência administrativa (federal, estadual, municipal, privada) certamente elevaria o R².
- **Explorar não linearidades** – Testar termos quadráticos ou interações (ex.: infraestrutura × gestão).
- **Modelos alternativos** – Floresta aleatória ou XGBoost podem capturar relações mais complexas e melhorar a predição.
- **Verificar multicolinearidade** – Embora os VIF não tenham sido calculados, é possível que `score_capacitacao_docente` compartilhe variância com outros scores. Calcular o VIF ajudaria a diagnosticar.

### Conclusão para o negócio

Os scores do EduMaps são preditores **significativos, porém limitados** do IDEB. A **infraestrutura** destaca-se como o fator mais importante entre os analisados. A **capacitação docente**, como medida atualmente construída, não mostrou associação linear com o IDEB fundamental II – isso sugere que ou a métrica precisa ser revista (ex.: incluir indicadores de prática docente em sala de aula, não apenas formação), ou que seu efeito é mediado por outras variáveis.

Recomenda-se usar este modelo como **ferramenta de diagnóstico** (identificar escolas com desempenho muito abaixo do predito) e não como preditor definitivo do IDEB. Para aumentar o poder preditivo, é essencial incorporar dados socioeconômicos.

# Resultados para Ensino Médio

## Avaliação do modelo regressivo para `ensino_medio`

O modelo linear para o IDEB do ensino médio (2023) apresenta resultados similares ao do fundamental II, mas com algumas diferenças importantes:

| Métrica | Valor |
|---------|-------|
| **R² ajustado** (treino) | 0,1128 |
| **R² no teste** | 0,1096 |
| **RMSE no teste** | 0,6336 |
| **Número de escolas** | 14.389 |

### Coeficientes e significância

| Preditores | Coeficiente | p-valor | Impacto no IDEB |
|------------|-------------|---------|------------------|
| `score_infraestrutura` | 0,1207 | < 0,001 | **Maior impacto positivo** |
| `score_diversidade_discente` | 0,0966 | < 0,001 | Impacto positivo relevante |
| `score_capacidade_atendimento` | 0,0455 | < 0,001 | Impacto positivo moderado |
| `score_sustentabilidade` | 0,0412 | < 0,001 | Impacto positivo pequeno |
| `score_capacidade_gestora` | 0,0136 | < 0,001 | Impacto positivo muito pequeno |
| `score_capacitacao_docente` | -0,0092 | 0,0017 | **Impacto negativo pequeno** |

### Principais conclusões

1. **Poder preditivo ainda modesto** (R² ~ 11%) – confirmando que fatores não capturados pelos scores (especialmente o nível socioeconômico e a trajetória anterior dos alunos) são determinantes para o IDEB do ensino médio.

2. **Infraestrutura continua sendo o preditor mais forte**, mas seu coeficiente (0,12) é aproximadamente a metade do observado no fundamental II (0,23). Isso sugere que, no ensino médio, a qualidade da infraestrutura importa menos ou que outros fatores (como a formação do professor e o engajamento dos alunos) ganham peso relativo.

3. **Diversidade discente apareceu como segundo fator mais importante** (coeficiente 0,097), ao passo que no fundamental II seu efeito era bem menor (0,025). Escolas com maior diversidade racial, equilíbrio de gênero, inclusão de PcD e oferta de EJA tendem a ter IDEB médio mais alto. Isso pode refletir um ambiente mais rico e inclusivo, ou uma associação com escolas maiores e urbanas.

4. **Capacitação docente apresentou coeficiente negativo e significativo** (‑0,0092). Embora pequeno, é estatisticamente relevante e contraintuitivo. Possíveis explicações:
   - **Correlação espúria** – A variável pode estar captando efeitos de confusão não controlados (escolas com docentes mais qualificados podem atender populações mais vulneráveis, que historicamente têm menor desempenho).
   - **Multicolinearidade** – `score_capacitacao_docente` pode estar correlacionado com outros scores, especialmente `infraestrutura` e `gestão`, e o sinal negativo surge após controle.
   - **Problema de medida** – O score atual (baseado em formação acadêmica e especializações) pode não refletir a qualidade efetiva da prática docente no ensino médio, onde a experiência e a didática específica por disciplina são cruciais.
   - **Efeito teto** – Muitas escolas têm alta qualificação docente, mas o IDEB varia por outras razões, gerando uma relação negativa após controle de outros fatores.

5. **Gestão teve impacto positivo, porém muito pequeno** (0,014) – muito menor que no fundamental II (0,051). Pode indicar que a gestão escolar influencia menos o desempenho médio no ensino médio, ou que o score atual não capta bem as competências gerenciais necessárias para essa etapa.

### Comparação entre as duas etapas

| Característica | Fundamental II | Ensino Médio |
|----------------|----------------|--------------|
| R² | 12,7% | 11,3% |
| RMSE (teste) | não calculado | 0,634 |
| Coeficiente `infraestrutura` | 0,230 | 0,121 |
| Coeficiente `diversidade` | 0,025 | 0,097 |
| Coeficiente `capacitação docente` | não significativo | negativo (-0,009) |
| Coeficiente `gestão` | 0,051 | 0,014 |

### Recomendações

1. **Aprimorar o modelo** – Adicionar variáveis contextuais: nível socioeconômico (INSE), porte da escola, dependência administrativa, localização (urbano/rural). Isso pode reduzir o viés nos coeficientes e melhorar o R².

2. **Revisar o score de capacitação docente** – Incluir indicadores como:
   - Porcentagem de professores com formação na disciplina que lecionam (adequação da formação).
   - Participação em desenvolvimento profissional nos últimos dois anos.
   - Avaliação de desempenho docente (se disponível).
   - Taxa de absenteísmo ou rotatividade.

3. **Explorar interações** – No ensino médio, a interação `infraestrutura × capacitação docente` pode ser relevante: escolas com boa estrutura e professores bem formados podem ter sinergia.

4. **Usar o modelo como diagnóstico** – Calcular resíduos para identificar escolas com desempenho muito abaixo do predito (resíduos negativos grandes) e priorizar intervenções nessas unidades, pois elas estão "subperformando" dado seu perfil de scores.

5. **Considerar modelos não lineares** – Árvores de regressão ou florestas aleatórias podem capturar relações que o modelo linear simples não detect

# Erro irredutível

No contexto da regressão linear ajustada para o IDEB observado (`yi`) usando os scores como preditores (`xi`), o termo **εᵢ** representa o **erro irredutível** (ou erro aleatório) do modelo. Formalmente:

```
yi = f(xi) + εᵢ
```

onde `f(xi)` é a parte sistemática (prevista pelos scores) e `εᵢ` é tudo o que não conseguimos explicar, mesmo com um modelo perfeito.

### Quem é εᵢ nos resultados do `lm()`?

- **Estimativa pontual**: os resíduos (`residuals`) – diferença entre o IDEB observado e o valor predito pelo modelo – são **realizações amostrais** de `εᵢ`.
- **Variância do erro**: o `Residual standard error` (RSE) fornecido pelo `lm()` é uma estimativa do desvio‑padrão de `εᵢ`, assumindo que os erros são homocedásticos e independentes.

### Valores obtidos nos modelos

| Etapa | Residual standard error (RSE) | Interpretação |
|-------|-------------------------------|----------------|
| Fundamental II | 0,8416 | O desvio‑padrão do erro irredutível é cerca de **0,84 pontos no IDEB**. |
| Ensino Médio   | 0,6339 | O desvio‑padrão do erro irredutível é cerca de **0,63 pontos no IDEB**. |

### O que compõe esse erro irredutível?

1. **Variáveis não observadas (ou não incluídas)** – Ex.: nível socioeconômico dos alunos, qualidade do ensino anterior, engajamento familiar, violência no entorno, políticas municipais/estaduais de educação, etc.
2. **Erro de medição** – Tanto nos scores (baseados em declaração das escolas) quanto no próprio IDEB (que depende da participação dos alunos na prova SAEB e de taxas de aprovação sujeitas a flutuações).
3. **Variação aleatória inerente** – Mesmo com todas as variáveis relevantes, o desempenho de uma escola em um dado ano tem um componente imprevisível (sorte no dia da prova, condições climáticas, etc.).

### Por que o erro é considerado “irredutível”?

Mesmo que tivéssemos um modelo perfeitamente especificado (com todas as variáveis causais) e um estimador não viesado, ainda restaria uma variância residual devido à aleatoriedade intrínseca do fenômeno. O RSE aproxima essa variância. No nosso caso, o RSE de 0,84 significa que, mesmo após usar todos os seis scores, o IDEB observado de uma escola típica se desvia do valor predito por cerca de ±0,84 pontos (em média) – e esse desvio não pode ser reduzido apenas melhorando o modelo, pois reflete a imprevisibilidade fundamental do processo.

### Resumo direto para a pergunta:

- **εᵢ é o erro aleatório** que captura a diferença entre o IDEB real e o que seria previsto por um modelo ideal com os preditores disponíveis.
- **Estimativa numérica**: `Residual standard error` = 0,84 (fundamental II) e 0,63 (ensino médio). Ele é a estimativa do desvio‑padrão de `εᵢ`.

# Categorizando municípios para construir modelo de regressão

Primeiro clusterizamos (kmeans) os municípios e para cada cluster extrairemos as escolas que serão modeladas com metodo regressivo
anterior

## Query para clusterização de municípios de SP em 5 grupos (k-means)

A consulta abaixo utiliza as tabelas `municipios_sp`, `dados_ibge` e `populacao_municipal` para criar 5 clusters com base na composição econômica (%) e no tamanho populacional. Os dados são padronizados (z-score) para evitar viés de escala. Requer a extensão `kmeans` (disponível em ambientes como PostgresML ou instalada separadamente).

```sql
-- ============================================================================
-- Clusterização dos municípios do estado de São Paulo em 5 grupos (k-means)
-- Base: composição setorial do PIB (%) + população estimada
-- ============================================================================

-- 1. Selecionar e padronizar as variáveis
WITH base_municipios AS (
    SELECT 
        m.codigo_ibge,
        m.nome,
        COALESCE(d.agro_percent, 0) AS agro,
        COALESCE(d.industria_percent, 0) AS industria,
        COALESCE(d.servicos_percent, 0) AS servicos,
        COALESCE(d.governo_percent, 0) AS governo,
        COALESCE(p.populacao_estimada, 0) AS pop
    FROM clean.municipios_sp m
    LEFT JOIN (
        SELECT DISTINCT ON (codigo_ibge) codigo_ibge, agro_percent, industria_percent, servicos_percent, governo_percent
        FROM clean.dados_ibge
        WHERE ano = (SELECT MAX(ano) FROM clean.dados_ibge)  -- ano mais recente disponível
        ORDER BY codigo_ibge, ano DESC
    ) d ON m.codigo_ibge = d.codigo_ibge
    LEFT JOIN clean.populacao_municipal p ON m.codigo_ibge = p.codigo_ibge
    WHERE m.sigla_estado = 'SP'
),

-- 2. Calcular média e desvio padrão para padronização (z-scores)
stats AS (
    SELECT 
        AVG(agro) AS mean_agro, STDDEV(agro) AS std_agro,
        AVG(industria) AS mean_industria, STDDEV(industria) AS std_industria,
        AVG(servicos) AS mean_servicos, STDDEV(servicos) AS std_servicos,
        AVG(governo) AS mean_governo, STDDEV(governo) AS std_governo,
        AVG(pop) AS mean_pop, STDDEV(pop) AS std_pop
    FROM base_municipios
),

base_padronizada AS (
    SELECT 
        b.codigo_ibge,
        b.nome,
        -- z-scores (evita divisão por zero com COALESCE)
        COALESCE((b.agro - s.mean_agro) / NULLIF(s.std_agro, 0), 0) AS z_agro,
        COALESCE((b.industria - s.mean_industria) / NULLIF(s.std_industria, 0), 0) AS z_industria,
        COALESCE((b.servicos - s.mean_servicos) / NULLIF(s.std_servicos, 0), 0) AS z_servicos,
        COALESCE((b.governo - s.mean_governo) / NULLIF(s.std_governo, 0), 0) AS z_governo,
        COALESCE(LOG(b.pop + 1) - (SELECT AVG(LOG(pop+1)) FROM base_municipios), 0) AS z_pop -- log para reduzir assimetria
    FROM base_municipios b
    CROSS JOIN stats s
)

-- 3. Aplicar k-means (k=5) sobre o vetor das 5 variáveis padronizadas
SELECT 
    codigo_ibge,
    nome,
    kmeans(ARRAY[z_agro, z_industria, z_servicos, z_governo, z_pop], 5) AS cluster_id,
    -- Opcional: incluir os valores originais para referência
    ROUND((z_agro * (SELECT std_agro FROM stats) + (SELECT mean_agro FROM stats)), 2) AS agro_percent,
    ROUND((z_industria * (SELECT std_industria FROM stats) + (SELECT mean_industria FROM stats)), 2) AS industria_percent,
    ROUND((z_servicos * (SELECT std_servicos FROM stats) + (SELECT mean_servicos FROM stats)), 2) AS servicos_percent,
    ROUND((z_governo * (SELECT std_governo FROM stats) + (SELECT mean_governo FROM stats)), 2) AS governo_percent,
    ROUND(EXP(z_pop + (SELECT AVG(LOG(pop+1)) FROM base_municipios)) - 1, 0) AS populacao_estimada
FROM base_padronizada
ORDER BY cluster_id, nome;
```

### Observações importantes

- **Dependência da extensão `kmeans`**: Essa função não faz parte do PostgreSQL puro. Você precisa ter instalada a extensão (ex.: `CREATE EXTENSION kmeans;`). Caso não disponha, pode obter resultados similares exportando os dados para R ou Python e fazendo o cluster lá.
- **Tratamento de dados faltantes**: Municípios sem dados econômicos ou populacionais recebem valor zero (`COALESCE(...,0)`). Isso pode distorcer os clusters; considere filtrar apenas municípios com todas as informações disponíveis adicionando `WHERE d.codigo_ibge IS NOT NULL AND p.codigo_ibge IS NOT NULL` na CTE `base_municipios`.
- **Padronização**: As porcentagens setoriais já são comparáveis, mas a população tem magnitude muito maior. Aplicamos log natural para reduzir assimetria e depois padronizamos (z-score de log(pop+1)). Isso evita que grandes cidades dominem os clusters.
- **Número de clusters (5)**: Você pode ajustar o segundo argumento da função `kmeans` para outro valor (ex.: 4, 6, 10).

### Alternativa sem extensão `kmeans`

Se a extensão não estiver disponível, você pode executar o cluster diretamente em R (por exemplo, usando `dbGetQuery` para extrair os dados e `kmeans()` do R). Segue um esboço:

```r
library(RPostgreSQL)
library(dplyr)
library(DBI)

con <- dbConnect(...)
dados <- dbGetQuery(con, "SELECT codigo_ibge, nome, 
                          COALESCE(agro_percent,0) AS agro, 
                          COALESCE(industria_percent,0) AS industria,
                          COALESCE(servicos_percent,0) AS servicos,
                          COALESCE(governo_percent,0) AS governo,
                          COALESCE(populacao_estimada,0) AS pop
                          FROM clean.municipios_sp m
                          LEFT JOIN ... -- mesma junção da query SQL")
dados_scaled <- scale(select(dados, agro, industria, servicos, governo, log(pop+1)))
set.seed(123)
clusters <- kmeans(dados_scaled, centers = 5, nstart = 25)
dados$cluster <- clusters$cluster
# Escrever de volta ou analisar
```

A consulta SQL acima resolve o problema no banco de dados quando a extensão `kmeans` está disponível. Caso contrário, utilize a alternativa em R.

## Kmeans e certos erros
O erro aconteceu porque a ordem dos argumentos na extensão `kmeans` que você compilou via PGXN é exatamente a oposta da que você usou.

O primeiro argumento precisa ser o **vetor/array** de dados, e o segundo argumento é o **número $K$ de clusters**. Além disso, o tipo do array esperado pela função geralmente precisa ser explicitado como `float8[]` (`double precision[]`) para evitar ambiguidades no Postgres.

---

### Como corrigir a Query

Na linha 52, altere de:

```sql
kmeans(5, ARRAY[z_agro, z_industria, z_servicos, z_governo, z_pop]) OVER () + 1 AS cluster_id,

```

Para:

```sql
kmeans(ARRAY[z_agro, z_industria, z_servicos, z_governo, z_pop]::float8[], 5) OVER () + 1 AS cluster_id,

```

---

### Por que a sua abordagem está excelente?

* **Z-score (Padronização):** Você fez perfeitamente ao normalizar os dados antes de passar para o K-Means. Como as porcentagens econômicas e o log da população possuem escalas e variâncias totalmente diferentes, sem o Z-score a população ou o setor de serviços (que costuma ser maior) iriam distorcer completamente a distância euclidiana.
* **`LN(pop + 1)`:** Aplicar o logaritmo na população foi uma ótima sacada para mitigar o efeito de "outliers" gigantescos como a capital (São Paulo) e Campinas frente aos municípios pequenos do interior.

Fazendo essa inversão de argumentos e adicionando o `::float8[]`, o seu mapeamento socioeconômico dos municípios paulistas vai rodar direto e de forma extremamente performática dentro do banco.

## Resultado com os clusteres municipais

Foi aplicado o modelo de regressão linear (*lm()*) para cada cluster dos municípios, e os resultados dos $R^2$ e $RMSE$ mostram-se
bem diversos em cada cluster


## Avaliação dos resultados por cluster (Fundamental II e Ensino Médio)

Os resultados mostram que o poder preditivo do modelo (scores + `media_inse`) varia **fortemente entre os clusters**, refletindo diferenças estruturais nos tipos de município (econômicas e populacionais). Abaixo a análise detalhada.

### 1. Visão geral

| Etapa | Cluster | N escolas | R²   | RMSE | Interpretação |
|-------|---------|-----------|------|------|----------------|
| **Fundamental II** | 1 | 217 | 0,282 | 0,467 | Moderado |
| | 2 | 81 | 0,072 | 0,527 | Muito baixo |
| | 3 | 468 | 0,264 | 0,450 | Moderado |
| | 4 | 396 | 0,291 | 0,433 | Moderado |
| | 5 | 3.535 | 0,488 | 0,414 | **Bom** |
| **Ensino Médio** | 1 | 184 | 0,108 | 0,430 | Baixo |
| | 2 | 63 | 0,113 | 0,426 | Baixo |
| | 3 | 336 | 0,185 | 0,496 | Baixo |
| | 4 | 253 | 0,329 | 0,498 | Moderado |
| | 5 | 2.252 | 0,358 | 0,504 | Moderado |

---

### 2. Principais achados

#### a) **Cluster 5 (ambas as etapas) – melhor desempenho preditivo**
- Fundamental II: R² = 0,488 (explica quase 50% da variância do IDEB), RMSE = 0,414.
- Ensino Médio: R² = 0,358, RMSE = 0,504.
- **Interpretação**: Esse cluster reúne os maiores municípios (alta população, economia diversificada, provavelmente com forte setor de serviços). Neles, os scores do censo somados ao INSE são bons preditores do IDEB – indicando que a infraestrutura, a gestão e o nível socioeconômico das famílias capturam bem o desempenho escolar.

#### b) **Cluster 2 (ambas as etapas) – desempenho preditivo muito baixo**
- Fundamental II: R² = 0,072 (apenas 7% da variância explicada).
- Ensino Médio: R² = 0,113.
- **Interpretação**: Cluster com poucas escolas (81 e 63). Provavelmente são municípios **muito pequenos, rurais ou economicamente especializados** (ex.: agropecuária intensiva). Neles, os fatores capturados pelos scores e INSE têm **baixa correlação** com o IDEB – o desempenho escolar pode ser influenciado por outros fatores não medidos (ex.: características da oferta de transporte, qualidade do ensino multisseriado, políticas locais específicas). O modelo não é adequado para esses contextos.

#### c) **Clusters 1, 3, 4 – comportamento intermediário**
- Fundamental II: R² entre 0,26 e 0,29; RMSE entre 0,43 e 0,47.
- Ensino Médio: R² mais baixos (0,11 a 0,33); destaque para o **cluster 4 do ensino médio** com R²=0,329.
- Esses clusters representam municípios de porte médio ou com perfil econômico misto. O modelo explica uma parcela razoável, mas ainda deixa muito não explicado – especialmente no ensino médio.

---

### 3. Comparação entre etapas

- **Fundamental II** apresenta, em todos os clusters, R² superiores aos do ensino médio (exceto cluster 2 que é muito baixo em ambos). Isso sugere que o IDEB do fundamental II é mais previsível a partir das características da escola e do nível socioeconômico do que o IDEB do ensino médio. Possíveis razões:
  - Ensino médio tem maior defasagem entre aferição do INSE (que reflete a família do aluno) e o momento do aluno – muitos já trabalham, o que enfraquece a relação.
  - As notas do SAEB no ensino médio são mais influenciadas por fatores como trajetória escolar anterior e engajamento do adolescente, menos capturados pelos scores atuais.

- **RMSE** ligeiramente maior no ensino médio (0,43–0,50) comparado ao fundamental II (0,41–0,53), indicando erro absoluto semelhante.

---

### 4. Conclusões e recomendações

| Cluster | Perfil provável (baseado na clusterização econômica/populacional) | Recomendação para uso do modelo |
|---------|-------------------------------------------------------------------|--------------------------------|
| **5** | Grandes centros urbanos, serviços predominantes, alta população | **Modelo útil** – pode ser usado para benchmarking e predição |
| **1, 3, 4** | Municípios de porte médio, economia mista (indústria + serviços, ou agropecuária com algum serviço) | Modelo **moderadamente útil** – usar com cautela; incluir variáveis regionais |
| **2** | Municípios muito pequenos, rurais, agropecuária extrativa ou especializada | **Modelo inadequado** – requer coleta de dados específicos ou modelos separados |

**Próximos passos sugeridos:**

1. **Caracterizar cada cluster** com médias das variáveis originais (agro%, serviço%, população, INSE médio) para confirmar os perfis.
2. **Cluster 2** – analisar individualmente: são municípios como Adolfo, Águas de Santa Bárbara, etc. Investigar se há problemas de qualidade dos dados ou se realmente o IDEB não se relaciona com os scores.
3. **Refinar o modelo** para clusters com R² baixo: testar interações ou incluir variáveis como porte da escola, dependência administrativa (pública/privada) e indicadores de transporte escolar.
4. **Para predição** (forecasting), utilizar o modelo específico de cada cluster – já que a relação entre preditores e IDEB difere significativamente entre eles.

Em resumo, **a estratificação por cluster revelou heterogeneidade importante**: o modelo funciona bem apenas para municípios grandes e urbanos (cluster 5), razoavelmente para médios, e falha para os muito pequenos/especializados. Essa é uma conclusão valiosa para políticas públicas direcionadas.

# Modelo alternativo

Entendi. Você já separou os dados em **5 clusters** (baseados na economia e população dos municípios) e rodou uma regressão linear simples **dentro de cada cluster**. Agora quer um **modelo paramétrico alternativo** que utilize esses mesmos grupos (os clusters) de forma mais eficiente, e comparar os resultados com os modelos lineares separados.

## Sugestão: Modelo Linear com Interações (Pooled com efeitos de cluster)

Em vez de rodar 5 regressões separadas, você pode estimar um **único modelo linear** que inclui:

- Os 6 scores + `media_inse`
- O **cluster** como variável categórica (4 dummies, cluster 5 como referência)
- **Interações** entre o cluster e cada preditor (ou pelo menos com os preditores mais relevantes)

### Vantagens

- **Compartilha a variância do erro** entre os clusters, aumentando a precisão (especialmente nos clusters pequenos como o 2).
- Permite **testar formalmente** se os coeficientes diferem entre clusters (teste F para interações).
- Mantém a interpretabilidade paramétrica.
- Facilita comparação com o modelo separado via **AIC**, **BIC** e **likelihood ratio test** (pois são modelos aninhados).

### Estrutura do modelo

```r
# Modelo com interações completas (equivalente a 5 regressões separadas)
modelo_interacoes <- lm(ideb_observado ~ 
  (score_capacidade_atendimento + score_infraestrutura + score_capacitacao_docente +
   score_diversidade_discente + score_capacidade_gestora + score_sustentabilidade + media_inse) * factor(cluster_id),
 data = dados_f2)

# Modelo reduzido (sem interações, apenas efeito principal de cluster)
modelo_principal <- lm(ideb_observado ~ 
  score_capacidade_atendimento + score_infraestrutura + score_capacitacao_docente +
  score_diversidade_discente + score_capacidade_gestora + score_sustentabilidade + media_inse + factor(cluster_id),
 data = dados_f2)

# Teste se as inclinações diferem entre clusters (H0: interações = 0)
anova(modelo_principal, modelo_interacoes, test = "F")
```

### Comparação com os modelos separados

Os modelos separados (um por cluster) produzem exatamente os **mesmos coeficientes** que o modelo com interações completas (quando estimados por OLS). A diferença está na estimativa da variância residual: o modelo separado usa a variância *dentro* de cada cluster, enquanto o modelo interações usa uma única variância residual **combinada** (assumindo homocedasticidade entre clusters). Isso pode ser mais ou menos adequado.

Para comparar formalmente:

```r
# Ajustar modelos separados manualmente e calcular log-verossimilhança conjunta
# (assumindo independência entre clusters)
logLik_separado <- sum(sapply(resultados_fund2, function(x) {
  if (!is.null(x$modelo)) as.numeric(logLik(x$modelo)) else 0
}))

# Modelo com interações (mesmos coeficientes, mas variância comum)
logLik_interacoes <- logLik(modelo_interacoes)

# Teste de razão de verossimilhança: o modelo separado tem 5 vezes mais parâmetros de variância
# (um sigma^2 por cluster) do que o modelo interações (um sigma^2 global)
# O teste não é direto, mas podemos comparar AIC corrigido:
AIC_separado <- -2 * logLik_separado + 2 * sum(sapply(resultados_fund2, function(x) length(coef(x$modelo)) + 1))
AIC_interacoes <- AIC(modelo_interacoes)

cat("AIC separado:", AIC_separado, "\nAIC interações:", AIC_interacoes)
```

### Interpretação dos resultados

- Se **AIC separado < AIC interações** → a heterocedasticidade entre clusters é importante (cada cluster tem sua própria variância residual).
- Se **AIC interações < AIC separado** → a variância é homogênea entre clusters, e o modelo interações é mais parcimonioso.

### Alternativa mais flexível: Modelo Linear Hierárquico com cluster como efeito aleatório

Você pode tratar os **clusters** como grupos hierárquicos (em vez de municípios). Assim:

```r
modelo_mlm_cluster <- lmer(ideb_observado ~ 
  score_capacidade_atendimento + score_infraestrutura + score_capacitacao_docente +
  score_diversidade_discente + score_capacidade_gestora + score_sustentabilidade + media_inse +
  (1 | cluster_id),  # intercepto aleatório para cluster
 data = dados_f2, REML = FALSE)
```

Isso captura diferenças médias entre clusters (efeitos aleatórios) sem estimar coeficientes separados para cada preditor. É mais parcimonioso que interações completas, mas pode não ser suficiente se as inclinações também variarem.

**Comparação de AIC** entre os três modelos (separado, interações, efeito aleatório) indicará o melhor trade-off entre ajuste e complexidade.

## Resumo da comparação com seus resultados atuais

| Abordagem | Nº parâmetros | Vantagem | Desvantagem |
|-----------|--------------|----------|--------------|
| **Separado por cluster** (seu atual) | 5× (p+1) parâmetros + 5 sigmas | Flexível, captura diferenças completas | Pouco eficiente para clusters pequenos (cluster 2) |
| **Interações (pooled)** | (p+1) + (k-1) + (p+1)*(k-1) | Modelo único, testes de hipótese diretos | Assume homocedasticidade entre clusters |
| **Efeito aleatório de cluster** | (p+1) + 2 | Parcimonioso, shrinkage para clusters pequenos | Assume que diferenças seguem distribuição normal |

**Recomendação**: Estime o modelo com interações e compare o AIC com o AIC dos modelos separados. Se o AIC for muito menor para os separados, fique com eles (especialmente se você tem interesse em inferência por cluster). Caso contrário, prefira o modelo interações por ser mais estável e fácil de reportar. O modelo de efeito aleatório é uma alternativa intermediária elegante.


# A forma correta de pensar nos Clusters e na análise segmentada

A abordagem de rodar uma regressão linear separada para cada cluster (conhecida como *Split-Sample Regression*) funciona, mas ela possui duas grandes limitações estatísticas:

1. **Perda de Poder Estatístico:** Você fragmenta sua amostra, o que diminui o $n$ de cada modelo e aumenta o erro padrão dos estimadores.
2. **Impossibilidade de Testar Hipóteses Globais:** Você não consegue testar diretamente se o efeito de um score (ex: `score_infraestrutura`) é estatisticamente diferente entre o Cluster 1 e o Cluster 2.

Para criar um **modelo paramétrico único e alternativo** que use toda a base de dados de forma eficiente, a melhor saída estatística é utilizar um **Modelo Linear com Termos de Interação Total** (ou uma formulação equivalente a um modelo de efeitos fixos com inclinações variáveis).

---

## O Modelo Paramétrico Alternativo: Regressão Interagida

Em vez de quebrar o dataset, incluímos o `cluster_id` (como fator) interagindo com **todos** os preditores. Isso permite que cada cluster tenha seu próprio intercepto e suas próprias inclinações (coeficientes), mas mantendo o cálculo do erro residual globalizado.

A equação matemática para uma escola $i$ no cluster $c$ assume a seguinte forma:

$$Ideb_i = \alpha_0 + \sum_{c=2}^5 \alpha_c D_{ci} + \sum_{j=1}^m \beta_j X_{ji} + \sum_{c=2}^5 \sum_{j=1}^m \gamma_{cj} (D_{ci} \times X_{ji}) + \epsilon_i$$

Onde:

* $D_{ci}$ são variáveis dummy para os clusters.
* $X_{ji}$ são os seus 7 scores preditores.
* $\gamma_{cj}$ são os termos de interação, que capturam exatamente **o quanto o efeito do score muda por estar naquele cluster específico** em relação ao cluster de referência (Cluster 1).

### Implementação em R

Podemos ajustar essa estrutura facilmente utilizando a sintaxe de interação total `*` aplicada ao fator do cluster:

```R
library(dplyr)
library(broom)
library(car) # Para o teste de Wald global

# Garantir que cluster_id seja tratado como fator categórico
dados_com_cluster <- dados_com_cluster %>%
  mutate(cluster_fct = as.factor(cluster_id))

# Nova fórmula com Interação Total: o '*' cria os efeitos principais e as interações
formula_interagida <- as.formula(
  "ideb_observado ~ cluster_fct * (score_capacidade_atendimento + score_infraestrutura + 
   score_capacitacao_docente + score_diversidade_discente + score_capacidade_gestora + 
   score_sustentabilidade + media_inse)"
)

# Ajustando os modelos globais por etapa
mod_global_fund2 <- lm(formula_interagida, data = dados_com_cluster %>% filter(etapa == "fundamental_ii"))
mod_global_medio <- lm(formula_interagida, data = dados_com_cluster %>% filter(etapa == "ensino_medio"))

```

---

## Como Comparar os Dois Modelos Eficientemente?

Para provar matematicamente se essa estrutura paramétrica com agrupamentos socioeconômicos faz sentido contra os modelos tradicionais, você deve realizar três validações:

### 1. Comparação de Ajuste Global ($R^2$ Ajustado e AIC)

O $R^2$ obtido no modelo interagido será muito próximo à média ponderada dos $R^2$ dos seus modelos separados, mas o **$R^2$ Ajustado** e o **AIC (Akaike Information Criterion)** vão penalizar o ganho de complexidade.

* Se o AIC do modelo interagido for significativamente **menor** que o de um modelo linear simples (sem considerar os clusters), a clusterização socioeconômica provou sua utilidade preditiva.

### 2. O Teste de Chow (ou Teste de Wald Global)

Para testar se os coeficientes dos scores realmente mudam de comportamento entre os grupos de municípios, aplicamos um teste de restrição linear (ANOVA/Wald). Se o p-valor for menor que $0.05$, a hipótese de que "os scores geram o mesmo efeito em qualquer tipo de município" é rejeitada.

```R
# Testar se a interação com os clusters é significante conjunta (Fundamental II)
# O modelo restrito seria a regressão sem nenhuma menção ao cluster
mod_restrito_fund2 <- lm(ideb_observado ~ score_capacidade_atendimento + score_infraestrutura + 
                         score_capacitacao_docente + score_diversidade_discente + score_capacidade_gestora + 
                         score_sustentabilidade + media_inse, 
                         data = dados_com_cluster %>% filter(etapa == "fundamental_ii"))

anova(mod_restrito_fund2, mod_global_fund2)

```

### 3. Extração de Coeficientes por Cluster de Forma Direta

A desvantagem do sumário padrão do modelo interagido é que ele exibe os coeficientes do Cluster 1 e as *diferenças* ($\gamma$) para os demais. Para extrair os coeficientes reais de cada cluster de forma limpa e compará-los lado a lado com o seu script anterior, use a função `marginaleffects`:

```R
# Instale se necessário: install.packages("marginaleffects")
library(marginaleffects)

# Obter o efeito (inclinação) de cada score dentro de cada cluster de forma explícita
coeficientes_por_cluster <- slopes(
  mod_global_fund2,
  variables = preditores,
  by = "cluster_fct"
)

print(coeficientes_por_cluster)

```

Essa modelagem unificada resolve o problema estatístico de graus de liberdade do seu loop `for`, blinda sua análise contra variações artificiais causadas por amostras pequenas em clusters específicos e eleva o rigor analítico do EduMaps.
