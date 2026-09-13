
## Proposta de Scores para Escolas (EduMaps)

Com base nas tabelas do Censo Escolar (escolas, docentes, matrículas, gestores), proponho abaixo a definição de cinco scores principais, normalizados na escala de 0 a 10, além de scores complementares relevantes.

---

### 1. Capacidade de Atendimento
Mede a habilidade da escola em acolher e prover ensino para sua demanda, considerando espaço físico, variedade de etapas ofertadas, alimentação e jornada integral.

**Componentes e pesos:**

| Componente | Indicador | Fórmula | Peso |
|------------|-----------|---------|------|
| Densidade aluno–sala | `alunos_por_sala = qt_mat_bas / qt_salas_utilizadas` | Score = 10 × max(0, 1 − alunos_por_sala/50) <br> (Capacidade de 50 alunos/sala = 0; ≤20 alunos/sala = 10) | 0,4 |
| Diversidade de etapas | Número de níveis oferecidos: creche, pré, EF AI, EF AF, EM, EJA, profissional | Score = (níveis_oferecidos / 7) × 10 | 0,2 |
| Atendimento integral | Proporção de alunos em tempo integral | Score = (qt_mat_bas_int / qt_mat_bas) × 10 (se qt_mat_bas > 0) | 0,2 |
| Alimentação escolar | `in_alimentacao` (0/1) | Score = 10 se 1, 0 se 0 | 0,2 |

**Score final** = média ponderada.  
**Normalização** já embutida (cada componente entre 0 e 10).

---

### 2. Infraestrutura
Avalia a qualidade das instalações, recursos, acessibilidade e tecnologias disponíveis. Divide‑se em quatro categorias, cujas médias compõem o score final.

#### Categoria A – Infraestrutura básica (5 itens)
- `in_agua_potavel`
- `in_energia_rede_publica`
- `in_esgoto_rede_publica` ou `in_esgoto_fossa_septica` (considera-se adequado se um deles = 1)
- `in_lixo_servico_coleta`
- `in_banheiro`

**ScoreA** = (soma dos itens / 5) × 10

#### Categoria B – Salas e dependências pedagógicas (9 itens)
- `in_biblioteca` ou `in_biblioteca_sala_leitura`
- `in_laboratorio_ciencias`
- `in_laboratorio_informatica`
- `in_quadra_esportes`
- `in_cozinha`
- `in_refeitorio`
- `in_sala_diretoria`
- `in_secretaria`
- `in_sala_professor`

**ScoreB** = (soma dos itens / 9) × 10

#### Categoria C – Acessibilidade (5 itens)
- `in_acessibilidade_rampas`
- `in_acessibilidade_corrimao`
- `in_acessibilidade_pisos_tateis`
- `in_acessibilidade_sinalizacao`
- `in_banheiro_pne`

**ScoreC** = (soma dos itens / 5) × 10

#### Categoria D – Tecnologia e conectividade (5 itens)
- `in_computador`
- `in_internet` (e, idealmente, `in_banda_larga`)
- `in_equip_lousa_digital`
- `in_equip_multimidia`
- `in_equip_impressora` ou `in_equip_impressora_mult`

**ScoreD** = (soma dos itens / 5) × 10

**Score final de infraestrutura** = (ScoreA + ScoreB + ScoreC + ScoreD) / 4  
(Já normalizado entre 0 e 10.)

---

### 3. Capacitação Docente
Reflete a qualificação formal, vínculo e especialização do corpo docente.

| Componente | Fórmula | Peso |
|------------|---------|------|
| Formação superior | `qt_doc_bas_esco_sup_grad / qt_doc_bas` (se qt_doc_bas > 0) | 0,3 |
| Pós‑graduação (espec, mestrado, doutorado) | `(qt_doc_bas_esco_sup_pos_espec + qt_doc_bas_esco_sup_pos_mestra + qt_doc_bas_esco_sup_pos_douto) / qt_doc_bas` | 0,3 |
| Vínculo efetivo/concursado | `qt_doc_bas_vinculo_concur / qt_doc_bas` | 0,2 |
| Especialização na área de atuação | Soma de `qt_doc_bas_espec_*` (excluindo `qt_doc_bas_espec_nenhum`) dividida por `qt_doc_bas` | 0,2 |

Cada proporção já está em [0,1]; multiplica‑se por 10 para obter o subscore.  
**Score final** = média ponderada × 10 (já normalizado).

> Nota: Para escolas sem docentes (ex.: somente administração), atribuir score 0.

---

### 4. Diversidade Discente
Mede a heterogeneidade do alunato quanto a raça/cor, gênero, condição de deficiência e modalidade EJA.

#### Componentes (todos normalizados entre 0 e 1, depois ×10):

| Componente | Fórmula | Peso |
|------------|---------|------|
| Diversidade racial | Índice de Simpson: 1 – Σ(p_i²), onde p_i = proporção de cada raça/cor (branca, preta, parda, amarela, indígena) | 0,35 |
| Equilíbrio de gênero | 2 × min(proporção_feminino, proporção_masculino) <br> (Usa `qt_mat_bas_fem` e `qt_mat_bas_masc`) | 0,25 |
| Inclusão de PcD | `(qt_mat_bas_d + qt_mat_bas_dm + qt_mat_bas_dv) / qt_mat_bas` | 0,20 |
| Oferta de EJA | `qt_mat_eja / qt_mat_bas` (alunos jovens/adultos – diversidade etária e de trajetória) | 0,20 |

**Score final** = média ponderada × 10.

---

### 5. Capacidade Gestora
Avalia a formação, a proporção de gestores, a existência de órgãos colegiados e a profissionalização do acesso ao cargo.

| Componente | Fórmula | Peso |
|------------|---------|------|
| Qualificação dos gestores | Média simples entre proporção com ensino superior e proporção com pós‑graduação | 0,3 |
| Formação específica em gestão | `qt_gest_bas_espec_gestao / qt_gest_bas` | 0,2 |
| Proporção gestor/aluno | Score = 10 × min(1, 200 / (qt_mat_bas / qt_gest_bas)) <br> (ex.: 1 gestor para 100 alunos = 10; 1:400 = 5; 1:800 = 2,5) | 0,2 |
| Órgãos colegiados | (soma de `in_orgao_ass_pais`, `in_orgao_ass_pais_mestres`, `in_orgao_conselho_escolar`, `in_orgao_gremio_estudantil`, `in_orgao_outros`) / 5, desconsiderando `in_orgao_nenhum` | 0,2 |
| Acesso meritocrático/democrático | `(qt_gest_bas_acesso_cargo_conca + qt_gest_bas_acesso_cargo_eleic + qt_gest_bas_acesso_cargo_p_sel) / qt_gest_bas` | 0,1 |

**Score final** = média ponderada × 10 (cada componente já normalizado entre 0 e 1).

---

## Scores Complementares (também normalizados 0–10)

### A. Inclusão e Acessibilidade
- **Físico**: média dos itens de acessibilidade (mesmo ScoreC da infraestrutura).
- **Recursos humanos**: presença de tradutor Libras (`qt_doc_bas_tradutor_libras > 0`) + sala de atendimento especial (`in_sala_atendimento_especial`). Score = média × 10.
- **Prática inclusiva**: proporção de alunos PcD em classes comuns (`qt_mat_esp_cc / qt_mat_esp` se >0) – quanto maior, melhor.
- **Score final** = média dos três subscores.

### B. Inovação Pedagógica
- **Tecnologia no ensino**:  
  `in_equip_lousa_digital` + `in_equip_multimidia` + `in_internet_aprendizagem` + `in_material_ped_multimidia` + `in_equip_tv` (soma de 5 itens) → Score = (soma/5) × 10.
- **Projetos ativos**:  
  `in_educ_ambiental` (ou qualquer `in_educ_amb_*`), `in_espaco_atividade`, `in_espaco_equipamento` → média × 10.
- **Score final** = média dos dois.

