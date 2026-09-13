# Clusterization

Aqui está um script em R estruturado exatamente como você pediu. Ele estabelece a conexão com o banco utilizando a configuração de serviço `"edumaps"` , busca as dimensões calculadas na sua view/tabela de scores e implementa uma função flexível e robusta para executar o algoritmo $K$-means com base nas variáveis escolhidas.

Como você mencionou que também deseja clusterizar pelo desempenho em exames (uma dimensão que não faz parte dessa tabela de infraestrutura/censo) , a função foi desenhada para aceitar dinamicamente qualquer coluna que você decida injetar no seu dataframe futuramente.

---

### Script R: Clusterização Flexível com $K$-means

```R
library(RPostgres)
library(dplyr)
library(tidyr)
library(cluster)

# 1. Conexão com o banco (ajuste conforme seu ambiente)
con <- dbConnect(RPostgres::Postgres(), service = "edumaps")

# 2. Busca os dados da tabela de scores do Censo 2025
# (Substitua 'nome_da_tabela_ou_view' pelo nome real da sua estrutura mapeada)
query_scores <- "
    SELECT 
        nu_ano_censo,
        co_entidade,
        score_capacidade_atendimento,
        score_infraestrutura,
        score_capacitacao_docente,
        score_diversidade_discente,
        score_capacidade_gestora,
        score_sustentabilidade
    FROM mv_escolas_scores;
"

df_escolas <- dbGetQuery(con, query_scores) %>% tibble::as_tibble()

# Opcional: Desconectar após extração se não for mais usar a sessão do banco
# dbDisconnect(con)


# 3. Função Genérica para Clusterização K-means
clusterizar_escolas <- function(data, variaveis, k = 3, seed = 42) {
  #' Executa o K-means em um dataframe de escolas baseado em variáveis selecionadas.
  #'
  #' @param data Tibble contendo os dados das escolas (deve incluir co_entidade).
  #' @param variaveis Vetor de strings com os nomes das colunas a serem usadas no modelo.
  #' @param k Número de clusters desejados (padrão: 3).
  #' @param seed Semente aleatória para reprodutibilidade (padrão: 42).
  #'
  #' @return O dataframe original com uma coluna adicional 'cluster' e os scores padronizados.
  
  set.seed(seed)
  
  # Filtrar dados para remover linhas com NA nas variáveis selecionadas e isolar as features
  dados_cluster <- data %>%
    drop_na(all_of(variaveis))
  
  if (nrow(dados_cluster) == 0) {
    stop("Erro: Nenhuma linha restou após a remoção de valores ausentes (NAs).")
  }
  
  # Extrair apenas a matriz numérica de interesse
  matriz_features <- dados_cluster %>% 
    select(all_of(variaveis))
  
  # Centralizar e escalar (Z-score) para evitar distorções por escalas diferentes
  matriz_escalada <- scale(matriz_features)
  
  # Executar o algoritmo K-means
  kmeans_resultado <- kmeans(matriz_escalada, centers = k, nstart = 25)
  
  # Adicionar o resultado de volta ao dataframe filtrado
  resultado <- dados_cluster %>%
    mutate(cluster = as.factor(kmeans_resultado$cluster))
  
  # Retorna uma lista com os dados finais e as estatísticas dos centros para análise
  return(list(
    dados = resultado,
    centros = kmeans_resultado$centers,
    tamanho_clusters = kmeans_resultado$size
  ))
}

```

---

### Exemplos Práticos de Uso

Aqui está como você pode chamar a função para atender a cada um dos cenários levantados no seu objetivo de negócio:

#### A. Clusterizar pelo Porte e Atendimento

Usando a dimensão de capacidade de atendimento calculada:

```R
colunas_atendimento <- c("score_capacidade_atendimento")
cluster_atendimento <- clusterizar_escolas(df_escolas, variaveis = colunas_atendimento, k = 3)

# Visualizar resumo do tamanho de cada cluster
print(cluster_atendimento$tamanho_clusters)

```

#### B. Clusterizar pelo Corpo Docente

Análise focada estritamente na capacitação dos professores:

```R
colunas_docente <- c("score_capacitacao_docente")
cluster_docente <- clusterizar_escolas(df_escolas, variaveis = colunas_docente, k = 3)

```

