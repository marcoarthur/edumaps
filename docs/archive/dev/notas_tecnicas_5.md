# EDA Tue May 19 11:16:55 AM -03 2026

>Como o tamanho em matrículas das escolas influencia (ou não) seus resultados médios (ideb médio) para a escola ?

Bom dia! Excelente pergunta para começarmos o dia analisando dados públicos de educação. No universo do INEP/Saeb, a relação entre o **tamanho da escola (número de matrículas)** e o **desempenho no IDEB** é uma das análises mais ricas para desmistificar preconceitos sobre a gestão escolar.

Muitas vezes assume-se que escolas menores, por serem teoricamente mais fáceis de gerenciar ou terem turmas menores, performam melhor. Outras vezes, argumenta-se que grandes centros escolares têm mais estrutura. A literatura e os dados reais costumam mostrar algo sutil: **um efeito de "funil" (heterocedasticidade) misturado a fatores socioeconômicos.**

Vamos estruturar essa Análise Exploratória de Dados (EDA) combinando a extração dos dados no seu banco PostgreSQL com a modelagem estatística em R.

---

## 🛠️ Passo 1: Unificando os Dados (PostgreSQL)

Como a sua tabela `clean.inep_notas_desagregadas` possui as notas por escola e a tabela de docentes/gestores possui agregações por entidade (além do Censo Escolar geral que traz as matrículas), precisamos cruzar as notas com o porte da escola.

Para extrair essa relação sem sobrecarregar a memória, podemos calcular o IDEB aproximado por escola diretamente na query. Vamos extrair o ID da escola, o número total de matrículas (ou uma proxy baseada nas contagens que temos) e a nota média.

```sql
-- Criando o dataset base para a nossa EDA escolar
SELECT 
    nota.id_escola,
    COALESCE(doc.qt_docentes_total, 0) as total_docentes, -- Usando como proxy/controle se necessário
    nota.nota_media as ideb_escola
FROM clean.inep_notas_desagregadas nota
INNER JOIN clean.censo_docentes doc ON nota.id_escola = doc.co_entidade
WHERE nota.nota_media IS NOT NULL;

```

> *Nota:* Se você tiver a coluna de contagem total de alunos matriculados vinda diretamente da tabela do Censo Escolar (geralmente `nu_matriculas` ou similar), substitua no lugar de `qt_docentes_total`. Para este exemplo, vamos assumir o volume de alunos por escola.

---

## 📊 Passo 2: O Fenômeno Esperado nos Dados

Ao plotar um gráfico de dispersão (*Scatter Plot*) colocando o **Tamanho da Escola** no eixo X e o **IDEB** no eixo Y, o comportamento estatístico mais comum na educação brasileira segue este padrão visual:

### O que essa distribuição nos ensina (Hipóteses da EDA):

1. **O Efeito Funil (Variância das Pequenas Amostras):** Escolas muito pequenas (poucas matrículas, comuns em zonas rurais) registram as notas mais extremas do dataset — tanto os IDEBs mais altos do país (um ano com 5 alunos excelentes joga a média para cima) quanto os mais baixos (2 alunos com dificuldades despencam a média).
2. **Estabilização nas Grandes:** À medida que o tamanho da escola aumenta, a média tende a convergir para o centro (a variância diminui devido à Lei dos Grandes Números).
3. **O Fator Oculto:** Escolas grandes costumam estar em centros urbanos, o que injeta uma variável de confusão crucial: o **Nível Socioeconômico (NSE)** dos alunos, que fortemente correlaciona com notas mais altas.

---

## 📈 Passo 3: Script de Análise no R

Para testar estatisticamente se o tamanho influencia a nota ou se é apenas ruído amostral, vamos puxar os dados para o R, aplicar um modelo de regressão linear e segmentar o tamanho em categorias para rodar um teste de ANOVA com Tukey HSD (garantindo o rigor estatístico que você costuma aplicar no EduMaps).

