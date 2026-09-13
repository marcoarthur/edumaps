# Similaridade

Deixando de lado a expansão universal de *Akira* e voltando para o nosso chão de fábrica dos dados, essa query é o primeiro passo para criar um algoritmo de **Clusterização** (como os vizinhos mais próximos ou o K-Means) dentro do EduMaps.

Em termos estatísticos, essa métrica de **Similaridade** calculada representa a **proximidade relativa de dois municípios dentro de um espaço vetorial tridimensional**. No entanto, ela possui um viés matemático oculto (um "bug" estatístico) que vai distorcer completamente os seus resultados se não for corrigido.

Vamos traduzir o que está acontecendo matematicamente:

---

### 1. O Espaço Vetorial Tridimensional ($3D$)

Cada município virou um ponto flutuando em um gráfico de 3 eixos (dimensões):

* **Eixo X:** Salário Médio (Escala de R$ 1.000 a R$ 15.000+)
* **Eixo Y:** Carga Horária Média (Escala de 10 a 44 horas)
* **Eixo Z:** Total de Profissionais (Escala de 10 a dezenas de milhares de CPFs)

A **Distância Euclidiana** é o comprimento da linha reta que conecta o Município A ao Município B nesse espaço $3D$. Se os dois forem idênticos em tudo, a distância é $0$.

---

### 2. O Significado Estatístico da Similaridade

A fórmula da similaridade aplicada ($S = \frac{1}{1 + d}$) é uma função de decaimento inverso. Ela serve para transformar uma distância (que vai de $0$ ao infinito) em uma nota de proximidade estruturada:

* **Estar próximo de 1:** Significa que os dois municípios possuem estruturas de pessoal e remuneração de professores **estatisticamente homogêneas** (muito parecidas).
* **Estar próximo de 0:** Significa que eles são **heterogêneos** (completamente discrepantes).

---

### 🚨 O Problema Crítico: O Efeito de Escala (Dominância de Grandeza)

Aqui está o ponto onde a estatística pura briga com a matemática simples da query: **suas variáveis estão em escalas totalmente desproporcionais**.

A distância euclidiana é extremamente sensível à magnitude dos números. Veja o que acontece se compararmos um município pequeno com um médio:

* **Diferença de Salário:** R$ 3.500 vs R$ 3.200 $\rightarrow \Delta = 300 \rightarrow \Delta^2 = \mathbf{90.000}$
* **Diferença de Carga Horária:** 40h vs 20h $\rightarrow \Delta = 20 \rightarrow \Delta^2 = \mathbf{400}$
* **Diferença de Profissionais:** 500 CPFs vs 50 CPFs $\rightarrow \Delta = 450 \rightarrow \Delta^2 = \mathbf{202.500}$

Repare que a variação na carga horária (que caiu pela metade, um impacto político e pedagógico gigantesco!) virou um mero ruído de **400** na soma do `POWER`. Enquanto isso, o número absoluto de profissionais e as diferenças em reais do salário engoliram o cálculo.

Do jeito que a query está escrita, a sua "Similaridade" na verdade está medindo quase que exclusivamente **o tamanho do município (volume de profissionais) e o montante financeiro**, ignorando os padrões de carga horária.

---

### 🛠️ Como corrigir isso como um Cientista de Dados? (Padronização Z-Score)

Para que a similaridade seja estatisticamente honesta, todas as dimensões precisam jogar com o mesmo peso. Você precisa aplicar a **Padronização (Z-Score)**, que transforma os valores em "desvios padrão a partir da média" (onde a média vira $0$ e o desvio vira $1$).

Podemos fazer isso nativamente no Postgres usando funções de agregação em uma CTE anterior (`AVG` e `STDDEV_SAMP`):

