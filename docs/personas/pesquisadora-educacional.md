# Persona: Pesquisadora em Política Educacional

> Curadoria do pacote `eduBR` (repo `~/Projects/eduBR`).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".

## Perfil

- **Papel**: economista da educação, doutora em políticas públicas; usa
  microdados do Censo Escolar, IDEB e IBGE para estudar desigualdades
  regionais e avaliar efeitos de infraestrutura/rede sobre o desempenho.
- **Objetivo com o `eduBR`**: montar bases de análise por
  escola/município/região — já tipadas e prontas para `tidymodels` — sem
  decorar `schema.tabela` nem escrever SQL.
- **Perguntas de pesquisa típicas**: "municípios de porte/região semelhantes
  têm oferta parecida?", "quanto da variação do IDEB se associa à
  infraestrutura, controlando por rede?", "como o perfil docente muda entre
  regiões?".
- **Funções que mais usa**: `conecta()`, `escolas()`, `municipios()`,
  `redes()`, `indicadores()`, `scores()`, `ideb()`, `censo_escolar()`,
  `clusters()`, `municipios_similares()`, `catalogo()`.
- **Critérios de avaliação**: (1) as chaves de join entre entidades são
  explícitas e confiáveis (código, não nome); (2) os tipos/ano são
  consistentes; (3) um recorte (UF/município) vira uma tabela pronta para
  modelagem; (4) a geometria permite análise/mapa regional.

## Perguntas canônicas

1. Consigo juntar `escola → município → IBGE/população` **por código**,
   sem adivinhar nomes de chave?
2. As variáveis vêm no tipo certo (numérico vs texto) e com o **ano**
   consistente entre censo, IDEB e indicadores?
3. Um recorte de UF/município vira uma tabela pronta para `tidymodels`?
4. A geometria dos municípios permite gerar um mapa para análise regional?

## Entradas

### 2026-09-30 — 2ª rodada (fontes de dados disponíveis para pesquisa, #123)

**P5 — o IVET responde a qual pergunta, exatamente?**
- Resposta: hoje responde *"onde a falta de acesso, a precariedade da
  infraestrutura e a insuficiência de recursos se sobrepõem"* — mas com **três
  fontes** (Censo, OSM, SIOPE) e **seis lacunas** declaradas: saúde, segurança,
  conectividade, investimentos planejados, mobilidade e meio ambiente.
  O IVET atual é um índice de vulnerabilidade **educacional** que carrega
  proxies de **contexto territorial** que não estão medidos.
