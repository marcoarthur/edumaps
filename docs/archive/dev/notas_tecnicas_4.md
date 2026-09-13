# Idéias sobre modelagem de domínio

## Sugestão DeepSeek

Com base no health check da tabela `clean.censo_escolas` (213.626 registros) e na sua pergunta sobre **modelagem de domínio** (tipos de dados, tipos abstratos, funções), sugiro melhorias focadas em: integridade referencial, validação de domínio, legibilidade e reuso.

## 1. Enums para colunas com domínio fixo e pequeno

Várias colunas armazenam valores de um conjunto pequeno e estável. Usar `ENUM` ou domínios restritos torna o esquema mais expressivo e evita valores inválidos.

**Exemplos onde ENUM é adequado:**

| Coluna | Domínio | Proposta |
|--------|---------|----------|
| `co_regiao` | 1..5 | `CREATE TYPE regiao_br AS ENUM ('Norte','Nordeste','Sudeste','Sul','Centro-Oeste')` (ou manter código, mas usar CHECK) |
| `sg_uf` | 27 siglas | `CREATE TYPE sigla_uf AS ENUM ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO')` |
| `tp_dependencia` | 1..4 | `CREATE TYPE dependencia AS ENUM ('Federal','Estadual','Municipal','Privada')` |
| `tp_localizacao` | 1,2 | `CREATE TYPE localizacao AS ENUM ('Urbana','Rural')` |
| `tp_situacao_funcionamento` | 1,2,3 | `CREATE TYPE situacao_escola AS ENUM ('Ativa','Paralisada','Extinta')` |

**Vantagem:** O PostgreSQL armazena enums de forma eficiente (4 bytes) e impede inserção de valores não listados.

**Implementação exemplo:**

```sql
CREATE TYPE tp_dependencia_enum AS ENUM ('Federal', 'Estadual', 'Municipal', 'Privada');
ALTER TABLE clean.censo_escolas 
  ALTER COLUMN tp_dependencia TYPE tp_dependencia_enum 
  USING CASE tp_dependencia 
    WHEN 1 THEN 'Federal'::tp_dependencia_enum 
    WHEN 2 THEN 'Estadual' 
    WHEN 3 THEN 'Municipal' 
    WHEN 4 THEN 'Privada' 
  END;
```

## 2. Domínios (CREATE DOMAIN) para padronizar códigos e pequenos inteiros

Colunas como `co_uf`, `co_municipio`, `co_regiao_geog_interm` são códigos inteiros que deveriam ter restrições (ex: positivo, faixa de valores). Use domínios para centralizar as regras.

```sql
CREATE DOMAIN codigo_ibge_uf AS smallint CHECK (VALUE BETWEEN 11 AND 53); -- faixa aproximada
CREATE DOMAIN codigo_ibge_municipio AS integer CHECK (VALUE >= 100000 AND VALUE <= 999999);
CREATE DOMAIN percentual_null AS numeric(5,2) CHECK (VALUE BETWEEN 0 AND 100);
```

Depois aplique às colunas:

```sql
ALTER TABLE clean.censo_escolas 
  ALTER COLUMN co_uf TYPE codigo_ibge_uf,
  ALTER COLUMN co_municipio TYPE codigo_ibge_municipio;
```

## 3. Tipos compostos (Composite Types) para agrupar campos relacionados

Observe campos de endereço: `ds_endereco`, `nu_endereco`, `ds_complemento`, `no_bairro`, `co_cep`. Eles formam uma unidade lógica. Um tipo composto `endereco_completo` pode ser usado, mas **cuidado**: isso dificulta consultas individuais e pode não ser vantajoso para uma tabela analítica. Recomendo **não** criar tipo composto para endereço a menos que você raramente acesse os campos separadamente. Prefiro manter colunas separadas, mas criar uma função de formatação.

### Função para exibir endereço formatado

```sql
CREATE FUNCTION formatar_endereco(row clean.censo_escolas) RETURNS TEXT IMMUTABLE LANGUAGE sql AS $$
  SELECT concat_ws(', ', row.ds_endereco, row.nu_endereco, row.ds_complemento, row.no_bairro, row.co_cep);
$$;
```

## 4. Colunas geradas (Generated Columns) para indicadores derivados

Muitas colunas são flags binárias (0/1) – por exemplo, `in_agua_potavel`, `in_energia_rede_publica`, `in_acessibilidade_rampas`. É útil criar **colunas virtuais** ou funções que resumem, como “possui água adequada”, “possui energia”, “acessibilidade básica”.

Exemplo de coluna gerada (PostgreSQL 12+):