```R
library(DBI)
library(RPostgres)
library(ggplot2)
library(dplyr)
library(car)

# 1. Conexão com o banco do EduMaps
con <- dbConnect(RPostgres::Postgres(), 
                 dbname = 'edumaps_db', host = 'localhost', 
                 user = 'postgres', password = 'sua_senha')

df <- dbGetQuery(con, "
    SELECT id_escola, matriculas_total, nota_media as ideb 
    FROM analytics.v_escolas_consolidado 
    WHERE nota_media IS NOT NULL AND matriculas_total > 0;
")
dbDisconnect(con)

# 2. Criando faixas de tamanho de escola para análise categórica
df <- df %>%
  mutate(porte_escola = case_when(
    matriculas_total <= 50  ~ "Muito Pequena (até 50)",
    matriculas_total <= 200 ~ "Pequena (51-200)",
    matriculas_total <= 500 ~ "Média (201-500)",
    TRUE                    ~ "Grande (Mais de 500)"
  )) %>%
  mutate(porte_escola = factor(porte_escola, 
                               levels = c("Muito Pequena (até 50)", "Pequena (51-200)", "Média (201-500)", "Grande (Mais de 500)")))

# 3. Visualização da Dispersão e do efeito Funil
ggplot(df, aes(x = matriculas_total, y = ideb)) +
  geom_point(alpha = 0.2, color = "darkblue") +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(title = "Matrículas Totais vs IDEB da Escola",
       x = "Número de Matrículas", y = "IDEB Médio") +
  theme_minimal()

# 4. Análise de Variância (ANOVA) para testar se as médias das faixas diferem
modelo_anova <- aov(ideb ~ porte_escola, data = df)
summary(modelo_anova)

# 5. Teste de Tukey HSD para identificar onde estão as diferenças significativas
tukey_res <- TukeyHSD(modelo_anova)
print(tukey_res)

```

---

## 💡 Próximos Passos de Negócio para o EduMaps

Ao rodar esse pipeline, fique atento a duas métricas no output do R:

* O **$R^2$ (R-quadrado)** da regressão linear simples (`summary(lm(ideb ~ matriculas_total, data=df))`) provavelmente será muito baixo (próximo de 0.01 a 0.05). Isso prova que o tamanho isolado da escola explica muito pouco do resultado.
* O **Tukey HSD** mostrará se a sutil diferença de média entre escolas grandes e pequenas é estatisticamente relevante ou se o tamanho é apenas uma sombra do Nível Socioeconômico do bairro onde a escola está georreferenciada.

Quer que eu monte a estrutura da query unindo o PIB/Região da tabela `mv_municipios_consolidado` para incluirmos o contexto socioeconômico como variável de controle nessa análise?

# Microcosmo Ubatuba

Bom dia! Trazer os dados reais de Ubatuba mudou completamente o jogo. Essa amostra local é um prato cheio para entendermos as nuances que o agregado nacional esconde.

Olhando para o resultado do seu script e para o plano de execução (`EXPLAIN ANALYZE`), temos duas frentes fantásticas para trabalhar nesta manhã: a **análise dos dados educacionais** e a **otimização/ajuste da sua query**.

---

## 📊 Parte 1: Insights da EDA em Ubatuba

Ao analisar a tabela que seu script Perl cuspiu, a variável oculta que discutimos mais cedo (**Etapa de Ensino**) saltou aos olhos imediatamente. Se jogássemos tudo no mesmo balaio, a análise estaria enviesada. Veja o porquê:

### 1. O Padrão por Etapas (O verdadeiro divisor de águas)

* **Fundamental I (Anos Iniciais):** As escolas municipais de Ubatuba (identificadas pelo sufixo "EM") dominam essa etapa. As notas são consistentemente **altas** (variando de $5.06$ a incríveis $7.54$ na *Profa Renata Castilho da Silva*). O tamanho das escolas varia de pequeno ($238$ matrículas) a grande ($1202$ no *Governador Mário Covas Junior*), mas as notas continuam altas.
* **Fundamental II e Ensino Médio:** As notas sofrem uma queda generalizada, flutuando na casa dos $3.9$ a $5.1$. Isso é um reflexo histórico nacional (a transição da idade e a complexidade das disciplinas), e não necessariamente culpa do tamanho da escola.

