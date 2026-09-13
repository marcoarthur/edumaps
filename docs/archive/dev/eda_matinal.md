# Questão

> tenho um plano de estudo para aumentar a prática de EDA, fazendo uma pergunta matinal e tentando responder com dados a essa pergunta (aprendendo assim técnicas estatísticas também), minha pergunta hoje é " Escolas próximas a universidades possuem melhor desempenho que escolas afastadas" ? Para tornar mais específica, apenas escolas de ensino fundamental I (1-4 série) . Existe um teste estatístico clássico neste caso ? ou qual o melhor desenho/plano para responder a essa pergunta ?

Essa é uma pergunta fantástica e digna de uma excelente pesquisa empírica! O seu plano de estudos baseado em "perguntas matinais" é uma das formas mais eficientes de consolidar ciência de dados, porque força você a pensar no **desenho metodológico** antes de simplesmente sair rodando códigos.

Para responder a essa pergunta específica sobre o Ensino Fundamental I (anos iniciais), o desafio principal não é a matemática em si, mas como você vai **definir "próximas"**, **medir "desempenho"** e **isolar o efeito da universidade** de outros fatores urbanos (como o fato de que universidades geralmente ficam em bairros mais ricos).

Aqui está o plano de voo ideal e os testes estatísticos clássicos para esse cenário.

---

## 1. O Desenho dos Dados (Preparação)

Antes de rodar o teste, você precisará estruturar seu dataframe final com três pilares por escola:

1. **Identificação e Alvo:** `co_entidade` e a nota média do SAEB/IDEB (sua métrica de desempenho).
2. **A Métrica Espacial (A Distância):** Você precisará das coordenadas geográficas (latitude/longitude) das escolas e das universidades. A partir daí, calcula a distância em quilômetros (usando a distância de Haversine ou pacotes como `sf` no R).
3. **Fatores de Confusão:** O INSE (Indicador de Nível Socioeconômico) da escola e a localização (Urbana/Rural).

---

## 2. Abordagem 1: O Teste Estatístico Clássico (Visão Binária)

Se você definir "próxima" como um ponto de corte rígido (ex: *"Escolas a menos de 2 km de uma universidade são consideradas próximas, e o resto é afastada"*), você dividirá suas escolas em dois grupos mutuamente exclusivos.

### O Teste Ideal: **Teste t de Student (ou Teste de Wilcoxon)**

* **O que ele faz:** Compara se a média das notas do Grupo A (Próximas) é estatisticamente diferente da média do Grupo B (Afastadas).
* **Como escolher:**
* Se a distribuição das notas nas escolas for normal (sino perfeito): Use o **Teste t de Student para amostras independentes** (`t.test()`).
* Se a distribuição for distorcida ou tiver muitos *outliers*: Use o **Teste de Wilcoxon-Mann-Whitney** (`wilcox.test()`), que é a versão não-paramétrica (baseada em ranks, mais robusta).



> ⚠️ **O Perigo Oculto (Viés):** Se você notar que o grupo "Próximas" tem notas maiores, pode ser apenas porque as universidades ficam nos centros das grandes cidades, onde as escolas já são naturalmente mais ricas. O teste t sozinho não corrige isso.

---

## 3. Abordagem 2: A Visão Contínua (Mais Elegante para EDA)

Em vez de criar uma barreira artificial de 2 km, trate a distância como uma linha contínua. Uma escola a 2.1 km não é tão diferente de uma a 1.9 km.

### O Teste Ideal: **Correlação de Spearman e Regressão Linear**

* **Passo 1 (Gráfico de Dispersão):** Plote no eixo X a `distancia_universidade_km` e no eixo Y a `nota_saeb`. Veja visualmente se há uma tendência de queda na nota conforme a distância aumenta.
* **Passo 2 (Correlação):** Calcule a **Correlação de Spearman** (`cor(..., method="spearman")`). Ela vai te dar um número entre -1 e 1. Espera-se uma correlação negativa (quanto menor a distância, maior a nota).
* **Passo 3 (Regressão Linear Múltipla - O padrão ouro aqui):**
Para isolar o efeito da universidade e garantir que você não está apenas medindo a riqueza do bairro, rode uma regressão controlando pelo INSE:

$$\text{Nota} = \beta_0 + \beta_1(\text{Distância}) + \beta_2(\text{INSE}) + \epsilon$$


No R: `lm(nota_media ~ distancia_km + media_inse, data = suas_escolas)`
* **O que olhar:** O p-valor e o coeficiente da `distancia_km`. Se mesmo controlando pelo nível socioeconômico (`media_inse`) a distância continuar sendo significativa, você tem um forte indício estatístico a favor da sua hipótese!



---