```sql
ALTER TABLE clean.censo_escolas ADD COLUMN tem_infraestrutura_basica BOOLEAN GENERATED ALWAYS AS (
  (in_agua_potavel = 1 OR in_agua_rede_publica = 1) 
  AND (in_energia_rede_publica = 1) 
  AND (in_esgoto_rede_publica = 1 OR in_esgoto_fossa_septica = 1)
) STORED;
```

Isso simplifica consultas e mantém consistência.

## 5. Funções para cálculos recorrentes (Badges / Scores)

Pelo seu script anterior, você já criou funções como `infra_badge_bag`, `accessibility_badge_bag` etc. Elas retornam JSON – uma boa abordagem para indicadores complexos. Sugiro também funções que retornem **tipos definidos** (compostos ou tabelas) para análises posteriores.

Exemplo: uma função que retorna um resumo de infraestrutura como tipo composto:

```sql
CREATE TYPE infra_summary AS (
  agua     boolean,
  energia  boolean,
  esgoto   boolean,
  acessibilidade text[]
);

CREATE FUNCTION summarize_infra(co_entidade bigint) RETURNS infra_summary LANGUAGE sql AS $$
  SELECT 
    (in_agua_potavel = 1 OR in_agua_rede_publica = 1) AS agua,
    (in_energia_rede_publica = 1) AS energia,
    (in_esgoto_rede_publica = 1 OR in_esgoto_fossa_septica = 1) AS esgoto,
    ARRAY_REMOVE(ARRAY[
      CASE WHEN in_acessibilidade_rampas = 1 THEN 'rampas' END,
      CASE WHEN in_acessibilidade_elevador = 1 THEN 'elevador' END,
      CASE WHEN in_acessibilidade_sinal_tatil = 1 THEN 'piso_tatil' END
    ], NULL) AS acessibilidade
  FROM clean.censo_escolas WHERE co_entidade = summarize_infra.co_entidade;
$$;
```

## 6. Índices parciais e check constraints implícitas

Use `CHECK` constraints para garantir que colunas com altos percentuais de nulo só sejam não-nulas quando necessário. Ex: `tp_categoria_escola_privada` só deve ser não-nulo se `tp_dependencia = 'Privada'`.

```sql
ALTER TABLE clean.censo_escolas ADD CONSTRAINT categoria_privada_valida CHECK (
  (tp_dependencia != 'Privada' AND tp_categoria_escola_privada IS NULL) OR
  (tp_dependencia = 'Privada' AND tp_categoria_escola_privada IS NOT NULL)
);
```

## 7. Sugestão extra: particionamento

O volume é médio (213k linhas). Não precisa de particionamento agora, mas se você planeja acumular vários anos (múltiplos `nu_ano_censo`), considere particionar por `nu_ano_censo`. Sua tabela já tem `nu_ano_censo`, mas o health check mostra apenas um único ano (distinct_approx = 1). Quando houver vários, o particionamento melhora a manutenção e a performance de consultas por ano.

## Resumo das recomendações

1. **Enums** para `co_regiao`, `sg_uf`, `tp_dependencia`, `tp_localizacao`, `tp_situacao_funcionamento`.
2. **Domínios** para códigos IBGE (`co_uf`, `co_municipio`, etc.) e percentuais.
3. **Colunas geradas** para indicadores derivados (água, energia, acesso).
4. **Funções** para resumos (infra, acessibilidade, internet) retornando tipos compostos.
5. **Constraints** para consistência entre dependência e categoria privada.
6. **Particionamento futuro** por ano censo.

Todas essas mudanças podem ser implementadas gradualmente via Sqitch (cada alteração como um changeset versionado). 

Se precisar de scripts específicos para converter colunas para enums ou para criar domínios, posso fornecer.

# Sugestão Gemini

Excelente ver que o gerenciamento de mudanças com Sqitch e Git já está consolidado. Isso dá a segurança necessária para aplicar refatorações estruturais à medida que o volume de dados cresce.

Analisando o *health check* enviado, fica claro que esta tabela é um reflexo direto do formato "flat" (desnormalizado) com o qual o INEP distribui o Censo Escolar. Embora excelente para consultas analíticas rápidas (*OLAP*), manter esses dados textuais e geográficos repetidos em todas as linhas gera um desperdício massivo de armazenamento e dificulta a integridade do domínio.

Considerando que você já lida com **centenas de milhares de linhas por ano do censo**, aqui estão as sugestões de modelagem de domínio, tipos abstratos e funções para otimizar o PostgreSQL:

---

## 1. Normalização do Domínio Territorial (Redução de Redundância)