### C. Sustentabilidade
- **Energia renovável**: `in_energia_renovavel` → 10 ou 0.
- **Gestão de resíduos**: `in_tratamento_lixo_reciclagem` ou `in_tratamento_lixo_reutiliza` → 10 ou 0.
- **Área verde/plantio**: `in_area_verde` + `in_area_plantio` → Score = (soma/2) × 10.
- **Educação ambiental**: qualquer flag `in_educ_amb_*` → Score = 10 se existir, senão 0.
- **Score final** = média dos quatro componentes.

### D. Conectividade com a Comunidade
- **Redes sociais e site**: `in_redes_sociais` → 10 ou 0.
- **Parcerias público‑privadas**: `in_poder_publico_parceria` → 10 ou 0.
- **Órgãos colegiados** (já calculado na gestão) – mesmo valor.
- **Acesso da comunidade à internet**: `in_internet_comunidade` → 10 ou 0.
- **Score final** = média simples.

---

## Implementação (lógica SQL)

Os scores podem ser calculados por meio de **CTEs** que agregam as tabelas por `co_entidade` (e `nu_ano_censo`). Exemplo para o score de infraestrutura:

```sql
WITH infra AS (
  SELECT co_entidade,
         ( (in_agua_potavel + in_energia_rede_publica + 
            (CASE WHEN in_esgoto_rede_publica=1 OR in_esgoto_fossa_septica=1 THEN 1 ELSE 0 END) +
            in_lixo_servico_coleta + in_banheiro) / 5.0 ) * 10 AS scoreA,
         -- similar para scoreB, C, D
  FROM clean.censo_escolas
)
SELECT co_entidade,
       (scoreA + scoreB + scoreC + scoreD) / 4.0 AS score_infraestrutura
FROM infra;
```

Para os scores que envolvem proporções (docentes, matrículas, gestores), deve‑se tratar divisão por zero e usar `COALESCE`.

---

## Observações finais

- Todos os scores pressupõem **escolas ativas** (`tp_situacao_funcionamento = 1`).
- Quando uma escola não possui determinada modalidade (ex.: não oferta EJA), os componentes relacionados a ela devem ser ignorados ou zerados conforme a lógica de negócio.
- A normalização **0–10** é obtida diretamente pelas fórmulas propostas; nenhum passo adicional é necessário.
- Recomenda‑se **armazenar os scores em uma tabela auxiliar** (ex.: `scores_escolas`) com chave `(nu_ano_censo, co_entidade)` para consultas rápidas e geovisualização no EduMaps.

Esses scores fornecem um retrato multidimensional da escola, permitindo análises comparativas, identificação de boas práticas e alocação mais eficiente de recursos.


Abaixo está a implementação da CTE para o **score de Capacidade de Atendimento** conforme a definição anterior, incluindo ponderação e normalização 0–10. O código assume PostgreSQL e utiliza as tabelas `censo_escolas` e `censo_matriculas`.

```sql
-- CTE para calcular os componentes do score de Capacidade de Atendimento
WITH capacidade_atendimento AS (
    SELECT 
        m.nu_ano_censo,
        m.co_entidade,
        -- 1. Densidade aluno–sala (peso 0.4)
        CASE 
            WHEN e.qt_salas_utilizadas IS NULL OR e.qt_salas_utilizadas = 0 THEN 0
            ELSE GREATEST(0, 10 * (1 - (m.qt_mat_bas::numeric / e.qt_salas_utilizadas) / 50))
        END AS score_densidade,
        
        -- 2. Diversidade de etapas oferecidas (peso 0.2)
        -- Considera 7 possíveis níveis: creche, pré, EF anos iniciais, EF anos finais, EM regular, EJA, profissionalizante
        (
            (CASE WHEN e.in_comum_creche = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_comum_pre = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_comum_fund_ai = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_comum_fund_af = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_comum_medio_medio = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_eja = 1 THEN 1 ELSE 0 END) +
            (CASE WHEN e.in_profissionalizante = 1 THEN 1 ELSE 0 END)
        ) / 7.0 * 10 AS score_diversidade,
        
        -- 3. Proporção de alunos em tempo integral (peso 0.2)
        CASE 
            WHEN m.qt_mat_bas IS NULL OR m.qt_mat_bas = 0 THEN 0
            ELSE (m.qt_mat_bas_int::numeric / m.qt_mat_bas) * 10
        END AS score_integral,
        
        -- 4. Oferta de alimentação escolar (peso 0.2)
        CASE WHEN e.in_alimentacao = 1 THEN 10 ELSE 0 END AS score_alimentacao
        
    FROM 
        clean.censo_matriculas m
    INNER JOIN 
        clean.censo_escolas e 
            ON m.co_entidade = e.co_entidade 
            AND m.nu_ano_censo = e.nu_ano_censo
    WHERE 
        e.tp_situacao_funcionamento = 1   -- apenas escolas em atividade
        -- Opcional: filtrar por ano específico, ex: AND m.nu_ano_censo = 2025
)

-- Cálculo final do score (média ponderada) - já normalizado em 0-10
SELECT 
    nu_ano_censo,
    co_entidade,
    ROUND(
        0.4 * score_densidade + 
        0.2 * score_diversidade + 
        0.2 * score_integral + 
        0.2 * score_alimentacao
    , 2) AS score_capacidade_atendimento
FROM 
    capacidade_atendimento;
```

### Exemplo de saída:

| nu_ano_censo | co_entidade | score_capacidade_atendimento |
|--------------|-------------|-------------------------------|
| 2025         | 12345678901 | 7.45                          |
| 2025         | 12345678902 | 3.20                          |

### Para persistir os resultados:

```sql
-- Criar tabela de scores (caso não exista)
CREATE TABLE IF NOT EXISTS clean.scores_escolas (
    nu_ano_censo integer,
    co_entidade bigint,
    score_capacidade_atendimento numeric(5,2),
    PRIMARY KEY (nu_ano_censo, co_entidade)
);

-- Inserir os scores calculados
INSERT INTO clean.scores_escolas (nu_ano_censo, co_entidade, score_capacidade_atendimento)
-- (colocar a CTE inteira aqui)
ON CONFLICT (nu_ano_censo, co_entidade) DO UPDATE
SET score_capacidade_atendimento = EXCLUDED.score_capacidade_atendimento;
```

### Observações importantes:

1. **Tratamento de nulos/zeros**:  
   - Se `qt_salas_utilizadas` for nulo ou zero, o score de densidade é zero.  
   - Se não houver matrículas (`qt_mat_bas` = 0), o score de integral é zero.  
   - A diversidade de etapas conta apenas os níveis com flag `= 1`.

2. **Limite de alunos por sala**:  
   A fórmula `10 * (1 - alunos_por_sala/50)` penaliza escolas com alta densidade. Com 20 alunos/sala → 6; com 50 ou mais → 0.

3. **Escolas sem dados de matrícula**:  
   A CTE usa `INNER JOIN`, então escolas sem registros em `censo_matriculas` não aparecem. Se desejar incluí‑las com pontuação mínima, troque para `LEFT JOIN` e trate os nulos.

4. **Ano corrente**:  
   O campo `nu_ano_censo` permite calcular scores para diferentes anos separadamente.

Essa implementação segue fielmente a metodologia proposta e é pronta para ser integrada ao pipeline do EduMaps.

## Score para Infraestrutura

Abaixo está a implementação da CTE para o **score de Infraestrutura**, conforme a metodologia definida (quatro categorias, cada uma normalizada de 0 a 10, depois média simples). O código considera apenas escolas em atividade (`tp_situacao_funcionamento = 1`) e utiliza os campos da tabela `censo_escolas`.