#### C. Clusterizar combinando Múltiplas Variáveis (Atendimento + Infraestrutura)

A função é flexível para receber duas ou mais dimensões ao mesmo tempo:

```R
colunas_mistas <- c("score_capacidade_atendimento", "score_infraestrutura")
cluster_misto <- clusterizar_escolas(df_escolas, variaveis = colunas_mistas, k = 4)

# Ver o perfil médio de cada score dentro dos clusters criados
print(cluster_misto$centros)

```

#### D. Nota sobre o Desempenho nos Exames

Como a sua view atual foca puramente em dimensões do Censo Escolar (infraestrutura, capacidade, sustentabilidade) , para usar a opção de **desempenho exibido nos exames** (como IDEB ou Saeb) , você precisará primeiro fazer um `LEFT JOIN` do seu dataframe `df_escolas` com a tabela correspondente do IDEB usando a chave única `co_entidade` e `nu_ano_censo`.

Uma vez adicionada a coluna (ex: `nota_ideb`), basta passar o nome dela na chamada da função:

```R
# Supondo que você adicionou a coluna 'nota_exame' ao tibble
cluster_desempenho <- clusterizar_escolas(df_escolas_com_ideb, variaveis = c("nota_exame"), k = 3)

```

### Detalhes de Implementação Relevantes:

* **`scale()`:** O script aplica uma normalização estatística básica nas colunas antes de rodar o algoritmo. Isso é vital para o $K$-means para garantir que uma variável com escala de 0 a 100 não domine o cálculo da distância Euclidiana sobre uma variável que varie de 0 a 1.
* **`nstart = 25`:** Garante que o R rode o algoritmo com 25 partições iniciais aleatórias diferentes, selecionando a melhor configuração local e evitando que o modelo fique preso em agrupamentos ruins causados por uma inicialização azarada.


# DeepSeek

Abaixo está um **script R completo** que atende aos seus requisitos:

1. Conecta ao banco de dados PostgreSQL usando `RPostgres` e o serviço `edumaps`.
2. Carrega os dados da view `mv_scores` (ou tabela equivalente) para um `tibble`.
3. Define uma função genérica `clusterizar_escolas()` que:
   - Recebe um dataframe e um vetor com **uma ou mais variáveis** (nomes das colunas).
   - Padroniza as variáveis (média 0, desvio 1).
   - Determina o número ideal de clusters (opcional: método do cotovelo ou silhueta).
   - Executa o algoritmo **k-means**.
   - Retorna o dataframe original acrescido de uma coluna `cluster`.
4. Demonstra como aplicar a função para os temas solicitados:
   - **Porte/atendimento** (`score_capacidade_atendimento`)
   - **Corpo docente** (`score_capacitacao_docente`)
   - **Infraestrutura** (`score_infraestrutura`)
   - *Desempenho em exames* – observação: a tabela fornecida **não contém notas de exames**. Caso essa coluna exista em outra tabela, basta incluí‑la no vetor `variaveis`.

O script é comentado em português e pode ser adaptado para outras variáveis ou bases.

