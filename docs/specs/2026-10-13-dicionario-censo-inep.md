# Dicionário do Censo a partir do dicionário oficial do INEP (#134, conclusão)

**Issue:** #134 · **Data:** 2026-10-13 · **Branch:** `feat/dicionario-censo-inep`
**Follow-up:** #228 (rótulos duplicados no backend, SQL e R passam a ler do
dicionário).

## Estado de partida (conferência de 2026-10-13)

- **Entregue em parte.** O PR #140 criou `clean.censo_data_dictionary` com
  765 colunas das 4 tabelas, mas o seed é **estático**: um CTE "YAML curado"
  que não existe, com `year_introduced = 2025` em todas as linhas.
- **Só 15 colunas têm domínio, e a maioria está errada:**
  - `tp_aee`, `tp_atividade_complementar` e `tp_itinerario_formativo` são, na
    verdade, 0/1/2;
  - `tp_regulamentacao` significa Não/Sim/Em tramitação, e não esfera de
    governo;
  - faltam os códigos **9 = Não informado**;
  - `tp_localizacao_diferenciada` e `tp_poder_publico_parceria` têm rótulos
    errados.

  O banco de dev e as fixtures do CI já têm códigos fora desses domínios.
- **A validação nunca falha:**
  - `censo_dict_validate` compara nomes com schema contra nomes sem schema;
  - o verify usa `SELECT` em vez de `RAISE`;
  - o teste Perl só emite `pass`;
  - os testes R não rodam no CI.
- **Funções R com `@export`,** mas o NAMESPACE não foi regenerado.
- **Rótulos errados chegam ao LLM** pelo `inst/chat/dicionario.yml`
  (`codificacoes` e a descrição de `tp_aee`/`tp_situacao_funcionamento`/
  `tp_localizacao_diferenciada`).
- **Fonte oficial disponível localmente:** o anexo Zotero 10296 (key
  ICPJZK6R), `dicionário_dados_educação_básica.xlsx`, é o "Dicionário de
  Variáveis" do INEP com as abas Escola, Matrícula, Docente, Turma, Gestor e
  Curso Técnico.
  - Coluna F = categorias, no formato `"código - rótulo"` por linha.
  - Colunas G..Y = coletada em 2007..2025 (`s`/`n`).
  - Coluna Z = notas de mudança.

## Decisões (developer, 2026-10-13)

1. **Fonte:** o dicionário oficial do INEP, convertido num **CSV canônico
   versionado** no repositório. O xlsx não entra; o CSV registra a fonte, a
   data e a chave Zotero.
2. **Escopo:** completar a #134 e **corrigir o `dicionario.yml` do chat**. Os
   rótulos duplicados no restante do app ficam para a #228.

## Contrato

### Gerador e CSV

- `tools/censo-dicionario/gerar.py`: Python **só com a stdlib**, lendo o xlsx
  por `zipfile` + XML. Uso:
  `python3 tools/censo-dicionario/gerar.py <xlsx> [--saida data_pipeline/dicionarios]`.
  É determinístico, e há testes em `tools/censo-dicionario/t/` (unittest).
- **Saída:** `data_pipeline/dicionarios/censo_inep_variaveis.csv` (UTF-8,
  separador `,`, aspas RFC 4180), com as colunas:
  - `aba` (Escola|Matricula|Docente|Gestor|…);
  - `variavel` (minúscula);
  - `descricao`;
  - `tipo` (Num|Char), `tamanho`;
  - `categorias` (JSON `{"código":"rótulo"}`; vazio quando não há);
  - `nao_aplicavel` (texto da linha "- Não aplicável…", se houver);
  - `anos_coletados` (ex.: `2007-2011,2014-2025`);
  - `ano_inicio`, `ano_fim` (fim vazio = ainda coletada em 2025);
  - `notas`.
- `data_pipeline/dicionarios/README.md` registra a proveniência: INEP,
  "Dicionário de Variáveis", Zotero 10296 / ICPJZK6R, data de extração, como
  regenerar e o aviso de que é material de referência público do INEP.

### Migration nova `censo_data_dictionary_inep [censo_data_dictionary]` (no fim do plano)

