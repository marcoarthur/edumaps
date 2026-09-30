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

### 2026-09-30 — 3ª rodada (lote de mobilidade — **corrige a 2ª**)

**P11 — mobilidade: existe dado utilizável em escala nacional?**
- Resposta: **existe, e são quatro fontes independentes.** A 2ª rodada respondeu
  que não, crendo que o padrão aberto de transporte é GTFS municipal. Verificando
  com o mesmo rigor dos outros lotes, apareceu:

  | Dimensão | Fonte | Chave |
  |---|---|---|
  | Fluxo de deslocamento | ANTT / MONITRIIP | par de municípios, mensal desde jan/2019, CC BY |
  | Tráfego e risco | ANTT (SAT, acidentes, geodados) | trecho viário com coordenada |
  | Malha com volume | DNIT/INDE (SNV + VMDA) | trecho de rodovia, domínio público |
  | Frota e sinistralidade | Transportes (RENAVAM, RENAEST) | município, mensal desde mai/2013 |

  E, para a pergunta de acesso propriamente dita: **isocronas OSRM/Valhalla**,
  que traduzem a malha do OSM em *população alcançável a pé em 15/30/45 min* —
  **sem tocar em dado de passageiro**.
- Status: **✓ atendido**. A lacuna 5 sai de "não resolvida" para "boa, com
  ressalva de granularidade".
- **A ressalva que importa para a pesquisa**: transporte escolar com **chave de
  escola** existe em **um único município brasileiro verificado** — o Recife
  publica vagas por unidade e por turno. Nenhuma fonte nacional chega perto.
  Isso inverte o diagnóstico: o gargalo **não é a coleta, é a publicação**. O
  dado existe nos DETRANs e nas secretarias de educação e quase nunca é aberto.
  Para esta persona é a descoberta mais útil das três rodadas — um e-SIC
  dirigido às secretarias municipais de educação renderia mais que qualquer
  pipeline adicional.
- **O que muda para o IVET**: `iv_mobilidade_isocrona_escolar_15` responde à
  pergunta de P8 (escola rural × urbana) **sem reidentificação**. A isocrona por
  escola em cidade pequena precisa sair agregada em grade de 1 km.
- Follow-up: a isocrona mede **oportunidade de acesso**, não **uso** — um aluno a
  4 km com ônibus a cada 40 min é alcançável na isocrona a pé e não no
  deslocamento real. A matriz OD da ANTT corrige parte disso, mas opera em chave
  **município-município**, não escola-aluno. A pergunta que fica é: **a
  distância por tempo de viagem (não a distância geométrica) é a variável-chave
  para o índice de vulnerabilidade, ou o IVET deve assume que a geométrica
  basta?**

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
- Resposta: **não**, e esta é a crítica mais forte que a verifiable evidência sustenta. O IVET
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

**P10 — mobilidade: existe dado utilizável?** *(respondida na 3ª rodada)*
- Resposta: **sim, e em nível nacional.** A 2ª rodada respondeu "não" — o que
  estava errado. Ver P11.
- Status: **✓ atendido**, com ressalva de granularidade.
- Follow-up: ver P11.

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
- [ ] **Verificar se o alcance a pé (isocrona) é a variável certa que responde à
  pergunta de acesso** — é a que liga malha viária e malha censitária sem dado
  individual (P11).

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
- **[alta]** **Isocronas** (OSRM/Valhalla **auto-hospedados**) — alcance real do
  aluno, sem dado de passageiro, é a forma mais segura em LGPD de medir acesso e
  **já responde à pergunta de P8**: distingue a escola rural da urbana sem
  depender de dado individual.
- **[média]** Matriz origem-destino municipal da **ANTT/MONITRIIP** (fluxo entre
  municípios), com supressão de célula pequena.
- **[média]** Transporte escolar como **prova de viabilidade no Recife** — é o
  único município com chave de escola verificado, e é ODbL, então serve de
  referência de indicador, não de fonte a ingerir.
- **[baixa]** Alinhar `ranking_escola` (dados vazios em dev).
- **[baixa]** Conectividade por escola, **condicional a e-SIC** ao MEC/NIC.br —
  hoje não há API nem licença publicada.

## Veredito

- **Aprova** (2026-09-30, 3ª rodada): das seis lacunas, **quatro** têm fonte
  verificada e **uma** (conectividade) depende de e-SIC. As pendências que sobram
  são de **decisão e governança** (leitura do IVET, LGPD, e-SIC), não de
  disponibilidade de dado. A correção da 2ª rodada sobre mobilidade é o fato
  mais importante desta persona: **a ausência de dado era de escopo de
  verificação, não de publicação ou de coleta** — e as duas coisas que faltam de
  verdade (transporte escolar por escola, conectividade por escola) são as duas
  que **exigem e-SIC**, não engenharia.
- **Aprova com ressalvas** (2026-09-30, 2ª rodada): a pergunta de **onde estão
  as fontes para as seis lacunas** tem resposta agora, e a resposta é
  razoavelmente boa em saúde/contexto e ruim em mobilidade. As pendências que
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
