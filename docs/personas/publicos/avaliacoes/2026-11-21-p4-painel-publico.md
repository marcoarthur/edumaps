# Reavaliação: P4 descreve uma escola pelo painel público (2026-11-21)

Vigésima oitava rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima sétima rodada:

| Entrega | O quê |
|---|---|
| #509 | ranking de redes só com as escolas em funcionamento na rede municipal do Censo, refeito pela base de análise (RB-01) |

- **Avaliou:** só a P4.
- **Material:**
  - o painel público da escola (`/escola/panel?inep=…`, aberto pela busca)
    e a resposta `/api/school/:inep/panel/info`, com a Escola Municipal
    Amai Pro (Salvador, 29190231) de estudo de caso;
  - a base de análise da BA, rede municipal, blocos "Etapas",
    "Infraestrutura", "Docência", "Índices", "INSE" e "Porte";
  - a ajuda do painel público (`painel-publico-da-escola.md`);
  - o código do painel (montagem da resposta e componentes de etapas,
    infraestrutura, matrículas e indicadores);
  - o banco local, só leitura, para medir o Brasil (Censo 2025, escolas em
    funcionamento).
- **O trabalho que ela faria:** descrever uma escola de estudo de caso
  (etapas oferecidas, infraestrutura, tamanho) com o painel público e
  conferir com a base de análise antes de citar.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Conferiu as etapas com a base.** A base diz que a Amai Pro oferece
   pré-escola e anos iniciais (`oferece_pre = 1`, `oferece_ai = 1`). O
   painel mostra só os anos iniciais acesos; o ícone da pré-escola fica
   apagado, como etapa não oferecida.
   - A resposta manda a etapa como `pre_infantil`; a tela procura
     `pre_escola`, não acha e apaga o ícone.
   - No Brasil, **98.010** escolas em funcionamento oferecem pré-escola, e o
     painel mostra todas sem ela.
2. **Conferiu a infraestrutura.** Três itens nunca acendem, ou acendem
   pela regra errada:
   - **Quadra de esportes:** a resposta manda `quadra_esporte`, a tela
     procura `quadra_esportes`. As **72.800** escolas com quadra aparecem
     sem quadra.
   - **Acessibilidade:** a resposta não manda o item; o ícone fica sempre
     apagado, inclusive nas **111.887** escolas com rampas
     (`in_acessibilidade_rampas` na base).
   - **Esgoto e energia** acendem só com a rede pública. As **70.538**
     escolas com fossa ou outra solução aparecem "sem esgoto", como as que
     não têm esgoto nenhum; **3.857** com gerador ou outra fonte aparecem
     "sem energia". A base separa os dois casos (`in_esgoto_inexistente`,
     `in_energia_inexistente`).
3. **Conferiu as matrículas.** O painel diz **357 matrículas, porte
   médio**. O Censo tem 285 na educação básica (72 na infantil e 213 no
   fundamental); a base dá 285 alunos por gestor, com um gestor.
   - O número do painel soma o total da educação básica com a infantil, a
     EJA e o médio, que já estão dentro dele: a infantil entra duas vezes.
   - No Brasil, **148.190** escolas aparecem com mais matrículas do que têm,
     e **36.034** mudam de porte por isso.
   - As faixas de porte (menos de 200, menos de 700, 700 ou mais) não têm
     fonte: o código diz que foram "assumidas" e que é para "ajustar se houver
     definição oficial". Nenhuma ajuda as explica, e a base não tem o porte
     da escola (o bloco "Porte" é o do município).
   - O painel não diz de que Censo vêm as etapas, a infraestrutura e as
     matrículas (2025).
4. **Leu os indicadores do painel.** Os cartões mostram a posição no
   município sem o empate que a página da posição passou a dizer (#507):
   sustentabilidade 0 aparece "767 de 1.432, acima de 0% no município", sem
   "empatada com 666 escolas".
5. **Procurou a ajuda.** A ajuda do painel público tem quatro linhas sobre
   o conteúdo. Não diz quais blocos existem, de onde vem cada um, de que ano,
   o que quer dizer um ícone apagado (não tem? sem dado?) nem como o porte é
   calculado.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o painel público para descrever a escola | o painel diz que a escola não tem o que tem (pré-escola, quadra, acessibilidade, esgoto por fossa) (RA-01); as matrículas contam a infantil, a EJA e o médio duas vezes, e o porte muda (RA-02); os cartões não dizem o empate e a ajuda não explica nada disso (RA-03) |

## O que funciona

- **A base de análise está certa** nos mesmos campos: etapas,
  infraestrutura e os seis índices da Amai Pro batem com o Censo.
- **Os seis índices** dos cartões batem com a base (valor) e com a página
  da posição (posição e "acima de").
- **A série do IDEB** (desempenho) e o mapa com a área de influência.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RA-01 | atrapalha | **O painel diz que a escola não tem o que tem.** Os nomes das etapas e da infraestrutura na resposta não batem com os da tela (`pre_infantil` × `pre_escola`, `quadra_esporte` × `quadra_esportes`), a acessibilidade não vem, e esgoto e energia só contam a rede pública. Um ícone apagado quer dizer "não oferece/não tem". Pedido: os mesmos nomes dos dois lados (com um teste que pegue a diferença); acessibilidade pela mesma regra da base; esgoto e energia como a base (rede pública, outra solução, inexistente), sem tratar a fossa como falta. | Amai Pro: pré-escola na base, apagada no painel. Brasil: 98.010 escolas com pré-escola, 72.800 com quadra, 111.887 com rampas, 70.538 com fossa ou outra solução de esgoto, 3.857 com outra fonte de energia | P4, P1, P2, P6 |
| RA-02 | atrapalha | **As matrículas contam etapas duas vezes, e o porte não tem fonte.** O número soma o total da educação básica com a infantil, a EJA e o médio, que já estão nele. As faixas de porte foram "assumidas" no código, sem ajuda; o ano do Censo não aparece. Pedido: o total da educação básica do Censo, com o ano; o porte por uma regra dita na ajuda (ou sem o porte), e a mesma conta onde a base usa as matrículas. | Amai Pro: 357 no painel, 285 no Censo. Brasil: 148.190 escolas com o número inflado, 36.034 mudam de porte | P4, P1, P2 |
| RA-03 | detalhe | **Os cartões não dizem o empate, e a ajuda do painel não explica o painel.** A página da posição diz "empatada com N escolas" (#507); os cartões do painel não. A ajuda não diz os blocos, a fonte, o ano, o que é um ícone apagado nem o porte. Pedido: o empate nos cartões (ou o link para a posição); a ajuda com os blocos, a fonte e o ano de cada um. | Sustentabilidade 0: "767 de 1.432, acima de 0%", sem "empatada com 666"; ajuda com quatro linhas sobre o conteúdo | P4, P1 |

## Encaminhamento

Issue **#510** (RA-01 a RA-03 juntas), aberta com a aprovação do
developer.