```r
# ============================================================================
# Script R: Clusterização de Escolas via k-means
# Autor: (seu nome)
# Descrição: 
#   1. Conecta ao banco via RPostgres (service = "edumaps").
#   2. Obtém os scores das escolas a partir da view mv_scores.
#   3. Função flexível para clusterizar segundo quaisquer variáveis numéricas.
#   4. Exemplo de aplicação para os temas: atendimento, docentes, infraestrutura.
# ============================================================================

# Carregar bibliotecas necessárias
library(RPostgres)
library(dplyr)
library(tidyr)
library(ggplot2)   # para gráfico do cotovelo (opcional)

# ----------------------------------------------------------------------------
# 1. Conexão com o banco de dados
#    Certifique-se de que o arquivo ~/.pg_service.conf contenha uma entrada [edumaps]
#    com os parâmetros: host, port, dbname, user, password.
# ----------------------------------------------------------------------------
con <- dbConnect(
  RPostgres::Postgres(),
  service = "edumaps"
)

# ----------------------------------------------------------------------------
# 2. Carregar os dados da view (ou tabela) para um tibble
#    Ajuste o nome do esquema se necessário (ex: public.mv_scores)
# ----------------------------------------------------------------------------
escolas_tbl <- dbGetQuery(con, "SELECT * FROM mv_escolas_scores") %>%
  as_tibble()

# Desconectar após a leitura (opcional, mantenha aberto se for usar depois)
# dbDisconnect(con)

# Verificar as primeiras linhas e estrutura
glimpse(escolas_tbl)

# ----------------------------------------------------------------------------
# 3. Função para clusterizar escolas usando k-means
#    Parâmetros:
#      df        - tibble ou dataframe contendo as variáveis e, opcionalmente, co_entidade
#      variaveis - vetor de caracteres com os nomes das colunas a serem usadas no cluster
#      k         - número de clusters (se NULL, escolhe automaticamente pelo método do cotovelo)
#      metodo    - "elbow" (padrão) ou "silhouette" para determinar k ideal
#      max_k     - número máximo de clusters a testar (padrão = 10)
#    Retorno:
#      O mesmo dataframe com uma coluna adicional 'cluster'
# ----------------------------------------------------------------------------
clusterizar_escolas <- function(df, variaveis, k = NULL, 
                                metodo = "elbow", max_k = 10) {
  
  # Verificar se as variáveis existem no dataframe
  variaveis_presentes <- variaveis[variaveis %in% names(df)]
  if (length(variaveis_presentes) == 0) {
    stop("Nenhuma das variáveis informadas foi encontrada no dataframe.")
  }
  if (length(variaveis_presentes) < length(variaveis)) {
    warning(paste("Variáveis não encontradas:", 
                  paste(setdiff(variaveis, variaveis_presentes), collapse = ", ")))
  }
  
  # Extrair a matriz com as variáveis selecionadas
  dados_kmeans <- df %>%
    select(all_of(variaveis_presentes)) %>%
    na.omit()   # remove linhas com NA (ou você pode tratar de outra forma)
  
  if (nrow(dados_kmeans) == 0) {
    stop("Não há dados válidos após remoção de NAs nas variáveis selecionadas.")
  }
  
  # Padronizar os dados (média 0, desvio 1)
  dados_padronizados <- scale(dados_kmeans)
  
  # Determinar número ótimo de clusters (se k não foi fornecido)
  if (is.null(k)) {
    if (metodo == "elbow") {
      # Método do cotovelo (within sum of squares)
      wss <- sapply(1:max_k, function(i) {
        kmeans(dados_padronizados, centers = i, nstart = 25, iter.max = 100)$tot.withinss
      })
      # Gráfico do cotovelo (opcional, descomente se quiser visualizar)
      # plot(1:max_k, wss, type = "b", pch = 19, 
      #      xlab = "Número de clusters (k)", ylab = "Soma total de quadrados intra-cluster")
      
      # Escolhe o k onde a redução começa a se estabilizar (regra do "ponto de joelho" simples)
      # Aumentos percentuais menores que 10% após o primeiro mínimo local?
      # Vamos usar o critério do maior "gap" relativo:
      diferencas <- -diff(wss)
      if (max(diferencas) > 0) {
        k_ideal <- which.max(diferencas) + 1
      } else {
        k_ideal <- 2
      }
      k <- min(k_ideal, max_k)
      message(paste("Número de clusters selecionado pelo método do cotovelo:", k))
      
    } else if (metodo == "silhouette") {
      # Método da silhueta (requer library(cluster))
      if (!requireNamespace("cluster", quietly = TRUE)) {
        install.packages("cluster")
      }
      library(cluster)
      sil_width <- sapply(2:max_k, function(i) {
        km <- kmeans(dados_padronizados, centers = i, nstart = 25, iter.max = 100)
        ss <- silhouette(km$cluster, dist(dados_padronizados))
        mean(ss[, 3])
      })
      k <- which.max(sil_width) + 1
      message(paste("Número de clusters selecionado pelo método da silhueta:", k))
    } else {
      stop("Método deve ser 'elbow' ou 'silhouette'")
    }
  } else {
    # Se k foi fornecido, valida se é um número positivo
    if (k < 2) stop("O número de clusters deve ser >= 2.")
  }
  
  # Executar k-means com o k definido
  set.seed(123)  # reprodutibilidade
  km_result <- kmeans(dados_padronizados, centers = k, nstart = 25, iter.max = 100)
  
  # Adicionar os clusters ao dataframe original (mantendo linhas com NA)
  # Primeiro cria um vetor de NA do tamanho do df original
  clusters_orig <- rep(NA_integer_, nrow(df))
  # Recupera os índices das linhas que foram usadas (após na.omit)
  linhas_usadas <- which(complete.cases(df[, variaveis_presentes]))
  clusters_orig[linhas_usadas] <- km_result$cluster
  df$cluster <- clusters_orig
  
  # Retornar o dataframe enriquecido
  return(df)
}

# ----------------------------------------------------------------------------
# 4. Exemplo de uso para cada tema solicitado
# ----------------------------------------------------------------------------

# a) Clusterizar por porte / capacidade de atendimento
escolas_com_cluster_atend <- clusterizar_escolas(
  df = escolas_tbl,
  variaveis = "score_capacidade_atendimento",
  k = 3,            # opcional: defina manualmente; se NULL, a função escolhe
  metodo = "elbow"
)

# b) Clusterizar por corpo docente (capacitação docente)
escolas_com_cluster_docente <- clusterizar_escolas(
  df = escolas_tbl,
  variaveis = "score_capacitacao_docente",
  k = 4,
  metodo = "elbow"
)

# c) Clusterizar por infraestrutura
escolas_com_cluster_infra <- clusterizar_escolas(
  df = escolas_tbl,
  variaveis = "score_infraestrutura",
  k = 3,
  metodo = "elbow"
)

# d) Clusterizar por desempenho em exames (atenção: a tabela mv_scores NÃO contém essa coluna)
#    Se existir uma coluna chamada, por exemplo, 'score_desempenho_exames' em outra tabela,
#    faça o join antes e depois chame a função:
#    escolas_completa <- escolas_tbl %>%
#      left_join(outra_tabela, by = c("nu_ano_censo", "co_entidade"))
#    escolas_cluster_exames <- clusterizar_escolas(escolas_completa, "score_desempenho_exames")

# Observação: caso queira clusterizar usando MAIS DE UMA variável (ex: atendimento + docente)
# basta passar um vetor:
escolas_cluster_mult <- clusterizar_escolas(
  df = escolas_tbl,
  variaveis = c("score_capacidade_atendimento", "score_capacitacao_docente"),
  k = 4
)

# ----------------------------------------------------------------------------
# 5. Visualização rápida dos resultados (exemplo para o primeiro cluster)
# ----------------------------------------------------------------------------
# Tabela resumo por cluster (média das variáveis originais)
resumo_cluster <- escolas_com_cluster_atend %>%
  group_by(cluster) %>%
  summarise(
    n_escolas = n(),
    media_atendimento = mean(score_capacidade_atendimento, na.rm = TRUE),
    .groups = "drop"
  )
print(resumo_cluster)

# ----------------------------------------------------------------------------
# Fim do script
# ----------------------------------------------------------------------------
```