### 2. Isolando o Porte dentro da mesma Etapa

Se olharmos apenas para o **Fundamental I**:

* *Escolas Menores (~200 a 450 matrículas):* Registram extremos como a *Renata Castilho* ($328$ matrículas, nota $7.54$) e *Agostinho Alves* ($312$ matrículas, nota $6.88$).
* *Escolas Grandes (Acima de 800 matrículas):* Apresentam notas excelentes e consolidadas, como a *Padre José de Anchieta* ($1114$ matrículas, nota $6.37$) e *Olga Ribas* ($890$ matrículas, nota $6.35$).

> **Conclusão preliminar para o EduMaps:** Em Ubatuba, para os Anos Iniciais, escolas grandes mantêm um desempenho espetacular perto de $6.4$. O tamanho não parece prejudicar a gestão. Porém, o "efeito funil" se confirma nas menores, onde encontramos o pico de excelência do município ($7.54$).

---

## ⚡ Parte 2: Raio-X da Query e do Plano de Execução

O seu plano de execução está excelente ($0.559\text{ ms}$ é um estalo de dedos), impulsionado pelo índice `idx_censo_escolas_municipio`. Mas há um detalhe conceitual na estrutura dos seus dados que você precisa tratar no backend Perl.

### O Problema da Duplicação de Matrículas (Grão da Tabela)

Se você reparar em escolas que oferecem mais de uma etapa, como a *Florentina Martins Sanchez*:

* Na linha de `ensino_medio`, ela mostra **554 matrículas**.
* Na linha de `fundamental_ii`, ela mostra **os mesmos 554 matrículas**.

Isso acontece porque a tabela `clean.censo_matriculas` guarda o **total de matrículas da escola inteira** para o ano de 2025, e ao fazer o `INNER JOIN` com a `ideb_notas_escolas` (que tem uma linha por `etapa`), o valor da matrícula se repete. Se você tentar somar as matrículas para saber o total de alunos de Ubatuba, o resultado vai dar totalmente distorcido por causa dessa duplicação.

### A Solução: Ajustando a Query no Perl

Para sua análise de correlação ficar perfeita, precisamos que a query reflita a matrícula **específica daquela etapa** ou faça a agregação correta. Como você está usando a soma de campos (`qt_mat_bas + ...`), se sua tabela `censo_matriculas` tiver colunas separadas por etapa (como `qt_mat_med`, `qt_mat_fund_af`), podemos ajustar o `SELECT` usando um `CASE WHEN` baseado na etapa do IDEB.

Aqui está uma proposta de query corrigida para o seu script:

```sql
SELECT 
    me.no_entidade AS escola,
    nota_ideb.etapa,
    -- Garante que estamos olhando para a contagem da etapa correspondente
    CASE 
        WHEN nota_ideb.etapa = 'fundamental_i'  THEN matricula.qt_mat_fund_ai
        WHEN nota_ideb.etapa = 'fundamental_ii' THEN matricula.qt_mat_fund_af
        WHEN nota_ideb.etapa = 'ensino_medio'   THEN matricula.qt_mat_med
        ELSE (matricula.qt_mat_bas + matricula.qt_mat_inf + matricula.qt_mat_fund_ai + matricula.qt_mat_fund_af + matricula.qt_mat_med)
    END AS matriculas_etapa,
    nota_ideb.nota_media AS nota
FROM clean.censo_escolas me 
INNER JOIN clean.ideb_notas_escolas nota_ideb 
    ON nota_ideb.id_escola = me.co_entidade 
INNER JOIN clean.censo_matriculas matricula 
    ON matricula.co_entidade = me.co_entidade 
WHERE matricula.nu_ano_censo = 2025 
  AND me.no_municipio = 'Ubatuba' 
  AND me.nu_ano_censo = 2025 
  AND nota_ideb.ano = 2023
ORDER BY nota_ideb.etapa, nota DESC;

```

