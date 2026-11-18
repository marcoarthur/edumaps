---
funcionalidade: ../../funcionalidades/analise/painel-escola.md
modulo: gestor
nivel: intermediario
publico:
- gestor
relacionadas:
- area-de-influencia
- painel-da-escola
status: parcial
titulo: IVET — Índice de Vulnerabilidade Educacional Territorial
ultima_revisao: '2026-11-18'
---

# IVET — Índice de Vulnerabilidade de Acesso

> Documento de ajuda para **gestores escolares, coordenação e secretarias de
> educação**. Explica, em linguagem simples, **o que o índice mede**, **quais
> fatores entram** na conta e **como ler o resultado** no painel da escola.
> Versão da fórmula: **`ivet-v1.8`** (de 17/11/2026; histórico na §3.1 e na
> página **Fontes e metodologia**) · Sem jargão técnico e sem fórmulas de
> programação.

---

## 1. O que é o IVET, em uma frase

O IVET mede **quanto o acesso à escola é difícil por causa do território onde
ela está** — transporte, distância, segurança, saúde, recursos e condições
socioeconômicas do entorno.

Ele vai de **0 a 1**:

- **0** = nenhuma barreira (acesso fácil, entorno favorável);
- **1** = barreira máxima (acesso muito difícil, entorno desfavorável).

> ⚠️ **Atenção ao sentido**: no IVET, **quanto maior, pior**. É um índice de
> *vulnerabilidade*, não de qualidade. Um IVET 0,45 indica mais barreiras de
> acesso do que um IVET 0,30.

**A escola é o ponto de observação; o índice descreve o território ao redor
dela.** Isto é uma escolha de leitura do EduMaps: o IVET é **territorial**. Ele
não é um retrato do prédio escolar — é um retrato do *acesso* à escola naquele
lugar. Por isso ele olha para o entorno (a população que mora perto, o trânsito
da região, a distância até um posto de saúde) e também para as condições
próprias da escola (infraestrutura, professores, gestão), que entram como *um*
dos sete blocos.

---

## 2. Quais fatores entram na conta

O IVET é a **média de sete blocos temáticos**. Cada bloco, por sua vez, é a
média de alguns indicadores. Os sete blocos aparecem no painel da escola pelas
letras **A a G**:

| Bloco | O que mede, em palavras simples | Exemplos de indicadores |
|-------|----------------------------------|--------------------------|
| **A. Porte / oferta** | Condições próprias da escola: o que ela tem, quantos profissionais, quantas vagas oferece, como é gerida | Infraestrutura (água, energia, esgoto, espaços), formação e quantidade de professores, capacidade de atendimento, diversidade de alunos, gestão, sustentabilidade |
| **B. Contexto socioeconômico** | Como é a vida das famílias que moram no entorno da escola | Analfabetismo, esgoto e lixo inadequados, falta de banheiro, renda média do responsável |
| **C. Acesso (isócrona)** | **Quão fácil é chegar à escola** e o quanto o trânsito da região oferece risco | População que se alcança a pé em 15 min e de carro em 45 min; risco de sinistros de trânsito; quantidade de veículos na cidade |
| **D. Saúde** | Facilidade de chegar a atendimento básico de saúde e a cobertura de saúde da região | Distância até a UBS mais próxima; cobertura de atenção básica |
| **E. Segurança** | Nível de criminalidade do município onde a escola está | Índices de crimes por 100 mil habitantes (média de 2021–2023) |
| **F. Meio ambiente** | Exposição do entorno a risco ambiental e de clima | Risco de fogo/queimada, vegetação natural, solo |
| **G. Recursos** | Quanto o município investe na educação em relação às suas obrigações | Indicadores fiscais educacionais (SIOPE/SICONFI) |

> **Como o índice trata "não tem" e "não sabemos"**: são coisas diferentes.
> Se o indicador foi medido e o resultado é "não tem", ele conta como **0**
> (ou seja, *puxa a vulnerabilidade para cima*, se for algo desejável que falta).
> Mas se o dado **não existe** para aquela escola, o bloco **não é penalizado** —
> ele simplesmente sai da conta e o painel mostra **"n/d" (não disponível)**.
> Esta é uma regra central da plataforma: **ausência nunca vira zero**.

---

## 3. Como o índice é montado (ordem da conta)

A montagem é feita de baixo para cima, em três passos:

1. **Indicador** — uma variável bruta é convertida para uma escala de 0 a 1
   (por exemplo, a distância até a UBS, ou a renda média do responsável).
2. **Bloco (A–G)** — a média dos indicadores daquele tema.
3. **IVET** — a média dos sete blocos.

Nesta versão (`ivet-v1.8`), **todos os blocos têm o mesmo peso** na média
final. Nenhum tema "vale mais" que outro por decisão arbitrária — é uma regra
explícita e auditável. Qualquer mudança de peso tem de ser justificada e sobe a
versão da fórmula.