## Explicações importantes

1. **Variável “desempenho em exames”** – A view `mv_scores` fornecida **não contém notas ou scores de exames**. Caso você possua essa informação em outra tabela (ex: `censo_desempenho`), faça um `left_join()` com `escolas_tbl` e então passe o nome da coluna para a função `clusterizar_escolas()`. O script está preparado para receber **qualquer coluna numérica** existente no dataframe.

2. **Conexão com o banco** – O código utiliza `service = "edumaps"`. Você precisa ter o arquivo `~/.pg_service.conf` configurado com os parâmetros do seu banco. Exemplo de conteúdo:
   ```
   [edumaps]
   host=meu_host
   port=5432
   dbname=meu_banco
   user=meu_usuario
   password=minha_senha
   ```

3. **Tratamento de NAs** – A função remove linhas com `NA` nas variáveis de clusterização antes de rodar o k‑means. As linhas removidas recebem `NA` na coluna `cluster`. Você pode alterar esse comportamento (ex: imputar valores) se desejar.

4. **Escolha automática do número de clusters** – Se `k = NULL`, a função aplica o método do cotovelo (padrão) ou o da silhueta. O método do cotovelo aqui implementado é simplificado (máxima queda da soma de quadrados). Para maior precisão, você pode ajustar o critério ou passar `k` manualmente.