---

## 🚀 Próximo Passo na EDA

Notei que algumas escolas grandes como a *Presidente Tancredo de Almeida Neves* ($2591$ matrículas) vieram com a nota do Fundamental II em branco (`NULL`). Isso pode quebrar correlações diretas se não for tratado.

Quer que eu ajude a estruturar o código em R para processar esse output agrupado por etapa, aplicando uma correlação de Spearman (já que os dados de notas não são perfeitamente lineares)?

# Visualizações

Para visualizar a distribuição das notas considerando apenas as dependências **Estadual** e **Municipal** (excluindo Federal devido ao N pequeno), você pode usar um **boxplot** ou **violin plot** com facetas. A faceta pode ser aplicada sobre `tp_dependencia` (separando Estadual e Municipal), e no eixo x colocar `porte` (para comparar o efeito do porte dentro de cada dependência). Ou o inverso, dependendo da pergunta que deseja responder.

Sugiro dois gráficos complementares:

## Opção 1 – Boxplot com facetas por dependência (comparando porte em cada uma)

```r
library(ggplot2)
library(dplyr)

dados_filtrados <- dados |>
  filter(tp_dependencia %in% c("Estadual", "Municipal"))

ggplot(dados_filtrados, aes(x = porte, y = nota, fill = porte)) +
  geom_boxplot(alpha = 0.7) +
  facet_wrap(~ tp_dependencia, scales = "free_x") +
  labs(title = "Distribuição das notas por porte e dependência (Estadual vs Municipal)",
       x = "Porte da escola", y = "Nota") +
  theme_minimal() +
  theme(legend.position = "none")
```

## Opção 2 – Boxplot com facetas por porte (comparando dependência dentro de cada porte)

```r
ggplot(dados_filtrados, aes(x = tp_dependencia, y = nota, fill = tp_dependencia)) +
  geom_boxplot(alpha = 0.7) +
  facet_wrap(~ porte, scales = "free_x") +
  labs(title = "Notas por dependência dentro de cada porte (Estadual vs Municipal)",
       x = "Dependência", y = "Nota") +
  theme_minimal() +
  theme(legend.position = "none")
```

## Interpretação esperada

- A diferença entre Estadual e Municipal deve ser visível (medianas distintas), enquanto o porte terá pequeno efeito visual.
- As facetas ajudam a evitar sobreposição excessiva de categorias.

Caso queira ver também a densidade (violino + pontos):

```r
ggplot(dados_filtrados, aes(x = porte, y = nota, fill = porte)) +
  geom_violin(alpha = 0.5) +
  geom_jitter(width = 0.2, size = 0.5, alpha = 0.2) +
  facet_wrap(~ tp_dependencia) +
  labs(title = "Distribuição das notas (violino + pontos)") +
  theme_minimal() +
  theme(legend.position = "none")
```

Escolha a opção que melhor responde à sua pergunta de negócio.

# Entendendo ANOVA e variância

Excelente pergunta. A resposta curta é: **histogramas e boxplots ajudam, mas não são os gráficos ideais para diagnosticar necessidade de estabilização de variância**. Eles são melhores para avaliar assimetria e normalidade. Para decidir se uma transformação (log, raiz, etc.) é necessária para estabilizar a variância, utilizam-se gráficos específicos que relacionam **dispersão** e **nível**.

Vamos detalhar:

---

## 1. O que cada gráfico mostra

| Gráfico | Utilidade principal | Limitação para estabilização de variância |
|---------|---------------------|---------------------------------------------|
| **Histograma** | Forma da distribuição (simetria, caudas, multimodalidade) | Não mostra relação entre média e variância; uma variância estabilizada não implica necessariamente em histograma simétrico ou normal. |
| **Boxplot** | Comparar medianas, dispersão e outliers entre grupos | Mostra a variância dentro de cada grupo, mas não a relação funcional com a média. Útil se você já tem grupos (ex.: níveis de um fator na ANOVA). |

