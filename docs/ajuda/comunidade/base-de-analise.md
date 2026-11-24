---
titulo: "Base de análise: indicadores por escola para baixar"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [rankings, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/base-de-analise.md
ultima_revisao: 2026-11-24
---

# Base de análise: indicadores por escola para baixar

> **Para quem:** quem quer cruzar indicadores das escolas numa planilha ou num programa de estatística
> **Tempo de leitura:** ~3 min

## Em 30 segundos
A página **Base de análise** (botão na página inicial, ou `/base-analise`)
gera uma planilha com **uma linha por escola em funcionamento** e os
indicadores que você escolher. Cada arquivo diz de que ano são os dados, e o
**dicionário** explica cada coluna. Não precisa de login.

## Passo a passo
1. **Recorte:** escolha a **UF** (a base sai uma UF por vez). Se quiser,
   restrinja a um **município** e a uma **rede** (pública, municipal,
   estadual, federal ou privada). A página mostra quantas escolas entram.
2. **Indicadores:** a **identificação** (INEP, nome, município, UF, região,
   rede, localização urbana ou rural, latitude, longitude, CEP, bairro e
   endereço) vem sempre.
   Marque os blocos que quiser:
   - **Etapas oferecidas:** se a escola oferece creche, pré-escola, anos
     iniciais (`oferece_ai`), anos finais (`oferece_af`), ensino médio
     (`oferece_em`, inclusive integrado e normal), EJA e educação
     profissional, e se tem classe especial exclusiva (1 = sim, 0 = não);
   - **Matrículas:** quantos alunos a escola tem na educação básica
     (`mat_basica`) e em cada etapa (`mat_creche`, `mat_pre`, `mat_ai`,
     `mat_af`, `mat_medio`, `mat_profissional`, `mat_eja`), na educação
     especial (`mat_especial`) e em tempo integral (`mat_integral`), do mesmo
     Censo;
   - **Parceria com o poder público:** se a escola tem convênio com o poder
     público para custear o atendimento (`parceria_poder_publico`, 1 = sim),
     com qual esfera (`parceria_esfera`: Municipal, Estadual ou Estadual e
     municipal) e a categoria da escola privada (`categoria_privada`:
     Particular, Comunitária, Confessional ou Filantrópica);
   - **Infraestrutura:** água, energia, esgoto, lixo, banheiro, biblioteca,
     laboratórios, quadra, internet e rampas (1 = tem, 0 = não tem), e se a
     escola **não tem** água, energia ou esgoto (`_inexistente`, 1 = não
     tem);
   - **Docência:** número de docentes e as proporções com licenciatura,
     mestrado, doutorado e concursados, a de docentes **sem formação
     continuada** (`prop_sem_formacao_continuada`), e as com ensino
     superior, pós-graduação e formação continuada, que são as partes do
     índice de capacitação docente, e os docentes por etapa
     (`qt_docentes_infantil`, `qt_docentes_ai`, `qt_docentes_af` e
     `qt_docentes_em`). As proporções são da escola inteira: veja
     [Docência num modelo por etapa](#docência-num-modelo-por-etapa);
   - **IDEB e SAEB por etapa:** IDEB, notas e aprovação nos anos iniciais
     (`_ai`), nos anos finais (`_af`) e no ensino médio (`_em`), na edição que
     você escolher;
   - **Índices do EduMaps:** os seis índices de 0 a 10 do ranking de
     escolas (`indice_infraestrutura`, `indice_capacidade_atendimento`,
     `indice_capacitacao_docente`, `indice_diversidade_discente`,
     `indice_capacidade_gestora` e `indice_sustentabilidade`), com a versão
     da fórmula na coluna `versao_indice`. O dicionário traz o método de
     cada um;
   - **Nível socioeconômico (INSE):** a média e o nível, da edição mais
     recente do SAEB;
   - **Porte do município:** a população estimada pelo IBGE, a classe de
     tamanho e as crianças de 0 a 3 e de 4 e 5 anos, do Censo Demográfico
     de 2022;
   - **Remuneração (SIOPE):** a folha que o município declara ao SIOPE,
     somada por escola no ano escolhido (só a rede municipal; veja abaixo).
     Com o bloco marcado, a tela diz que municípios da UF têm a folha, em que
     anos e com quantos meses, e quantas escolas do recorte têm folha no ano
     escolhido; se nenhuma tiver, avisa e diz os anos que têm.
3. **Baixar:** **Baixar base (CSV)** gera a planilha; **Baixar dicionário das
   colunas** gera a lista das colunas com a descrição, a fonte, o ano e o
   link oficial. O endereço da página guarda as escolhas, então o link
   reabre a mesma base. Mas o link traz sempre a **carga mais recente**:
   depois de uma carga nova do Censo, o mesmo link dá outros números. Para
   citar, guarde o **arquivo**: os anos estão no nome e nas últimas colunas.

## Entendendo os números
- **Ausência é célula vazia, nunca zero.** Escola sem IDEB numa etapa (porque
  não oferece a etapa ou não teve nota publicada) fica com a célula vazia.
  Para separar os dois casos, marque **Etapas oferecidas**: `oferece_ai = 1`
  com `ideb_ai` vazio é "oferece e não teve nota".
- **Quem fica sem IDEB.** O IDEB só é publicado para as escolas com
  participação suficiente no SAEB, e a falta não é aleatória: as escolas
  pequenas, as rurais e as sem infraestrutura ficam de fora com muito mais
  frequência.
  - **Exemplo:** entre as escolas públicas da BA e do ES que oferecem anos
    iniciais, 12,7% das que não têm algum item básico (água, energia,
    esgoto ou banheiro) têm IDEB 2023, contra 44,3% das completas.
  - **O efeito:** um modelo do IDEB que use só as escolas com nota quase não
    vê as escolas sem infraestrutura, e a associação some por seleção.
  - **Antes de modelar,** compare quem tem IDEB entre os grupos. No R:
    `base$tem_ideb <- !is.na(base$ideb_ai)` e
    `with(subset(base, oferece_ai == 1), tapply(tem_ideb, in_agua_inexistente, mean))`.
- **Versão dos dados:** as últimas colunas (`ano_censo`, `ano_ideb`,
  `ano_inse`, `ano_populacao`, `ano_populacao_idade`) repetem em toda linha o ano de cada base, e o
  nome do arquivo também leva os anos (ex.:
  `base-analise-ES-censo2025-ideb2023.csv`). Guardado ou renomeado, o arquivo
  continua dizendo de onde veio.
- **Matrículas:** use o número, e não as etapas oferecidas, para medir a
  oferta. Contar as escolas que oferecem a etapa engana: em Mirante e em
  São José do Jacuípe (BA, cerca de 10.500 habitantes cada), 3 escolas
  municipais oferecem creche, com 106 e 329 matrículas em creche.
  - **As etapas não somam o total:** a educação profissional repete
    matrículas que também estão no médio (o médio integrado), e a educação
    especial atravessa as etapas. Para o total, use `mat_basica`.
  - **0 é 0;** vazio é a escola sem linha de matrículas no Censo.
  - **Para somar por município** (no R), junto com o porte e a região:
    `aggregate(cbind(mat_creche, mat_pre) ~ codigo_ibge + municipio + porte_municipio + regiao, data = base, FUN = sum)`
    (marque também o bloco **Porte do município**).
  - **Taxa de atendimento:** some as matrículas em creche (ou na
    pré-escola) do município e divida por `populacao_0_3` (ou
    `populacao_4_5`), do bloco **Porte do município**. A conta está em
    **Taxa de atendimento da educação infantil no R**, abaixo.
    - **A população é do Censo Demográfico de 2022,** e as matrículas, do
      Censo Escolar mais recente (`ano_populacao_idade` e `ano_censo`).
    - **A taxa pode passar de 100%:** entram crianças de outros municípios
      e fora da idade.
    - **É uma taxa bruta de matrícula,** e não o indicador oficial da meta
      1 do PNE, que mede o percentual das crianças da idade que frequentam
      creche ou escola, em pesquisa domiciliar. Os números podem diferir.
  - **Creches conveniadas:** parte da oferta de creche das prefeituras é
    feita por convênio com escolas privadas, que ficam na rede privada. Em
    SP, das matrículas em creche da rede municipal mais as das conveniadas
    com a prefeitura, 41% estão nas conveniadas. No **Distrito Federal**,
    sem prefeitura, o convênio é com o governo distrital, e a base mostra
    `parceria_esfera` = "Estadual": para a oferta pública do DF, some a
    rede estadual (a distrital) às privadas com essa parceria.
    - **Exemplo:** Franca (SP) tem 0 matrícula em creche na rede municipal
      e 7.758 em 78 escolas privadas conveniadas com a prefeitura.
    - **A soma é um teto.** O Censo marca a escola conveniada, não a vaga:
      uma conveniada pode ter também alunos pagantes. Somar as matrículas
      dela dá o máximo da oferta conveniada. O caso mais provável de
      mistura são as conveniadas da categoria **Particular** (em SP, 155
      escolas com creche e 9.844 matrículas, 2,4% das conveniadas); nas
      comunitárias e filantrópicas a soma deve ficar perto do real.
    - **Para a oferta da prefeitura,** baixe a rede municipal (blocos
      **Matrículas** e **Porte do município**) e a rede privada (blocos
      **Matrículas** e **Parceria com o poder público**) e some as
      conveniadas com a prefeitura à rede municipal. O código no R está em
      [Taxa de atendimento da educação infantil no R](#taxa-de-atendimento-da-educação-infantil-no-r).
    - **Escolas públicas também têm parceria** (sobretudo na educação
      profissional): para a oferta conveniada, filtre a rede privada.
- **Remuneração (SIOPE):** uma linha por escola, sem nomes nem CPF, no ano
  escolhido em **Ano da folha (SIOPE)**. O padrão é o último ano completo
  (12 meses) **da UF escolhida**; sem ano completo, o mais recente da UF. Cada
  município carregou anos diferentes: em SP, por exemplo, a folha é só de
  2026, e a base de SP sai com 2026.
  O ano vai na coluna `ano_siope` e no nome do arquivo (`-siope2025`).
  - `prof_magisterio`: os profissionais do magistério pagos no ano. Cada
    pessoa conta uma vez: a chave é o CPF mascarado **e** o nome, porque o
    SIOPE publica só seis dígitos do CPF e pessoas diferentes caem no mesmo
    CPF mascarado. **Não é o número de docentes:** conta todo mundo que
    recebeu no ano, inclusive quem esteve na escola só parte dele. Em Cuiabá
    (2025), a mediana é 1,6 vez os docentes do Censo (`qt_docentes`).
  - `prof_magisterio_mes`: a média de profissionais do magistério por mês com
    folha. É o número mais perto dos docentes do Censo, mas ainda inclui quem
    está na escola sem dar aula (coordenação, apoio).
  - `aux_educacional`, `aux_educacional_mes` e
    `salario_medio_aux_educacional`: os auxiliares e assistentes educacionais
    (categoria "Auxiliar/Assistente Educacional" do SIOPE), no ano, por mês e
    o salário médio mensal sem dezembro. Na educação infantil, podem ser
    quem trabalha com as crianças: em Cuiabá, as creches não têm ninguém no
    magistério na folha, só auxiliares.
  - `salario_medio_magisterio`, `carga_horaria_media_magisterio` e
    `salario_40h_magisterio`: médias por pessoa e por mês, **sem dezembro**
    (que traz o 13º). Quem tem dois vínculos na escola no mesmo mês tem os
    salários e as cargas somados. O salário para 40 horas é salário ÷ carga
    × 40, para comparar escolas com jornadas diferentes.
  - `gasto_pessoal_ano`: todo o salário pago na escola no ano, do magistério
    e dos demais profissionais, **com** o 13º. Com `meses_folha` menor que
    12, é o gasto só desses meses.
  - `gasto_fundeb_70_ano`, `gasto_fundeb_30_ano` e
    `gasto_outras_fontes_ano`: o `gasto_pessoal_ano` dividido pela fonte do
    dinheiro, como o município declara ao SIOPE em cada pagamento (a parcela
    de 70% do Fundeb, a de 30% e as outras fontes). As três somam o
    `gasto_pessoal_ano`, em reais inteiros, com diferença de arredondamento de
    até 2 reais. Não
    é a verificação do mínimo de 70% da lei, que usa a receita do Fundeb do
    município (fora da base). A folha da Secretaria, sem escola, não entra.
  - **Vazio:** escola fora da rede municipal, município sem folha nesse ano,
    ou município em que o SIOPE só traz o total da Secretaria, sem separar as
    escolas. A cobertura é pequena (poucos municípios carregados) e não é uma
    amostra: a lista, com os anos de cada município, está em
    [Fontes e metodologia](fontes-e-metodologia.md). No R:
    `base[!is.na(base$prof_magisterio), ]` antes de modelar.
  - **`prof_magisterio` = 0 e o salário vazio:** a escola tem folha, mas
    ninguém no magistério. É o caso das creches em que a folha só traz
    auxiliares e assistentes educacionais (veja `aux_educacional`); o Censo
    costuma dar 0 docentes a essas escolas também. Não é falta de dado: tire
    essas escolas antes de modelar o salário do magistério.
- **Índices do EduMaps:** são calculados por nós a partir do Censo Escolar,
  não pelo INEP. Os seis se refazem com as partes que estão na base, pelo
  [bloco R abaixo](#refazer-os-seis-índices-no-r). Cite com a
  versão (`versao_indice`, ex.: `indices-v7`, que também vai no nome do
  arquivo): notas de versões diferentes não são comparáveis, e o histórico
  está em [Fontes e metodologia](fontes-e-metodologia.md). Logo depois de
  uma carga nova do Censo, as células dos índices podem ficar vazias até o
  recálculo. A regra "vazio, nunca zero" vale também aqui: a escola sem
  matrículas, docentes ou gestores no Censo fica com a célula vazia no
  índice que depende desse registro (o dicionário diz qual). Para comparar
  médias entre municípios, não troque o vazio por 0. Para a **infraestrutura básica** (0 a 4) do ranking, some os
  itens da base, no R:
  `with(base, (1 - in_agua_inexistente) + (1 - in_energia_inexistente) + (1 - in_esgoto_inexistente) + in_banheiro)`.
- **IDEB e Censo de anos diferentes:** só o Censo Escolar mais recente está
  carregado (hoje, 2025), e o IDEB sai a cada dois anos (o mais recente é
  2023). Então o IDEB é **sempre** cruzado com uma lista de escolas, uma
  infraestrutura e uma docência de outro ano, inclusive na edição mais
  recente, que é a padrão. A página e o dicionário (`ano_ideb`) avisam e
  dizem a distância em anos. Para quem modela:
  - **o preditor vem depois do resultado:** explicar o IDEB de 2023 pela
    infraestrutura de 2025 usa uma medida tirada dois anos depois da prova.
    Diga isso no texto e, se puder, teste a robustez (por exemplo, só com
    itens que mudam pouco, como água, energia e esgoto);
  - **as escolas fechadas depois da edição não entram:** no Brasil, 254 das
    41.295 escolas com IDEB dos anos iniciais em 2023 não estão em
    funcionamento no Censo 2025 (0,6%); com uma edição antiga, são mais;
  - **o INSE é da mesma edição do SAEB** do IDEB mais recente (2023), e o
    dicionário (`ano_inse`) diz quando não é;
  - para uma série de anos, cada ano precisaria do seu Censo.
- **"Rede pública = 0" não quer dizer "sem".** `in_energia_rede_publica = 0`
  pode ser gerador ou energia renovável; `in_esgoto_rede_publica = 0` pode
  ser fossa; `in_agua_potavel = 0` pode ser água não potável. Para contar as
  escolas **sem** o serviço, use `in_agua_inexistente`,
  `in_energia_inexistente` e `in_esgoto_inexistente`. No Piauí, por exemplo,
  2.725 escolas têm esgoto fora da rede pública, e 179 não têm esgoto
  nenhum.
- **Coordenadas:** `latitude` e `longitude` em graus decimais, com 6 casas,
  como a escola declarou ao Censo Escolar, sem verificação. Cerca de 4 em 5
  escolas têm; nas outras, a célula fica vazia. A falta é bem maior nas
  **privadas** (cerca de 1 em cada 3 no Brasil, contra 16% das municipais e
  12% das estaduais): uma lista de concorrentes só pela coordenada deixa
  muitas privadas de fora. Veja
  [Escolas próximas](#escolas-próximas). Para um mapa, no R:
  `sf::st_as_sf(na.omit(base[, c("inep", "latitude", "longitude")]),
  coords = c("longitude", "latitude"), crs = 4326)`; no Python, com
  `geopandas.points_from_xy(base.longitude, base.latitude)`.
- **Endereço:** `cep` no formato `00000-000` (com o hífen, o Excel não tira
  o zero do começo), `bairro` e `endereco` (logradouro e número, sem o
  número quando a escola declarou S/N), como declarados ao Censo Escolar.
  Toda escola tem CEP. O bairro falta em cerca de 6 em cada 10 escolas
  rurais.
- **Docência:** as proporções são sobre o total de docentes da escola
  (`qt_docentes`). Na contagem do Censo Escolar, quem dá aula em mais de uma
  escola conta em cada uma.
- **As partes do índice de diversidade discente** (bloco Índices do
  EduMaps):
  - **as quatro partes:** `diversidade_racial` (35%), `equilibrio_genero`
    (25%), `prop_educacao_especial_cc` (20%) e `prop_eja` (20%);
  - **`prop_cor_nao_declarada`:** com metade ou mais das matrículas sem cor
    declarada, `diversidade_racial` fica vazia e o peso dela vai para as
    outras três;
  - **para refazer o índice no R:** `refeito_diversidade_discente`, no
    [bloco R abaixo](#refazer-os-seis-índices-no-r);
  - **para modelar, use as partes:** a inclusão e a cor/raça podem ir em
    sentidos opostos.
- **As partes do índice de capacidade de atendimento** (bloco Índices do
  EduMaps):
  - **as quatro partes:** `alunos_sala_turno` (40%, matrículas ÷ salas ×
    `turnos`), `etapas_regulares` (20%, de 7), `prop_tempo_integral` (20%)
    e `alimentacao` (20%);
  - **as etapas:** `etapas_regulares` conta as etapas do ensino regular do
    Censo, que não são a soma das colunas `oferece_*`;
  - **para refazer o índice no R:** `refeito_capacidade_atendimento`, no
    [bloco R abaixo](#refazer-os-seis-índices-no-r).
- **As partes do índice de capacidade gestora** (bloco Índices do
  EduMaps):
  - **as cinco partes:** `gestores_formacao` (30%, média entre superior e
    pós-graduação), `prop_gestores_espec_gestao` (20%), `alunos_por_gestor`
    (20%, a parte vale 10 com 200 alunos ou menos por gestor),
    `orgaos_colegiados` (20%, de 5) e `prop_acesso_cargo_selecao` (10%,
    concurso, eleição ou processo seletivo);
  - **partes vazias:** `alunos_por_gestor` fica vazia sem matrículas, e
    `prop_acesso_cargo_selecao` nas privadas, onde o gestor é escolhido pela
    mantenedora. A parte vazia fica de fora, e o peso dela vai para as
    outras;
  - **para refazer o índice no R:** `refeito_capacidade_gestora`, no
    [bloco R abaixo](#refazer-os-seis-índices-no-r);
  - **para comparar pública com privada,** deixe o acesso ao cargo de fora:
    ele só existe na rede pública.
- **INSE vazio:** o INSE só existe para as escolas com alunos avaliados no
  SAEB. As privadas nunca têm, e as creches e pré-escolas quase nunca:
  cerca de 60% das escolas de uma UF ficam sem. Entre as escolas com IDEB,
  quase todas têm INSE.
- **As partes do índice de capacitação docente:**
  - **as quatro partes:** `prop_superior` (30%), `prop_pos_graduacao` (30%),
    `prop_efetivos` (20%) e `prop_formacao_continuada` (20%);
  - **concursados só na rede pública:** o Censo só pergunta o vínculo do
    docente (concursado, contrato, terceirizado ou CLT) na escola pública.
    Na privada, `prop_efetivos` fica vazia, e no índice o peso dela vai para
    as outras três partes (o índice é a soma das três dividida por 0,8).
    Até a `indices-v6`, a coluna vinha 0 e a privada ficava com no máximo 8.
    Num modelo que junta públicas e privadas, deixe os concursados de fora
    ou separe as redes;
  - **o limite a 1:** a pós-graduação e a formação continuada são limitadas a
    1, como no índice. No Censo, quem tem mais de uma pós ou formação conta
    mais de uma vez;
  - **para refazer o índice no R:** `refeito_capacitacao_docente`, no
    [bloco R abaixo](#refazer-os-seis-índices-no-r);
  - **para modelar, use as partes:** elas podem se associar ao resultado em
    sentidos opostos, e o índice soma todas com peso positivo.
- **Formação continuada não é especialização:**
  - **`prop_sem_formacao_continuada`** é a proporção de docentes que não
    fizeram nenhum curso de formação continuada de no mínimo 80 horas (o
    Censo pergunta por "outros cursos"). A pós-graduação, inclusive a
    especialização, está em `prop_pos_graduacao`. Uma escola pode ter
    muitos professores com pós e, ao mesmo tempo, muitos sem formação
    continuada: na rede estadual de SP, 32% têm pós e 91% não declararam
    formação continuada;
  - **o nome antigo:** até novembro de 2026 a coluna se chamava
    `prop_sem_especializacao`, e o rótulo dizia "sem especialização", o que
    estava errado. Scripts com o nome antigo dão erro de coluna
    inexistente: troque pelo nome novo;
  - **cursos ou pessoas:** `prop_formacao_continuada` soma os cursos e
    divide pelos docentes, então quem fez dois cursos conta duas vezes. Para
    saber quantos professores fizeram ao menos um curso, use
    `1 - prop_sem_formacao_continuada`. Na rede estadual de SP, a soma de
    cursos dá 15,5% e os professores com ao menos um curso são 9,5%.
- **As partes do índice de infraestrutura** (bloco Índices do EduMaps), de
  0 a 1, com peso igual:
  - **`infra_basico`:** água potável, energia da rede pública, esgoto da
    rede ou fossa séptica, coleta de lixo e banheiro (de 5);
  - **`infra_salas_equipamentos`:** biblioteca ou sala de leitura,
    laboratórios de ciências e de informática, quadra, cozinha, refeitório e
    salas da diretoria, da secretaria e dos professores (de 9);
  - **`infra_acessibilidade`:** rampas, corrimão, piso tátil, sinalização e
    banheiro adaptado (de 5);
  - **`infra_tecnologia`:** computador, internet, lousa digital, multimídia
    e impressora (de 5);
  - **para separar o básico dos equipamentos,** use os grupos no modelo no
    lugar do índice.
- **As partes do índice de sustentabilidade** (bloco Índices do EduMaps),
  com peso igual: `energia_renovavel` (1 = sim), `reciclagem_lixo`
  (reciclagem ou reaproveitamento), `area_verde_plantio` (área verde e área
  de plantio, meio ponto cada) e `educacao_ambiental` (em qualquer forma do
  Censo).
- Nas partes da infraestrutura e da sustentabilidade, como no índice, item
  sem resposta no Censo conta como ausente.
- O arquivo usa `;` como separador e vírgula decimal: abre direto no Excel.
  No R, `read.csv2()`; no Python, `pandas.read_csv(sep=";", decimal=",")`.
- Os indicadores são os publicados pelo INEP e pelo IBGE, sem correção.

## Taxa de atendimento da educação infantil no R

Para a taxa de atendimento da creche e da pré-escola de cada prefeitura
(a meta 1 do PNE), somando as escolas privadas conveniadas com ela (veja
**Creches conveniadas**, acima), baixe duas bases da mesma UF:

- a rede **municipal**, com os blocos **Matrículas** e **Porte do
  município**;
- a rede **privada**, com os blocos **Matrículas** e **Parceria com o poder
  público**.

```r
municipal <- read.csv2("base-analise-SP-municipal-censo2025.csv")
privada   <- read.csv2("base-analise-SP-privada-censo2025.csv")
conv <- subset(privada, parceria_esfera %in% c("Municipal", "Estadual e municipal"))
rede <- aggregate(cbind(mat_creche, mat_pre) ~ codigo_ibge + municipio + populacao_0_3 + populacao_4_5,
                  data = municipal, FUN = sum)
conv <- aggregate(cbind(conv_creche = mat_creche, conv_pre = mat_pre) ~ codigo_ibge,
                  data = conv, FUN = sum)
oferta <- merge(rede, conv, by = "codigo_ibge", all.x = TRUE)
oferta$conv_creche[is.na(oferta$conv_creche)] <- 0
oferta$conv_pre[is.na(oferta$conv_pre)] <- 0
oferta$taxa_creche <- 100 * (oferta$mat_creche + oferta$conv_creche) / oferta$populacao_0_3
oferta$taxa_pre    <- 100 * (oferta$mat_pre + oferta$conv_pre) / oferta$populacao_4_5
```

- **Conferência:** em SP, `oferta` tem os 645 municípios. Franca fica com
  48,9% na creche e 75,7% na pré-escola. 304 municípios chegam aos 50% da
  creche, e 171 aos 100% da pré-escola.
- **Não esqueça o `all.x = TRUE`.** Sem ele, o `merge` fica só com os
  municípios que têm conveniadas (271 em SP), e os outros somem da conta em
  vez de entrar com 0.
- **As taxas são um teto:** o Censo marca a escola conveniada, não a vaga.
- **Só a rede municipal:** divida `mat_creche`, sem somar `conv_creche`.
  A taxa da meta do PNE conta todas as redes, inclusive as privadas sem
  convênio, e está na comparação de redes do município.

## Escolas próximas

Para listar as escolas perto de uma unidade (concorrentes, ou quem atende a
mesma vizinhança), calcule a distância pela coordenada. As escolas sem
coordenada não entram nessa conta. Liste-as à parte, pelo bairro e pelo CEP,
para conferir no mapa ou geocodificar o endereço.

```r
base <- read.csv2("base-analise-SP-3516200-censo2025.csv",
                  fileEncoding = "UTF-8-BOM")
unidade <- base[base$inep == 35004827, ]
km <- function(lat1, lon1, lat2, lon2) {
  r <- pi / 180
  a <- sin((lat2 - lat1) * r / 2)^2 +
    cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  2 * 6371 * asin(sqrt(a))
}
base$dist_km <- km(unidade$latitude, unidade$longitude,
                   base$latitude, base$longitude)
perto <- subset(base, !is.na(dist_km) & dist_km <= 2 & inep != unidade$inep)
sem_coordenada <- subset(base, is.na(latitude),
                         select = c(inep, escola, rede, bairro, cep, endereco))
```

- **Conferência:** em Franca, a unidade 35004827 tem 60 escolas a até 2 km
  (37 delas com pré-escola ou anos iniciais), e `sem_coordenada` tem 18
  escolas, 16 delas privadas.
- **Mesmo bairro:** `subset(sem_coordenada, bairro == unidade$bairro)` mostra
  quem não tem coordenada e declarou o mesmo bairro da unidade (em Franca, 1
  escola, no bairro Cidade Nova).
- **Geocodificar:** com o CEP, o endereço e o município, um serviço de mapas
  acha a escola; a coordenada assim obtida é sua, não do Censo.

## Docência num modelo por etapa

As proporções do bloco Docência (formação, concursados, formação
continuada) são sobre **todos** os docentes da escola. Num modelo do IDEB
dos anos iniciais, a escola que também tem anos finais ou ensino médio
entra com a formação de professores dessas outras etapas. Em SP, isso
acontece em 1.725 das 5.779 escolas municipais e estaduais com IDEB dos
anos iniciais. Nelas, a mediana é de 55% do quadro nos anos iniciais, e o
efeito estimado dos concursados vai de +0,02 (escolas só de anos iniciais)
a −0,30.

Use os docentes por etapa para separar ou ponderar as escolas. Quem dá aula
em duas etapas conta nas duas, então a parte da etapa é um teto e a soma das
etapas pode passar de `qt_docentes`.

```r
base <- read.csv2("base-analise-SP-censo2025-ideb2023-inse2023.csv",
                  fileEncoding = "UTF-8-BOM")
ai <- subset(base, !is.na(ideb_ai) & rede %in% c("Municipal", "Estadual"))
ai$parte_ai <- pmin(1, ai$qt_docentes_ai / ai$qt_docentes)
so_ai <- subset(ai, parte_ai >= 0.8)
modelo <- lm(ideb_ai ~ prop_superior + prop_pos_graduacao +
               prop_sem_formacao_continuada + prop_efetivos + inse_media + rede,
             data = so_ai)
```

- **Conferência:** em SP, `ai` tem 5.781 escolas, e `so_ai` fica com as
  3.386 escolas, as que têm ao menos 80% do quadro nos anos iniciais. Nelas,
  o efeito dos concursados é de +0,03 (p = 0,51).
- **O corte de 80% é uma escolha:** teste outros, ou use `parte_ai` como
  peso (`weights = parte_ai`) ou como controle.

## Refazer os seis índices no R

Com a base lida (`base <- read.csv2("base-analise-….csv")`), o bloco abaixo
refaz os seis índices a partir das partes. Cada `refeito_*` bate com o
`indice_*` da mesma escola, com diferença de até 0,01 (o índice é
arredondado a duas casas). A parte vazia fica de fora, como no índice. Um
teste automático roda este bloco contra uma amostra da base, então ele não
fica diferente do índice sem aviso.

```r
base <- within(base, {
  refeito_infraestrutura <- 10 * (infra_basico + infra_salas_equipamentos +
    infra_acessibilidade + infra_tecnologia) / 4
  refeito_sustentabilidade <- 10 * (energia_renovavel + reciclagem_lixo +
    area_verde_plantio + educacao_ambiental) / 4
  tem_efetivos <- !is.na(prop_efetivos)
  refeito_capacitacao_docente <- 10 * (0.3 * prop_superior +
    0.3 * prop_pos_graduacao +
    0.2 * ifelse(tem_efetivos, pmin(prop_efetivos, 1), 0) +
    0.2 * prop_formacao_continuada) / (0.8 + 0.2 * (tem_efetivos))
  refeito_diversidade_discente <- ifelse(is.na(diversidade_racial),
    10 * (0.25 * equilibrio_genero + 0.2 * prop_educacao_especial_cc +
      0.2 * prop_eja) / 0.65,
    10 * (0.35 * diversidade_racial + 0.25 * equilibrio_genero +
      0.2 * prop_educacao_especial_cc + 0.2 * prop_eja))
  refeito_capacidade_atendimento <- 10 * (
    0.4 * ifelse(is.na(alunos_sala_turno), 0, pmax(0, 1 - alunos_sala_turno / 50)) +
    0.2 * etapas_regulares / 7 + 0.2 * prop_tempo_integral +
    0.2 * ifelse(is.na(alimentacao), 0, alimentacao))
  tem_aluno_gestor <- !is.na(alunos_por_gestor)
  tem_acesso <- !is.na(prop_acesso_cargo_selecao)
  refeito_capacidade_gestora <- 10 * (0.3 * gestores_formacao +
    0.2 * prop_gestores_espec_gestao +
    0.2 * ifelse(tem_aluno_gestor, pmin(1, 200 / alunos_por_gestor), 0) +
    0.2 * pmin(1, orgaos_colegiados / 5) +
    0.1 * ifelse(tem_acesso, prop_acesso_cargo_selecao, 0)) /
    (0.7 + 0.2 * tem_aluno_gestor + 0.1 * tem_acesso)
})
```

## Limitações conhecidas
- Uma UF por vez. A base de uma região ou do Brasil inteiro, as séries de
  vários anos e o acesso por API não estão nesta página; para uma região,
  baixe as UFs dela (as colunas são as mesmas, e a coluna `regiao` já vem
  em cada linha) e junte os arquivos. O
  [ranking das redes](rankings.md) já aceita a região.
- O INSE vem só da edição mais recente do SAEB.
- A remuneração cobre só os municípios com a folha do SIOPE carregada e
  separada por escola, cada um com os seus anos (a lista está em Fontes e
  metodologia).

## Veja também
- [Rankings de redes e de escolas](rankings.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