5. **Performance** – Para bases muito grandes (milhões de escolas), k‑means pode ser lento. Considere amostrar ou utilizar algoritmos mais escaláveis (ex: `kmeans` do pacote `bigstatsr`). O script já utiliza `nstart = 25` e `iter.max = 100` para boa convergência.

## Como usar a função com **uma ou mais variáveis**

Basta chamar a função passando um vetor com os nomes das colunas desejadas:

```r
# Apenas uma variável
df_cluster <- clusterizar_escolas(df, variaveis = "score_infraestrutura")

# Múltiplas variáveis
df_cluster <- clusterizar_escolas(df, variaveis = c("score_capacidade_atendimento", 
                                                    "score_capacitacao_docente"))
```

A coluna `cluster` será adicionada ao final do dataframe original, permitindo análises subsequentes.


## Resultados interessantes

Com base nos resultados da clusterização por `score_capacitacao_docente` (capacitação do corpo docente), segue a análise análoga à que fizemos para infraestrutura.

## Ordem dos clusters (do pior ao melhor score)

| Cluster | Média de `score_capacitacao_docente` | Total de escolas |
|---------|--------------------------------------|------------------|
| **4**   | 1,31                                 | 3.606            |
| **5**   | 3,74                                 | 12.903           |
| **1**   | 5,34                                 | 15.989           |
| **3**   | 6,97                                 | 15.656           |
| **2**   | 8,59                                 | 12.862           |

## Composição percentual por dependência (do pior ao melhor cluster)

| Cluster (pior → melhor) | Federal | Estadual | Municipal | Privada | Total |
|------------------------|--------|----------|----------|--------|-------|
| **4** (pior)           | 0,0%   | 11,1%    | **71,3%**| 17,6%  | 3.606 |
| **5**                  | 0,0%   | 13,2%    | 24,8%    | **62,0%**| 12.903 |
| **1**                  | 0,02%  | 38,7%    | 31,8%    | 29,5%  | 15.989 |
| **3**                  | 0,04%  | 37,8%    | **55,5%**| 6,7%   | 15.656 |
| **2** (melhor)         | 0,25%  | 28,6%    | **71,0%**| 0,2%   | 12.862 |

> **Nota:** As cores em negrito destacam a dependência predominante em cada cluster.

## Principais conclusões

### 1. Padrão completamente diferente da infraestrutura
Enquanto na infraestrutura as escolas municipais estavam concentradas nos piores clusters e as federais/privadas nos melhores, aqui a situação é mais complexa e até **inversa** em alguns pontos:

- **Melhor capacitação docente (cluster 2)** – surpreendentemente, **71% são escolas municipais**. A rede municipal lidera no topo, junto com uma pequena participação estadual (28,6%). Privadas e federais são quase inexistentes nesse grupo.
- **Segundo melhor (cluster 3)** – também dominado por municipais (55,5%), seguidas por estaduais (37,8%).
- **Pior capacitação (cluster 4)** – municipais representam 71,3%, mas agora no extremo inferior. Ou seja, **as escolas municipais estão nos dois extremos**: tanto as melhor capacitadas quanto as pior capacitadas. Isso indica **alta heterogeneidade** dentro da rede municipal.
- **Cluster 5** (segundo pior) – curiosamente, **62% são escolas privadas**. É o único cluster onde privadas são maioria, e está entre os de baixa capacitação docente.
- **Escolas federais** – poucas, mas aparecem nos clusters de capacitação mediana a alta (1, 2, 3), nenhuma nos piores.

### 2. Distribuição das redes ao longo dos clusters

| Dependência | Onde se concentra? | Interpretação |
|-------------|--------------------|----------------|
| **Municipal** | Bimodal: forte nos piores (cluster 4) e nos melhores (clusters 2 e 3) | Há escolas municipais com excelente capacitação docente e outras com péssima. Isso pode refletir diferenças regionais, porte, ou investimento em formação continuada. |
| **Estadual** | Predomina nos clusters intermediários (1 e 3) e tem participação razoável no melhor (2) | Distribuição relativamente equilibrada, ligeiramente inclinada para níveis médios-altos. |
| **Privada** | Concentrada no cluster 5 (62%) – baixa capacitação – e também presente no cluster 4 (17,6%) | A maioria das escolas privadas está entre os piores níveis de capacitação docente. Isso é contraintuitivo, pois se esperava que privadas investissem mais em formação. Pode ser um artefato da definição do score (talvez priorize formação específica como pós-graduação, que não é tão comum em privadas de pequeno porte) ou indicar que muitas privadas têm docentes sem qualificação adequada. |
| **Federal** | Muito poucas, mas todas com capacitação mediana a alta | Reforça a qualidade da rede federal, embora com número inexpressivo. |