## 4. Abordagem Avançada: Pareamento (*Propensity Score Matching*)

Se você quiser elevar o nível da sua EDA e simular um "experimento científico controlado", estude o conceito de **Matching** (pacote `MatchIt` no R).

Como você não pode mover as escolas de lugar, você faz o seguinte: para cada escola "próxima a uma universidade", o algoritmo encontra uma escola "afastada" que tenha **exatamente o mesmo nível socioeconômico (INSE)**, mesmo tamanho e mesma dependência administrativa (Estadual/Municipal).

Depois que você cria esses "pares gêmeos", você roda o **Teste t pareado** apenas neles. Qualquer diferença na nota encontrada ali terá uma chance muito maior de ser um efeito real da proximidade da universidade (ou do ecossistema que ela gera ao redor).

---

### Seu plano de ação para hoje:

1. Filtrar a base do Censo/Inse apenas para escolas de Ensino Fundamental I.
2. Calcular a distância de cada escola até a universidade mais próxima.
3. Fazer um boxplot: Notas do Grupo Próximo vs. Grupo Afastado.
4. Aplicar o **Teste de Wilcoxon** ou partir para a **Regressão Linear Múltipla** para controlar pelo INSE.

# Distribuicao das notas

Sim, excelente ideia. Antes de confiar no teste t, é essencial verificar a forma das distribuições, especialmente assimetrias, caudas e possíveis multimodalidades.

## Código para histogramas comparativos

```r
library(ggplot2)
library(dplyr)

# Criar a variável de grupo
dados <- dados %>%
  mutate(grupo = ifelse(nro_etapas == 1, "Única etapa", "Múltiplas etapas"))

# Histograma sobreposto com transparência
ggplot(dados, aes(x = nota_media, fill = grupo)) +
  geom_histogram(aes(y = after_stat(density)), 
                 alpha = 0.5, position = "identity", bins = 30) +
  labs(x = "IDEB (Fundamental I, 2023, Sudeste)", 
       y = "Densidade",
       title = "Distribuição das notas por grupo") +
  theme_minimal() +
  scale_fill_manual(values = c("#1b9e77", "#d95f02"))
```

## Versão com curvas de densidade (mais suave)

```r
ggplot(dados, aes(x = nota_media, color = grupo, fill = grupo)) +
  geom_density(alpha = 0.4, linewidth = 1) +
  labs(x = "IDEB", y = "Densidade", title = "Densidade das notas por grupo") +
  theme_minimal() +
  scale_color_manual(values = c("#1b9e77", "#d95f02")) +
  scale_fill_manual(values = c("#1b9e77", "#d95f02"))
```

## Gráfico de quantil-quantil (Q-Q plot) por grupo

Para avaliar a normalidade mais formalmente:

```r
# Separar as notas
notas_1 <- dados$nota_media[dados$nro_etapas == 1]
notas_2 <- dados$nota_media[dados$nro_etapas >= 2]

# Q-Q plots lado a lado
par(mfrow = c(1,2))
qqnorm(notas_1, main = "Única etapa"); qqline(notas_1, col = "red")
qqnorm(notas_2, main = "Múltiplas etapas"); qqline(notas_2, col = "red")
par(mfrow = c(1,1))
```

Com esses gráficos você poderá decidir se o teste t de Welch é razoável (distribuições aproximadamente simétricas e sem outliers extremos) ou se prefere o teste de Mann-Whitney.
Boa sorte com a pergunta do dia! Se precisar de ajuda para estruturar o SQL da distância ou a sintaxe do teste no R quando chegar na etapa do código, é só chamar.


## R script para análise exploratória e testes estatísticos

Com base nos seus dados (tabela `censo_escolas` + `ideb_notas_escolas`), seguem os códigos em **R** para responder à pergunta:  
*"Escolas que oferecem uma única etapa possuem, em média, notas melhores?"*

### 1. Conexão com o banco de dados e obtenção dos dados

```r
# Opção 1: via DBI + odbc (exemplo para PostgreSQL)
library(DBI)
library(odbc)
con <- dbConnect(odbc(), dsn = "seu_bd", database = "seu_db")

query <- "
SELECT me.nro_etapas, nota_ideb.nota_media AS nota_ideb,
       me.tp_dependencia, me.tp_localizacao
FROM clean.censo_escolas me
INNER JOIN clean.ideb_notas_escolas nota_ideb 
  ON nota_ideb.id_escola = me.co_entidade
WHERE me.no_regiao = 'Sudeste' 
  AND nota_ideb.ano = 2023 
  AND nota_ideb.etapa = 'fundamental_i'
  AND me.nro_etapas > 0
"

df <- dbGetQuery(con, query)
dbDisconnect(con)
```