```sql
WITH estatisticas_globais AS (
    -- Calcula a média e o desvio padrão de cada variável no ano de 2025
    SELECT 
        AVG(salario_total) AS avg_sal, STDDEV_SAMP(salario_total) AS std_sal,
        AVG(carga_horaria) AS avg_ch,  STDDEV_SAMP(carga_horaria) AS std_ch,
        COUNT(DISTINCT cpf)::numeric / COUNT(DISTINCT cod_municipio) AS avg_prof -- aproximação da média de profs
    FROM clean.remuneracao_municipal
    WHERE ano = 2025
),
medias_municipio AS (
    SELECT  
        cod_municipio,
        AVG(salario_total) AS salario_medio,
        AVG(carga_horaria) AS carga_media,
        COUNT(DISTINCT cpf) AS total_profissionais
    FROM clean.remuneracao_municipal
    WHERE ano = 2025
    GROUP BY cod_municipio
),
municipios_normalizados AS (
    -- Aplica o Z-Score: (Valor - Média) / Desvio Padrão
    SELECT 
        m.cod_municipio,
        (m.salario_medio - (SELECT avg_sal FROM estatisticas_globais)) / (SELECT NULLIF(std_sal, 0) FROM estatisticas_globais) AS sal_z,
        (m.carga_media - (SELECT avg_ch FROM estatisticas_globais)) / (SELECT NULLIF(std_ch, 0) FROM estatisticas_globais) AS ch_z,
        -- Como total_profissionais varia muito, o desvio padrão populacional direto pode ser obtido aqui:
        (m.total_profissionais - AVG(m.total_profissionais) OVER()) / NULLIF(STDDEV_SAMP(m.total_profissionais) OVER(), 0) AS prof_z
    FROM medias_municipio m
)
SELECT 
    a.cod_municipio AS municipio_1,
    b.cod_municipio AS municipio_2,
    -- Agora a distância é justa (todas as variáveis têm peso idêntico)
    SQRT(
        POWER(a.sal_z - b.sal_z, 2) +
        POWER(a.ch_z - b.ch_z, 2) +
        POWER(a.prof_z - b.prof_z, 2)
    ) AS distancia_euclidiana,
    
    1 / (1 + SQRT(
        POWER(a.sal_z - b.sal_z, 2) +
        POWER(a.ch_z - b.ch_z, 2) +
        POWER(a.prof_z - b.prof_z, 2)
    )) AS similaridade
FROM municipios_normalizados a
CROSS JOIN municipios_normalizados b
WHERE a.cod_municipio < b.cod_municipio
ORDER BY similaridade DESC;

```

### O que muda no EduMaps com isso?

Com a normalização, se o Município A tem professores que ganham proporcionalmente bem trabalhando poucas horas, a query vai encontrar outros municípios com o **mesmo perfil de eficiência/gargalo**, independentemente de um ter 100 professores e o outro ter 800.

Seu mapeamento de similaridade vai deixar de rastrear apenas "tamanho" e passará a rastrear **comportamento político-educacional**.

## Algumas queries interessantes com a similiridade

> "Quais são as cidades vizinhas (até 100km) que possuem o perfil de contratação mais parecido com o meu?", 

```sql
WITH geo_alvo AS (
    -- Seleciona a geometria da cidade base (ex: São José dos Campos)
    SELECT codigo_ibge_antigo, geometry
    FROM clean.municipios_sp 
    WHERE codigo_ibge_antigo = '354990'
)
SELECT 
    CASE 
        WHEN sim.municipio_1 = g.codigo_ibge_antigo THEN sim.municipio_2
        ELSE sim.municipio_1
    END AS municipio_vizinho_cod,
    sim.similaridade,
    -- Fazemos o CAST (::geography) para que o PostGIS calcule em metros.
    -- Dividimos por 1000 para obter o resultado final em quilómetros.
    ST_Distance(g.geometry::geography, geo_vizinho.geometry::geography)::numeric / 1000 AS distancia_km
FROM analytics.municipio_similaridade sim
JOIN geo_alvo g ON (sim.municipio_1 = g.codigo_ibge_antigo OR sim.municipio_2 = g.codigo_ibge_antigo)
JOIN clean.municipios_sp geo_vizinho ON (
    geo_vizinho.codigo_ibge_antigo = CASE WHEN sim.municipio_1 = g.codigo_ibge_antigo THEN sim.municipio_2 ELSE sim.municipio_1 END
)
-- IMPORTANTE: Convertemos para ::geography também no filtro. 
-- Agora o raio de 100000 significa rigorosamente 100.000 metros (100km).
WHERE ST_DWithin(g.geometry::geography, geo_vizinho.geometry::geography, 100000)
ORDER BY sim.similaridade DESC
LIMIT 5;
```

>"Identificar Gêmeos Estatísticos Inesperados"

```sql
SELECT 
    municipio_1,
    municipio_2,
    (select nome_municipio from clean.municipios_sp m WHERE m.codigo_ibge_antigo = municipio_1) AS nome_1,
    (select nome_municipio from clean.municipios_sp m WHERE m.codigo_ibge_antigo = municipio_2) AS nome_2,
    distancia_euclidiana,
    similaridade
FROM analytics.municipio_similaridade
WHERE similaridade > 0.95
ORDER BY distancia_euclidiana ASC
LIMIT 10;
```