### 3. Contraste com infraestrutura

- **Infraestrutura**: federais e privadas no topo; municipais na base.
- **Capacitação docente**: municipais no topo e na base; privadas na base; estaduais no meio.

Isso sugere que **os determinantes da qualidade docente são distintos dos de infraestrutura**. Por exemplo, uma escola pode ter boa estrutura física, mas corpo docente despreparado (caso de muitas privadas no cluster 5) ou o oposto (municipais com boa capacitação, mas infraestrutura precária).

## Recomendações para gestão

- **Para a rede municipal**: há um grupo de escolas (cluster 2 e 3) com excelente capacitação docente. É importante identificar boas práticas (formação continuada, planos de carreira, parcerias) para replicar nas escolas municipais que estão no cluster 4 (pior capacitação).
- **Para a rede privada**: a forte concentração nos piores clusters de capacitação docente é um alerta. Órgãos reguladores (conselhos de educação) poderiam exigir maior qualificação dos professores, especialmente em escolas privadas de menor porte.
- **Análise multivariada**: recomendo fazer uma clusterização considerando **simultaneamente** infraestrutura e capacitação docente. Você pode usar `variaveis = c("score_infraestrutura", "score_capacitacao_docente")` na função. Isso revelará perfis como: escolas com boa infra e boa docência (ideal), boa infra mas docência fraca (privadas?), infra fraca mas docência boa (municipais?), etc.

## Visualização sugerida

Para comunicar o padrão bimodal das escolas municipais, um gráfico de densidade ou boxplot por dependência é útil:

```r
library(ggplot2)
ggplot(escolas_com_cluster_docente, aes(x = score_capacitacao_docente, fill = tp_dependencia)) +
  geom_density(alpha = 0.5) +
  labs(title = "Distribuição do score de capacitação docente por dependência",
       x = "Score de capacitação docente", y = "Densidade") +
  theme_minimal()
```

Caso queira aprofundar comparando os dois scores (infra vs docente), posso ajudar a gerar uma matriz de clusters ou uma análise de correlação.
Vamos aprofundar a relação entre infraestrutura (`score_infraestrutura`) e capacitação docente (`score_capacitacao_docente`). Para isso, usaremos a tabela original `escolas_tbl` (que contém ambas as colunas) e realizaremos análises conjuntas.

## 1. Correlação entre os dois scores

Primeiro, verifique a força da associação linear:

```r
# Correlação de Pearson (ignorando NAs)
correlacao <- escolas_tbl %>%
  summarise(
    cor = cor(score_infraestrutura, score_capacitacao_docente, use = "complete.obs")
  )
print(correlacao)
```

**Interpretação esperada:** Provavelmente uma correlação **baixa a moderada** (ex: 0,3 a 0,5), indicando que infraestrutura e capacitação docente não andam tão juntas – o que já foi sugerido pelas análises separadas (municipais com boa docência mas infra baixa, privadas com boa infra mas docência baixa).

## 2. Gráfico de dispersão com dependência

```r
library(ggplot2)

ggplot(escolas_tbl, aes(x = score_infraestrutura, y = score_capacitacao_docente, color = tp_dependencia)) +
  geom_point(alpha = 0.3, size = 0.8) +
  geom_smooth(method = "lm", se = FALSE, aes(group = 1), color = "black", linetype = "dashed") +
  labs(
    title = "Relação entre infraestrutura e capacitação docente",
    x = "Score de infraestrutura", y = "Score de capacitação docente",
    color = "Dependência"
  ) +
  theme_minimal()
```

Esse gráfico permitirá visualizar:
- **Privadas** (geralmente alta infra, mas docência espalhada – muitas com baixa docência).
- **Municipais** (maior concentração em infra baixa, mas docência variando do muito baixo ao muito alto).
- **Estaduais** (posição intermediária em ambos).

## 3. Clusterização conjunta (k-means com ambas as variáveis)

