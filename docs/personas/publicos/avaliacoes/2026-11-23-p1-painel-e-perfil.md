# Reavaliação: P1 lê o painel e o perfil da escola para o conselho (2026-11-23)

Rodada da P1 (gestor escolar) a pedido do developer. A última foi em
2026-11-13 (visão da rede, #375), com o veredito **adotaria**. Desde então,
nas telas públicas da escola:

| Entrega | O quê |
|---|---|
| #483, #485 | IDEB do perfil na mesma etapa e a evolução com o SAEB por etapa |
| #487, #496 | escolas semelhantes pelas notas e escolas similares do perfil pelo contexto |
| #506 | posição da escola com o empate dito |
| #510 | painel público com as etapas, a infraestrutura e as matrículas certas |
| #522, #527 | "sem formação continuada"; a privada sem comparação de concursados |
| #536 | nomes da folha corrigidos |

- **Avaliou:** só a P1.
- **Material:** o painel da escola e o perfil analítico de uma escola
  municipal de Cuiabá (MT) de INSE baixo, de pré-escola ao 9º ano, com 237
  matrículas (INEP 51038510). Só as telas públicas, sem entrar como
  gestora.
- **O trabalho que ela faria:** a diretora prepara a reunião do conselho
  escolar com três perguntas do perfil: "como está a infraestrutura da
  minha escola?", "estou abaixo da média do município?" e "melhoramos no
  IDEB?".
- ⚠️ Simulação: não substitui uma diretora de verdade.

## O que ela fez

1. **Infraestrutura:** o painel mostra, em ícones, o que a escola tem (água,
   energia da rede pública, esgoto por outra solução, coleta de lixo,
   internet, rampas e alimentação) e o que não tem (biblioteca,
   laboratórios e quadra). Ela entende sem ajuda e anota para o conselho a
   falta de biblioteca e de quadra.
2. **"Estou abaixo da média do município?"** Os cartões de indicadores dão
   a posição da escola no município. Ela se confunde em dois:
   - **IDEB dos anos iniciais:** **76ª de 81**, nota 4,7 (2023), e embaixo,
     **em verde**, "Acima de 4% das outras escolas no município". Todos os
     cartões usam o mesmo verde, do 31º lugar ao 76º de 81. Para ela,
     verde é "está bem", e é o IDEB que o conselho vai cobrar.
   - **Taxa de aprovação dos anos iniciais:** **1ª de 81**, 100%,
     "empatada com 67 escolas" e "Acima de 16% das outras escolas". Ela lê
     "primeira" e "acima de 16%" juntos e não sabe qual vale. A conta está
     certa (68 escolas têm 100%), mas a frase não diz que o primeiro lugar
     é dividido.
3. **O perfil analítico:** abre com dois **sinais de atenção**, os dois de
   gravidade "Média":
   - "Proporção de docentes com licenciatura no **quartil inferior do grupo
     de referência**";
   - "Proporção de docentes efetivos no quartil inferior do grupo de
     referência".

   Na tabela logo abaixo, a escola tem **94,1%** de docentes com
   licenciatura, contra 85,2% no município, 80,6% na rede e 79,6% no
   Brasil. Os docentes efetivos são **70,6%**, contra 67,7% no município.
   Nas 30 escolas parecidas, a mediana é 100% nos dois.

   O sinal tem razão (a escola fica atrás das parecidas), mas a frase
   não diz isso. "Quartil inferior do grupo de referência" é linguagem
   de quem faz estatística. Sem ler a tabela coluna por coluna, o que
   ela leva à secretaria é "estamos mal em licenciatura", quando a escola
   está acima do município e do Brasil. O "?" explica que "não é
   julgamento absoluto", mas a frase do sinal continua sem o número das
   escolas parecidas.
4. **"Melhoramos no IDEB?":** o perfil mostra a série do SAEB de
   matemática dos anos iniciais, de 179,8 (2009) a 175,4 (2023), com "▼
   4,4". Ela entende que caiu desde 2009.
5. **Para a reunião:** nem o painel nem o perfil têm botão para imprimir
   ou baixar. Ela usaria a impressão do navegador.

## O que funciona para ela

- A infraestrutura em ícones, com o que falta riscado.
- A posição no município com o total ("de 81") e o empate dito.
- A tabela do perfil com a escola, o município, a rede, o Brasil e as
  escolas parecidas, lado a lado.
- A série do SAEB com a direção da mudança.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| P1-PN-01 | atrapalha | **O painel pinta de verde qualquer posição.** "Acima de X% das outras escolas" sai sempre em verde: no IDEB dos anos iniciais, 76ª de 81 vem com "Acima de 4%" em verde. No primeiro lugar dividido, "1ª de 81" e "acima de 16%" parecem se contradizer. Pedido: (1) cor neutra, ou que siga o terço da posição (de cima, do meio, de baixo), nunca verde fixo; (2) no empate no topo, dizer que o primeiro lugar é dividido (ex.: "1º lugar, dividido com 67 escolas (todas com 100%)") em vez de "acima de 16%". | `/escola/panel?inep=51038510`; `SchoolIndicator.svelte` usa `text-green-600` sempre | P1, P2 |
| P1-PN-02 | atrapalha | **O sinal de atenção põe a escola mal sem dizer o porquê.** "Proporção de docentes com licenciatura no quartil inferior do grupo de referência" é jargão, e a frase não traz o número da escola nem o das escolas parecidas. A escola tem 94,1%, acima do município (85,2%) e do Brasil (79,6%), e só fica atrás das 30 parecidas (mediana de 100%). Pedido: a frase do sinal em linguagem do dia a dia e com os números (ex.: "Docentes com licenciatura: 94% na escola; nas 30 escolas parecidas do município, a maioria tem 100%"), e o aviso de quando a escola está acima do município e do Brasil. | `/escola/perfil?inep=51038510`, sinais de atenção e tabela "Posição relativa" | P1, P2 |

Observação, sem pedido: não há botão de imprimir nem de baixar no painel
nem no perfil. A impressão do navegador funciona.

## Veredito

**Adotaria** (mantido). A infraestrutura e a posição no município
respondem às perguntas dela, mas o painel pode passar uma impressão errada
para o conselho: o verde no IDEB ruim (P1-PN-01) e o sinal que a coloca
mal sem explicar (P1-PN-02).

## Encaminhamento

Os achados viram issue com a aprovação do developer.