Os dados de IBGE (`co_municipio`, `co_uf`, `co_regiao_geog_interm`, etc.) são **estáticos**. Você está repetindo strings como `"Região Sudeste"` ou `"São Paulo"` 213.626 vezes para um único ano de censo.

### Sugestão: Dicionários Territoriais do IBGE

Crie tabelas de dimensões separadas para a hierarquia do IBGE. Sua tabela do Censo deve apontar apenas para a granularidade mais baixa necessária (geralmente `co_distrito` ou `co_municipio`), e a partir dela você alcança a macroregião.

Se optar por manter a tabela desnormalizada por performance (evitar JOINs em consultas massivas), aplique os conceitos abaixo:

---

## 2. Otimização de Tipos de Dados

### `character varying(20)` e `character(2)` para Enums / Domínios

* **`sg_uf`:** Em vez de `character(2)`, você pode criar um tipo **`DOMAIN`** baseado em uma constraint de check para garantir a integridade dos estados brasileiros, ou manter o `character(2)` mas garantir que não existam espaços em branco.
* **`no_regiao` (`distinct_approx: 5`):** Gastar `character varying(20)` para repetir "Norte", "Nordeste", etc., é ineficiente. Use um tipo **`ENUM`**:
```sql
CREATE TYPE regiao_br AS ENUM ('Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul');

```



### Códigos do IBGE (`co_municipio`, `co_uf`, etc.)

* Os tipos atuais estão ótimos (`smallint` para UF e `integer` para municípios). Eles respeitam exatamente os padrões do IBGE (UFs vão até 53, Municípios possuem 7 dígitos).
* **`co_entidade` (`bigint`):** O código INEP (escola) possui 8 dígitos. O tipo `integer` (que vai até ~2.1 bilhões) comporta perfeitamente esse dado, economizando 4 bytes por linha em comparação ao `bigint`. Multiplicado pelo volume de dados, isso reduz significativamente o tamanho do índice e da tabela.

---

## 3. Tipos Abstratos e Extensões Essenciais

Dado que você está lidando com o Censo Escolar e infraestrutura educacional, três abordagens de tipos abstratos se tornam fundamentais:

### A. Tipagem Geoespacial com PostGIS

A tabela possui campos de texto para endereço (`ds_endereco`, `no_bairro`). Para análises de densidade e mapas:

* Substitua ou complemente os campos de texto por um tipo **`GEOMETRY(Point, 4674)`** (usando o SIRGAS 2000, padrão do IBGE).
* Isso permite transformar endereços em pontos reais e realizar queries espaciais.

### B. Encapsulamento de Infraestrutura com `JSONB`

Campos com alto índice de valores nulos (como `tp_categoria_escola_privada` com **80% de nulos** ou `no_regiao_administrativa` com **99%**) são fortes candidatos para uma abordagem híbrida.

* Se a tabela contiver dezenas de colunas do INEP sobre "se a escola possui banheiro, biblioteca, água potável, internet" (característico do Censo), agrupar essas flags binárias/smallint em um único campo **`infraestrutura jsonb`** economiza espaço físico de armazenamento de colunas nulas e permite indexação por herança via índices `GIN`.

---

## 4. Funções de Domínio Sugeridas (PL/pgSQL)

Para blindar o seu domínio de regras de negócio específicas da educação brasileira, sugiro criar funções que convertam códigos brutos em strings legíveis ou que validem regras do INEP.

### Tradutores de Tipos (Enums Virtuais)

Evite fazer `CASE WHEN tp_localizacao = 1 THEN 'Urbana' ...` nas suas views ou backend. Crie funções estáveis (`IMMUTABLE`) para isso:

```sql
CREATE OR REPLACE FUNCTION get_tp_localizacao_desc(tp_localizacao smallint) 
RETURNS text AS $$
BEGIN
    RETURN CASE tp_localizacao
        WHEN 1 THEN 'Urbana'
        WHEN 2 THEN 'Rural'
        ELSE 'Desconhecida'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

```

*Por ser `IMMUTABLE`, você pode inclusive criar índices funcionais utilizando essa função.*

### Validador do Código do Município (Dígito Verificador)

O código do IBGE possui um dígito verificador baseado no módulo 10. Você pode criar uma função para validar se o `co_municipio` inserido é matematicamente válido antes de aceitar o dado na tabela.

---

## Resumo da Estratégia para o Sqitch

1. **Refatorar `co_entidade**` de `bigint` para `integer` (ganho imediato de performance de I/O).
2. **Criar ENUMs** para variáveis categóricas de baixa cardinalidade (`no_regiao`, `tp_dependencia`).
3. **Isolar dados territoriais textuais** (`no_municipio`, `no_uf`) em uma tabela `dim_municipios` para limpar o inchaço de strings da tabela fato do censo.