**Para o IVET ser publicado como número, os blocos de território precisam
existir.** O sistema só publica o índice quando os blocos **C (acesso),
D (saúde) e E (segurança)** têm dado — são eles que dão sentido à leitura
territorial. Quando falta qualquer um dos três, o painel **não inventa um
número**: diz quais blocos faltam e mostra os que já foram medidos (§4.3).

### 3.1 Versões da fórmula

Cada número do IVET carrega a versão da fórmula que o calculou (ex.:
`ivet-v1.8`). **Para citar o índice, informe a versão**: valores de versões
diferentes nem sempre se comparam. A lista completa, com a data e o que mudou
em cada uma, está na página **Fontes e metodologia** (`/fontes`), no cartão
"IVET do EduMaps".

| Versão | Data | O que mudou |
|--------|------|-------------|
| `ivet-v1.4` a `ivet-v1.8` | 16 e 17/11/2026 | Correções nos índices do Censo que formam o bloco A (inclusão, cor/raça, lotação por sala e turno, gestão, escola sem registro). A conta do IVET não mudou. |
| `ivet-v1.3` | 10/11/2026 | O acesso a pé e de carro (bloco C) passou a uma escala logarítmica, que diferencia melhor as escolas fora das grandes cidades. O bloco C ficou mais baixo para quase todas: **não compare com valores da v1.2 ou anteriores.** |
| `ivet-v1.0` a `ivet-v1.2` | 15 a 17/10/2026 | Primeira versão e o bloco B (instrução, saneamento e renda do entorno). |

---

## 4. Como ler o resultado no painel da escola

No painel, o bloco **"Vulnerabilidade de acesso"** mostra:

### 4.1 O selo do índice

Um selo circular com o valor geral **entre 0 e 1**, e a inscrição da versão da
fórmula e da data da medição (ex.: `ivet-v1.8 · 2026-11-17`).

- **Quanto maior o número, mais barreiras de acesso** o território apresenta.
- O valor é uma **posição relativa**, não uma nota absoluta: como é a média de
  sete blocos, os valores das escolas ficam próximos uns dos outros, e
  diferenças pequenas já contam.
- **Compare com o município, o estado e escolas parecidas** — é assim que o
  número ganha significado. Um IVET isolado diz pouco.
- **Ainda não há uma régua nacional da versão atual** (a mediana e as faixas
  de leitura). As medições publicadas são de outubro de 2026, de antes da
  mudança de escala do bloco C (`ivet-v1.3`), e não valem para os valores de
  hoje. A régua volta a esta ajuda quando a versão atual for medida.

### 4.2 Os sete blocos (A a G)

Abaixo do selo, cada bloco aparece com sua letra, um pequeno rótulo e o valor
(ou **"n/d"**). Este é o mapa do *porquê*:

- **Um bloco alto** aponta onde está a maior barreira daquela escola. Por
  exemplo, um bloco **C** alto significa acesso difícil (pouca população ao
  alcance, ou trânsito de risco); um bloco **B** alto significa entorno
  socioeconômico desfavorável.
- **Um bloco "n/d"** significa que aquele tema ainda não tem dado para esta
  escola — **não** que a situação ali seja boa ou ruim.
- Use os blocos para **priorizar**: o índice geral mostra *se* há
  vulnerabilidade; os blocos mostram *onde* agir.

### 4.3 As três situações possíveis

O painel trata cada caso de forma explícita:

| O que aparece | O que significa |
|---------------|-----------------|
| **Um número (ex.: 0,34)** e os sete blocos | Índice calculado para esta escola. |
| **"Esta escola ainda não teve o índice de acesso calculado."** | Não há medição vigente para a escola. |
| **Aviso cinza "ainda não pode ser calculado"**, com os blocos abaixo | A região da escola ainda não tem algum dos blocos de território: **C (acesso), D (saúde) ou E (segurança)**. O aviso diz quais faltam; os blocos já medidos aparecem com o valor, e os outros como **n/d**. Ver §5. |

---

## 5. Por que o índice pode ficar sem número

O IVET só vira número quando a região da escola tem os **três blocos de
território**: **C (acesso)**, **D (saúde)** e **E (segurança)**. Hoje o que
mais falta é o acesso a pé e de carro, que só foi calculado para escolas do
Sudeste e do Nordeste.

Nesses casos, o painel:

- diz **quais blocos faltam** ("faltam os blocos C (acesso) e D (saúde) desta
  região");
- mostra os **blocos que já foram medidos** — por exemplo, o bloco A, das
  condições da própria escola — e os demais como **n/d**;
- **não mostra o selo**, porque uma média sem os blocos de território não
  descreve o acesso.

> Ficar sem número **não é proteção de dados nem sigilo**: o IVET usa dados
> públicos e agregados (Censo Escolar, IBGE, saúde, segurança, finanças do
> município) e não tem regra de privacidade. É só **falta de dado** naquela
> região, e o número aparece quando o bloco que falta for medido.

---

## 6. A área de influência e a isócrona

O bloco **C (acesso)** tem uma parte que o gestor **vê desenhada no mapa**: a
**isócrona**.

- **15 min a pé** — o alcance caminhando em 15 minutos;
- **45 min de carro** — o alcance usando transporte motorizado em 45 minutos.

No mapa, cada faixa é um polígono que pode ser **ligado e desligado** pela
legenda. A isócrona responde a uma pergunta prática: *quantas pessoas moram
dentro do alcance da escola, e portanto poderiam usá-la?*

- **População maior no alcance** = acesso mais fácil = **menor** contribuição
  para o bloco C (bom para o acesso).
- **População pequena no alcance** = acesso mais difícil = **maior**
  contribuição para o bloco C.

A isócrona também alimenta o mapa de **área de influência** da escola (ver a
documentação *Área de influência*). A isócrona de transporte é calculada como
**carro**; ela **não** modela ônibus ou trem (o motor de rotas não tem dados de
transporte coletivo).

---

## 7. Perguntas frequentes

**O IVET diz se minha escola é boa?**
Não. Ele diz **quão difícil é o acesso** pela perspectiva do território. Uma
escola excelente pode ter IVET alto se estiver num lugar de acesso ruim. Leia-o
junto do desempenho, do perfil e das escolas semelhantes.

**Por que minha escola tem "n/d" em alguns blocos?**
Porque aquele dado ainda não existe para ela (fonte não cobre o município, ou a
escola não entrou numa extração). **Não** significa nota zero nem situação boa.

**Por que o índice geral aparece como não calculado, se vejo alguns blocos?**
Porque o IVET só é publicado quando os blocos de território **C, D e E** estão
disponíveis. Sem eles, não há leitura territorial — e o sistema prefere não
publicar a publicar um número enganoso.

**O valor mudou desde a última vez que consultei. Por quê?**
O IVET é **recalculado periodicamente** (a data aparece junto ao selo). Quando
uma fonte nova entra (por exemplo, mais municípios passam a ter isócrona), a
cobertura cresce e os valores podem se deslocar levemente.

**Por que aparece "ainda não pode ser calculado"?**
Porque a região da escola ainda não tem algum dos blocos de território
(C, D ou E). O aviso diz quais faltam e os blocos medidos aparecem logo
abaixo (§5). Não é sigilo nem proteção de dados.

**Posso comparar o IVET de agora com um valor antigo?**
Só se a versão da fórmula for a mesma, ou se a mudança entre elas não mexeu na
conta (§3.1). Da `ivet-v1.2` para a `ivet-v1.3` o bloco C mudou de escala, e os
valores não se comparam.

**Quanto maior o número, pior?**
Sim. O IVET mede **vulnerabilidade** de acesso: **maior = mais barreira**.

---

## 8. Glossário rápido

| Termo | Significado |
|-------|-------------|
| **IVET** | Índice de Vulnerabilidade de Acesso (0 a 1; maior = pior acesso). |
| **Bloco (A–G)** | Um dos sete temas que compõem o índice. |
| **Isócrona** | Área que se alcança num tempo (15 min a pé; 45 min de carro). |
| **Área de influência** | O entorno considerado nas leituras de território da escola. |
| **n/d** | "Não disponível": o dado não foi medido — não é zero. |
| **Blocos de território** | C (acesso), D (saúde) e E (segurança): sem eles o IVET não vira número. |
| **Versão da fórmula** | O nome da conta que gerou o número (ex.: `ivet-v1.8`); informe ao citar. |
| **Snapshot** | A data da medição vigente do índice. |

---

## 9. Para saber mais

- **Área de influência** — o mapa do entorno da escola
  (`docs/funcionalidades/gestor/area-de-influencia.md`).
- Painel da escola (documentação funcional):
  `docs/funcionalidades/analise/painel-escola.md`.
- Área de influência (documentação funcional):
  `docs/funcionalidades/gestor/area-de-influencia.md`.

- **Fontes e metodologia** (`/fontes`) — a versão vigente do IVET e o
  histórico das versões.

> Esta ajuda é **derivada** da formulação técnica do índice
> (`docs/analises/ivet.md`, fórmula `ivet-v1.8`) e da ficha de coeficientes
> (`docs/analises/ivet-coeficientes.md`). Mudou a fórmula → revise este arquivo.

## Limitações conhecidas

- Cobertura parcial por fonte/UF.
- Ausência de dado aparece como **n/d** (nunca é zero, #154).
- O acesso a pé e de carro só existe para escolas do Sudeste e do Nordeste; nas
  demais aparece **n/d**.
- Desde novembro de 2026 o acesso usa uma escala que diferencia melhor as
  escolas fora das grandes cidades. Por isso o valor de mobilidade (e o IVET)
  ficou mais baixo para quase todas: não compare com valores anteriores.