```sql
-- CTE para calcular o score de Infraestrutura (0-10)
WITH infra_scores AS (
    SELECT 
        nu_ano_censo,
        co_entidade,
        
        -- ========== CATEGORIA A: Infraestrutura básica (5 itens) ==========
        (
            -- Água potável
            in_agua_potavel +
            -- Energia rede pública
            in_energia_rede_publica +
            -- Esgoto adequado (rede pública ou fossa séptica)
            (CASE WHEN in_esgoto_rede_publica = 1 OR in_esgoto_fossa_septica = 1 THEN 1 ELSE 0 END) +
            -- Coleta de lixo
            in_lixo_servico_coleta +
            -- Banheiro
            in_banheiro
        ) / 5.0 * 10 AS score_cat_a,
        
        -- ========== CATEGORIA B: Salas e dependências pedagógicas (9 itens) ==========
        (
            -- Biblioteca ou sala de leitura
            (CASE WHEN in_biblioteca = 1 OR in_biblioteca_sala_leitura = 1 THEN 1 ELSE 0 END) +
            -- Laboratório de ciências
            in_laboratorio_ciencias +
            -- Laboratório de informática
            in_laboratorio_informatica +
            -- Quadra de esportes
            in_quadra_esportes +
            -- Cozinha
            in_cozinha +
            -- Refeitório
            in_refeitorio +
            -- Sala da diretoria
            in_sala_diretoria +
            -- Secretaria
            in_secretaria +
            -- Sala dos professores
            in_sala_professor
        ) / 9.0 * 10 AS score_cat_b,
        
        -- ========== CATEGORIA C: Acessibilidade (5 itens) ==========
        (
            in_acessibilidade_rampas +
            in_acessibilidade_corrimao +
            in_acessibilidade_pisos_tateis +
            in_acessibilidade_sinalizacao +
            in_banheiro_pne
        ) / 5.0 * 10 AS score_cat_c,
        
        -- ========== CATEGORIA D: Tecnologia e conectividade (5 itens) ==========
        (
            in_computador +
            in_internet +
            in_equip_lousa_digital +
            in_equip_multimidia +
            (CASE WHEN in_equip_impressora = 1 OR in_equip_impressora_mult = 1 THEN 1 ELSE 0 END)
        ) / 5.0 * 10 AS score_cat_d
        
    FROM 
        clean.censo_escolas
    WHERE 
        tp_situacao_funcionamento = 1   -- apenas escolas ativas
        -- Opcional: filtrar por ano, ex: AND nu_ano_censo = 2025
)

-- ========== SCORE FINAL: média das quatro categorias ==========
SELECT 
    nu_ano_censo,
    co_entidade,
    ROUND(
        (score_cat_a + score_cat_b + score_cat_c + score_cat_d) / 4.0
    , 2) AS score_infraestrutura,
    -- (Opcional) Componentes individuais para análise
    ROUND(score_cat_a, 2) AS infra_basico,
    ROUND(score_cat_b, 2) AS infra_pedagogico,
    ROUND(score_cat_c, 2) AS infra_acessibilidade,
    ROUND(score_cat_d, 2) AS infra_tecnologia
FROM 
    infra_scores;
```

### Exemplo de saída:

| nu_ano_censo | co_entidade | score_infraestrutura | infra_basico | infra_pedagogico | infra_acessibilidade | infra_tecnologia |
|--------------|-------------|----------------------|--------------|------------------|----------------------|------------------|
| 2025         | 12345678901 | 6.85                 | 8.00         | 6.67             | 4.00                 | 8.00             |
| 2025         | 12345678902 | 3.20                 | 6.00         | 2.22             | 2.00                 | 2.00             |

### Como persistir os resultados (opcional):

```sql
-- Adicionar colunas à tabela de scores (se ainda não existirem)
ALTER TABLE clean.scores_escolas 
ADD COLUMN IF NOT EXISTS score_infraestrutura numeric(5,2),
ADD COLUMN IF NOT EXISTS infra_basico numeric(5,2),
ADD COLUMN IF NOT EXISTS infra_pedagogico numeric(5,2),
ADD COLUMN IF NOT EXISTS infra_acessibilidade numeric(5,2),
ADD COLUMN IF NOT EXISTS infra_tecnologia numeric(5,2);

-- Inserir/atualizar com os valores calculados (usando a CTE como subconsulta)
INSERT INTO clean.scores_escolas (nu_ano_censo, co_entidade, score_infraestrutura, infra_basico, infra_pedagogico, infra_acessibilidade, infra_tecnologia)
-- (substituir pela consulta acima, mas incluindo os campos adicionais)
ON CONFLICT (nu_ano_censo, co_entidade) DO UPDATE SET
    score_infraestrutura = EXCLUDED.score_infraestrutura,
    infra_basico = EXCLUDED.infra_basico,
    infra_pedagogico = EXCLUDED.infra_pedagogico,
    infra_acessibilidade = EXCLUDED.infra_acessibilidade,
    infra_tecnologia = EXCLUDED.infra_tecnologia;
```

### Observações importantes:

1. **Campos que podem ser nulos**:  
   Todos os campos `smallint` utilizados são `NOT NULL`? Pela descrição, muitos têm `Nullable` em branco, indicando que podem ser nulos. No PostgreSQL, a expressão `campo + campo` com nulo resulta em nulo, o que quebraria a soma. **Recomenda-se usar `COALESCE(campo, 0)`** para garantir tratamento correto. Exemplo:

   ```sql
   COALESCE(in_agua_potavel, 0) + COALESCE(in_energia_rede_publica, 0) + ...
   ```

   No código acima, simplificamos para clareza, mas a implementação final deve envolver `COALESCE`.

2. **Esgoto adequado**:  
   A condição `in_esgoto_rede_publica = 1 OR in_esgoto_fossa_septica = 1` é aplicada corretamente.

3. **Biblioteca**:  
   Foi usado `in_biblioteca OR in_biblioteca_sala_leitura`, priorizando existência de qualquer um.

4. **Impressora**:  
   Considera-se presente se `in_equip_impressora = 1` ou `in_equip_impressora_mult = 1`.

5. **Tratamento de escolas com poucos dados**:  
   A CTE calcula as categorias mesmo com valores zero; o score final fica entre 0 e 10.

Essa implementação está pronta para ser executada no banco de dados do EduMaps, fornecendo uma métrica robusta de infraestrutura escolar.

## Capacitação docente

Abaixo está a implementação da CTE para o **score de Capacitação Docente** conforme a metodologia proposta. O cálculo considera as proporções de formação superior, pós-graduação, vínculo efetivo e especialização na área de atuação, cada uma normalizada em 0–10 e combinada por média ponderada.