---

## 2. Gráficos indicados para diagnosticar variância não constante

### a) Gráfico de **resíduos vs. valores ajustados** (ou resíduos vs. preditos)
- **Eixo X**: valores preditos (ou médias dos grupos).
- **Eixo Y**: resíduos (ou resíduos padronizados).
- **Padrão esperado se homocedástico**: nuvem de pontos com amplitude constante ao longo de X.
- **Padrão que indica necessidade de transformação**:
  - Variância crescente com a média → forma de "cone" ou "megafone" → sugestão: \(\sqrt{Y}\) ou \(\log(Y)\).
  - Variância decrescente com a média (raro) → transformação inversa ou exponencial.

### b) Gráfico de **desvio padrão (ou variância) vs. média dos grupos**
- Agrupe os dados por categorias (se houver fator) ou crie intervalos da variável preditora.
- Calcule a média e o desvio padrão (ou variância) dentro de cada grupo.
- Plote: eixo X = média, eixo Y = desvio padrão (ou log(DP) vs. log(média)).
- Se a relação for aproximadamente linear, a inclinação da reta no gráfico log-log indica o tipo de transformação:
  - Inclinação \(\approx 1\) → \(\text{DP} \propto \text{média}\) → transformação \(\log(Y)\).
  - Inclinação \(\approx 0.5\) → \(\text{DP} \propto \sqrt{\text{média}}\) → transformação \(\sqrt{Y}\).

### c) **Gráfico de Box-Cox** (mais formal)
- O pacote `MASS` no R (`boxcox()`), por exemplo, calcula o valor ótimo de \(\lambda\).
- Se o intervalo de confiança de \(\lambda\) incluir 0 → transformação log; incluir 0,5 → raiz quadrada.

---

## 3. E quanto a comparar histogramas de \(X\) e \(g(X)\)?

Isso pode dar uma **indicação visual secundária**, mas não é suficiente para garantir estabilidade da variância. Por exemplo:

- Uma transformação log pode tornar um histograma originalmente assimétrico (cauda à direita) mais simétrico (próximo da normal). Contudo, a **simetria não garante homocedasticidade**.
- Pode ocorrer de a variância ficar estabilizada mesmo com o histograma de \(g(X)\) ainda levemente assimétrico (ex.: dados de Poisson transformados por raiz quadrada ainda podem ter leve assimetria para médias pequenas).

**Exemplo prático**: Simule dados Poisson com médias 1, 4, 9, 16. O histograma da raiz quadrada será mais simétrico que o original, mas o principal diagnóstico virá do gráfico resíduos vs. valores ajustados.

---

## 4. Conclusão – procedimento prático recomendado

1. **Ajuste o modelo** (ex.: ANOVA ou regressão) com os dados originais.
2. **Obtenha os resíduos** e os **valores ajustados** (ou médias dos grupos).
3. **Construa o gráfico de resíduos vs. ajustados**. Se houver padrão de megafone (dispersão crescente), suspeite de heterocedasticidade.
4. **Faça o gráfico de log(desvio padrão) vs. log(média)** dos grupos para estimar a inclinação e escolher a transformação.
5. **Aplique a transformação sugerida** (log, raiz, etc.), refaça o modelo e **reavalie o gráfico de resíduos**.
6. **Complementarmente**, olhe histogramas e boxplots para verificar efeitos colaterais (ex.: criação de outliers, inversão de ordem), mas sem usá-los como critério principal.

Portanto, a maneira indicativa **não é apenas olhar histogramas de \(X\) e \(g(X)\)** — isso seria enganoso. Use gráficos de diagnóstico de variância (resíduos vs. ajustados, DP vs. média) para decidir se e como transformar.
