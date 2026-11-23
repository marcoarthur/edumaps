# Reavaliação: P5 audita a educação de Cuiabá (2026-11-23)

Segunda rodada da P5 (órgãos de controle e conselhos), a pedido do
developer. A primeira foi em 2026-11-14 (análises públicas), com o
veredito **não adotaria** (registro). Desde então, nas telas públicas:

| Entrega | O quê |
|---|---|
| #422, #426, #512 | ausência e cobertura honestas; os municípios com folha listados em `/fontes` |
| #428 | página `/fontes`, com a fonte, o período e a data da carga, e o selo de fonte nas telas |
| #430 a #453 | ranking de redes municipais (porte, região, destaque) e de escolas por município |
| #491 | folha por escola, por pessoa e por ano, na base de análise |
| #533 | população por idade do Censo 2022 e taxa de atendimento da creche e da pré-escola |

- **Avaliou:** só a P5. Ela continua só como registro: não orienta produto
  até a decisão de posicionamento (vender ao fiscal, ao fiscalizado ou aos
  dois).
- **Material:**
  - `/fontes`;
  - a comparação de redes de Cuiabá (MT), com a taxa de atendimento;
  - o ranking de redes municipais de MT e o nacional de municípios com mais
    de 500 mil habitantes, com Cuiabá em destaque;
  - a base de análise da rede municipal de Cuiabá (blocos Matrículas, INSE,
    Remuneração e Porte, folha de 2025);
  - a folha de uma escola municipal de INSE baixo.
- **Por que Cuiabá:** é o único município com a folha de 2025 completa (12
  meses, 167 escolas). Tem também os blocos da base.
- **O trabalho que ele faria:** o auditor do TCE-MT prepara a fiscalização
  da educação de Cuiabá com as três perguntas do perfil:
  1. "Este município gasta parecido com os semelhantes? E entrega parecido?"
  2. "O recurso do Fundeb chegou às escolas que mais precisam?"
  3. "A prestação de contas que recebi se sustenta nos dados públicos?"

  Junta a elas a meta 1 do PNE, que o tribunal acompanha.
- ⚠️ Simulação: não substitui um auditor de verdade.

## O que ele fez