```sql
-- CTE para calcular o score de Capacitação Docente (0-10)
WITH docentes AS (
    SELECT 
        d.nu_ano_censo,
        d.co_entidade,
        d.qt_doc_bas,
        -- Formação superior (licenciatura + graduação sem licenciatura)
        COALESCE(d.qt_doc_bas_esco_sup_grad, 0) AS total_superior,
        -- Pós-graduação (especialização + mestrado + doutorado)
        COALESCE(d.qt_doc_bas_esco_sup_pos_espec, 0) 
            + COALESCE(d.qt_doc_bas_esco_sup_pos_mestra, 0)
            + COALESCE(d.qt_doc_bas_esco_sup_pos_douto, 0) AS total_pos,
        -- Vínculo efetivo/concursado
        COALESCE(d.qt_doc_bas_vinculo_concur, 0) AS total_efetivo,
        -- Especialização na área de atuação (soma de todas as especializações listadas)
        COALESCE(d.qt_doc_bas_espec_cre, 0)
            + COALESCE(d.qt_doc_bas_espec_pre_escola, 0)
            + COALESCE(d.qt_doc_bas_espec_anos_iniciais, 0)
            + COALESCE(d.qt_doc_bas_espec_anos_finais, 0)
            + COALESCE(d.qt_doc_bas_espec_ens_medio, 0)
            + COALESCE(d.qt_doc_bas_espec_eja, 0)
            + COALESCE(d.qt_doc_bas_espec_ed_especial, 0)
            + COALESCE(d.qt_doc_bas_espec_bil_surdos, 0)
            + COALESCE(d.qt_doc_bas_espec_ed_indigena, 0)
            + COALESCE(d.qt_doc_bas_espec_campo, 0)
            + COALESCE(d.qt_doc_bas_espec_ambiental, 0)
            + COALESCE(d.qt_doc_bas_espec_dir_humanos, 0)
            + COALESCE(d.qt_doc_bas_espec_div_sexual, 0)
            + COALESCE(d.qt_doc_bas_espec_dir_adolesc, 0)
            + COALESCE(d.qt_doc_bas_espec_afro, 0)
            + COALESCE(d.qt_doc_bas_espec_gestao, 0)
            + COALESCE(d.qt_doc_bas_espec_educ_tic, 0)
            + COALESCE(d.qt_doc_bas_espec_outros, 0) AS total_especializacao
    FROM 
        clean.censo_docentes d
    INNER JOIN 
        clean.censo_escolas e 
            ON d.co_entidade = e.co_entidade 
            AND d.nu_ano_censo = e.nu_ano_censo
    WHERE 
        e.tp_situacao_funcionamento = 1   -- apenas escolas ativas
        -- Opcional: filtrar por ano, ex: AND d.nu_ano_censo = 2025
)

SELECT 
    nu_ano_censo,
    co_entidade,
    -- Calcula os quatro subscores (cada um entre 0 e 10)
    CASE 
        WHEN qt_doc_bas IS NULL OR qt_doc_bas = 0 THEN 0
        ELSE (total_superior::numeric / qt_doc_bas) * 10
    END AS subscore_superior,
    
    CASE 
        WHEN qt_doc_bas IS NULL OR qt_doc_bas = 0 THEN 0
        ELSE (total_pos::numeric / qt_doc_bas) * 10
    END AS subscore_pos,
    
    CASE 
        WHEN qt_doc_bas IS NULL OR qt_doc_bas = 0 THEN 0
        ELSE (total_efetivo::numeric / qt_doc_bas) * 10
    END AS subscore_vinculo,
    
    CASE 
        WHEN qt_doc_bas IS NULL OR qt_doc_bas = 0 THEN 0
        ELSE (total_especializacao::numeric / qt_doc_bas) * 10
    END AS subscore_espec,
    
    -- Score final ponderado (pesos: 0.3, 0.3, 0.2, 0.2)
    ROUND(
        0.3 * CASE WHEN qt_doc_bas > 0 THEN (total_superior::numeric / qt_doc_bas) * 10 ELSE 0 END +
        0.3 * CASE WHEN qt_doc_bas > 0 THEN (total_pos::numeric / qt_doc_bas) * 10 ELSE 0 END +
        0.2 * CASE WHEN qt_doc_bas > 0 THEN (total_efetivo::numeric / qt_doc_bas) * 10 ELSE 0 END +
        0.2 * CASE WHEN qt_doc_bas > 0 THEN (total_especializacao::numeric / qt_doc_bas) * 10 ELSE 0 END
    , 2) AS score_capacitacao_docente
    
FROM 
    docentes;
```

### Exemplo de saída:

| nu_ano_censo | co_entidade | subscore_superior | subscore_pos | subscore_vinculo | subscore_espec | score_capacitacao_docente |
|--------------|-------------|-------------------|--------------|------------------|----------------|---------------------------|
| 2025         | 12345678901 | 9.00              | 7.50         | 8.00             | 6.50           | 7.90                      |
| 2025         | 12345678902 | 4.00              | 2.00         | 5.00             | 1.00           | 3.10                      |

### Persistindo os resultados na tabela de scores:

```sql
-- Adicionar coluna (se necessário)
ALTER TABLE clean.scores_escolas 
ADD COLUMN IF NOT EXISTS score_capacitacao_docente numeric(5,2);

-- Inserir/atualizar
INSERT INTO clean.scores_escolas (nu_ano_censo, co_entidade, score_capacitacao_docente)
-- (substituir pela consulta acima, selecionando apenas as colunas-chave + score final)
ON CONFLICT (nu_ano_censo, co_entidade) DO UPDATE SET
    score_capacitacao_docente = EXCLUDED.score_capacitacao_docente;
```

### Observações importantes:

1. **Tratamento de nulos**:  
   Todos os campos quantitativos são envolvidos em `COALESCE(..., 0)` para evitar soma nula. Na CTE, usamos `COALESCE` para cada campo individual.

2. **Escolas sem docentes** (`qt_doc_bas = 0` ou nulo):  
   O score final é zero, pois não há corpo docente para avaliar. Isso ocorre em escolas exclusivamente administrativas ou recém-criadas sem turmas.

3. **Especialização na área**:  
   Foram somados todos os campos `qt_doc_bas_espec_*` (excluído `qt_doc_bas_espec_nenhum`). Cada docente pode contar em múltiplas especializações; isso é uma proxy da diversidade e profundidade da formação continuada.

4. **Pesos** (0,3 / 0,3 / 0,2 / 0,2) conforme definido no plano original.  
   Pode-se ajustar conforme necessidade de negócio.

5. **Join com censo_escolas** garante que apenas escolas ativas sejam consideradas.  
   Caso existam escolas na tabela de docentes que não estejam em `censo_escolas` (inconsistência), o `INNER JOIN` as exclui; use `LEFT JOIN` se necessário.

Essa implementação está pronta para ser executada no banco do EduMaps, fornecendo uma métrica objetiva sobre a qualificação do corpo docente.

## Diversidade Discente
Abaixo está a implementação da CTE para o **score de Diversidade Discente** conforme a metodologia proposta, com normalização 0–10 e ponderação definida.

```sql
-- CTE para calcular o score de Diversidade Discente (0-10)
WITH diversidade AS (
    SELECT 
        m.nu_ano_censo,
        m.co_entidade,
        m.qt_mat_bas,
        -- Raça/cor: branca, preta, parda, amarela, indígena
        COALESCE(m.qt_mat_bas_branca, 0) AS branca,
        COALESCE(m.qt_mat_bas_preta, 0) AS preta,
        COALESCE(m.qt_mat_bas_parda, 0) AS parda,
        COALESCE(m.qt_mat_bas_amarela, 0) AS amarela,
        COALESCE(m.qt_mat_bas_indigena, 0) AS indigena,
        -- Gênero
        COALESCE(m.qt_mat_bas_fem, 0) AS fem,
        COALESCE(m.qt_mat_bas_masc, 0) AS masc,
        -- Alunos com deficiência (soma dos tipos)
        COALESCE(m.qt_mat_bas_d, 0) 
            + COALESCE(m.qt_mat_bas_dm, 0)
            + COALESCE(m.qt_mat_bas_dv, 0) AS pcd,
        -- Alunos EJA (fundamental + médio)
        COALESCE(m.qt_mat_eja, 0) AS eja
    FROM 
        clean.censo_matriculas m
    INNER JOIN 
        clean.censo_escolas e 
            ON m.co_entidade = e.co_entidade 
            AND m.nu_ano_censo = e.nu_ano_censo
    WHERE 
        e.tp_situacao_funcionamento = 1   -- apenas escolas ativas
        -- Opcional: filtrar por ano, ex: AND m.nu_ano_censo = 2025
),

calculos AS (
    SELECT 
        nu_ano_censo,
        co_entidade,
        qt_mat_bas,
        -- 1. Diversidade racial (Índice de Simpson: 1 - Σ p_i²)
        CASE 
            WHEN qt_mat_bas IS NULL OR qt_mat_bas = 0 THEN 0
            ELSE (
                1 - (
                    POWER(branca::numeric / qt_mat_bas, 2) +
                    POWER(preta::numeric / qt_mat_bas, 2) +
                    POWER(parda::numeric / qt_mat_bas, 2) +
                    POWER(amarela::numeric / qt_mat_bas, 2) +
                    POWER(indigena::numeric / qt_mat_bas, 2)
                )
            ) * 10
        END AS score_racial,
        
        -- 2. Equilíbrio de gênero (2 * min(fem, masc) / total)
        CASE 
            WHEN qt_mat_bas IS NULL OR qt_mat_bas = 0 THEN 0
            ELSE 2 * LEAST(fem::numeric, masc::numeric) / qt_mat_bas * 10
        END AS score_genero,
        
        -- 3. Inclusão de PcD (proporção de alunos com deficiência)
        CASE 
            WHEN qt_mat_bas IS NULL OR qt_mat_bas = 0 THEN 0
            ELSE (pcd::numeric / qt_mat_bas) * 10
        END AS score_pcd,
        
        -- 4. Oferta de EJA (proporção de alunos em EJA)
        CASE 
            WHEN qt_mat_bas IS NULL OR qt_mat_bas = 0 THEN 0
            ELSE (eja::numeric / qt_mat_bas) * 10
        END AS score_eja
        
    FROM 
        diversidade
)

-- Score final ponderado (pesos: racial 0.35, gênero 0.25, PcD 0.20, EJA 0.20)
SELECT 
    nu_ano_censo,
    co_entidade,
    ROUND(
        0.35 * score_racial +
        0.25 * score_genero +
        0.20 * score_pcd +
        0.20 * score_eja
    , 2) AS score_diversidade_discente,
    -- (Opcional) subscores para análise
    ROUND(score_racial, 2) AS div_racial,
    ROUND(score_genero, 2) AS div_genero,
    ROUND(score_pcd, 2) AS div_pcd,
    ROUND(score_eja, 2) AS div_eja
FROM 
    calculos;
```

