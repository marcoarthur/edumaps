---
funcionalidade: ../../funcionalidades/analise/assistente-censo.md
modulo: gestor
nivel: intermediario
publico:
- gestor
relacionadas:
- area-de-influencia
- painel-da-escola
status: parcial
titulo: IVET — Índice de Vulnerabilidade Educacional Territorial
ultima_revisao: '2026-10-25'
---

# IVET — Índice de Vulnerabilidade de Acesso

> Documento de ajuda para **gestores escolares, coordenação e secretarias de
> educação**. Explica, em linguagem simples, **o que o índice mede**, **quais
> fatores entram** na conta e **como ler o resultado** no painel da escola.
> Versão da fórmula: **`ivet-v1.2`** · Sem jargão técnico e sem fórmulas de
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

Nesta versão (`ivet-v1.2`), **todos os blocos têm o mesmo peso** na média
final. Nenhum tema "vale mais" que outro por decisão arbitrária — é uma regra
explícita e auditável. Qualquer mudança de peso tem de ser justificada e sobe a
versão da fórmula.

**Para o IVET ser publicado como número, os blocos de território precisam
existir.** O sistema só publica o índice quando os blocos **C (acesso),
D (saúde) e E (segurança)** têm dado — são eles que dão sentido à leitura
territorial. Quando falta qualquer um dos três, o painel **não inventa um
número**: mostra que o índice ainda não pôde ser calculado.

---

## 4. Como ler o resultado no painel da escola

No painel, o bloco **"Vulnerabilidade de acesso"** mostra:

### 4.1 O selo do índice

Um selo circular com o valor geral **entre 0 e 1**, e a inscrição da versão da
fórmula e da data da medição (ex.: `ivet-v1.2 · 2026-10-20`).

- **Quanto maior o número, mais barreiras de acesso** o território apresenta.
- O valor é uma **posição relativa**, não uma nota absoluta: por construção, a
  maioria das escolas fica na faixa **0,30 a 0,42**. Um valor de **0,40** já está
  acima da mediana nacional; **0,60** é bem alto.
- **Compare com o município, o estado e escolas parecidas** — é assim que o
  número ganha significado. Um IVET isolado diz pouco.

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
| **Um número (ex.: 0,34)** | Índice calculado e publicável para esta escola. |
| **"Esta escola ainda não teve o índice de acesso calculado."** | Não há medição vigente para a escola. |
| **Aviso âmbar "não é publicável"** | A medição **existe**, mas não pode ser exibida (amostra insuficiente ou dado sensível — ver §5). |

---

## 5. Privacidade e proteção de dados (LGPD)

Alguns índices **não podem ser publicados** para determinadas escolas — quando a
amostra é pequena demais (o que poderia expor indivíduos ou permitir
reidentificação) ou quando envolve dado sensível.

Nesses casos, o painel **não exibe os valores**. Ele mostra apenas um aviso de
que a medição existe, mas não é publicável para aquela escola. Isso protege as
pessoas por trás dos dados **sem esconder** que a escola foi analisada.

> Um aviso de "não publicável" **não** é um erro nem uma ausência de dado: é uma
> decisão de proteção aplicada de propósito.

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

**O que é "não publicável"?**
Uma proteção de privacidade (§5). A medição existe, mas os valores não são
exibidos para proteger as pessoas por trás dos dados.

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
| **Publicável** | Se o índice pode, ou não, ser exibido (proteção de privacidade). |
| **Snapshot** | A data da medição vigente do índice. |

---

## 9. Para saber mais

- **Área de influência** — o mapa do entorno da escola
  (`docs/funcionalidades/gestor/area-de-influencia.md`).
- Painel da escola (documentação funcional):
  `docs/funcionalidades/analise/painel-escola.md`.
- Área de influência (documentação funcional):
  `docs/funcionalidades/gestor/area-de-influencia.md`.

> Esta ajuda é **derivada** da formulação técnica do índice
> (`docs/analises/ivet.md`, fórmula `ivet-v1.2`) e da ficha de coeficientes
> (`docs/analises/ivet-coeficientes.md`). Mudou a fórmula → revise este arquivo.

## Limitações conhecidas

- Cobertura parcial por fonte/UF.
- Ausência de dado aparece como **n/d** (nunca é zero, #154).
- Os tetos dos componentes de acesso foram recalibrados com a cobertura ampliada (SP+RJ+NE).