```

```
Para o cenário que você descreveu — trabalhando diretamente na camada do banco de dados (PostgreSQL/PostGIS) com dados massivos do Censo Escolar e agregando novas tabelas gigantes —, a estratégia ideal é **parar de tratar o banco como um mero depósito de dados e transformá-lo no motor de inteligência do domínio**.

Se movermos a lógica de validação, os tipos abstratos e as agregações espaciais para o coração do PostgreSQL, a sua aplicação (backend) se tornará extremamente leve e as consultas rodarão de forma infinitamente mais eficiente.

Abaixo, apresento uma proposta de arquitetura de banco de dados desenhada especificamente para expressar o domínio da educação pública brasileira, otimizando drasticamente o armazenamento e a velocidade.

---

## 1. Tipos de Dados Abstratos e Domínios (Expressividade e Segurança)

O Censo do INEP é repleto de códigos numéricos para variáveis categóricas (`1` para urbana, `2` para rural; `1` para em atividade, etc.). Em vez de espalhar `smallint` com regras soltas, criamos **Domains** e **Custom Types**.

### Domínios para Códigos do INEP

O `DOMAIN` no PostgreSQL funciona como um tipo existente, mas com restrições (`CHECK`) embutidas. Se tentarem inserir um código inválido, o banco barra na hora.

```sql
-- Garante que a situação de funcionamento siga estritamente o padrão INEP
CREATE DOMAIN situacao_funcionamento AS smallint
    CHECK (VALUE IN (1, 2, 3, 4)); -- 1: Em Atividade, 2: Paralisada, 3: Extinta...

-- Garante consistência na localização da escola
CREATE DOMAIN localizacao_escola AS smallint
    CHECK (VALUE IN (1, 2)); -- 1: Urbana, 2: Rural

-- Dependência Administrativa
CREATE DOMAIN dependencia_adm AS smallint
    CHECK (VALUE IN (1, 2, 3, 4)); -- 1: Federal, 2: Estadual, 3: Municipal, 4: Privada

```

### Tipos Enumerados (ENUMs) para Legibilidade

Para colunas que não dependem de códigos rígidos do INEP, use `ENUM`. Eles ocupam apenas **4 bytes** em disco, mas são exibidos como texto legível no seu código.

```sql
CREATE TYPE regiao_brasil AS ENUM ('Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul');

```

---

## 2. Tipos de Dados Compostos (Composite Types)

A infraestrutura da escola possui mais de 40 colunas binárias. Em vez de inflar a tabela principal (`escola`) com dezenas de colunas, podemos encapsular esses dados em **Tipos Compostos**. No disco, o PostgreSQL armazena isso de forma compacta; na query, você acessa como se fossem subcampos.

```sql
-- Encapsulando recursos básicos de sobrevivência da escola
CREATE TYPE infra_basica AS (
    agua_potavel        boolean,
    energia_publica     boolean,
    esgoto_publico      boolean,
    coleta_lixo         boolean
);

-- Encapsulando recursos pedagógicos
CREATE TYPE infra_pedagogica AS (
    biblioteca          boolean,
    lab_ciencias        boolean,
    lab_informatica     boolean,
    quadra_esportes     boolean,
    internet_alunos     boolean
);

```

### Aplicando na Tabela Principal:

Sua tabela passa de um emaranhado de colunas para uma estrutura limpa e semântica:

```sql
CREATE TABLE escolas (
    co_entidade         integer PRIMARY KEY,
    no_entidade         varchar(200) NOT NULL,
    situacao            situacao_funcionamento NOT NULL,
    dependencia         dependencia_adm NOT NULL,
    localizacao         localizacao_escola NOT NULL,
    
    -- Utilizando os tipos compostos
    servicos_basicos    infra_basica,
    pedagogico          infra_pedagogica,
    
    -- Geometria Nativa PostGIS (Escolas são pontos, EPSG:4674 - SIRGAS 2000)
    geom                geometry(Point, 4674)
);

```

*Como consultar um tipo composto?* É incrivelmente simples:

```sql
SELECT no_entidade 
FROM escolas 
WHERE (servicos_basicos).agua_potavel IS FALSE; -- Parênteses são obrigatórios aqui

```

---

## 3. Otimização Espacial Avançada (PostGIS)

Como você tem coordenadas (`latitude`/`longitude`), armazená-las como texto ou duas colunas de `numeric` mata a performance de qualquer busca espacial. A coluna `geom geometry(Point, 4674)` resolve isso.

