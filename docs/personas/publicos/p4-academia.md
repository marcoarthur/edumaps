# Persona P4: pesquisadora em políticas educacionais

> Público **P4 — Pesquisadores e academia** 🥈 do plano de negócios
> (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** economista da educação, doutora em políticas públicas, num
  programa de pós-graduação ou instituto. Usa microdados do Censo Escolar,
  IDEB e IBGE para estudar desigualdades regionais.
- **Quem paga:** agência de fomento, instituto ou assinatura institucional
  (R$ 20 mil a 80 mil por ano, dados ou API).
- **Dor central:** montar bases de análise **reprodutíveis** sem escrever SQL
  nem federar fontes à mão.
- **Perguntas típicas:**
  - "Municípios de porte e região semelhantes têm oferta parecida?"
  - "Quanto da variação do IDEB se associa à infraestrutura, controlando por
    rede?"
  - "Como o perfil docente muda entre regiões?"
- **O que usa:** clusters, ranking, escolas similares, comparação de redes,
  fontes de dados, busca de análises, histórico de conversas.
- **O que valoriza:** metodologia explícita e citável, versão dos dados
  fixada, dado ausente tratado como ausente (#154), possibilidade de refazer
  a conta.
- **O que a faz desistir:** número sem método, base que muda sem aviso,
  resultado que não se reproduz.
- **Fonte de leitura:** a pesquisadora educacional do repositório `eduBR` (só
  leitura) é a mesma figura do lado do pacote de dados.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — fluxo do INEP](ciclos/2026-11-13-fluxo-inep.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — escolas semelhantes em dia](ciclos/2026-11-13-embedding-diario.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — botão de salvar sem réplica](ciclos/2026-11-14-duplo-envio.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — envio sem duplicidade no servidor](ciclos/2026-11-14-envio-sem-duplicidade.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — suíte em paralelo e backend sem o PDL](ciclos/2026-11-14-build-e-testes.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-15 — análises públicas legíveis e ausência honesta](ciclos/2026-11-15-analises-legiveis.md#p4--academia-pesquisadora): não adotaria por ora (mantido; sem reavaliação). Regra dos sinais versionada; ficam AN-05, AN-08, AN-09.
- [2026-11-15 — busca por município, menus em PT-BR e menos jargão](ciclos/2026-11-15-busca-e-linguagem.md#p4--academia-pesquisadora): não adotaria por ora (mantido). IDEB com edição e etapa; ficam #427 e #428.
- [2026-11-15 — agrupamento que presta contas e se reproduz](ciclos/2026-11-15-agrupamento-reprodutivel.md#p4--academia-pesquisadora): não adotaria por ora (mantido). AN-05 e AN-09 resolvidos; fica #428. Reavaliar depois dela.
- [2026-11-15 — fonte, ano e versão dos dados na tela](ciclos/2026-11-15-fontes-e-metodologia.md#p4--academia-pesquisadora): não adotaria por ora (mantido). AN-08 resolvido: os três bloqueios saíram; reavaliar.
- [2026-11-15 — ranking de redes municipais e de escolas por município](ciclos/2026-11-15-ranking-de-redes.md#p4--academia-pesquisadora): não adotaria por ora (mantido; reavaliação pendente). CSV de redes com INSE.
- [2026-11-15 — ranking com salto atípico, mínimo e ordem crescente](ciclos/2026-11-15-ranking-atipico.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido). RV-01 resolvido; ficam #438 e #439.
- [2026-11-16 — versão dos dados no CSV do agrupamento](ciclos/2026-11-16-csv-versao.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido). RV-03 resolvido; fica #439.
- [2026-11-16 — porte no ranking e base de análise](ciclos/2026-11-16-base-analise.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido até nova rodada). RV-02 e RV-05 resolvidos; nenhum achado da reavaliação aberto.
- [2026-11-16 — avisos da base de análise](ciclos/2026-11-16-avisos-base.md#p4--academia-pesquisadora): adotaria (mantido). BA-01, BA-03 e BA-04 resolvidos; fica #445.
- [2026-11-16 — recorte por região no ranking](ciclos/2026-11-16-ranking-regiao.md#p4--academia-pesquisadora): adotaria (mantido). BA-02 resolvido no ranking (região e porte); base por região fica na assinatura. Nenhum achado aberto.
- [2026-11-16 — região na base e recorte nos CSVs](ciclos/2026-11-16-regiao-base-csv.md#p4--academia-pesquisadora): adotaria (mantido). RG-01 e RG-02 resolvidos; fica #449 (RG-03).
- [2026-11-16 — município destacado no ranking](ciclos/2026-11-16-destaque-municipio.md#p4--academia-pesquisadora): adotaria (mantido). RG-03 resolvido; nenhum achado da P4 aberto.

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas: reavaliada em 2026-11-16 (**adotaria**). Os achados
  RV-01 a RV-05 foram entregues (#440 a #443). BA-01, BA-03 e BA-04 entregues
  (#446). BA-02 entregue no ranking (#447); a base por região fica na
  assinatura (decisão de produto). Quarta rodada (2026-11-16, **adotaria**):
  RG-01 a RG-03, detalhes, entregues (#450 e #451). Nenhum achado aberto.
- Voltar a checar quando houver mais de um Censo carregado (séries) ou base
  nacional (assinatura).

## Entradas

### 2026-11-16 — Análises públicas (quarta rodada, região no ranking)

**Veredito:** **adotaria** (mantido), agora também para comparar regiões no
ranking. Consolidação em
[`avaliacoes/2026-11-16-p4-ranking-regiao.md`](avaliacoes/2026-11-16-p4-ranking-regiao.md).

**O que tentou:**
- "Porte e região semelhantes": o ranking do Nordeste com 10 a 20 mil
  habitantes (519 redes), contra o Sul e o Brasil do mesmo porte.
- "Perfil docente entre regiões": baixou a docência das 27 UFs (22 s),
  juntou no R (180.540 escolas) e comparou a licenciatura por região e porte.

**O que funciona para ela:**
- região e porte no mesmo link, com o salto atípico e o INSE medidos no
  recorte;
- as bases das UFs se juntam sem ajuste (mesmo cabeçalho, versão na linha,
  `NA` como ausência).

**Barreiras (detalhes):**
- RG-01: a base não traz a região, e o mapa UF → região vai à mão;
- RG-02: o CSV do ranking não diz o recorte nas colunas;
- RG-03: não dá para achar um município na lista de redes.


### 2026-11-16 — Análises públicas (terceira rodada, base de análise)

**Veredito:** adotaria com ressalvas → **adotaria**, como base de artigo para
um corte transversal de uma UF; séries e Brasil inteiro, ainda não.
Consolidação em
[`avaliacoes/2026-11-16-p4-base-analise.md`](avaliacoes/2026-11-16-p4-base-analise.md).

**O que tentou:** as três perguntas do perfil.
- "IDEB × infraestrutura, controlando por rede": baixou a base do ES, abriu
  com `read.csv2()` e rodou `lm(ideb_ai ~ infra + rede + inse_media)` (822
  escolas).
- "Porte e região semelhantes": o ranking nacional de 10 a 20 mil
  habitantes.
- "Perfil docente entre regiões": o bloco de docência da base.

**O que funciona para ela:**
- a base sai sem SQL e com o IDEB por etapa ao lado do Censo;
- a versão vem em cada linha e no nome do arquivo;
- o dicionário dá a fonte e o link de cada coluna;
- ausente é `NA`, nunca zero;
- o porte refaz o ranking entre cidades do mesmo tamanho.

**Barreiras:**
- BA-01 (atrapalha): o IDEB de uma edição antiga é cruzado com o Censo 2025
  sem aviso.
- BA-02 (detalhe): não há recorte por região.
- BA-03 (detalhe): o link não fixa a versão.
- BA-04 (detalhe): falta a fórmula das proporções de docência.


### 2026-11-15 — Análises públicas (reavaliação)

**Veredito:** não adotaria por ora → **adotaria com ressalvas** (exploração e
recortes citáveis; ainda não como base de artigo). Consolidação em
[`avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`](avaliacoes/2026-11-15-analises-publicas-reavaliacao.md).

- **Resolveu:** os três bloqueios (AN-05, AN-08 e AN-09).
  - O agrupamento diz o universo, guarda parâmetros e versão dos dados, tem
    link por 90 dias e CSV com os valores.
  - `/fontes` traz o ano lido da base, a data da carga e o SHA-256.
- **Atrapalha:**
  - RV-01: resultados atípicos sem aviso no topo do ranking de redes;
  - RV-02: sem exportação multi-indicador direta; o agrupamento serve de
    exportador.
- **Detalhes:**
  - RV-03: o CSV do agrupamento não traz o ano dos dados;
  - RV-05: falta o porte do município como contexto no ranking.


### 2026-11-14 — Análises públicas (primeira avaliação)

**Material:** agrupamento, escolas semelhantes, ranking, perfil da escola e
da rede, comparação de redes, numa sessão no navegador com a stack local
(Vitória, ES). Consolidação em
[`avaliacoes/2026-11-14-analises-publicas.md`](avaliacoes/2026-11-14-analises-publicas.md).

**O que tentou:** agrupar as escolas de Vitória por infraestrutura e
relacionar com o IDEB; ver onde a escola fica contra o município, a rede e
o Brasil.

**O que funciona para ela:** o perfil diz o Censo usado (2025) e quando foi
atualizado; a evolução do IDEB e do SAEB vem desde 2005; o ranking diz o
universo ("de 180").

**Barreiras:**
- AN-09 (bloqueia): o agrupamento não se reproduz. A URL não guarda os
  parâmetros, e não há exportação nem lista das escolas.
- AN-08 (bloqueia): não há página pública de fontes, metodologia e versão dos
  dados.
- AN-05 (atrapalha): 167 escolas no mapa, 180 no resumo e 226 no município,
  sem dizer quem ficou de fora. Para ela, o dado ausente tem que aparecer
  como ausente.
- AN-02 (atrapalha): o sinal de atenção lê ao contrário os indicadores em
  que menor é melhor.
- AN-03 (atrapalha): a distância das escolas semelhantes aparece como
  "0.00", sem método.

**Veredito:** **não adotaria** por ora. Usaria para explorar, não para
publicar: número sem método e resultado que não se reproduz são o que a faz
desistir.