- **Coluna nova** `origem text NOT NULL DEFAULT 'inep' CHECK (origem IN
  ('inep','derivada'))`. Colunas criadas pelo EduMaps (`linha_id`,
  `geometry`, `cluster_id`, `nro_etapas`, `nro_participacoes_exame`,
  `latitude`, `longitude` e outras sem correspondência no INEP) ficam
  `derivada`.
- **Atualização a partir do CSV:** o deploy é **gerado pelo script**
  (`--sql`), com os dados embutidos em `INSERT … VALUES` + `UPDATE … FROM`.
  Para cada coluna das 4 tabelas que existe no INEP (mapa: aba Escola →
  `clean.censo_escolas`, Matricula → `clean.censo_matriculas`, Docente →
  `clean.censo_docentes`, Gestor → `clean.censo_gestor`):
  - `description` = descrição do INEP;
  - `value_domain` = categorias, com `"9"` quando o INEP define;
  - `year_introduced` = `ano_inicio`, `year_deprecated` = `ano_fim`;
  - `notes` = notas do INEP;
  - `source_*` = o dicionário INEP.

  Sem correspondência no INEP: `origem='derivada'` e uma nota explicativa.
  As colunas `in_*` sem categoria no INEP recebem
  `{"0":"Não","1":"Sim"}` quando o INEP as define como binárias; senão, nota.
- **Função** `clean.censo_dict_violacoes()` →
  `TABLE(tipo text, tabela text, coluna text, valor text, n bigint)`. Os
  tipos são:
  - `coluna_sem_dicionario`: coluna real das 4 tabelas ausente do
    dicionário;
  - `codigo_fora_do_dominio`: valor distinto não nulo de uma coluna com
    `value_domain` que não é chave do domínio;
  - `binaria_invalida`: coluna `in_*` com valor fora de {0,1}.
- **Verify em gate** (`DO $$ … RAISE EXCEPTION`):
  - a coluna `origem` existe;
  - a função existe;
  - nenhuma `coluna_sem_dicionario`.

  `codigo_fora_do_dominio` **não** entra no verify, para não travar o deploy
  por causa de dados; é responsabilidade do teste e da carga.

### Gate do build

- **Perl** `backend/t/02-models/censo_dictionary.t` (reescrito): roda no CI
  sobre as fixtures e exige `clean.censo_dict_violacoes()` **vazia**. Um
  código novo ou uma coluna nova **quebra o build**. Cobre também o domínio
  correto de alguns códigos-chave (tp_aee, tp_regulamentacao,
  tp_dependencia, tp_localizacao_diferenciada, o 9 = Não informado).
- **Dev:** em `edumaps_dev` (dados reais de 2025), a função também precisa
  voltar vazia, conferido no e2e.

### R (edumapsr)

- `censo_dict_validate()` corrigido:
  - usa a função `clean.censo_dict_violacoes()` quando ela existe; senão,
    consulta corrigida por `table_schema` + `table_name`;
  - devolve as violações e falha (`ok = FALSE`) quando há alguma.
- **Exports** (`censo_dictionary`, `censo_dict_filter`, `censo_dict_domain`,
  `censo_dict_validate` e os métodos S3 `print`/`summary`) no NAMESPACE, com
  as páginas `man/`.
- **`inst/chat/dicionario.yml`:**
  - corrigir os rótulos errados;
  - remover as `codificacoes` duplicadas que o dicionário canônico já cobre,
    ou alinhá-las ao INEP;
  - manter o caminho existente em `chat-dictionary.R` (prefere
    `censo_dictionary()`).
- Versão `edumapsAnalytics` 0.3.2 + `analytics_source_version` 0.3.2.

## WBS

| ID | Trilha | Escopo |
|----|--------|--------|
| D1 | T-D | Gerador Python + testes + CSV + README de proveniência |
| D2 | T-D | Migration (coluna `origem`, carga do CSV, função de violações, verify em gate) |
| D3 | T-D | Teste Perl do gate + fixtures coerentes |
| R1 | T-R | `censo_dict_validate`, exports/man, `dicionario.yml` do chat, versão |
| C | coord. | Verificação, deploy (db, analytics), e2e em dev (violações = 0 nos dados reais), docs, PR |