### Gatilho de Autopreenchimento Geográfico

Se os novos dados que estão entrando vêm com `latitude` e `longitude` em colunas separadas (geralmente de arquivos `.csv` do governo), crie uma função engatilhada (`TRIGGER`) para gerar o ponto geométrico automaticamente antes de salvar.

```sql
CREATE OR REPLACE FUNCTION tg_atualizar_geometria()
RETURNS TRIGGER AS $$
BEGIN
    -- Se latitude e longitude forem fornecidas, gera o Point do PostGIS
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4674);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_escola_bi_geo
    BEFORE INSERT OR UPDATE ON escolas
    FOR EACH ROW
    EXECUTE FUNCTION tg_atualizar_geometria();

```

### Índice Espacial (Essencial)

Para rodar consultas de proximidade e densidade (como o KDE) instantaneamente em 150 mil pontos:

```sql
CREATE INDEX idx_escolas_geom ON escolas USING GIST (geom);

```

---

## 4. Geração de Métricas e Scores via Funções de Banco (Stored Procedures)

Para evitar que seu backend precise calcular scores de infraestrutura toda vez que um mapa for carregado, o próprio banco pode expor uma função especializada para criar os indicadores sintéticos de vulnerabilidade.

```sql
CREATE OR REPLACE FUNCTION calcular_score_infra(pedago infra_pedagogica)
RETURNS numeric AS $$
DECLARE
    score integer := 0;
BEGIN
    IF (pedago).biblioteca      THEN score := score + 1; END IF;
    IF (pedago).lab_ciencias    THEN score := score + 1; END IF;
    IF (pedago).lab_informatica THEN score := score + 1; END IF;
    IF (pedago).quadra_esportes THEN score := score + 1; END IF;
    
    -- Retorna uma nota de 0 a 100
    RETURN (score / 4.0) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE; -- IMMUTABLE diz ao banco que o resultado é sempre o mesmo para os mesmos dados, permitindo cache otimizado

```

---

## 5. Lidando com Grandes Volumes: Particionamento de Tabelas

Como novos dados de grandes tabelas entram constantemente (provavelmente novas edições anuais do Censo Escolar), o **Particionamento Declarativo** do PostgreSQL é indispensável. Em vez de uma tabela gigantesca de milhões de linhas lentas de buscar, dividimos a tabela física por ano, mas mantemos uma interface única para consultas.

```sql
-- Tabela "Pai" particionada por ano
CREATE TABLE historico_escolas (
    co_entidade         integer,
    ano_censo           int,
    situacao            situacao_funcionamento,
    pedagogico          infra_pedagogica,
    geom                geometry(Point, 4674)
) PARTITION BY RANGE (ano_censo);

-- Criação das partições físicas (uma por ano)
CREATE TABLE historico_escolas_2024 PARTITION OF historico_escolas
    FOR VALUES FROM (2024) TO (2025);

CREATE TABLE historico_escolas_2025 PARTITION OF historico_escolas
    FOR VALUES FROM (2025) TO (2026);

```

Quando você rodar um `SELECT * FROM historico_escolas WHERE ano_censo = 2025`, o PostgreSQL ignora completamente todos os outros anos do disco (**Partition Pruning**), fazendo a consulta rodar na velocidade de uma tabela pequena.

---

### Resumo dos Ganhos com essa Modelagem:

1. **Espaço em Disco:** Redução drástica pelo uso de tipos nativos adequados (`smallint` mapeado em domínios, booleanos compactados em `composite types`, `ENUMs`).
2. **Qualidade do Dado:** O banco rejeita inconsistências na porta de entrada (via domínios e checagens estritas).
3. **Velocidade Spacial:** Consultas geográficas usando indexação `GiST` e funções puras nativas do PostGIS rodam em milissegundos.
4. **Legibilidade:** O código do seu backend ou das suas consultas em R fica limpo, natural e focado em regras de negócio, não em parsing de dados brutos.

# Health Check para toda base

Analisando os relatórios do seu script e as execuções da função `health_check_approx`, os dados estruturais e a consistência geral parecem **muito bons**, mas existem alguns pontos específicos de atenção e cruzamento de dados que valem a pena destacar.

Aqui está um diagnóstico detalhado do estado atual das suas tabelas:

---

## 1. Tabela: `clean.inep_notas_desagregadas`

