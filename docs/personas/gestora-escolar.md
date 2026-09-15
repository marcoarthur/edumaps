# Persona: Gestora Escolar

> Curadoria do pacote `eduBR` (repo `~/Projects/eduBR`).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".

## Perfil

- **Papel**: diretora de escola pública municipal de anos iniciais, em
  município pequeno. Trabalha com planilha; **não programa em R**.
- **Objetivo com o `eduBR`**: uma "foto" da **sua escola** dentro do painel
  da cidade/estado — onde ela está acima/abaixo da média, com quem se
  parece, e como evolui no IDEB.
- **Perguntas típicas**: "como está a infraestrutura da minha escola?",
  "estou abaixo da média do município?", "quais escolas são parecidas com a
  minha para eu trocar ideia?", "melhoramos no IDEB?".
- **Funções que (deveria) usar**: `conecta()`, `escola(codigo_inep)`,
  `scores()`, `indicadores()`, `ideb()`, `redes()`, `municipios_similares()`.
- **Critérios de avaliação**: (1) consigo ver a **minha** escola numa linha;
  (2) comparação pronta com a média do município/estado; (3) benchmark com
  escolas semelhantes; (4) saída **legível para não-técnico** (PT-BR, nomes
  claros, sem SQL).

## Perguntas canônicas

1. Como vejo os indicadores da **minha escola** numa linha, sem digitar SQL?
2. Dá para comparar com a **média do município/estado** (infraestrutura e
   IDEB)?
3. Quais escolas são **mais parecidas** com a minha (benchmark)?
4. A saída é **legível para não-técnico** (nome da escola, rótulos claros,
   sem jargão/SQL)?

## Entradas

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**G1 — minha escola numa linha.**
- Resposta: `escola(con, "13078070") |> as_tibble()` devolve 1 linha com o
  nome ("ESC MUNICIPAL PROF NORMA SILVA DE OLIVEIRA"). Funciona com o código
  como texto ou número.
- Status: **✓**.
- Follow-up: incluir já um resumo (rede, etapa, porte) em vez da linha crua?

**G2 — comparar com a média do município/estado.**
- Resposta: **não existe** helper de comparação ("minha escola vs média").
  O usuário teria que coletar a cidade inteira e calcular à mão.
- Status: **lacuna**.
- Follow-up: criar `perfil_escola()`/`comparar()` que devolva a escola com
  as médias de município/estado e a posição relativa.

**G3 — escolas parecidas (benchmark).**
- Resposta: `municipios_similares()` é de **municípios**, não de escolas, e
  está **vazia** em dev (0 linhas). Similaridade entre escolas não está
  exposta no `eduBR`.
- Status: **lacuna**.
- Follow-up: expor `escolas_similares(escola_id)` (benchmark escolar).

**G4 — saída legível para não-técnico.**
- Resposta: `print()` mostra `<eduBR_escola>`, `Source: SQL [?? x 20]` e
  `# Database: devel@ubatexu.lan:5432/edumaps_dev`, além de colunas cruas
  (`restricao_atendimento`, `tp_dependencia` numérico). Técnico demais.
- Status: **sugestão**.
- Follow-up: `print`/`resumo` em PT-BR, com rótulos e poucas colunas
  essenciais (nome, município, rede, indicadores-chave).

**Observações extras da rodada.**
- Onde há dados, o acesso é simples: `escolas()`, `escola()` e `scores()`
  respondem bem.
- `indicadores()` está vazio em dev; `ideb()` tem 814 mil linhas (precisa de
  filtro por escola para ser usável por ela).

## Pendências

- [ ] `perfil_escola()` / `comparar()` (escola vs município/estado).
- [ ] `escolas_similares(escola_id)` (benchmark escolar).
- [ ] `print`/`resumo` legível para não-técnico, com rótulos PT-BR.

## Sugestões priorizadas

- **[alta]** `perfil_escola()` com comparação pronta (município/estado).
- **[alta]** `print` amigável (esconder SQL/host; rótulos em PT-BR).
- **[média]** `escolas_similares()` para benchmark entre escolas.
- **[média]** Resumo de uma linha por escola (rede, etapa, porte, IDEB).
- **[baixa]** Exemplos prontos com uma escola real no README.

## Veredito

- **Aprova com ressalvas** (2026-09-15): dá para "ver a minha escola", mas
  sem comparação com o painel da cidade/estado nem benchmark, e a saída
  ainda não é amigável para quem não programa.