1. **Fontes:** em `/fontes`, cada base tem o período e a data da carga. A
   população por idade traz o arquivo baixado, com o sha256. A folha do
   SIOPE tem período 2024–2026 e a lista dos municípios (Cuiabá, Alta
   Floresta D'Oeste, Taubaté e Ubatuba), mas a carga aparece como "não
   registrada".
2. **Entrega parecido?** No IDEB dos anos iniciais, a rede municipal de
   Cuiabá é a 25ª de 53 redes de MT e a 20ª dos 47 municípios do país com
   mais de 500 mil habitantes. O ranking diz a edição (2023), o mínimo de
   escolas e o porte. Isso responde "entrega parecido".
3. **Meta 1 do PNE:** a comparação de redes de Cuiabá dá a taxa de
   atendimento:

   | Etapa | Todas as redes | Rede municipal | Com as conveniadas (teto) |
   |---|---|---|---|
   | Creche | 44,9% | 34,3% | 38,1% |
   | Pré-escola | 92,8% | 67,1% | 70,0% |

   A tela traz a fonte e o ano da população (Censo 2022) e avisa que a
   taxa pode passar de 100%. O tribunal, porém, fiscaliza os 141
   municípios do estado e precisa da lista dos que estão abaixo da meta,
   ordenada. O ranking de redes só aceita indicadores do IDEB e do SAEB
   ("use um do IDEB/SAEB"). A lista só sai baixando a base da UF e rodando
   o código R da ajuda. Conferida no banco: 116 dos 141 municípios de MT
   ficam abaixo dos 50% na creche, e 79 abaixo dos 100% na pré-escola
   (todas as redes). A mediana da creche é 38,5%.
4. **Gasta parecido?** Não há comparação de gasto entre municípios. A
   folha cobre 4 municípios, e o gasto em educação declarado ao SICONFI
   (`analytics.esforco_fiscal_educacao`, com gasto por aluno e o
   percentual da receita) existe no banco, vazio e sem tela. Segue aberto
   o AN-12.
5. **O recurso chegou a quem mais precisa?** Na base da rede municipal,
   com a folha de 2025:
   - 167 das 171 escolas têm folha (R$ 472 milhões no ano). As 4 sem
     folha são 3 centros de educação infantil e 1 escola de ensino básico;
   - só 52 das 167 têm INSE, que vem do SAEB e quase nunca existe nas
     creches e pré-escolas. As outras 115 ficam sem medida socioeconômica;
   - nas 52, o quarto de INSE mais baixo gasta, na mediana, R$ 7.628 de
     pessoal por aluno no ano, e o quarto mais alto, R$ 6.977. O salário
     mediano do magistério é R$ 6.627 e R$ 6.500. É um começo de
     resposta, para uma parte das escolas.
6. **A prestação de contas se sustenta?** Na folha de uma escola de INSE
   baixo, ele confere os profissionais contra o portal da transparência
   do município, pelo nome, e encontra um sobrenome com "Ç" escrito
   "Ã¿". No banco, em Cuiabá:
   - **nenhum nome com acento está certo:** cerca de 440 nomes distintos
     estão com a codificação quebrada (2.514 linhas de 2025 e 1.572 de
     2026);
   - "Á" e "Í" foram codificados duas vezes e ainda dá para recuperá-los.
     O "Ç", o "Ã", o "É" e outros viraram o mesmo "Ã¿" (2.841
     ocorrências), e o caractere original se perdeu;
   - a carga do SIOPE converte a planilha em CSV antes de ler e já corrige
     à mão o mesmo defeito na coluna da categoria ("magistério",
     "educação"), mas não nos nomes.

   Os nomes das escolas estão certos. Os dos outros três municípios não
   têm o defeito. Na fiscalização, um nome que não bate com o do portal é
   um profissional que não se confere.

## O que funciona para ele

- `/fontes` com o período, a data da carga e o arquivo baixado (sha256),
  para citar no relatório de auditoria.
- O ranking de redes por porte e UF, com o destaque: "entrega parecido com
  os semelhantes" tem resposta.
- A taxa de atendimento da educação infantil por município, com as três
  contas e os avisos.
- A folha por escola em Cuiabá, com a base para cruzar com matrícula e
  INSE.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QO-01 | atrapalha | **A taxa de atendimento só existe município a município.** O tribunal fiscaliza todos os municípios do estado e precisa dos que estão abaixo da meta 1 do PNE, ordenados. O ranking de redes só aceita IDEB e SAEB, e a lista exige baixar a base e rodar R. Pedido: a taxa de atendimento da creche e da pré-escola (todas as redes, e a da rede municipal com as conveniadas como teto) como indicador do ranking de redes, com a meta marcada e o CSV. | MT: 116 dos 141 municípios abaixo de 50% na creche e 79 abaixo de 100% na pré-escola (mediana da creche 38,5%); `/api/ranking/redes?indicador=…` devolve 400 "use um do IDEB/SAEB" | P5, P2, P6 |
| QO-02 | atrapalha | **Nomes com acento quebrados na folha de Cuiabá.** Todo nome acentuado da folha de Cuiabá (2025 e 2026) está com a codificação errada. "Á" e "Í" foram codificados duas vezes, e o "Ç", o "Ã", o "É" e outros viraram "Ã¿", com o caractere perdido. A carga converte a planilha do SIOPE em CSV e só corrige à mão a coluna da categoria. Pedido: ler a planilha sem perder a codificação, recarregar a folha de Cuiabá (e conferir os outros municípios) e um teste com nome acentuado. | ~440 nomes distintos; 2.514 linhas de 2025 e 1.572 de 2026; 2.841 ocorrências de "Ã¿"; nenhum nome acentuado correto em Cuiabá | P5, P1 |

Continuam abertos: AN-12 (a folha cobre 4 municípios) e a falta de
comparação de gasto entre municípios (o SICONFI está no banco, vazio e sem
tela). O registro da carga da folha em `/fontes` ("não registrada") é
conhecido: a carga é anterior ao registro.

Observação, sem pedido: 115 das 167 escolas municipais de Cuiabá com folha
não têm INSE (creches e pré-escolas). "O recurso chegou a quem mais
precisa?" só se responde para as outras 52.

## Veredito

**Não adotaria** (registro; mantido), **mais perto**. Entre as perguntas
do perfil, já têm resposta "entrega parecido?", a meta 1 do PNE de um
município e o rastro da fonte. Faltam "gasta parecido?" (o gasto só existe
em 4 municípios), a meta no estado inteiro (QO-01) e nomes da folha que
batam com os do portal (QO-02).

## Encaminhamento

Os achados viram issue com a aprovação do developer. A P5 não orienta
produto até a decisão de posicionamento, mas o QO-01 também serve à P2 e à
P6. O QO-02 é um defeito de dado e vale para qualquer público.