* **Total de linhas:** 384.169 | **Campos Nulos:** 0% em todas as colunas.
* **Diagnóstico:** A tabela está completamente preenchida (sem `NULL`s), o que é excelente para o pipeline de processamento e evita erros de agregação.
* **Pontos de atenção:**
* **`id_escola` vs `linha_original`:** Ambas possuem exatamente o mesmo número estimado de valores distintos (`52474`). Verifique se a granularidade da tabela é realmente por escola/ano ou se há alguma relação direta/redundância acidental que gerou essa coincidência exata de cardinalidade.
* **`nota_media`:** Tem uma cardinalidade altíssima (`341132`), o que faz sentido por ser o resultado de um cálculo decimal (`numeric`). `nota_mat` e `nota_por` possuem cerca de 11k valores distintos cada, o que também é normal para notas com casas decimais vindas do Saeb/INEP.



## 2. Tabela: `clean.censo_gestor`

* **Total de linhas:** 180.540 | **Campos Nulos:** 0% em todas as colunas.
* **Diagnóstico:** Uma tabela tipicamente de contagens (`qt_...`). A integridade física está perfeita (zero nulos).
* **Pontos de atenção:**
* **`nu_ano_censo`:** Possui apenas **1 valor distinto**. Isso significa que essa tabela guarda dados de um único ano específico. Se o objetivo for um painel histórico/série temporal, os dados dos outros anos ainda não foram importados ou consolidados aqui.
* **`co_entidade`:** O número de valores distintos é **exatamente igual** ao total de linhas (`180540`). Isso confirma que a chave primária de fato é o código da escola (`co_entidade`) e que existe exatamente **um registro de gestor por escola** para o ano em questão.



## 3. Tabela: `clean.censo_docentes`

* **Total de linhas:** 178.772 | **Campos Nulos:** 0% (relatório truncado, mas a tendência se manteve).
* **Diagnóstico:** Assim como a de gestores, monitora a quantidade de docentes por nível/vínculo.
* **Pontos de atenção:**
* **`co_entidade`:** O número de valores distintos é **178.772**, igual ao total de linhas. Portanto, também é uma tabela agregada por escola (um registro descritivo por escola).
* **Cruzamento com Gestores:** Note que `censo_gestor` tem 180.540 escolas e `censo_docentes` tem 178.772. Isso aponta que existem **1.768 escolas** que possuem dados de gestores cadastrados, mas não possuem dados de docentes (ou vice-versa). Vale investigar se são escolas extintas, sem turmas ativas ou apenas omissão no censo.



## 4. Tabela: `clean.remuneracao_municipal`

* **Total de linhas:** 2.548.530 | **Campos Nulos:** Baixíssimo (apenas em `cod_inep`).
* **Diagnóstico:** É a sua maior tabela em volume de linhas. A qualidade geral está ótima.
* **Pontos de atenção:**
* **`cod_inep` com Nulos:** Possui 2.718 valores nulos (`0.11%`). É um percentual baixo, mas como o `cod_inep` (ou `id_escola`) costuma ser a chave de relacionamento com o restante do ecossistema do EduMaps, esses profissionais ficarão "órfãos" de escola nas análises espacializadas. Pode ser necessário um tratamento via `escola` (texto) ou `cpf` para tentar resgatar esses códigos, ou mapeá-los para um código genérico da secretaria de educação correspondente.
* **`rede`:** Possui apenas **1 valor distinto**. Indica que essa tabela foi filtrada apenas para uma rede específica (provavelmente a rede Municipal, dado o nome da tabela).



## 5. Tabela: `analytics.mv_municipios_consolidado`

* **Total de linhas:** 5.571 | **Campos Nulos:** Concentrados no bloco do IDEB e PIB.
* **Diagnóstico:** Perfeito. O total de linhas (`5571`) condiz exatamente com o número de municípios do Brasil (5.568 municípios + Fernando de Noronha + Brasília + eventual resíduo/histórico).
* **Pontos de atenção:**
* **`ideb_medio` com 3.30% de nulos:** Há 184 municípios sem nota do IDEB do Ensino Médio. Isso é comum na realidade brasileira, pois muitos municípios de pequeno porte não possuem oferta de Ensino Médio na rede municipal (ficando a cargo do Estado) ou não atingiram o número mínimo de alunos avaliados pelo Saeb para divulgar a nota.
* **Nulos no PIB (1 linha):** Existe **1 município** com dados nulos em `pib_total`, `pib_per_capita`, `ano_pib`, etc. Vale a pena rodar um `SELECT no_municipio, sg_uf FROM analytics.mv_municipios_consolidado WHERE pib_total IS NULL;` para identificar quem é. Geralmente é um município muito novo que ainda não teve o PIB calculado/divulgado pelo IBGE no ano base utilizado.


## 🚀 Desempenho do Script