- Status: **lacuna** (é o que a issue #123 endereça).
- Follow-up: uma vez ingeridas as fontes de alta prioridade, o IVET vira índice
  **territorial** (o-school em contexto) ou permanece **escolar com contexto**?
  A escolha de leitura muda a interpretação de todos os coeficientes.

**P6 — qual é o limite de validade do indicador de saúde do IVET?**
- Resposta: a fonte canônica de saúde **escolar** é a **PeNSE** (edições 2009,
  2012, 2015, 2019, **2024**, esta publicada em 25/03/2026) — e é a **única** com
  microdado em **nível de escola**. A PNS é de **adultos** e sua última edição é
  **2019**. A PeNSE inclui literalmente "faltaram aula por motivos relacionados
  à própria saúde" e "deixaram de ir à escola porque não se sentiam seguros no
  trajeto" — que são exatamente as dimensões que faltam.
- Status: **lacuna**, e a de maior **valor** do catálogo.
- Follow-up: é aceitável usar PeNSE como insumo do IVET, ou ela só pode virar
  análise separada, com governança LGPD própria? Ver a pendência P7.

**P7 — qual dado de saúde é publicável?**
- Resposta: verificado em **payload de produção**, não inferido. A API de Dados
  Abertos do SUS devolve **microdado individual sem mitigação** em
  `/sisvan/estado-nutricional` (peso, altura, IMC, data, por pessoa) e
  `/vacinacao/doses-aplicadas-pni-*` (data de vacinação + `codigo_documento`).
  Já o `CNES` devolve **nome de pessoa física, CNPJ, telefone e e-mail** do
  estabelecimento. Nada disso entra no pipeline. O que é agregável por município
  (`SISAB/PMMB`) e o que é **ponto com coordenada** (`CNES`) é o caminho limpo.
- Status: **lacuna de governança** (não de dados).
- Follow-up: quem aprova a allowlist de endpoints e a regra de supressão de
  células? Sem isso, nenhum indicador de saúde sai do status de proposta.

**P8 — a granularidade municipal basta para o IVET?**
- Resposta: **não**, e esta é a crítica mais forte que averifyc sustente. O IVET
  atual repassa o **valor municipal uniforme a todas as escolas do município** —
  uma escola rural e uma urbana, no mesmo município, recebem o mesmo contexto.
  O **Censo 2022 por setor censitário** (316.574 setores, ~3.000 variáveis) e o
  **Atlas do IDHM** (~120 indicadores municipais, com dimensões SAÚDE e
  VULNERABILIDADE) permitem sair disso, por *arealização* sobre a área de
  influência da escola.
- Status: **✓ atendido** (fonte disponível) / **lacuna** (ainda não ingerida).
- Follow-up: arealizar exige a malha do setor censitário e um buffer coerente
  com a área de influência que o IVET já usa. O buffer é compatível?

**P9 — a segurança é comparável entre municípios?**
- Resposta: `BrazilCrime` é o único caminho reproduzível, nacional e municipal.
  Mas dado de ocorrência policial é sensível por natureza, e o acesso primário
  (SINESP) é restrito. Consequência metodológica: só é defensável usar
  **métricas municipais agregadas com supressão de célula pequena** (count<5), e
  como **sinal de risco contextual**, nunca como atributo da escola.
- Status: **lacuna** (deve entrar com revisão de LGPD antes de qualquer
  exposição na interface).
- Follow-up: a agregação municipal elimina a questão do endereço da ocorrência,
  mas a pergunta de quem é a ocorrência — bairro, escola, via — continua sem
  resposta, e é a que o gestor realmente quer.

**P10 — mobilidade: existe dado utilizável?**
- Resposta: ver `docs/analises/fontes/mobilidade.md`. Em resumo, o padrão de
  dados abertos de transporte é **GTFS, municipal e não padronizado** — não há
  base nacional comparável. É a lacuna mais difícil de fechar e a que mais
  depende de escopo local.
- Status: **lacuna** (a mais estrutural do catálogo).
- Follow-up: faz sentido priorizar dois ou três municípios-piloto para
  mobilidade, em vez de tentar cobertura nacional que não existe?

## Pendências

- [ ] Join escola→município **por código** (expor `co_municipio` ou helper).
- [ ] Projeção de colunas / amostragem antes do `collect`.
- [ ] `as_sf()` / suporte PostGIS para mapas regionais.
- [ ] Dicionário de tipos/ano das relações.
- [ ] **Decidir** se o IVET vira índice territorial ou permanece escolar com
  contexto (P5) — bloqueia a leitura de todos os coeficientes.
- [ ] **Governança LGPD/CEP** para PeNSE (P6, P7) — única fonte que exige
  decisão institucional, não técnica.
- [ ] **Arealização**: malha do setor censitário + buffer compatível com a área
  de influência do IVET (P8).
- [ ] **Escopo de mobilidade**: municipal-piloto em vez de cobertura nacional
  inexistente (P10).

## Sugestões priorizadas

- **[alta]** Ingerir contexto municipal e sub-municipal (IBGE SIDRA + malhas +
  Censo por setor censitário) — sem isso, o IVET não ganha resolução e a
  pergunta P8 fica sem resposta.
- **[alta]** Bloco de saúde via `CNES` + `DATASUS/SISAB`, **sempre** com
  allowlist de endpoints — torna a saúde cartografável sem microdado.
- **[alta]** Expor chave de município (`co_municipio`) junto às escolas, ou
  um helper de join por código.
- **[alta]** Suporte `sf`/PostGIS (`as_sf()`) para a geometria.
- **[média]** Governança LGPD para PeNSE: projeto CEP/Conep, ambiente
  controlado, supressão de célula pequena — o maior ganho de saúde *disponível*,
  condicionado a decisão institucional.
- **[média]** Segurança via `BrazilCrime`, agregada a município, com supressão
  (count<5) e nunca exposta por escola.
- **[média]** Dimensão fiscal municipal (SICONFI) — dá sentido a "insuficiência
  de recursos" com dado de receita, não só de repasse federal.
- **[média]** Projeção/`select` no acesso (evitar trazer 20–318 colunas).
- **[média]** Documentar tipo e ano de referência das chaves/relações.
- **[média]** Mobilidade como **piloto municipal** (GTFS), com honestidade sobre
  a ausência de base nacional.
- **[baixa]** Alinhar `ranking_escola` (dados vazios em dev).
- **[baixa]** Conectividade por escola, **condicional a e-SIC** ao MEC/NIC.br —
  hoje não há API nem licença publicada.

## Veredito

- **Aprova com ressalvas** (2026-09-30, 2ª rodada): a pergunta de **onde estão
  as fontes para as seis lacunas** tem resposta agora, e a resposta é
  embarrassingly boa em saúde/contexto e ruim em mobilidade. As pendências que
  sobram são de **decisão e governança** (leitura do IVET, LGPD), não de
  disponibilidade de dado — o que é a melhor notícia possível para esta rodada.
- **Aprova com ressalvas** (2026-09-15): o acesso de alto nível funciona e
  esconde o schema, mas faltam join por código, projeção de colunas e
  suporte geoespacial para o fluxo de pesquisa regional/nacional.

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**P1 — join escola → município por código.**
- Resposta: `clean.escolas` (⇒ `escolas()`) só possui `municipio` (nome) e
  `uf`; **não há código IBGE** na tabela. O código (`co_municipio`) existe
  apenas em `clean.school_indicators` (⇒ `escola`/`indicadores`). Logo, o
  join escola→município é por **nome** hoje — frágil (homônimos/acentos).
- Status: **lacuna**.
- Follow-up: como fazer um join escola→município **por código** de forma
  direta com o `eduBR`? (expor `co_municipio` junto de `escolas()`, ou um
  `escola_municipio()`/`juncao`.)

**P2 — tipos e ano.**
- Resposta: chaves com tipos mistos — `clean.escolas.codigo_inep` é
  `bigint`, `clean.municipios_sp.codigo_ibge` é `varchar`,
  `school_indicators.co_entidade` é `bigint`, `nu_ano_censo` é `integer`.
  Não há dicionário de tipos/anos no pacote.
- Status: **sugestão**.
- Follow-up: o pacote deveria expor/validar os tipos das chaves (e o ano
  de referência de cada relação)?

**P3 — recorte UF → tabela pronta.**
- Resposta: `escolas(con, uf = "SP") |> as_tibble()` devolve 28.710 linhas
  × 20 colunas em **~40 s** (coleta total). Funciona, mas é lento e traz a
  tabela inteira sem projeção de colunas.
- Status: **✓ com ressalva** (performance).
- Follow-up: há uma forma de projetar colunas / amostrar antes de coletar?

**P4 — geometria para mapa.**
- Resposta: a coluna `geometry` é devolvida como `pq_geometry` (WKB cru,
  ex. `0106000020421200...`), não como `sf`. Sem `sf`, não gera mapa direto.
- Status: **lacuna** (GIS adiado por decisão de escopo).
- Follow-up: o `as_sf()`/integração PostGIS está previsto e para quando?

**Observações extras da rodada.**
- `municipios()` cobre 5.573 municípios em 27 UFs (não é só SP, apesar do
  nome físico) — bom para perguntas nacionais.
- `indicadores()` lê `analytics.ranking_escola`, que está **vazia** no dev
  (0 linhas) → perguntas de ranking não são respondíveis hoje (lacuna de
  dados, não do pacote).

> Pendências, sugestões e veredito desta persona ficam **no topo** do arquivo,
> após a entrada mais recente. O histórico por rodada é preservado nas seções
> `### <data>` correspondentes.
