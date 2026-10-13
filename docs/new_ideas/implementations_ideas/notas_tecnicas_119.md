# Nota técnica 119 — Dicionário do Censo a partir do INEP, com gate no CI (PR #229)

## Resumo

A #134 estava aberta desde 30/09 com o PR #140 entregue em parte. A conferência
de 2026-10-13 mostrou um seed **estático**: um "YAML curado" que não existia e
só 15 domínios, **a maioria errada**. A validação também **nunca falhava**. O PR
#229 (merge `fb1c7ad`) refaz o dicionário a partir do **Dicionário de Variáveis
oficial do INEP**, põe um **gate que quebra o build** e corrige de passagem um
bug do Assistente do Censo, que mandava o prompt **sem nenhuma tabela**.

## Achados que motivaram o desenho

- **Domínios errados:**
  - `tp_aee`, `tp_atividade_complementar` e `tp_itinerario_formativo` são
    0/1/2 (não oferece / não exclusivamente / exclusivamente), não listas de
    salas ou áreas;
  - `tp_regulamentacao` é Não/Sim/Em tramitação, não esfera de governo;
  - faltavam os códigos 9 = Não informado;
  - `tp_localizacao_diferenciada` e `tp_poder_publico_parceria` tinham
    rótulos trocados.

  O banco real e as fixtures já tinham códigos fora desses domínios.
- **Validação que nunca falha:**
  - `censo_dict_validate` comparava `information_schema.table_name` (sem
    schema) com `'clean.censo_escolas'`;
  - o verify usava `SELECT` (o Sqitch só reprova com erro);
  - o teste Perl emitia `pass`;
  - os testes R não rodam no CI.
- **Fonte oficial já disponível:** o anexo Zotero 10296 (o item Z:9892 da
  issue era só um link para uma planilha). Layout da aba Escola:
  - coluna F = categorias `"código - rótulo"`;
  - G..Y = coletada em 2007..2025;
  - Z = notas de mudança.

  As abas Gestor e Curso Técnico têm layout diferente.

## Decisões

- **CSV canônico versionado** (developer). O xlsx fica fora do repositório.
  - O gerador usa só a stdlib (zipfile+XML) e é determinístico; o CSV
    regenerado sai byte a byte igual.
  - O SQL de deploy é **gerado** a partir do CSV, com os dados embutidos, o
    que mantém o Sqitch autocontido.
  - Uma edição nova do INEP entra como uma change nova.
- **`origem` inep|derivada:** separa o que é do INEP do que o EduMaps
  calcula (`geometry`, `cluster_id`, `linha_id`, contagens).
- **Função `clean.censo_dict_violacoes()`:** a regra fica num lugar só, usado
  pelo teste do CI, pelo R (`censo_dict_validate`) e, no futuro, pela carga.
  - O **verify não chama a função**, para não varrer os dados no deploy:
    confere só o catálogo.
  - O código fora do domínio é responsabilidade do teste e da carga.
- **Ajustes de dados documentados, não escondidos:**
  - 5 colunas com nome encurtado nas migrations (`_con`) foram mapeadas ao
    nome oficial (`_conc`);
  - o código **9** dos microdados em `in_educ_amb_*` (escola sem educação
    ambiental, 88 mil linhas reais), que o dicionário do INEP omite, entrou
    como complemento do EduMaps; o CSV continua fiel ao xlsx.
- **Escopo** (developer): o chat foi corrigido aqui. Os rótulos duplicados no
  backend, no SQL e no R ficam para a **#228**.

## Bug colateral corrigido

`chat_dictionary()` usava `tabelas$schema_table` antes de criá-la. Desde
`eaaf66d`, o dicionário do Assistente do Censo saía **vazio** e o prompt ia
sem tabelas. Agora vão 8 tabelas com os rótulos oficiais, cerca de 12 mil
caracteres a mais de entrada por pergunta.

## Validação

- Em dev, sobre os 214 mil registros de 2025, a função devolve **0
  violações** (cerca de 29 s).
- Gate no CI sobre as fixtures; detecção conferida plantando um código
  inválido e uma coluna nova numa transação.
- Gerador: 25 testes unittest com um xlsx sintético.
- R: 31 / 1658.
- Backend: só falhas antigas.
- Verify, revert e deploy no banco de CI.

## Lições

- **Conferir o aceite antes de fechar.** "Merge com #N no título" não
  significa issue cumprida; a #134 ficou 13 dias aberta com metade
  entregue.
- **Um validador precisa de um teste que prove que ele falha.** Foi assim
  que os três validadores mortos apareceram.
- **O dicionário oficial também erra.** Os dados reais mandam, desde que a
  divergência fique documentada.

## Pendências

- **#228:** os rótulos duplicados passam a ler do dicionário.
- **Carga:** chamar a função depois de uma carga real do Censo (job INEP,
  hoje um stub bloqueado por e-SIC).
- **Custo da função:** ~29 s em dev. Se entrar num caminho quente, considerar
  amostragem ou materialização.