O tempo de execução da sua função de health check está espetacular. Rodar uma análise probabilística de cardinalidade e nulos em uma tabela de **2.5 milhões de linhas** em apenas **3.5 ms** (com planejamento de 0.08 ms) mostra que a sua abordagem usando aproximações (provavelmente se baseando nas estatísticas do catálogo do Postgres, como `pg_statistic` ou `HyperLogLog`) está funcionando de forma extremamente eficiente para o pipeline do projeto.


---

# Sugestões de melhorias

Com base nos health checks apresentados, seu banco está bem estruturado para consultas, mas o modelo de domínio (tipos, restrições, normalização) pode evoluir para aumentar clareza, integridade e reuso. Considerando o volume médio (centenas de milhares de linhas), sugiro as seguintes mudanças, organizadas por impacto.

## 1. ENUMs para colunas com domínio pequeno e estável

| Coluna | Domínio atual (smallint) | Proposta ENUM | Benefício |
|--------|--------------------------|---------------|------------|
| `co_regiao` | 1..5 | `regiao_br ENUM ('Norte','Nordeste','Sudeste','Sul','Centro-Oeste')` | auto-documentação, evita números mágicos |
| `tp_dependencia` | 1..4 | `dependencia_administrativa ENUM ('Federal','Estadual','Municipal','Privada')` | mesmo, usado em muitas tabelas (censo_escolas, ideb_notas_escolas) |
| `tp_localizacao` | 1..2 | `localizacao ENUM ('Urbana','Rural')` | |
| `tp_situacao_funcionamento` | 1..3 | `situacao_escola ENUM ('Ativa','Paralisada','Extinta')` | |
| `rede` (tabela ideb_notas_escolas) | texto "Federal", etc. | usar o mesmo `dependencia_administrativa` | consistência entre tabelas |

**Exemplo de migração**:
```sql
CREATE TYPE dependencia_administrativa AS ENUM ('Federal','Estadual','Municipal','Privada');
ALTER TABLE clean.censo_escolas 
  ALTER COLUMN tp_dependencia TYPE dependencia_administrativa 
  USING CASE tp_dependencia 
    WHEN 1 THEN 'Federal'::dependencia_administrativa 
    WHEN 2 THEN 'Estadual' 
    WHEN 3 THEN 'Municipal' 
    WHEN 4 THEN 'Privada' 
  END;
```

## 2. Converter flags smallint para BOOLEAN (com default false, NOT NULL)

Atualmente muitas colunas `in_*` são `smallint` permitindo nulo, mas semanticamente são booleanos. Exemplos: `in_agua_potavel`, `in_energia_rede_publica`, `in_acessibilidade_rampas`.

- **Problema**: `null_percentage` muitas vezes é 15,62% (caso do censo_escolas) porque o valor original é nulo quando a escola não respondeu. Na prática, para análises, precisamos tratar como `false`.
- **Solução**:
  ```sql
  ALTER TABLE clean.censo_escolas 
    ALTER COLUMN in_agua_potavel SET DEFAULT false,
    ALTER COLUMN in_agua_potavel SET NOT NULL,
    ALTER COLUMN in_agua_potavel TYPE BOOLEAN USING (in_agua_potavel = 1);
  ```
- **Antes** substituir nulos por false (ou 0). Isso elimina a necessidade de `COALESCE` em consultas e acelera índices booleanos.

## 3. Domínios para códigos padronizados

Você tem muitas colunas de código IBGE (7 dígitos), códigos de região, etc. Use `CREATE DOMAIN` para centralizar validações e documentar.

```sql
CREATE DOMAIN codigo_ibge_municipio AS integer 
  CHECK (VALUE >= 100000 AND VALUE <= 999999);

CREATE DOMAIN codigo_ibge_uf AS smallint 
  CHECK (VALUE BETWEEN 11 AND 53);

CREATE DOMAIN telefone_br AS varchar(20) 
  CHECK (VALUE ~ '^\d{10,11}$'); -- simplificado

ALTER TABLE clean.censo_escolas 
  ALTER COLUMN co_municipio TYPE codigo_ibge_municipio,
  ALTER COLUMN co_uf TYPE codigo_ibge_uf;
```

## 4. Normalização de grupos repetitivos (reduzir largura da linha)

As tabelas `censo_escolas`, `censo_matriculas`, `censo_docentes`, `censo_gestor` possuem **centenas de colunas**, muitas com domínio idêntico e alta redundância vertical. Exemplo: `in_comum_creche`, `in_comum_pre`, `in_comum_fund_ai`, etc. – 20+ colunas que representam **oferta de etapas**.