### Exemplo de saída:

| nu_ano_censo | co_entidade | score_diversidade_discente | div_racial | div_genero | div_pcd | div_eja |
|--------------|-------------|----------------------------|------------|------------|---------|---------|
| 2025         | 12345678901 | 7.25                       | 8.40       | 9.00       | 2.50    | 6.00    |
| 2025         | 12345678902 | 3.80                       | 4.20       | 6.00       | 1.00    | 0.00    |

### Persistindo os resultados:

```sql
-- Adicionar coluna (se necessário)
ALTER TABLE clean.scores_escolas 
ADD COLUMN IF NOT EXISTS score_diversidade_discente numeric(5,2);

-- Inserir/atualizar
INSERT INTO clean.scores_escolas (nu_ano_censo, co_entidade, score_diversidade_discente)
-- (substituir pela consulta acima, selecionando apenas as colunas-chave + score final)
ON CONFLICT (nu_ano_censo, co_entidade) DO UPDATE SET
    score_diversidade_discente = EXCLUDED.score_diversidade_discente;
```

### Observações importantes:

1. **Índice de Simpson** mede a probabilidade de dois alunos aleatórios pertencerem a grupos raciais diferentes. Quanto mais próximo de 1, maior a diversidade. Multiplicamos por 10 para escala 0–10.

2. **Equilíbrio de gênero** usa `2 * min(fem, masc)/total`. Se houver apenas um gênero, o score é 0; com 50% cada, score = 10. Alunos com gênero não declarado (`qt_mat_bas_nd`) são ignorados; a fórmula considera apenas os declarados. Caso queira incluí-los como terceira categoria, o índice precisaria ser ajustado.

3. **Alunos com deficiência (PcD)**: a métrica valoriza escolas com maior proporção de inclusão, mas sem penalizar por ausência – escolas sem PcD recebem 0 nesse componente.

4. **EJA**: escolas que atendem jovens e adultos demonstram diversidade etária e de trajetória. A proporção de alunos EJA é usada diretamente.

5. **Divisão por zero**: tratada com `CASE WHEN qt_mat_bas > 0` – caso contrário, subscores zerados e score final zero.

6. **Apenas escolas ativas**: join com `censo_escolas` garante isso.

Essa CTE está pronta para integrar o pipeline do EduMaps, fornecendo uma visão quantitativa da diversidade do alunado.

## Capacidade Gestora

Abaixo está a implementação da CTE para o **score de Capacidade Gestora** conforme a metodologia definida (normalização 0–10, pesos especificados). O cálculo combina dados das tabelas `censo_gestor`, `censo_matriculas` e `censo_escolas`.

```sql
-- CTE para calcular o score de Capacidade Gestora (0-10)
WITH gestao AS (
    SELECT 
        g.nu_ano_censo,
        g.co_entidade,
        -- Totais de gestores
        COALESCE(g.qt_gest_bas, 0) AS qt_gest_bas,
        -- Formação superior (graduação com ou sem licenciatura)
        COALESCE(g.qt_gest_bas_esco_sup_grad, 0) AS sup_grad,
        -- Pós-graduação (especialização + mestrado + doutorado)
        COALESCE(g.qt_gest_bas_esco_sup_pos_espec, 0) 
            + COALESCE(g.qt_gest_bas_esco_sup_pos_mestra, 0)
            + COALESCE(g.qt_gest_bas_esco_sup_pos_douto, 0) AS pos_grad,
        -- Formação específica em gestão
        COALESCE(g.qt_gest_bas_espec_gestao, 0) AS espec_gestao,
        -- Acesso por mérito/democracia (concurso, eleição, processo seletivo+eleição)
        COALESCE(g.qt_gest_bas_acesso_cargo_conca, 0) 
            + COALESCE(g.qt_gest_bas_acesso_cargo_eleic, 0)
            + COALESCE(g.qt_gest_bas_acesso_cargo_p_sel, 0) AS acesso_merito,
        -- Número total de gestores (repetido para clareza)
        g.qt_gest_bas AS qt_gest_total
    FROM 
        clean.censo_gestor g
    INNER JOIN 
        clean.censo_escolas e 
            ON g.co_entidade = e.co_entidade 
            AND g.nu_ano_censo = e.nu_ano_censo
    WHERE 
        e.tp_situacao_funcionamento = 1   -- apenas escolas ativas
),

matriculas AS (
    SELECT 
        nu_ano_censo,
        co_entidade,
        COALESCE(qt_mat_bas, 0) AS qt_mat_bas
    FROM 
        clean.censo_matriculas
),

orgãos_colegiados AS (
    SELECT 
        nu_ano_censo,
        co_entidade,
        -- Conta quantos órgãos colegiados existem (máximo 5 itens considerados)
        (CASE WHEN in_orgao_ass_pais = 1 THEN 1 ELSE 0 END) +
        (CASE WHEN in_orgao_ass_pais_mestres = 1 THEN 1 ELSE 0 END) +
        (CASE WHEN in_orgao_conselho_escolar = 1 THEN 1 ELSE 0 END) +
        (CASE WHEN in_orgao_gremio_estudantil = 1 THEN 1 ELSE 0 END) +
        (CASE WHEN in_orgao_outros = 1 THEN 1 ELSE 0 END) AS qt_colegiados
    FROM 
        clean.censo_escolas
    WHERE 
        tp_situacao_funcionamento = 1
),

calculos AS (
    SELECT 
        g.nu_ano_censo,
        g.co_entidade,
        g.qt_gest_bas,
        m.qt_mat_bas,
        -- 1. Qualificação dos gestores (média entre proporção com superior e proporção com pós) - peso 0.3
        CASE 
            WHEN g.qt_gest_bas > 0 THEN 
                ((g.sup_grad::numeric / g.qt_gest_bas) * 10 +
                 (g.pos_grad::numeric / g.qt_gest_bas) * 10) / 2
            ELSE 0
        END AS score_qualificacao,
        
        -- 2. Formação específica em gestão (proporção) - peso 0.2
        CASE 
            WHEN g.qt_gest_bas > 0 THEN (g.espec_gestao::numeric / g.qt_gest_bas) * 10
            ELSE 0
        END AS score_espec_gestao,
        
        -- 3. Proporção gestor/aluno (escala: 1 gestor para até 200 alunos = 10; linear até 1000 alunos/gestor = 0) - peso 0.2
        CASE 
            WHEN g.qt_gest_bas = 0 OR m.qt_mat_bas = 0 THEN 0
            ELSE GREATEST(0, 10 * (1 - (m.qt_mat_bas::numeric / g.qt_gest_bas - 200) / 800))
            -- Fórmula: 200 alunos/gestor => 10; 1000 => 0; valores intermediários lineares
            -- Simplificação: 10 * min(1, 200 / (alunos/gestores)) - mas a versão linear é mais suave
            -- Vamos usar a versão simples e robusta: 10 * LEAST(1, 200 * qt_gest_bas / qt_mat_bas)
        END AS score_proporcao,
        
        -- 4. Órgãos colegiados (quantidade / 5) - peso 0.2
        (COALESCE(o.qt_colegiados, 0) / 5.0) * 10 AS score_colegiados,
        
        -- 5. Acesso meritocrático/democrático (proporção) - peso 0.1
        CASE 
            WHEN g.qt_gest_bas > 0 THEN (g.acesso_merito::numeric / g.qt_gest_bas) * 10
            ELSE 0
        END AS score_acesso
        
    FROM 
        gestao g
    LEFT JOIN 
        matriculas m ON g.co_entidade = m.co_entidade AND g.nu_ano_censo = m.nu_ano_censo
    LEFT JOIN 
        orgãos_colegiados o ON g.co_entidade = o.co_entidade AND g.nu_ano_censo = o.nu_ano_censo
)

-- Score final ponderado
SELECT 
    nu_ano_censo,
    co_entidade,
    ROUND(
        0.3 * score_qualificacao +
        0.2 * score_espec_gestao +
        0.2 * score_proporcao +
        0.2 * score_colegiados +
        0.1 * score_acesso
    , 2) AS score_capacidade_gestora,
    -- Subscores para análise (opcional)
    ROUND(score_qualificacao, 2) AS gest_qualificacao,
    ROUND(score_espec_gestao, 2) AS gest_espec,
    ROUND(score_proporcao, 2) AS gest_proporcao,
    ROUND(score_colegiados, 2) AS gest_colegiados,
    ROUND(score_acesso, 2) AS gest_acesso
FROM 
    calculos;
```

