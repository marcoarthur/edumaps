# Fuzzy Matching RENAEST → Município IBGE

Script para completar o de-para `clean.renaest_localidade_municipio` usando fuzzy matching.

## Dependências

```bash
pip install -r requirements.txt
```

## Uso

### Opção 1: Carregar localidades de CSV
```bash
python fuzzy_match_renaest.py \
  --input-csv renaest_localidades.csv \
  --output-csv renaest_matches.csv \
  --pg-host localhost \
  --pg-db edumaps_dev \
  --pg-user devel \
  --pg-password senhaboa123 \
  --threshold 70 \
  --limit 3
```

### Opção 2: Carregar localidades da tabela `renaest_sinistro` (padrão)
```bash
python fuzzy_match_renaest.py \
  --output-csv renaest_matches.csv \
  --pg-host localhost \
  --pg-db edumaps_dev \
  --pg-user devel \
  --pg-password senhaboa123 \
  --threshold 70 \
  --limit 3
```

### Parâmetros

| Parâmetro | Descrição | Padrão |
|-----------|-----------|--------|
| `--input-csv` | CSV com localidades RENAEST (colunas: localidade, uf) | - |
| `--output-csv` | CSV de saída com matches | `renaest_matches.csv` |
| `--pg-host` | Host PostgreSQL | localhost |
| `--pg-port` | Porta PostgreSQL | 5432 |
| `--pg-db` | Database PostgreSQL | edumaps_dev |
| `--pg-user` | Usuário PostgreSQL | devel |
| `--pg-password` | Senha PostgreSQL | senhaboa123 |
| `--threshold` | Threshold fuzzy match (0-100) | 70 |
| `--limit` | Limite de matches por localidade | 3 |

## Formato do CSV de Entrada

```csv
localidade,uf
São Paulo,SP
Campinas,SP
Rio de Janeiro,RJ
```

## Formato do CSV de Saída

```csv
localidade_renaest,uf,codigo_ibge,municipio_ibge,match_type,match_score,notes
"São Paulo","SP","3550308","São Paulo",exact,100,
"Campinas","SP","3509502","Campinas",exact,100,
"Sao Paulo","SP","3550308","São Paulo",fuzzy,95,"Top 3 matches; best: São Paulo (100)"
```

## Match Types

| Tipo | Descrição | Score |
|-------|-----------|-------|
| `exact` | Match exato (nome normalizado + UF igual) | 100 |
| `fuzzy` | Fuzzy matching (rapidfuzz ratio) | 70-99 |
| `none` | Sem match encontrado | 0 |

## Processo de Revisão

1. Execute o script para gerar `matches.csv`
2. Revise os matches `fuzzy` (score 70-99) - validar/ajustar manualmente
3. Para matches `none`, investigar manualmente
4. Importar matches validados na tabela `clean.renaest_localidade_municipio`

## Importar Matches Validados

```sql
-- Exemplo de importação manual
INSERT INTO clean.renaest_localidade_municipio 
(localidade, uf, codigo_ibge, nome_municipio, match_type, match_score, validated_by, validated_at, dt_snapshot)
VALUES 
  ('Campinas', 'SP', '3509502', 'Campinas', 'exact', 100, 'analista', NOW(), CURRENT_DATE),
  ('Sao Paulo', 'SP', '3550308', 'São Paulo', 'fuzzy', 95, 'analista', NOW(), CURRENT_DATE)
ON CONFLICT (localidade, uf, dt_snapshot) DO NOTHING;
```

## Fuzzy Matching Logic

1. **Match exato** (score 100): nome normalizado + UF igual
2. **Fuzzy matching** (rapidfuzz ratio ≥ 70): 
   - Normaliza: remove acentos, lowercase, remove pontuação
   - Filtra por UF primeiro
   - Ratio ≥ threshold (padrão 70)
   - Retorna top N matches ordenados por score
3. **Sem match**: retorna vazio para revisão manual

## Fuzzy Matching Tuning

| Threshold | Recall | Precision | Uso |
|-----------|--------|-----------|-----|
| 90+ | Baixo | Muito alto | Matches quase certos |
| 80-89 | Médio | Alto | Boa cobertura |
| 70-79 | Alto | Médio | Padrão recomendado |
| <70 | Muito alto | Baixo | Muitos falsos positivos |

Recomendado: **threshold=70, limit=3** para revisão manual.