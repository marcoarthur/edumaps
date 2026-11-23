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
- [2026-11-16 — itens inexistentes e coordenadas na base](ciclos/2026-11-16-infra-inexistente.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: infraestrutura básica sem confusão e coordenadas.
- [2026-11-16 — posição pela variação e variação vazia](ciclos/2026-11-16-variacao-csv.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: as duas posições no arquivo.
- [2026-11-16 — infraestrutura básica e método dos índices](ciclos/2026-11-16-infraestrutura-basica.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: índices com método, inclusive a falha da diversidade (#459).
- [2026-11-16 — diversidade discente com a educação especial](ciclos/2026-11-16-diversidade-especial.md#p4--academia-pesquisadora): adotaria (mantido). Impacto direto: índice sem componente constante; IVET ivet-v1.4.
- [2026-11-16 — etapas oferecidas e cobertura do IDEB](ciclos/2026-11-16-etapas-cobertura.md#p4--academia-pesquisadora): adotaria (mantido). RX-02 resolvido; fica #462.
- [2026-11-16 — versão citável dos índices](ciclos/2026-11-16-versao-indices.md#p4--academia-pesquisadora): adotaria (mantido). RX-01 resolvido; nenhum achado aberto da quinta avaliação.
- [2026-11-16 — índices do EduMaps na base de análise](ciclos/2026-11-16-indices-na-base.md#p4--academia-pesquisadora): adotaria (mantido). RY-01 e RY-02 resolvidos; nenhum achado aberto da sexta avaliação.
- [2026-11-17 — índice vazio, não 0, sem registro](ciclos/2026-11-17-indices-sem-registro.md#p4--academia-pesquisadora): adotaria (mantido). RZ-01 e RZ-02 resolvidos; nenhum achado aberto da sétima avaliação.
- [2026-11-17 — partes do índice de capacitação docente](ciclos/2026-11-17-partes-capacitacao.md#p4--academia-pesquisadora): adotaria (mantido). RW-01 e RW-02 resolvidos; nenhum achado aberto da oitava avaliação.
- [2026-11-17 — cor/raça sobre os declarados](ciclos/2026-11-17-diversidade-cor-declarada.md#p4--academia-pesquisadora): adotaria (mantido), com a diversidade. RT-01 a RT-03 resolvidos; nenhum achado aberto da nona avaliação.
- [2026-11-17 — lotação por sala e por turno](ciclos/2026-11-17-atendimento-por-turno.md#p4--academia-pesquisadora): adotaria (mantido), com o atendimento. RS-01 e RS-02 resolvidos; nenhum achado aberto da décima avaliação.
- [2026-11-17 — capacidade gestora sem o zero imposto](ciclos/2026-11-17-gestora-partes.md#p4--academia-pesquisadora): adotaria (mantido). RR-01 e RR-02 resolvidos; nenhum achado aberto da décima primeira avaliação.
- [2026-11-17 — a ajuda refaz os seis índices](ciclos/2026-11-17-ajuda-refaz-indices.md#p4--academia-pesquisadora): adotaria (mantido). RQ-01 e RQ-02 resolvidos; nenhum achado aberto da décima segunda avaliação.
- [2026-11-17 — comparação de redes só com escolas em funcionamento](ciclos/2026-11-17-comparacao-redes-ativas.md#p4--academia-pesquisadora): adotaria (mantido), com a comparação de redes. RP-01 a RP-04 resolvidos; nenhum achado aberto da décima terceira avaliação.
- [2026-11-17 — agrupamento por desempenho numa etapa](ciclos/2026-11-17-agrupamento-etapa.md#p4--academia-pesquisadora): adotaria (mantido), com o agrupamento por desempenho. RO-01 e RO-02 resolvidos; nenhum achado aberto da décima quarta avaliação.
- [2026-11-17 — IDEB do perfil na mesma etapa](ciclos/2026-11-17-perfil-ideb-etapa.md#p4--academia-pesquisadora): adotaria (mantido), com o IDEB do perfil. RN-01 e RN-02 resolvidos; nenhum achado aberto da décima quinta avaliação.
- [2026-11-17 — evolução com o SAEB por etapa](ciclos/2026-11-17-evolucao-saeb-etapa.md#p4--academia-pesquisadora): adotaria (mantido), com a série do SAEB. RM-01 e RM-02 resolvidos; nenhum achado aberto da décima sexta avaliação.
- [2026-11-18 — escolas semelhantes pela distância entre as notas](ciclos/2026-11-18-semelhantes-distancia-notas.md#p4--academia-pesquisadora): adotaria (mantido), com as escolas semelhantes. RL-01 e RL-02 resolvidos; nenhum achado aberto da décima sétima avaliação.
- [2026-11-18 — IVET com o motivo certo e a versão citável](ciclos/2026-11-18-ivet-motivo-versao.md#p4--academia-pesquisadora): adotaria (mantido), com o IVET citável. RK-01 e RK-02 resolvidos; fica a régua da `ivet-v1.8` (medição no LXC).
- [2026-11-18 — folha pela pessoa, por ano e na base](ciclos/2026-11-18-folha-pessoa-ano.md#p4--academia-pesquisadora): adotaria (mantido), com a folha. RJ-01, RJ-02 e RJ-03 resolvidos; fica a cobertura do SIOPE.
- [2026-11-18 — grupo de referência do perfil pelo contexto](ciclos/2026-11-18-perfil-grupo-contexto.md#p4--academia-pesquisadora): adotaria (mantido), com o grupo de referência. RI-01 a RI-03 resolvidos; ficam as similares do Perfil.
- [2026-11-19 — escolas similares do perfil pelo contexto](ciclos/2026-11-19-perfil-similares-contexto.md#p4--academia-pesquisadora): adotaria (mantido), com as escolas similares. RH-01 e RH-02 resolvidos; nenhum achado aberto da vigésima primeira avaliação.
- [2026-11-19 — perfil da rede contra a mesma rede](ciclos/2026-11-19-perfil-rede-referencia.md#p4--academia-pesquisadora): adotaria (mantido), com o perfil da rede. RG-01 e RG-02 resolvidos; nenhum achado aberto da vigésima segunda avaliação.
- [2026-11-19 — variação do ranking de redes nas mesmas escolas](ciclos/2026-11-19-ranking-variacao-pareada.md#p4--academia-pesquisadora): adotaria (mantido), com a variação do ranking de redes. RF-01 resolvido; nenhum achado aberto da vigésima terceira avaliação.
- [2026-11-19 — versão citável dos índices nos textos](ciclos/2026-11-19-versao-indices-textos.md#p4--academia-pesquisadora): adotaria (mantido). RE-01 e RE-02 resolvidos; nenhum achado aberto da vigésima quarta avaliação.
- [2026-11-19 — lista de escolas pelo IDEB com cobertura](ciclos/2026-11-19-ranking-escolas-cobertura.md#p4--academia-pesquisadora): adotaria (mantido), com a lista de escolas pelo IDEB. RD-01 e RD-02 resolvidos; nenhum achado aberto da vigésima quinta avaliação.
- [2026-11-20 — posição da escola com empate](ciclos/2026-11-20-posicao-escola-empate.md#p4--academia-pesquisadora): adotaria (mantido), agora também com a posição da escola. RC-01 e RC-02 resolvidos; nenhum achado aberto da vigésima sexta avaliação.
- [2026-11-20 — ranking de redes só com escolas em funcionamento](ciclos/2026-11-20-ranking-redes-funcionamento.md#p4--academia-pesquisadora): adotaria (mantido), agora citando o ranking de redes. RB-01 resolvido; nenhum achado aberto da vigésima sétima avaliação.
- [2026-11-21 — painel público da escola](ciclos/2026-11-21-painel-publico-escola.md#p4--academia-pesquisadora): adotaria (mantido), agora também descrevendo a escola pelo painel público. RA-01 a RA-03 resolvidos; nenhum achado aberto da vigésima oitava avaliação.
- [2026-11-21 — folha da base por UF](ciclos/2026-11-21-base-folha-uf.md#p4--academia-pesquisadora): adotaria (mantido), agora com a remuneração em todos os municípios carregados. QZ-01 a QZ-03 resolvidos; nenhum achado aberto da vigésima nona avaliação.
- [2026-11-21 — aviso de anos na base](ciclos/2026-11-21-base-aviso-anos.md#p4--academia-pesquisadora): adotaria (mantido), com a base para a pergunta do perfil. QY-01 resolvido; nenhum achado aberto da trigésima avaliação.
- [2026-11-21 — matrículas na base](ciclos/2026-11-21-base-matriculas.md#p4--academia-pesquisadora): adotaria (mantido), agora com a base para medir a oferta. QX-01 e QX-02 resolvidos; nenhum achado aberto da trigésima primeira avaliação.
- [2026-11-21 — conveniadas](ciclos/2026-11-21-conveniadas.md#p4--academia-pesquisadora): adotaria (mantido), com a oferta da prefeitura somando as conveniadas. QW-01 resolvido; nenhum achado aberto da trigésima segunda avaliação.
- [2026-11-22 — teto das conveniadas](ciclos/2026-11-22-conveniadas-teto.md#p4--academia-pesquisadora): adotaria (mantido). QV-01 e QV-02 resolvidos; nenhum achado aberto da trigésima terceira avaliação.
- [2026-11-22 — sem formação continuada](ciclos/2026-11-22-sem-formacao-continuada.md#p4--academia-pesquisadora): adotaria (mantido), sem a ressalva no perfil docente. QU-01 e QU-02 resolvidos; nenhum achado aberto da trigésima quarta avaliação.
- [2026-11-22 — concursados vazios nas privadas](ciclos/2026-11-22-concursados-privadas.md#p4--academia-pesquisadora): adotaria (mantido), sem a ressalva entre pública e privada. QT-01 e QT-02 resolvidos; nenhum achado aberto da trigésima quinta avaliação.
- [2026-11-23 — rótulos curtos e a privada sem comparação](ciclos/2026-11-23-sobras-concursados.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: o agrupamento fala do indicador do mesmo jeito em toda a tela.
- [2026-11-23 — docentes por etapa](ciclos/2026-11-23-docentes-por-etapa.md#p4--academia-pesquisadora): adotaria (mantido), sem a ressalva em modelos por etapa. QS-01 resolvido; nenhum achado aberto da trigésima sexta avaliação.
- [2026-11-23 — CEP e endereço na base](ciclos/2026-11-23-cep-endereco.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: a cobertura das coordenadas por rede no dicionário.
- [2026-11-23 — taxa de atendimento da educação infantil](ciclos/2026-11-23-taxa-atendimento-infantil.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: a população por idade na base, com fonte e ano.
- [2026-11-23 — taxa de atendimento no ranking de redes](ciclos/2026-11-23-ranking-atendimento.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: o CSV dos municípios sem rodar R.

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas: reavaliada em 2026-11-16 (**adotaria**). Os achados
  RV-01 a RV-05 foram entregues (#440 a #443). BA-01, BA-03 e BA-04 entregues
  (#446). BA-02 entregue no ranking (#447); a base por região fica na
  assinatura (decisão de produto). Quarta rodada (2026-11-16, **adotaria**):
  RG-01 a RG-03, detalhes, entregues (#450 e #451). Nenhum achado aberto. Quinta rodada
  (2026-11-16, **adotaria**): RX-02 entregue (#463) e RX-01 entregue
  (#464). Sexta rodada (2026-11-16, **adotaria**): RY-01 (índices fora da
  base) e RY-02 (versão no nome do CSV) → #465, entregues
  (#466). Sétima rodada
  (2026-11-17, **adotaria**): RZ-01 (índice 0 para escola sem registro) e
  RZ-02 (dicionário da infraestrutura) → #467 (opção A, `indices-v3`),
  entregues (#468). Oitava rodada (2026-11-17, **adotaria**): RW-01 (partes do
  índice de capacitação fora da base) e RW-02 (pesos normativos não ditos),
  → #469, entregues (#470). Nona rodada (2026-11-17, **adotaria**, sem
  a diversidade): RT-01 (parte racial mede a cor não declarada), RT-02
  (partes da diversidade fora da base) e RT-03 (motivo do INSE vazio)
  → #471, entregues (#472). Décima rodada (2026-11-17, **adotaria**, sem o
  atendimento): RS-01 (alunos por sala sem os turnos) e RS-02 (partes do
  atendimento fora da base) → #473, entregues (#474). Décima primeira rodada
  (2026-11-17, **adotaria**): RR-01 e RR-02, detalhes da capacidade gestora
  → #475 (fórmula, `indices-v6`), entregues (#476). Décima segunda rodada (2026-11-17, **adotaria**): RQ-01 (expressão R da
  ajuda errada para a capacidade gestora) e RQ-02 (infraestrutura e
  sustentabilidade sem partes na base) → #477, entregues (#478). Décima terceira rodada (2026-11-17, **adotaria**, sem a
  comparação de redes): RP-01 (escolas fechadas contadas), RP-02 (n e etapa
  do perfil), RP-03 e RP-04 (detalhes) → #479, entregues (#480). Décima quarta rodada (2026-11-17, **adotaria**, sem o
  agrupamento por desempenho): RO-01 (etapas misturadas) e RO-02 (fossa
  como falta) → #481 (modo autônomo), entregues (#482). Décima quinta rodada (2026-11-17, **adotaria**, sem o IDEB
  do perfil): RN-01 (médias de etapas misturadas) e RN-02 (uma etapa só)
  → #483 (modo autônomo), entregues (#484). Décima sexta rodada (2026-11-17, **adotaria**, sem a série
  do SAEB): RM-01 (SAEB só dos anos iniciais) e RM-02 (▲ 0.0) → #485
  (modo autônomo), entregues (#486).
  Décima sétima rodada (2026-11-18, **adotaria**, sem as escolas
  semelhantes do painel): RL-01 (cosseno ignora o nível das notas) e RL-02
  (cartão sem o quanto se parece; ajuda) → #487, entregues (#488).
  Décima oitava rodada (2026-11-18, **adotaria**, sem o IVET): RK-01
  (privacidade dada como motivo do IVET sem os blocos de território) e RK-02
  (ajuda na `ivet-v1.2`, régua de antes da escala log, IVET fora de
  `/fontes`) → #489, entregues (#490); a régua da `ivet-v1.8` volta depois
  da medição no LXC.
  Décima nona rodada (2026-11-18, **adotaria**, sem a folha): RJ-01
  (profissionais contados pelo CPF mascarado), RJ-02 (totais de anos
  diferentes sem o período) e RJ-03 (folha por escola sem saída para
  baixar) → #491, entregues (#492).
  Vigésima rodada (2026-11-18, **adotaria**, sem o grupo de referência do
  perfil): RI-01 (grupo formado com o próprio IDEB), RI-02 (INSE como sinal
  de atenção) e RI-03 (N do grupo no lugar do N com dado) → #493,
  entregues (#494); ficam as escolas similares do Perfil (usam o IDEB).
  Vigésima primeira rodada (2026-11-18, **adotaria**, sem as escolas
  similares do perfil): RH-01 (similares escolhidas pelo IDEB) e RH-02 (só
  as primeiras 299 escolas do município) → #495, entregues (#496).
  Vigésima segunda rodada (2026-11-19, **adotaria**, sem o perfil da rede):
  RG-01 (rede comparada com o Brasil de todas as redes) e RG-02 (grupos da
  rede = último agrupamento gravado) → #497, entregues (#498).
  Vigésima terceira rodada (2026-11-19, **adotaria**, sem a variação do
  ranking de redes): RF-01 (variação compara escolas diferentes) → #499,
  entregue (#500).
  Vigésima quarta rodada (2026-11-19, **adotaria**): RE-01 (versão citável
  dos índices diverge entre os textos) e RE-02 (arquivos da carga
  prometidos e ausentes) → #501, entregues (#502).
  Vigésima quinta rodada (2026-11-19, **adotaria**, sem a lista de escolas
  pelo IDEB para descrever o município): RD-01 (cobertura do IDEB não dita)
  e RD-02 (escolas fora de funcionamento na lista) → #503, entregues
  (#504).
  Vigésima sexta rodada (2026-11-19, **adotaria**, sem a posição da escola):
  RC-01 ("acima de X%" conta os empates como abaixo) e RC-02 (posição do
  IDEB com escolas fora de funcionamento, sem ajuda) → #506, entregues
  (#507).
  Vigésima sétima rodada (2026-11-20, **adotaria**, sem citar o ranking
  de redes): RB-01 (o ranking de redes conta escolas fora de
  funcionamento e não se refaz pela base) → #508, entregue (#509).
  Vigésima oitava rodada (2026-11-21, **adotaria**, sem o painel público
  para descrever a escola): RA-01 (etapas e infraestrutura apagadas que a
  escola tem), RA-02 (matrículas contadas duas vezes, porte sem fonte) e
  RA-03 (cartões sem o empate, ajuda do painel vazia) → #510, entregues
  (#511).
  Vigésima nona rodada (2026-11-21, **adotaria**, com a remuneração só para
  Cuiabá): QZ-01 (ano da folha único para o Brasil, sem dizer quem tem
  folha), QZ-02 (educação infantil sem magistério, motivo não dito) e QZ-03
  (`prof_magisterio` não é o número de professores) → #512, entregues
  (#513).
  Trigésima rodada (2026-11-21, **adotaria**, com a base para a pergunta
  do perfil): QY-01 (cruzamento de anos só dito com edição antiga do IDEB)
  → #514, entregue (#515).
  Trigésima primeira rodada (2026-11-21, **adotaria**, sem a base para
  medir a oferta): QX-01 (a base não traz o número de matrículas) e QX-02
  (comparação de redes junta creche e pré-escola e não exporta) → #516,
  entregues (#517).
  Trigésima segunda rodada (2026-11-21, **adotaria**, com as matrículas,
  sem as conveniadas): QW-01 (creches conveniadas com o poder público na
  rede privada, sem a parceria na base) → #518, entregue (#519).
  Trigésima terceira rodada (2026-11-21, **adotaria**, com a oferta pública
  somando as conveniadas): QV-01 (a soma das conveniadas é um teto, sem
  aviso) e QV-02 (o código da ajuda para no `subset` e a junção perde
  municípios) → #520, entregues (#521).
  Trigésima quarta rodada (2026-11-22, **adotaria**, com ressalva no
  perfil docente): QU-01 ("sem especialização" mede quem não fez formação
  continuada) e QU-02 (duas medidas de formação continuada sem a relação
  dita) → #522, entregues (#523).
  Trigésima quinta rodada (2026-11-22, **adotaria**, com ressalva na
  comparação entre pública e privada): QT-01 (concursados 0 nas privadas,
  onde o Censo não pergunta, no agrupamento, no índice e no ranking) e
  QT-02 (o agrupamento ainda fala `prop_sem_especializacao` e mostra o
  comentário inteiro do banco) → #524, entregues (#525).
  Trigésima sexta rodada (2026-11-22, **adotaria**, com ressalva em
  modelos por etapa): QS-01 (a docência é da escola inteira e mistura as
  etapas, sem os docentes por etapa na base) → #529, entregue (#530).
- Voltar a checar quando houver mais de um Censo carregado (séries) ou base
  nacional (assinatura).

## Entradas

### 2026-11-22 — Base de análise (trigésima sexta rodada, IDEB e formação docente)

**Veredito:** **adotaria** (mantido), com ressalva em modelos por etapa.
Consolidação em
[`avaliacoes/2026-11-22-p4-ideb-docencia.md`](avaliacoes/2026-11-22-p4-ideb-docencia.md).

**O que funcionou:** etapas, docência, IDEB por etapa, INSE e porte numa
leitura só; concursados vazios só nas privadas.

**Barreiras:**
- QS-01 (atrapalha): a docência é da escola inteira; em 1.725 das 5.779
  escolas de SP com IDEB dos anos iniciais há outras etapas (mediana de 55%
  do quadro nos anos iniciais), e o efeito dos concursados vai de +0,02
  para −0,30. Os docentes por etapa existem no banco, mas não na base.

### 2026-11-22 — Agrupamento (trigésima quinta rodada, docência em SP)

**Veredito:** **adotaria** (mantido), com ressalva na comparação entre
pública e privada. Consolidação em
[`avaliacoes/2026-11-22-p4-agrupamento-docencia.md`](avaliacoes/2026-11-22-p4-agrupamento-docencia.md).

**O que funcionou:** o CSV do agrupamento diz a base no nome e nas colunas;
o rótulo "sem formação continuada" chegou ao perfil e ao banco.

**Barreiras:**
- QT-01 (atrapalha): `prop_efetivos` é 0 nas privadas, mas o Censo só
  pergunta o vínculo na escola pública; 92,7% das privadas de SP caem em
  "Baixa"/"Muito baixa qualidade da docência", o índice de capacitação
  docente delas tem teto de 8, e 116 das 136 privadas de Franca ficam na
  metade de baixo do ranking.
- QT-02 (detalhe): o agrupamento ainda usa `prop_sem_especializacao` (a
  base usa `prop_sem_formacao_continuada`), e a tela mostra o comentário
  inteiro do banco como rótulo.

### 2026-11-22 — Análises públicas (trigésima quarta rodada, perfil docente entre regiões)

**Veredito:** **adotaria** (mantido), com ressalva no perfil docente.
Consolidação em
[`avaliacoes/2026-11-22-p4-perfil-docente-regioes.md`](avaliacoes/2026-11-22-p4-perfil-docente-regioes.md).

**O que funcionou:** dez bases (cinco UFs, uma por região, redes municipal
e estadual) juntam pela coluna `regiao`; o dicionário diz o denominador de
cada proporção e a contagem dupla de quem dá aula em duas escolas.

**Barreiras:**
- QU-01 (atrapalha): "docentes sem especialização" vem de
  `qt_doc_bas_espec_nenhum`, que o INEP define como sem formação
  continuada de 80 horas ou mais; em 56% das escolas, pós-graduação + "sem
  especialização" passa de 1. O rótulo está na base, nos perfis da escola
  e da rede, no agrupamento e nas ajudas.
- QU-02 (detalhe): duas medidas de formação continuada (soma de cursos e
  docentes com ao menos um curso) sem a relação dita; 15,5% e 9,5% na rede
  estadual de SP.

### 2026-11-21 — Análises públicas (trigésima terceira rodada, oferta com as conveniadas)

**Veredito:** **adotaria** (mantido), com a oferta pública somando as
conveniadas. Consolidação em
[`avaliacoes/2026-11-21-p4-oferta-conveniadas.md`](avaliacoes/2026-11-21-p4-oferta-conveniadas.md).

**O que funcionou:** o bloco Parceria refaz pela base a conta que antes
pedia o banco (correlação de postos de 0,51 e 25 municípios que mudam 20
posições ou mais, nos 71 de 100 a 500 mil habitantes); com as conveniadas,
a oferta pública de creche fica entre 18 e 25 por mil habitantes em todos
os portes, e o convênio cresce com o porte (29% acima de 500 mil).

**Barreiras:**
- QV-01 (detalhe): a soma das conveniadas é um teto (o Censo marca a
  escola, não a vaga), e nenhum texto diz isso; 9.844 matrículas em creche
  em conveniadas da categoria Particular em SP.
- QV-02 (detalhe): o código da ajuda para no `subset`; o `merge` padrão
  do R deixa só 271 dos 645 municípios de SP.

### 2026-11-21 — Análises públicas (trigésima segunda rodada, creche conveniada)

**Veredito:** **adotaria** (mantido), com as matrículas, sem as
conveniadas. Consolidação em
[`avaliacoes/2026-11-21-p4-creche-conveniada.md`](avaliacoes/2026-11-21-p4-creche-conveniada.md).

**O que funcionou:** o bloco Matrículas lê no R e soma por município com a
linha da ajuda; o total de creche da rede municipal de SP bate com o Censo
(579.970).

**Barreiras:**
- QW-01 (atrapalha): a oferta de creche das prefeituras feita por convênio
  fica na rede privada, e a base não traz a parceria com o poder público.
  Em SP, 41% das matrículas em creche custeadas pelas prefeituras estão em
  conveniadas; Franca tem 0 na rede municipal e 7.758 em 78 conveniadas, e
  vai da 71ª para a 21ª posição entre os 71 municípios de 100 a 500 mil
  habitantes.

### 2026-11-21 — Análises públicas (trigésima primeira rodada, oferta de municípios parecidos)

**Veredito:** **adotaria** (mantido), sem a base para medir a oferta.
Consolidação em
[`avaliacoes/2026-11-21-p4-oferta-municipios.md`](avaliacoes/2026-11-21-p4-oferta-municipios.md).

**Barreiras:**
- QX-01 (atrapalha): a base não traz o número de matrículas, só as etapas
  oferecidas (0 ou 1). Nos 182 municípios da BA de 10 a 20 mil habitantes,
  contar escolas com creche tem correlação de postos de 0,36 com as
  matrículas em creche; Mirante e São José do Jacuípe têm 3 escolas cada e
  106 contra 329 matrículas.
- QX-02 (detalhe): a comparação de redes junta creche e pré-escola na
  "Infantil", um município por vez, sem arquivo.

### 2026-11-21 — Análises públicas (trigésima rodada, IDEB e infraestrutura pela base)

**Veredito:** **adotaria** (mantido), com a base para a pergunta "quanto da
variação do IDEB se associa à infraestrutura, controlando por rede?".
Consolidação em
[`avaliacoes/2026-11-21-p4-ideb-infraestrutura.md`](avaliacoes/2026-11-21-p4-ideb-infraestrutura.md).

**O que funcionou:** a base lê no R com `read.csv2`, o IDEB se refaz (nota
média × rendimento), os seis índices se refazem pelo bloco R da ajuda (0
diferenças em 11.932 escolas), e o modelo dos anos finais roda com 2.271
escolas.

**Barreiras:**
- QY-01 (detalhe): com a edição mais recente do IDEB (2023), a base cruza
  com o Censo 2025 sem aviso; o aviso só aparece com uma edição antiga.
  Preditor medido depois do resultado; 254 de 41.295 escolas com IDEB dos
  anos iniciais fora (0,6%).

### 2026-11-21 — Análises públicas (vigésima nona rodada, remuneração na base de análise)

**Veredito:** **adotaria** (mantido), com a remuneração só para Cuiabá.
Consolidação em
[`avaliacoes/2026-11-21-p4-remuneracao-base.md`](avaliacoes/2026-11-21-p4-remuneracao-base.md).

**Barreiras:**
- QZ-01 (atrapalha): o Ano da folha (SIOPE) é um só para o Brasil (2025),
  e a tela não diz quais municípios da UF têm folha em cada ano. SP
  (Ubatuba, só 2026) e RO (Alta Floresta d'Oeste, só 2024) saem vazios no
  padrão; `/fontes` não tem a lista que a ajuda promete.
- QZ-02 (detalhe): 53 das 167 escolas de Cuiabá com folha são só de
  educação infantil e não têm magistério no SIOPE (auxiliares/assistentes
  educacionais); `prof_magisterio` = 0, salário vazio, motivo não dito.
- QZ-03 (detalhe): `prof_magisterio` conta as pessoas pagas no ano (mediana
  1,59 vez os docentes do Censo; EMEB Ranulpho: 89 no ano, 75 por mês, 37
  docentes).

### 2026-11-21 — Análises públicas (vigésima oitava rodada, painel público da escola)

**Veredito:** **adotaria** (mantido), sem o painel público para descrever a
escola. Consolidação em
[`avaliacoes/2026-11-21-p4-painel-publico.md`](avaliacoes/2026-11-21-p4-painel-publico.md).

**Barreiras:**
- RA-01 (atrapalha): o painel apaga o que a escola tem. Pré-escola (98.010
  escolas) e quadra (72.800) por nomes diferentes entre a resposta e a tela;
  acessibilidade sempre apagada; esgoto por fossa (70.538) e energia de outra
  fonte (3.857) como falta. Amai Pro (29190231): pré-escola na base, apagada
  no painel.
- RA-02 (atrapalha): as matrículas somam a infantil, a EJA e o médio ao
  total que já as contém (Amai Pro: 357 contra 285; 148.190 escolas,
  36.034 mudam de porte); faixas de porte sem fonte; ano do Censo não dito.
- RA-03 (detalhe): os cartões do painel não dizem o empate (#507), e a ajuda
  do painel público não explica blocos, fonte, ano nem ícone apagado.

### 2026-11-20 — Análises públicas (vigésima sétima rodada, refazer o ranking de redes)

**Veredito:** **adotaria** (mantido), sem citar o ranking de redes.
Consolidação em
[`avaliacoes/2026-11-20-p4-refazer-ranking-redes.md`](avaliacoes/2026-11-20-p4-refazer-ranking-redes.md).

**Barreiras:**
- RB-01 (atrapalha): o valor da rede conta escolas paralisadas, extintas ou
  fora do Censo, que a base de análise não traz; 17 das 348 redes da BA não
  se refazem. Mário Campos (MG) fica em 216º de 302 por uma escola
  paralisada com IDEB 3,0 (69º sem ela). A ajuda de rankings não diz.

### 2026-11-19 — Análises públicas (vigésima sexta rodada, posição da escola)

**Veredito:** **adotaria** (mantido), sem a posição da escola. Consolidação
em [`avaliacoes/2026-11-19-p4-posicao-escola.md`](avaliacoes/2026-11-19-p4-posicao-escola.md).

**Barreiras:**
- RC-01 (atrapalha): "acima de X% das escolas" conta as empatadas como
  abaixo (sustentabilidade 0: "acima de 29%" no Brasil; aprovação 100%:
  14.508 escolas "1º, acima de 100%").
- RC-02 (detalhe): a posição do IDEB conta escolas fora de funcionamento
  ("1º de 257" contra 247 na lista) e nenhuma ajuda explica a posição.

### 2026-11-19 — Análises públicas (vigésima quinta rodada, ranking de escolas pelo IDEB)

**Veredito:** **adotaria** (mantido), sem a lista de escolas pelo IDEB para
descrever o município. Consolidação em
[`avaliacoes/2026-11-19-p4-ranking-escolas.md`](avaliacoes/2026-11-19-p4-ranking-escolas.md).

**Barreiras:**
- RD-01 (atrapalha): a lista não diz a cobertura do IDEB (Salvador: 794
  escolas oferecem os anos iniciais, 243 com IDEB; Brasil: 52% das públicas,
  24% das rurais) nem que a falta não é aleatória.
- RD-02 (detalhe): entram escolas paralisadas, extintas ou fora do Censo
  2025 (10 de 257 em Salvador).

### 2026-11-19 — Análises públicas (vigésima quarta rodada, citação dos índices)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-19-p4-citar-indices.md`](avaliacoes/2026-11-19-p4-citar-indices.md).

**Barreiras:**
- RE-01 (atrapalha): a versão citável dos índices é `indices-v6` em
  `/fontes` e no CSV, `indices-v5` na ajuda de rankings e `indices-v2` na
  fórmula completa.
- RE-02 (detalhe): a ajuda manda conferir o SHA-256 dos "arquivos da última
  carga", e nenhuma base pública tem arquivos registrados.

### 2026-11-19 — Análises públicas (vigésima terceira rodada, variação do ranking de redes)

**Veredito:** **adotaria** (mantido), sem a variação do ranking de redes.
Consolidação em
[`avaliacoes/2026-11-19-p4-variacao-redes.md`](avaliacoes/2026-11-19-p4-variacao-redes.md).

**Barreiras:**
- RF-01 (atrapalha): a variação é a média das escolas com IDEB em 2023
  menos a das escolas com IDEB em 2021, conjuntos diferentes (129 de 2.476
  redes com o sinal trocado; São Sebastião da Boa Vista/PA +1,15 na tela,
  +0,03 nas mesmas escolas).

### 2026-11-19 — Análises públicas (vigésima segunda rodada, perfil da rede)

**Veredito:** **adotaria** (mantido), sem o perfil da rede. Consolidação em
[`avaliacoes/2026-11-19-p4-perfil-rede.md`](avaliacoes/2026-11-19-p4-perfil-rede.md).

**Barreiras:**
- RG-01 (atrapalha): a rede filtrada é comparada com o Brasil de todas as
  redes (Salvador, municipal: efetivos +17,6 p.p. na tela, +3,9 p.p. contra
  as redes municipais).
- RG-02 (atrapalha): os "grupos de contexto parecido" são o último
  agrupamento gravado (k-means de infraestrutura, só no ES; Salvador inteira
  em "Sem cluster").

### 2026-11-18 — Análises públicas (vigésima primeira rodada, escolas similares do perfil)

**Veredito:** **adotaria** (mantido), sem as escolas similares do perfil.
Consolidação em
[`avaliacoes/2026-11-18-p4-similares-perfil.md`](avaliacoes/2026-11-18-p4-similares-perfil.md).

**Barreiras:**
- RH-01 (atrapalha): as similares são escolhidas pelos indicadores do perfil,
  inclusive o IDEB (correlação 0,97 entre o IDEB da escola e a mediana das
  similares, 37 escolas de Salvador).
- RH-02 (atrapalha): só as primeiras 299 escolas do município entram (São
  Paulo: similares só entre os INEPs 35000243 e 35044428).

### 2026-11-18 — Análises públicas (vigésima rodada, grupo de referência do perfil)

**Veredito:** **adotaria** (mantido), sem o grupo de referência do perfil.
Consolidação em
[`avaliacoes/2026-11-18-p4-grupo-referencia.md`](avaliacoes/2026-11-18-p4-grupo-referencia.md).

**Barreiras:**
- RI-01 (atrapalha): o grupo "de contexto parecido" é um k-means sobre os
  indicadores comparados, inclusive IDEB, nota e INSE; correlação 0,83 entre
  o IDEB da escola e a mediana do grupo (37 escolas de Salvador).
- RI-02 (atrapalha): o INSE vira sinal de atenção (13 de 38 escolas).
- RI-03 (detalhe): o N da distribuição é o tamanho do grupo (IDEB N = 436
  num município com 417 escolas com IDEB).

### 2026-11-18 — Análises públicas (décima nona rodada, folha de pagamento)

**Veredito:** **adotaria** (mantido), sem a folha. Consolidação em
[`avaliacoes/2026-11-18-p4-folha.md`](avaliacoes/2026-11-18-p4-folha.md).

**Barreiras:**
- RJ-01 (atrapalha): "Profissionais (total)" conta pelo CPF mascarado, que
  junta pessoas diferentes (Cuiabá 2025: −4,1%; Alta Floresta 2024: −11,4%).
- RJ-02 (atrapalha): o custo total e por categoria somam 2025 e dois meses
  de 2026, com o 13º, sem dizer o período.
- RJ-03 (atrapalha): a folha por escola não se baixa; "salário docente ×
  IDEB" só sai por SQL (r = 0,23 em 50 escolas de Cuiabá).

### 2026-11-18 — Análises públicas (décima oitava rodada, IVET)

**Veredito:** **adotaria** (mantido), sem o IVET. Consolidação em
[`avaliacoes/2026-11-18-p4-ivet.md`](avaliacoes/2026-11-18-p4-ivet.md).

**Barreiras:**
- RK-01 (atrapalha): o painel diz "não é publicável (amostra insuficiente ou
  dado sensível)" quando só falta o bloco C, D ou E; esconde o bloco A.
- RK-02 (atrapalha): a ajuda está na `ivet-v1.2`, com a régua de leitura de
  antes da escala logarítmica; o IVET não está em `/fontes`.

### 2026-11-18 — Análises públicas (décima sétima rodada, escolas semelhantes)

**Veredito:** **adotaria** (mantido), sem as escolas semelhantes do painel.
Consolidação em
[`avaliacoes/2026-11-18-p4-escolas-semelhantes.md`](avaliacoes/2026-11-18-p4-escolas-semelhantes.md).

**Barreiras:**
- RL-01 (atrapalha): o cosseno das seis notas junta escolas de níveis
  diferentes (CEIFAR, de Salvador, tem como "mais parecida" uma escola 2 a
  3 pontos abaixo em todas as notas).
- RL-02 (detalhe): o cartão não diz o quanto a vizinha se parece, e a ajuda
  descreve outro critério.

### 2026-11-17 — Análises públicas (décima sexta rodada, evolução da escola)

**Veredito:** **adotaria** (mantido), sem a série do SAEB. Consolidação em
[`avaliacoes/2026-11-17-p4-evolucao-saeb.md`](avaliacoes/2026-11-17-p4-evolucao-saeb.md).

**Barreiras:**
- RM-01 (atrapalha): a série do SAEB é só dos anos iniciais, sem dizer, e
  falta para 18.533 escolas.
- RM-02 (detalhe): série de uma edição mostra "▲ 0.0".

### 2026-11-17 — Análises públicas (décima quinta rodada, IDEB do perfil)

**Veredito:** **adotaria** (mantido), sem o IDEB do perfil. Consolidação em
[`avaliacoes/2026-11-17-p4-perfil-ideb-etapa.md`](avaliacoes/2026-11-17-p4-perfil-ideb-etapa.md).

**O que tentou:**
- O perfil de uma escola como estudo de caso, comparando o IDEB com o do
  Brasil, do município, da rede e do grupo.

**Barreiras:**
- RN-01 (atrapalha): as médias de comparação misturam etapas ("Brasil"
  5,33 contra 4,74 nos anos finais).
- RN-02 (detalhe): o perfil mostra só a etapa de maior nota.

### 2026-11-17 — Análises públicas (décima quarta rodada, agrupamento por desempenho)

**Veredito:** **adotaria** (mantido), sem o agrupamento por desempenho.
Consolidação em
[`avaliacoes/2026-11-17-p4-agrupamento-desempenho.md`](avaliacoes/2026-11-17-p4-agrupamento-desempenho.md).

**O que tentou:**
- Usar o agrupamento por "Desempenho dos alunos" do ES como tipologia.

**O que funciona para ela:**
- a execução guardada, com CSV, que permitiu conferir os grupos.

**Barreiras:**
- RO-01 (atrapalha): o agrupamento mistura as etapas e separa a etapa
  oferecida ("Alto" com IDEB menor que "Baixo").
- RO-02 (detalhe): o agrupamento por infraestrutura conta fossa como falta.

### 2026-11-17 — Análises públicas (décima terceira rodada, comparação de redes)

**Veredito:** **adotaria** (mantido), sem a comparação de redes.
Consolidação em
[`avaliacoes/2026-11-17-p4-comparar-redes.md`](avaliacoes/2026-11-17-p4-comparar-redes.md).

**O que tentou:**
- Comparar as redes de Salvador em `/municipio/compare` e
  `/municipio/perfil`, conferindo com a base.

**O que funciona para ela:**
- docentes, proporções e IDEB por rede batem com a base.

**Barreiras:**
- RP-01 (atrapalha): a comparação conta escolas paralisadas e extintas
  (+16% no Brasil; Formoso, MG: 56 contra 4).
- RP-02 (atrapalha): o perfil não diz em quantas escolas cada média se
  apoia, e o IDEB mistura etapas.
- RP-03 e RP-04 (detalhes): n da linha do IDEB e ajuda antiga.

### 2026-11-17 — Análises públicas (décima segunda rodada, partes dos índices)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-partes-dos-indices.md`](avaliacoes/2026-11-17-p4-partes-dos-indices.md).

**O que tentou:**
- "Quanto do IDEB se associa à infraestrutura, controlando por rede?", com
  as partes de todos os índices (BA e MG, 32 mil escolas).
- Refazer os seis índices com as expressões da ajuda.

**O que funciona para ela:**
- `indices-v6` em todo lugar; quatro índices se refazem pela base;
- as partes mostram o acesso ao cargo associado ao IDEB ao contrário do
  peso.

**Barreiras:**
- RQ-01 (atrapalha): a expressão R da ajuda para a capacidade gestora erra
  por até 4,1 pontos (precedência do `!`).
- RQ-02 (atrapalha): a infraestrutura e a sustentabilidade não se
  decompõem pela base, e a ajuda não diz quais índices se refazem.

### 2026-11-17 — Análises públicas (décima primeira rodada, capacidade gestora)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-gestora.md`](avaliacoes/2026-11-17-p4-gestora.md).

**O que tentou:**
- Fechar a revisão dos seis índices, procurando dado ausente que vira valor.

**O que funciona para ela:**
- a lotação por turno e as partes do atendimento;
- infraestrutura, sustentabilidade e colegiados sem resposta vazia.

**Barreiras:**
- RR-01 (detalhe): a escola sem matrícula conta 0 em "gestores por aluno"
  (1.774 escolas).
- RR-02 (detalhe): "acesso ao cargo" vale 0 em toda privada, por
  construção.

### 2026-11-17 — Análises públicas (décima rodada, oferta e turnos)

**Veredito:** **adotaria** (mantido), sem o índice de capacidade de
atendimento. Consolidação em
[`avaliacoes/2026-11-17-p4-oferta-e-turnos.md`](avaliacoes/2026-11-17-p4-oferta-e-turnos.md).

**O que tentou:**
- "Municípios de porte semelhante têm oferta parecida?", com o índice de
  capacidade de atendimento.
- Abrir o método e recalcular a lotação por turno.

**O que funciona para ela:**
- a diversidade corrigida e as partes na base;
- o porte na base e no ranking.

**Barreiras:**
- RS-01 (atrapalha): "alunos por sala" ignora os turnos. 14.673 das
  16.220 escolas com 0 nessa parte têm menos de 35 alunos por turno.
- RS-02 (atrapalha): as partes do índice de atendimento não estão na base.

### 2026-11-17 — Análises públicas (nona rodada, regiões e diversidade)

**Veredito:** **adotaria** (mantido), sem o índice de diversidade.
Consolidação em
[`avaliacoes/2026-11-17-p4-regioes-e-diversidade.md`](avaliacoes/2026-11-17-p4-regioes-e-diversidade.md).

**O que tentou:**
- Perfil docente por região, com SP, BA, RS, PA e GO (72.151 escolas).
- O modelo do IDEB com os seis índices e as partes da capacitação.
- Entender por que a diversidade sai negativa.

**O que funciona para ela:**
- cinco UFs baixadas em segundos;
- as partes da capacitação, que mostram o efeito dos efetivos mudando de
  sinal entre regiões.

**Barreiras:**
- RT-01 (atrapalha): a parte racial do índice de diversidade mede a cor não
  declarada (correlação 0,78; 0,99 com mais de 80% não declarada).
- RT-02 (atrapalha): as partes do índice de diversidade não estão na base.
- RT-03 (detalhe): o dicionário não diz por que o INSE é vazio (63% da
  base).

### 2026-11-17 — Análises públicas (oitava rodada, índice vazio sem registro)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-indices-v3.md`](avaliacoes/2026-11-17-p4-indices-v3.md).

**O que tentou:**
- Conferiu o vazio dos índices contra o registro de docentes e matrículas.
- Refez a comparação das redes municipais e o modelo do IDEB.
- Tentou decompor o índice de capacitação docente com a base.

**O que funciona para ela:**
- vazio só onde falta o registro, e o 0 de volta a ser nota;
- `indices-v3` em `/fontes`, no arquivo e na coluna.

**Barreiras:**
- RW-01 (atrapalha): o índice de capacitação junta partes de sinais
  opostos no modelo (licenciatura +0,34, efetivos −0,30), e a base não traz
  as partes para separá-lo.
- RW-02 (detalhe): a ajuda não diz que os pesos são uma escolha do EduMaps.

### 2026-11-17 — Análises públicas (sétima rodada, índices na base)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-indices-na-base.md`](avaliacoes/2026-11-17-p4-indices-na-base.md).

**O que tentou:**
- Baixou a BA e o ES com os seis índices e conferiu com o ranking.
- Pôs os índices no modelo do IDEB.
- Comparou as redes municipais pela capacitação docente.

**O que funciona para ela:**
- os índices no arquivo da UF, com a versão no nome e na linha;
- a base igual ao ranking escola a escola;
- o índice de infraestrutura associado ao IDEB (0,084 por ponto,
  p < 0,001), onde a contagem básica não se associa.

**Barreiras:**
- RZ-01 (atrapalha): 312 escolas sem registro de docentes e matrículas
  ficam com 0, não vazio. Elas baixam médias municipais em até 2 pontos e
  ficam no fim do ranking de escolas.
- RZ-02 (detalhe): o dicionário da infraestrutura aponta para uma coluna
  que não está na base.

### 2026-11-16 — Análises públicas (sexta rodada, seleção do IDEB e versão dos índices)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-16-p4-versao-e-selecao.md`](avaliacoes/2026-11-16-p4-versao-e-selecao.md).

**O que tentou:**
- Refez a seleção do IDEB só com a base (BA e ES) e modelou "tem IDEB".
- Citou o índice de diversidade com a versão.
- Tentou pôr o índice de infraestrutura do EduMaps no modelo.

**O que funciona para ela:**
- as etapas oferecidas e o exemplo da ajuda, que se reproduz;
- a versão `indices-v2` em `/fontes`, na tela e no CSV, com o histórico.

**Barreiras:**
- RY-01 (atrapalha): os índices não estão na base de análise, só no ranking
  de um município por vez.
- RY-02 (detalhe): o nome do CSV do ranking de escolas não traz a versão.

### 2026-11-16 — Análises públicas (quinta rodada, índices e cobertura do IDEB)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-16-p4-indices-e-cobertura.md`](avaliacoes/2026-11-16-p4-indices-e-cobertura.md).

**O que tentou:**
- Juntou a BA e o ES (19.152 escolas, com a coluna `regiao`).
- Refez o modelo do IDEB com a infraestrutura básica.
- Montou os pontos com as coordenadas.
- Tentou citar a diversidade corrigida hoje.

**O que funciona para ela:**
- a região, as coordenadas e o "sem" que é "sem";
- o método de cada índice, com a data da correção.

**Barreiras:**
- RX-02 (atrapalha): o IDEB falta sobretudo nas escolas sem infraestrutura
  (12,7% contra 44,3% com nota), e a base não traz as etapas oferecidas
  para separar a falta da não oferta.
- RX-01 (atrapalha): os índices próprios não têm versão citável nem lugar
  em `/fontes`.


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