Crie perfis combinados usando a mesma função `clusterizar_escolas()` com duas variáveis:

```r
escolas_cluster_junto <- clusterizar_escolas(
  df = escolas_tbl,
  variaveis = c("score_infraestrutura", "score_capacitacao_docente"),
  k = 4,  # escolha um número razoável; teste 4 ou 5
  metodo = "elbow"
)
```

Depois, analise os clusters resultantes:

```r
# Médias de cada cluster para as duas dimensões
clusters_summary <- escolas_cluster_junto %>%
  group_by(cluster) %>%
  summarise(
    media_infra = mean(score_infraestrutura, na.rm = TRUE),
    media_docente = mean(score_capacitacao_docente, na.rm = TRUE),
    n = n()
  ) %>%
  arrange(media_infra, media_docente)
print(clusters_summary)

# Composição por dependência
clusters_dependencia <- escolas_cluster_junto %>%
  group_by(cluster, tp_dependencia) %>%
  summarise(total = n()) %>%
  group_by(cluster) %>%
  mutate(percent = total / sum(total) * 100) %>%
  arrange(cluster)
print(clusters_dependencia, n = Inf)
```

### Exemplo de perfis que podem surgir (baseado nos padrões observados separadamente):

| Cluster | Infraestrutura | Capacitação docente | Perfil predominante |
|---------|---------------|---------------------|---------------------|
| A       | Alta          | Alta                | Federais + parte estaduais e privadas de elite |
| B       | Alta          | Baixa               | **Privadas** (boa estrutura, professores despreparados) |
| C       | Baixa         | Alta                | **Municipais** (estrutura ruim, mas docentes capacitados) |
| D       | Baixa         | Baixa               | Municipais e estaduais mais vulneráveis |

O cluster B (alto infra + baixo docente) seria muito revelador – indicaria escolas que investiram em prédios, laboratórios, mas negligenciaram a formação de professores. O cluster C indicaria o oposto.

## 4. Análise de desvios (resíduos)

Para identificar escolas que fogem do padrão geral (ex: infra muito acima do esperado para sua capacitação docente), podemos calcular resíduos de uma regressão linear:

```r
modelo <- lm(score_infraestrutura ~ score_capacitacao_docente, data = escolas_tbl)
escolas_tbl <- escolas_tbl %>%
  mutate(
    residuo_infra = residuals(modelo),
    tipo_desvio = case_when(
      residuo_infra > 1.5 * sd(residuo_infra, na.rm = TRUE) ~ "Infra muito maior que o esperado",
      residuo_infra < -1.5 * sd(residuo_infra, na.rm = TRUE) ~ "Infra muito menor que o esperado",
      TRUE ~ "Esperado"
    )
  )

# Ver dependências com maior proporção de desvios positivos (infra acima do esperado)
escolas_tbl %>%
  filter(!is.na(tipo_desvio)) %>%
  group_by(tp_dependencia, tipo_desvio) %>%
  summarise(n = n()) %>%
  group_by(tp_dependencia) %>%
  mutate(prop = n / sum(n)) %>%
  filter(tipo_desvio == "Infra muito maior que o esperado")
```

Isso dirá, por exemplo, se privadas tendem a ter infra maior do que o previsto pela sua capacitação docente.

## 5. Visualização dos clusters conjuntos

```r
library(ggplot2)

ggplot(escolas_cluster_junto, aes(x = score_infraestrutura, y = score_capacitacao_docente, color = factor(cluster))) +
  geom_point(alpha = 0.4) +
  stat_ellipse(aes(fill = factor(cluster)), geom = "polygon", alpha = 0.1, show.legend = FALSE) +
  labs(
    title = "Clusters combinando infraestrutura e capacitação docente",
    x = "Score de infraestrutura", y = "Score de capacitação docente",
    color = "Cluster"
  ) +
  theme_minimal()
```

## O que esperar dos resultados?

Com base nas análises separadas que você já fez:

- **Municipais** devem dominar os clusters de **baixa infra + alta docência** e também de **baixa infra + baixa docência** (devido à heterogeneidade).
- **Privadas** devem se concentrar em **alta infra + baixa docência** (cluster 5 da docente sozinho já mostrou 62% de privadas com baixa capacitação).
- **Federais** (poucas) aparecerão em **alta infra + alta docência**.
- **Estaduais** ficarão nos quadrantes intermediários.

