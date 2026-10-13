# Dicionários de referência (`data_pipeline/dicionarios/`)

## `censo_inep_variaveis.csv` — Dicionário de Variáveis do Censo Escolar (INEP)

Conversão em CSV do **"Dicionário de Variáveis"** oficial do INEP, o Anexo I
dos microdados do Censo Escolar da Educação Básica 2025
(`dicionário_dados_educação_básica.xlsx`). É a fonte de verdade do dicionário
canônico do banco (`clean.censo_data_dictionary`, issue #134).

| | |
|---|---|
| Fonte | INEP — Microdados do Censo Escolar 2025, "ANEXO I - Dicionário de Dados" |
| Página | <https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar> |
| Cópia local | Zotero, anexo **10296** (key **ICPJZK6R**), adicionado em 2026-05-08 |
| SHA-256 do xlsx | `26969843532e11ba9493682823958e1177067eb1ad86bddc30656bfab1a2d5ce` |
| Extração | 2026-10-13, por `tools/censo-dicionario/gerar.py` |
| Licença | Material de referência público do INEP (dados abertos). O xlsx **não** entra no repositório; só esta conversão. |

### Conteúdo

Uma linha por **aba × variável**, todas as 6 abas do xlsx (1.052 linhas):
Escola (367), Matricula (239), Docente (158), Turma (192), Gestor (65),
CursoTecnico (31). As 4 primeiras de interesse do EduMaps alimentam a migration;
Turma e CursoTecnico ficam só como referência.

| Coluna | Conteúdo |
|---|---|
| `aba` | `Escola`, `Matricula`, `Docente`, `Turma`, `Gestor`, `CursoTecnico` |
| `variavel` | nome da variável, em minúsculas (como no banco) |
| `descricao` | descrição do INEP (espaços normalizados) |
| `tipo`, `tamanho` | `Num`/`Char` e tamanho, como no INEP |
| `categorias` | JSON `{"código":"rótulo"}`, vazio quando não há. Inclui as categorias que o INEP só cita nas notas (`Existe adicionalmente a categoria "9 - Não informado"`). |
| `nao_aplicavel` | texto das linhas `- Não aplicável…` (o significado de NULL) |
| `anos_coletados` | faixas de anos com `s`, ex.: `2007-2011,2014-2025` |
| `ano_inicio`, `ano_fim` | primeiro e último ano coletado; `ano_fim` vazio = coletada no último ano da aba (2025; 2024 na aba CursoTecnico, que não tem coluna 2025) |
| `notas` | "Notas Importantes" do INEP (mudanças de nome/código). Quando a coluna Categoria tem só texto livre (ex.: "Educação Profissional Não-Técnica"), ele vem aqui prefixado por `Categoria (INEP):`. |

O CSV é **fiel ao xlsx**. Os ajustes do EduMaps (nomes de coluna diferentes do
INEP, códigos que aparecem nos microdados mas faltam no dicionário, colunas
derivadas) ficam em `tools/censo-dicionario/gerar.py` (`APELIDOS`,
`COMPLEMENTOS`, `DERIVADAS`) e entram só na migration.

### Regenerar

```bash
# CSV (todas as abas) + deploy da migration
python3 tools/censo-dicionario/gerar.py <caminho>/dicionário_dados_educação_básica.xlsx \
    --saida data_pipeline/dicionarios \
    --sql data_pipeline/deploy/censo_data_dictionary_inep.sql

# só o deploy, a partir do CSV versionado (sem o xlsx)
python3 tools/censo-dicionario/gerar.py --csv data_pipeline/dicionarios/censo_inep_variaveis.csv \
    --sql data_pipeline/deploy/censo_data_dictionary_inep.sql

# testes do gerador
python3 -m unittest discover -s tools/censo-dicionario/t -v
```

A saída é determinística. **Atenção**: a change `censo_data_dictionary_inep`
já deployada não pode ser regenerada com conteúdo diferente; uma edição nova
do INEP (Censo 2026) entra numa change **nova** no fim do `sqitch.plan` (ver
`AGENTS.md`, seção Database).