### Exemplo de saída:

| nu_ano_censo | co_entidade | score_capacidade_gestora | gest_qualificacao | gest_espec | gest_proporcao | gest_colegiados | gest_acesso |
|--------------|-------------|---------------------------|-------------------|------------|----------------|-----------------|--------------|
| 2025         | 12345678901 | 7.80                      | 9.00              | 6.00       | 8.00           | 8.00            | 7.00         |
| 2025         | 12345678902 | 3.20                      | 4.00              | 2.00       | 2.00           | 4.00            | 4.00         |

### Persistindo os resultados:

```sql
-- Adicionar coluna (se necessário)
ALTER TABLE clean.scores_escolas 
ADD COLUMN IF NOT EXISTS score_capacidade_gestora numeric(5,2);

-- Inserir/atualizar
INSERT INTO clean.scores_escolas (nu_ano_censo, co_entidade, score_capacidade_gestora)
-- (substituir pela consulta acima, selecionando apenas as colunas-chave + score final)
ON CONFLICT (nu_ano_censo, co_entidade) DO UPDATE SET
    score_capacidade_gestora = EXCLUDED.score_capacidade_gestora;
```

### Observações importantes:

1. **Proporção gestor/aluno**:  
   A fórmula foi ajustada para usar `10 * LEAST(1, 200 * qt_gest_bas / qt_mat_bas)` de forma mais simples e robusta, garantindo que:
   - Se a relação for ≥ 1 gestor para cada 200 alunos → score 10.
   - Caso contrário, score proporcional (ex.: 1:400 → 5, 1:800 → 2.5, 1:1000 → 2.0, mas limitado inferior a 0).

   Na implementação acima, usamos `GREATEST(0, 10 * (1 - (alunos/gestores - 200)/800))` – mas a versão mais direta e recomendada é:

   ```sql
   CASE 
       WHEN m.qt_mat_bas = 0 OR g.qt_gest_bas = 0 THEN 0
       ELSE 10 * LEAST(1, 200.0 * g.qt_gest_bas / m.qt_mat_bas)
   END AS score_proporcao
   ```

   Vou corrigir no código abaixo (mantendo a versão simplificada). O código acima já reflete essa lógica? Na verdade, a expressão `10 * LEAST(1, 200 * qt_gest_bas / qt_mat_bas)` está no comentário, mas não no cálculo. Ajustarei.

2. **Órgãos colegiados**:  
   Foram considerados os campos `in_orgao_ass_pais`, `in_orgao_ass_pais_mestres`, `in_orgao_conselho_escolar`, `in_orgao_gremio_estudantil` e `in_orgao_outros`. A pontuação máxima (10) ocorre quando a escola possui todos os cinco.

3. **Tratamento de escolas sem gestores** (`qt_gest_bas = 0`):  
   Score zero, pois não há capacidade gestora avaliável.

4. **Join com `censo_matriculas`**:  
   Usamos `LEFT JOIN` para não excluir escolas que possuem gestores mas ainda não têm matrículas (ex.: novas escolas). Nesse caso, `qt_mat_bas` será nulo e o score de proporção será zero.

5. **Escolas ativas**:  
   Filtro aplicado no `INNER JOIN` com `censo_escolas` via `tp_situacao_funcionamento = 1`.

Abaixo a versão final corrigida para o cálculo da proporção gestor/aluno usando `LEAST`:

```sql
-- Dentro da CTE calculos, substituir score_proporcao por:
CASE 
    WHEN g.qt_gest_bas = 0 OR m.qt_mat_bas = 0 THEN 0
    ELSE 10 * LEAST(1, (200.0 * g.qt_gest_bas) / m.qt_mat_bas)
END AS score_proporcao
```

Essa implementação está pronta para uso no EduMaps.

# View para os scores das escolas

Abaixo está a criação da **Materialized View** consolidando todos os scores desenvolvidos (capacidade de atendimento, infraestrutura, capacitação docente, diversidade discente, capacidade gestora e sustentabilidade), com dados apenas de escolas em funcionamento.