Caso já tenha um arquivo CSV ou data frame, basta carregá-lo.

### 2. Pacotes necessários

```r
library(tidyverse)   # ggplot2, dplyr, tidyr
library(rstatix)     # testes estatísticos amigáveis
library(ggpubr)      # gráficos prontos
```

### 3. Preparação das variáveis

```r
df <- df %>%
  mutate(
    grupo_etapas = ifelse(nro_etapas == 1, "Única etapa", "Múltiplas etapas"),
    grupo_etapas = factor(grupo_etapas, levels = c("Única etapa", "Múltiplas etapas")),
    tp_dependencia = as.factor(tp_dependencia),
    tp_localizacao = as.factor(tp_localizacao)
  )
```

### 4. Análise descritiva e gráficos

#### a) Tabela resumo por `nro_etapas`

```r
df %>%
  group_by(nro_etapas) %>%
  summarise(
    n = n(),
    media = mean(nota_ideb, na.rm = TRUE),
    dp = sd(nota_ideb, na.rm = TRUE),
    ic_inf = media - qt(0.975, n-1) * dp / sqrt(n),
    ic_sup = media + qt(0.975, n-1) * dp / sqrt(n)
  ) %>%
  print()
```

#### b) Gráfico de barras com intervalos de confiança (95%)

```r
df %>%
  group_by(nro_etapas) %>%
  summarise(
    media = mean(nota_ideb, na.rm = TRUE),
    n = n(),
    se = sd(nota_ideb, na.rm = TRUE) / sqrt(n)
  ) %>%
  ggplot(aes(x = as.factor(nro_etapas), y = media)) +
  geom_col(fill = "steelblue") +
  geom_errorbar(aes(ymin = media - 1.96*se, ymax = media + 1.96*se), width = 0.2) +
  labs(x = "Número de etapas/modalidades", y = "IDEB médio (Fundamental I, 2023)",
       title = "Sudeste – Média do IDEB por quantidade de etapas") +
  theme_minimal()
```

#### c) Boxplot: única etapa vs. múltiplas etapas

```r
ggplot(df, aes(x = grupo_etapas, y = nota_ideb, fill = grupo_etapas)) +
  geom_boxplot(alpha = 0.7, outlier.shape = 1) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "red") +
  labs(x = "", y = "IDEB", title = "Distribuição do IDEB por grupo") +
  theme_minimal() +
  scale_fill_manual(values = c("#1b9e77", "#d95f02")) +
  theme(legend.position = "none")
```

#### d) Histograma + densidade (KDE)

```r
ggplot(df, aes(x = nota_ideb, fill = grupo_etapas, color = grupo_etapas)) +
  geom_histogram(aes(y = after_stat(density)), alpha = 0.4, position = "identity", bins = 30) +
  geom_density(alpha = 0.6, linewidth = 1) +
  labs(x = "IDEB", y = "Densidade", title = "Distribuição do IDEB por grupo") +
  theme_minimal() +
  scale_fill_manual(values = c("#1b9e77", "#d95f02")) +
  scale_color_manual(values = c("#1b9e77", "#d95f02"))
```

### 5. Testes estatísticos

#### a) Verificar normalidade (Shapiro-Wilk) – amostras grandes

```r
# Para grupos com muitos casos, testamos uma amostra aleatória (limite 5000)
set.seed(123)
notas_1 <- df %>% filter(grupo_etapas == "Única etapa") %>% pull(nota_ideb)
notas_2 <- df %>% filter(grupo_etapas == "Múltiplas etapas") %>% pull(nota_ideb)

if(length(notas_1) > 5000) notas_1 <- sample(notas_1, 5000)
if(length(notas_2) > 5000) notas_2 <- sample(notas_2, 5000)

shapiro.test(notas_1)  # p normalmente << 0.05 (dados não normais)
shapiro.test(notas_2)
```

Como as amostras são muito grandes, o teste de normalidade será significativo mesmo para pequenos desvios. **Na prática, o teste t é robusto devido ao TLC.**

#### b) Homogeneidade das variâncias (Levene)

```r
levene_test(df, nota_ideb ~ grupo_etapas)
```

#### c) Teste t de Welch (não assume variâncias iguais)

```r
t_test_result <- t.test(nota_ideb ~ grupo_etapas, data = df, var.equal = FALSE)
t_test_result
```

#### d) Alternativa não paramétrica: Mann-Whitney

```r
wilcox.test(nota_ideb ~ grupo_etapas, data = df)
```

### 6. Análise estratificada por dependência administrativa

Para verificar se o efeito se mantém dentro de cada `tp_dependencia`:

```r
df %>%
  group_by(tp_dependencia, grupo_etapas) %>%
  summarise(
    media = mean(nota_ideb, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = tp_dependencia, y = media, fill = grupo_etapas)) +
  geom_col(position = position_dodge(0.9)) +
  labs(x = "Dependência administrativa (1-Federal,2-Estadual,3-Municipal,4-Privada)",
       y = "IDEB médio", title = "IDEB por dependência e grupo de etapas") +
  theme_minimal()
```

Testes por estrato (exemplo para escolas municipais, código `3`):

```r
df_municipal <- df %>% filter(tp_dependencia == 3)
t.test(nota_ideb ~ grupo_etapas, data = df_municipal, var.equal = FALSE)
```

### 7. Regressão linear múltipla (ajuste por confundidores)

```r
modelo <- lm(nota_ideb ~ nro_etapas + tp_dependencia + tp_localizacao, data = df)
summary(modelo)

# Alternativa com grupo binário (única vs múltiplas)
df <- df %>% mutate(unicas = ifelse(nro_etapas == 1, 1, 0))
modelo2 <- lm(nota_ideb ~ unicas + tp_dependencia + tp_localizacao, data = df)
summary(modelo2)
```

### 8. Interpretação resumida

Com base nos resultados que você já mostrou (médias):

- O grupo `nro_etapas = 1` tem média **6,355** vs. as demais (~5,92–6,04).
- O teste t de Welch resultará em **p-valor praticamente zero**, indicando diferença estatisticamente significativa.
- O gráfico de barras com IC e o boxplot evidenciarão que a mediana do grupo “única etapa” é superior.
- **Cuidado**: a relação pode ser influenciada pelo tipo de dependência (escolas privadas tendem a ter notas mais altas e podem ofertar menos etapas). Por isso, a regressão múltipla ou a estratificação são importantes.

### 9. Exportar gráficos (opcional)

```r
ggsave("boxplot_ideb_etapas.png", width = 8, height = 6)
ggsave("barras_ideb_etapas.png", width = 10, height = 6)
```

Caso você precise de ajuda para adaptar a conexão ou interpretar os resultados, é só me dizer!

# Teste estatístico

Para testar a hipótese nula de que a média das escolas com uma única etapa é igual à média das escolas com múltiplas etapas, você precisa dos dados individuais (a nota de cada escola), não apenas das médias agregadas que estão na tabela `medias`.

Assumindo que você tem o data frame `dados` com as colunas `nro_etapas` e `nota_media` (IDEB por escola), o teste mais adequado é o **teste t de Welch** (que não assume variâncias iguais), dadas as grandes amostras e a possível heterocedasticidade.

### Código R para o teste

```r
# Separar as notas dos dois grupos
single <- dados$nota_media[dados$nro_etapas == 1]
multi  <- dados$nota_media[dados$nro_etapas >= 2]

# Teste t de Welch (bilateral, pois a hipótese alternativa é "diferente")
teste_t <- t.test(single, multi, alternative = "two.sided")
teste_t
```

### Interpretação

- **Se p-valor < 0,05**: rejeita-se H₀ → as médias são estatisticamente diferentes.
- **Se p-valor ≥ 0,05**: não há evidência suficiente para afirmar que as médias diferem.

Com os valores que você mostrou (média de 6,35 vs. ~6,0 e grandes amostras), o p-valor certamente será **muito baixo** (<< 0,001), rejeitando a hipótese nula.

### Alternativa não paramétrica (caso suspeite de forte não normalidade)

```r
wilcox.test(single, multi)
```

> **Atenção**: A interpretação do teste de Wilcoxon é sobre medianas, não médias. Se o interesse for estritamente a média, prefira o teste t (robusto para amostras grandes).

## Resultado do teste t de Welch

Seu teste mostrou:

- **t = 22,05** (muito alto)
- **gl ≈ 9203** (graus de liberdade)
- **p-valor < 2,2 × 10⁻¹⁶** (praticamente zero)
- **Intervalo de confiança 95%** para a diferença das médias: [0,260; 0,311]
- **Média do grupo de etapa única**: 6,355
- **Média do grupo de múltiplas etapas**: 6,069
- **Diferença observada**: 0,286 pontos no IDEB

## Conclusão

Rejeita-se a hipótese nula. As escolas que oferecem **apenas uma etapa/modalidade** possuem média IDEB **significativamente maior** (cerca de 0,29 pontos) do que aquelas que oferecem duas ou mais etapas.

O p-valor extremamente baixo e o intervalo de confiança inteiramente positivo indicam que essa diferença não se deve ao acaso.

Agora, se quiser, podemos explorar se esse padrão se mantém quando você controla por dependência administrativa (ex.: só escolas municipais ou só privadas).