Esses achados são importantes para formular políticas diferenciadas:  
- Para escolas com **boa docência mas infra ruim** (municipais): prioridade em investimento físico.  
- Para escolas com **boa infra mas docência ruim** (privadas): programas de formação continuada ou exigência regulatória.

Rode os códigos acima com seus dados e compartilhe os resultados (tabelas resumo dos clusters conjuntos) para que possamos interpretar juntos.

## Interessante resultados

O resultado que você mostrou é extremamente revelador e confirma a hipótese levantada anteriormente: **escolas privadas têm uma tendência muito maior de apresentar infraestrutura “excessivamente boa” em relação ao que seria esperado pela sua capacitação docente**.

## Interpretação do resultado

A análise de resíduos identificou escolas cujo `score_infraestrutura` é **> 1,5 desvios padrão acima** do valor previsto por uma regressão linear tendo `score_capacitacao_docente` como preditor. Em outras palavras, são escolas que **investiram muito mais em estrutura física do que em formação de professores**, comparado à média geral.

| Dependência | Nº de escolas com infra muito acima do esperado | Proporção dentro da rede |
|-------------|------------------------------------------------|---------------------------|
| **Privada** | 1.341                                         | **9,29%**                 |
| Estadual    | 169                                           | 0,95%                     |
| Municipal   | 35                                            | 0,12%                     |

### Principais insights

1. **Desalinhamento crítico na rede privada**: Quase 1 em cada 10 escolas privadas possui uma infraestrutura muito superior ao que seria justificado pela qualificação de seus professores. Isso sugere um padrão de investimento **focado em ativos físicos** (prédios, laboratórios, bibliotecas, etc.) em detrimento da **formação continuada, pós-graduação ou planos de carreira docente**.

2. **Redes pública e municipal são mais equilibradas**: A proporção muito baixa (menos de 1%) nessas redes indica que, quando a infraestrutura é boa, a capacitação docente também tende a ser boa (ou vice-versa). Não há o mesmo descolamento observado nas privadas.

3. **O oposto (infra muito abaixo do esperado)** – você não mostrou, mas seria igualmente importante. Sugiro rodar:
   ```r
   escolas_tbl %>%
     filter(!is.na(tipo_desvio)) %>%
     group_by(tp_dependencia, tipo_desvio) %>%
     summarise(n = n()) %>%
     group_by(tp_dependencia) %>%
     mutate(prop = n / sum(n)) %>%
     filter(tipo_desvio == "Infra muito menor que o esperado")
   ```
   Provavelmente veremos **municipais** liderando nesse caso, confirmando a situação oposta: boa docência com infra ruim.

## Por que isso é relevante para a gestão?

- **Para escolas privadas**: órgãos reguladores (conselhos de educação, secretarias) poderiam exigir comprovação de investimentos em formação docente proporcional aos investimentos em infraestrutura. Pais e responsáveis podem usar essa informação ao escolher uma escola – uma estrutura bonita não garante professores bem preparados.
- **Para políticas públicas**: o FIES, ProUni ou outros programas de financiamento a privadas poderiam condicionar benefícios a indicadores de capacitação docente.
- **Para as próprias escolas privadas**: o resultado sugere uma oportunidade de realocação de recursos – investir em capacitação pode trazer maior retorno em qualidade do que novas quadras ou laboratórios.

## Próxima etapa: clusterização conjunta (infra + docente)

Agora que vimos o desalinhamento, a **clusterização com as duas variáveis simultaneamente** vai classificar as escolas exatamente nesses perfis. Peço que rode o código da clusterização conjunta que sugeri anteriormente (com `k = 4` ou `5`) e compartilhe as duas saídas:

1. `clusters_summary` (médias de infra e docente por cluster)
2. `clusters_dependencia` (composição por dependência)

Com isso, poderemos nomear cada cluster de forma substantiva, por exemplo:
- **Cluster A**: Alta infra + Alta docente (excelência)
- **Cluster B**: Alta infra + Baixa docente (privadas desalinhadas)
- **Cluster C**: Baixa infra + Alta docente (municipais esforçadas)
- **Cluster D**: Baixa infra + Baixa docente (vulnerabilidade)

Aguardo os resultados.