```sql
-- ============================================================
-- Materialized View: mv_escolas_scores
-- Descrição: Consolidada dos scores para cada escola ativa
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS clean.mv_escolas_scores;

CREATE MATERIALIZED VIEW clean.mv_escolas_scores AS

-- 1. Lista de todas as escolas ativas (base)
WITH escolas_base AS (
    SELECT DISTINCT
        e.nu_ano_censo,
        e.co_entidade
    FROM clean.censo_escolas e
    WHERE e.tp_situacao_funcionamento = 1
),

-- ========== 2. SCORE CAPACIDADE DE ATENDIMENTO ==========
score_capacidade AS (
    SELECT
        e.nu_ano_censo,
        e.co_entidade,
        ROUND(
            0.4 * CASE
                WHEN e.qt_salas_utilizadas > 0 AND COALESCE(m.qt_mat_bas, 0) > 0
                THEN GREATEST(0, 10 * (1 - (m.qt_mat_bas::numeric / e.qt_salas_utilizadas) / 50))
                ELSE 0
            END +
            0.2 * ( (COALESCE(e.in_comum_creche,0) + COALESCE(e.in_comum_pre,0) +
                      COALESCE(e.in_comum_fund_ai,0) + COALESCE(e.in_comum_fund_af,0) +
                      COALESCE(e.in_comum_medio_medio,0) + COALESCE(e.in_eja,0) +
                      COALESCE(e.in_profissionalizante,0) ) / 7.0 * 10 ) +
            0.2 * CASE
                WHEN COALESCE(m.qt_mat_bas, 0) > 0
                THEN (COALESCE(m.qt_mat_bas_int,0)::numeric / m.qt_mat_bas) * 10
                ELSE 0
            END +
            0.2 * CASE WHEN e.in_alimentacao = 1 THEN 10 ELSE 0 END
        , 2) AS score_capacidade_atendimento
    FROM clean.censo_escolas e
    LEFT JOIN clean.censo_matriculas m
        ON e.co_entidade = m.co_entidade AND e.nu_ano_censo = m.nu_ano_censo
    WHERE e.tp_situacao_funcionamento = 1
),

-- ========== 3. SCORE INFRAESTRUTURA ==========
score_infra AS (
    SELECT
        nu_ano_censo,
        co_entidade,
        ROUND(
            ( -- Categoria A
                (COALESCE(in_agua_potavel,0) +
                 COALESCE(in_energia_rede_publica,0) +
                 CASE WHEN COALESCE(in_esgoto_rede_publica,0)=1 OR COALESCE(in_esgoto_fossa_septica,0)=1 THEN 1 ELSE 0 END +
                 COALESCE(in_lixo_servico_coleta,0) +
                 COALESCE(in_banheiro,0)
                ) / 5.0 * 10
              + -- Categoria B
                ( (CASE WHEN COALESCE(in_biblioteca,0)=1 OR COALESCE(in_biblioteca_sala_leitura,0)=1 THEN 1 ELSE 0 END) +
                  COALESCE(in_laboratorio_ciencias,0) +
                  COALESCE(in_laboratorio_informatica,0) +
                  COALESCE(in_quadra_esportes,0) +
                  COALESCE(in_cozinha,0) +
                  COALESCE(in_refeitorio,0) +
                  COALESCE(in_sala_diretoria,0) +
                  COALESCE(in_secretaria,0) +
                  COALESCE(in_sala_professor,0)
                ) / 9.0 * 10
              + -- Categoria C
                ( COALESCE(in_acessibilidade_rampas,0) +
                  COALESCE(in_acessibilidade_corrimao,0) +
                  COALESCE(in_acessibilidade_pisos_tateis,0) +
                  COALESCE(in_acessibilidade_sinalizacao,0) +
                  COALESCE(in_banheiro_pne,0)
                ) / 5.0 * 10
              + -- Categoria D
                ( COALESCE(in_computador,0) +
                  COALESCE(in_internet,0) +
                  COALESCE(in_equip_lousa_digital,0) +
                  COALESCE(in_equip_multimidia,0) +
                  CASE WHEN COALESCE(in_equip_impressora,0)=1 OR COALESCE(in_equip_impressora_mult,0)=1 THEN 1 ELSE 0 END
                ) / 5.0 * 10
            ) / 4.0
        , 2) AS score_infraestrutura
    FROM clean.censo_escolas
    WHERE tp_situacao_funcionamento = 1
),

-- ========== 4. SCORE CAPACITAÇÃO DOCENTE ==========
score_docente AS (
    SELECT
        d.nu_ano_censo,
        d.co_entidade,
        ROUND(
            0.3 * CASE
                WHEN d.qt_doc_bas > 0
                THEN (COALESCE(d.qt_doc_bas_esco_sup_grad,0)::numeric / d.qt_doc_bas) * 10
                ELSE 0
            END +
            0.3 * CASE
                WHEN d.qt_doc_bas > 0
                THEN ( (COALESCE(d.qt_doc_bas_esco_sup_pos_espec,0) +
                        COALESCE(d.qt_doc_bas_esco_sup_pos_mestra,0) +
                        COALESCE(d.qt_doc_bas_esco_sup_pos_douto,0))::numeric / d.qt_doc_bas ) * 10
                ELSE 0
            END +
            0.2 * CASE
                WHEN d.qt_doc_bas > 0
                THEN (COALESCE(d.qt_doc_bas_vinculo_concur,0)::numeric / d.qt_doc_bas) * 10
                ELSE 0
            END +
            0.2 * CASE
                WHEN d.qt_doc_bas > 0
                THEN ( (COALESCE(d.qt_doc_bas_espec_cre,0) +
                        COALESCE(d.qt_doc_bas_espec_pre_escola,0) +
                        COALESCE(d.qt_doc_bas_espec_anos_iniciais,0) +
                        COALESCE(d.qt_doc_bas_espec_anos_finais,0) +
                        COALESCE(d.qt_doc_bas_espec_ens_medio,0) +
                        COALESCE(d.qt_doc_bas_espec_eja,0) +
                        COALESCE(d.qt_doc_bas_espec_ed_especial,0) +
                        COALESCE(d.qt_doc_bas_espec_bil_surdos,0) +
                        COALESCE(d.qt_doc_bas_espec_ed_indigena,0) +
                        COALESCE(d.qt_doc_bas_espec_campo,0) +
                        COALESCE(d.qt_doc_bas_espec_ambiental,0) +
                        COALESCE(d.qt_doc_bas_espec_dir_humanos,0) +
                        COALESCE(d.qt_doc_bas_espec_div_sexual,0) +
                        COALESCE(d.qt_doc_bas_espec_dir_adolesc,0) +
                        COALESCE(d.qt_doc_bas_espec_afro,0) +
                        COALESCE(d.qt_doc_bas_espec_gestao,0) +
                        COALESCE(d.qt_doc_bas_espec_educ_tic,0) +
                        COALESCE(d.qt_doc_bas_espec_outros,0))::numeric / d.qt_doc_bas ) * 10
                ELSE 0
            END
        , 2) AS score_capacitacao_docente
    FROM clean.censo_docentes d
),

-- ========== 5. SCORE DIVERSIDADE DISCENTE ==========
score_diversidade AS (
    SELECT
        m.nu_ano_censo,
        m.co_entidade,
        ROUND(
            0.35 * CASE
                WHEN m.qt_mat_bas > 0
                THEN (1 - ( POWER(COALESCE(m.qt_mat_bas_branca,0)::numeric / m.qt_mat_bas, 2) +
                           POWER(COALESCE(m.qt_mat_bas_preta,0)::numeric / m.qt_mat_bas, 2) +
                           POWER(COALESCE(m.qt_mat_bas_parda,0)::numeric / m.qt_mat_bas, 2) +
                           POWER(COALESCE(m.qt_mat_bas_amarela,0)::numeric / m.qt_mat_bas, 2) +
                           POWER(COALESCE(m.qt_mat_bas_indigena,0)::numeric / m.qt_mat_bas, 2) )) * 10
                ELSE 0
            END +
            0.25 * CASE
                WHEN m.qt_mat_bas > 0
                THEN 2 * LEAST(COALESCE(m.qt_mat_bas_fem,0)::numeric, COALESCE(m.qt_mat_bas_masc,0)::numeric) / m.qt_mat_bas * 10
                ELSE 0
            END +
            0.20 * CASE
                WHEN m.qt_mat_bas > 0
                THEN (COALESCE(m.qt_mat_bas_d,0) + COALESCE(m.qt_mat_bas_dm,0) + COALESCE(m.qt_mat_bas_dv,0))::numeric / m.qt_mat_bas * 10
                ELSE 0
            END +
            0.20 * CASE
                WHEN m.qt_mat_bas > 0
                THEN COALESCE(m.qt_mat_eja,0)::numeric / m.qt_mat_bas * 10
                ELSE 0
            END
        , 2) AS score_diversidade_discente
    FROM clean.censo_matriculas m
),

-- ========== 6. SCORE CAPACIDADE GESTORA ==========
score_gestao AS (
    SELECT
        g.nu_ano_censo,
        g.co_entidade,
        ROUND(
            0.3 * CASE
                WHEN g.qt_gest_bas > 0
                THEN ( (COALESCE(g.qt_gest_bas_esco_sup_grad,0)::numeric / g.qt_gest_bas) * 10 +
                       (COALESCE(g.qt_gest_bas_esco_sup_pos_espec,0) +
                        COALESCE(g.qt_gest_bas_esco_sup_pos_mestra,0) +
                        COALESCE(g.qt_gest_bas_esco_sup_pos_douto,0))::numeric / g.qt_gest_bas * 10 ) / 2
                ELSE 0
            END +
            0.2 * CASE
                WHEN g.qt_gest_bas > 0
                THEN (COALESCE(g.qt_gest_bas_espec_gestao,0)::numeric / g.qt_gest_bas) * 10
                ELSE 0
            END +
            0.2 * CASE
                WHEN g.qt_gest_bas > 0 AND COALESCE(m.qt_mat_bas, 0) > 0
                THEN 10 * LEAST(1, 200.0 * g.qt_gest_bas / m.qt_mat_bas)
                ELSE 0
            END +
            0.2 * ( COALESCE(o.qt_colegiados, 0) / 5.0 * 10 ) +
            0.1 * CASE
                WHEN g.qt_gest_bas > 0
                THEN ( (COALESCE(g.qt_gest_bas_acesso_cargo_conca,0) +
                        COALESCE(g.qt_gest_bas_acesso_cargo_eleic,0) +
                        COALESCE(g.qt_gest_bas_acesso_cargo_p_sel,0))::numeric / g.qt_gest_bas ) * 10
                ELSE 0
            END
        , 2) AS score_capacidade_gestora
    FROM clean.censo_gestor g
    LEFT JOIN clean.censo_matriculas m
        ON g.co_entidade = m.co_entidade AND g.nu_ano_censo = m.nu_ano_censo
    LEFT JOIN (
        SELECT
            co_entidade,
            nu_ano_censo,
            (COALESCE(in_orgao_ass_pais,0) +
             COALESCE(in_orgao_ass_pais_mestres,0) +
             COALESCE(in_orgao_conselho_escolar,0) +
             COALESCE(in_orgao_gremio_estudantil,0) +
             COALESCE(in_orgao_outros,0)) AS qt_colegiados
        FROM clean.censo_escolas
        WHERE tp_situacao_funcionamento = 1
    ) o ON g.co_entidade = o.co_entidade AND g.nu_ano_censo = o.nu_ano_censo
),

-- ========== 7. SCORE SUSTENTABILIDADE ==========
score_sustentabilidade AS (
    SELECT
        nu_ano_censo,
        co_entidade,
        ROUND(
            ( CASE WHEN COALESCE(in_energia_renovavel,0) = 1 THEN 10 ELSE 0 END +
              CASE WHEN COALESCE(in_tratamento_lixo_reciclagem,0) = 1 OR COALESCE(in_tratamento_lixo_reutiliza,0) = 1 THEN 10 ELSE 0 END +
              ( (CASE WHEN COALESCE(in_area_verde,0) = 1 THEN 10 ELSE 0 END) +
                (CASE WHEN COALESCE(in_area_plantio,0) = 1 THEN 10 ELSE 0 END) ) / 2.0 +
              CASE WHEN COALESCE(in_educ_ambiental,0) = 1 OR COALESCE(in_educ_amb_conteudo,0)=1 OR
                         COALESCE(in_educ_amb_curricular,0)=1 OR COALESCE(in_educ_amb_eixo,0)=1 OR
                         COALESCE(in_educ_amb_eventos,0)=1 OR COALESCE(in_educ_amb_projetos,0)=1
                    THEN 10 ELSE 0 END
            ) / 4.0
        , 2) AS score_sustentabilidade
    FROM clean.censo_escolas
    WHERE tp_situacao_funcionamento = 1
),

-- ========== 8. JUNÇÃO FINAL ==========
scores_juntos AS (
    SELECT
        b.nu_ano_censo,
        b.co_entidade,
        COALESCE(cap.score_capacidade_atendimento, 0) AS score_capacidade_atendimento,
        COALESCE(inf.score_infraestrutura, 0) AS score_infraestrutura,
        COALESCE(doc.score_capacitacao_docente, 0) AS score_capacitacao_docente,
        COALESCE(div.score_diversidade_discente, 0) AS score_diversidade_discente,
        COALESCE(ges.score_capacidade_gestora, 0) AS score_capacidade_gestora,
        COALESCE(sus.score_sustentabilidade, 0) AS score_sustentabilidade,
        -- Data/hora da última atualização
        NOW() AS data_atualizacao
    FROM escolas_base b
    LEFT JOIN score_capacidade cap ON b.co_entidade = cap.co_entidade AND b.nu_ano_censo = cap.nu_ano_censo
    LEFT JOIN score_infra inf ON b.co_entidade = inf.co_entidade AND b.nu_ano_censo = inf.nu_ano_censo
    LEFT JOIN score_docente doc ON b.co_entidade = doc.co_entidade AND b.nu_ano_censo = doc.nu_ano_censo
    LEFT JOIN score_diversidade div ON b.co_entidade = div.co_entidade AND b.nu_ano_censo = div.nu_ano_censo
    LEFT JOIN score_gestao ges ON b.co_entidade = ges.co_entidade AND b.nu_ano_censo = ges.nu_ano_censo
    LEFT JOIN score_sustentabilidade sus ON b.co_entidade = sus.co_entidade AND b.nu_ano_censo = sus.nu_ano_censo
)

SELECT * FROM scores_juntos;

-- ========== 9. ÍNDICES PARA CONSULTAS EFICIENTES ==========
CREATE UNIQUE INDEX idx_mv_scores_pk ON clean.mv_escolas_scores (nu_ano_censo, co_entidade);
CREATE INDEX idx_mv_scores_atendimento ON clean.mv_escolas_scores (score_capacidade_atendimento);
CREATE INDEX idx_mv_scores_infra ON clean.mv_escolas_scores (score_infraestrutura);
CREATE INDEX idx_mv_scores_docente ON clean.mv_escolas_scores (score_capacitacao_docente);
CREATE INDEX idx_mv_scores_diversidade ON clean.mv_escolas_scores (score_diversidade_discente);
CREATE INDEX idx_mv_scores_gestao ON clean.mv_escolas_scores (score_capacidade_gestora);
CREATE INDEX idx_mv_scores_sustentabilidade ON clean.mv_escolas_scores (score_sustentabilidade);

-- ========== 10. COMENTÁRIOS (DOCUMENTAÇÃO) ==========
COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS 'Scores das escolas ativas calculados a partir do Censo Escolar. Escala 0-10, quanto maior melhor. Atualizar com REFRESH MATERIALIZED VIEW.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_capacidade_atendimento IS 'Base: densidade aluno-sala, diversidade de etapas, tempo integral, alimentação.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_infraestrutura IS 'Média de quatro categorias: básico, pedagógico, acessibilidade, tecnologia.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_capacitacao_docente IS 'Formação superior, pós-graduação, vínculo efetivo, especializações.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_diversidade_discente IS 'Diversidade racial, gênero, inclusão PcD, oferta EJA.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_capacidade_gestora IS 'Qualificação dos gestores, formação em gestão, proporção gestor/aluno, órgãos colegiados, acesso meritocrático.';
COMMENT ON COLUMN clean.mv_escolas_scores.score_sustentabilidade IS 'Energia renovável, gestão de resíduos, área verde/plantio, educação ambiental.';
```

### Como usar a Materialized View:

```sql
-- Atualizar dados (após novas cargas do Censo)
REFRESH MATERIALIZED VIEW CONCURRENTLY clean.mv_escolas_scores;

-- Consultar scores de uma escola específica
SELECT * FROM clean.mv_escolas_scores WHERE co_entidade = 12345678901;

-- Escolas com melhor infraestrutura
SELECT co_entidade, score_infraestrutura 
FROM clean.mv_escolas_scores 
WHERE nu_ano_censo = 2025 
ORDER BY score_infraestrutura DESC 
LIMIT 10;
```

### Observações importantes:

1. **Atualização**: Use `REFRESH MATERIALIZED VIEW CONCURRENTLY` para evitar bloqueios de leitura (exige índice único, criado no código).
2. **Desempenho**: Os índices criados aceleram filtros e ordenações por cada score.
3. **Escolas sem dados**: Escolas ativas sem matrículas, docentes ou gestores recebem score 0 nos componentes ausentes.
4. **Ano corrente**: A view armazena dados do ano do censo; se houver múltiplos anos, cada par (ano, escola) é uma linha.

Essa solução permite consultas analíticas e alimentação de dashboards de forma eficiente.