**Sugestão**: Criar tabelas filhas 1:N (modelo EAV controlado) para armazenar apenas as ofertas existentes.

- `escola_ofertas (co_entidade, etapa, tipo_oferta)` onde `tipo_oferta` = 'regular', 'especial_exclusiva', 'eja', etc.
- `escola_infraestrutura (co_entidade, recurso, quantidade)` para colunas `qt_*` e `in_*`.

**Vantagens**:
- Facilita consultas do tipo "escolas que oferecem creche E têm biblioteca".
- Reduz o número de colunas (de 306 para umas 40), facilitando manutenção e evolução.
- Permite adicionar novos recursos sem alterar o schema principal.

**Cuidado**: Essa desnormalização pode impactar a performance de algumas consultas agregadas. Mas, para um volume médio (200k escolas), é perfeitamente viável, especialmente com índices apropriados.

## 5. Funções de domínio (como alternativas a ENUMs compostos)

Você já tem funções que retornam JSON (`infra_badge_bag`). Para análises mais estruturadas, crie funções que retornam **tipos compostos** ou **tabelas**.

Exemplo: função que retorna resumo de infraestrutura básica:

```sql
CREATE TYPE resumo_infra AS (
  agua_adequada boolean,
  energia_adequada boolean,
  esgoto_adequado boolean,
  banheiros boolean,
  cozinha boolean
);

CREATE FUNCTION resumo_infra_escola(p_co_entidade bigint)
RETURNS resumo_infra STABLE LANGUAGE sql AS $$
  SELECT 
    (in_agua_potavel OR in_agua_rede_publica) AS agua_adequada,
    in_energia_rede_publica AS energia_adequada,
    (in_esgoto_rede_publica OR in_esgoto_fossa_septica) AS esgoto_adequado,
    in_banheiro,
    in_cozinha
  FROM clean.censo_escolas WHERE co_entidade = p_co_entidade;
$$;
```

Essa função pode ser usada em consultas com `LATERAL`.

## 6. Domínios para percentuais e notas

Colunas como `pc_nivel_1` (INSE) e `nota_matematica` têm restrições implícitas (0-100, 0-10). Crie domínios:

```sql
CREATE DOMAIN percentual_0_100 AS numeric(5,2) CHECK (VALUE BETWEEN 0 AND 100);
CREATE DOMAIN nota_0_10 AS numeric(4,2) CHECK (VALUE BETWEEN 0 AND 10);

ALTER TABLE clean.inse 
  ALTER COLUMN pc_nivel_1 TYPE percentual_0_100,
  ALTER COLUMN pc_nivel_2 TYPE percentual_0_100;
```

Isso evita valores inválidos (ex.: 105%) e documenta a coluna.

## 7. Colunas geradas (generated columns) para indicadores derivados

Útil para cálculos que são sempre baseados nos mesmos campos. Exemplo: se você já criou `nro_etapas` como coluna calculada, pode torná-la `STORED` (evita recalcular a cada consulta).

```sql
ALTER TABLE clean.censo_escolas 
  ADD COLUMN nro_etapas_stored integer GENERATED ALWAYS AS (
    (in_comum_creche::int + in_comum_pre::int + ...)  -- somar todas flags de oferta
  ) STORED;
```

Como você já tem `nro_etapas` calculado via UPDATE, pode mantê-lo ou migrar para generated.

## 8. Índices parciais e constraints para dependências nulas

Muitas colunas têm alta porcentagem de nulos condicionais (ex.: `tp_categoria_escola_privada` é nulo para escolas públicas). Reforce isso com `CHECK` constraints:

```sql
ALTER TABLE clean.censo_escolas ADD CONSTRAINT categoria_privada_valida CHECK (
  (tp_dependencia != 'Privada' AND tp_categoria_escola_privada IS NULL) OR
  (tp_dependencia = 'Privada' AND tp_categoria_escola_privada IS NOT NULL)
);
```

## Resumo da recomendação (prioridade alta para média)

1. **ENUMs** para domínios pequenos (dependência, localização, situação, região) – melhora legibilidade imediata.
2. **BOOLEAN** para flags – simplifica consultas.
3. **Domínios** para códigos IBGE e percentuais – impõe integridade.
4. **Normalização** das ofertas de etapa (in_comum_*, in_esp_exclusiva_*) – reduz drasticamente o número de colunas e facilita manutenção futura (especialmente quando novos anos do censo trouxerem novas modalidades).

Se você quiser, posso fornecer scripts específicos para cada uma dessas transformações (em Sqitch, para versionamento). Basta indicar quais delas você deseja implementar primeiro.
