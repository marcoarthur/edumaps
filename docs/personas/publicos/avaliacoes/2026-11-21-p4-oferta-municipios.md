# Reavaliação: P4 compara a oferta de municípios parecidos (2026-11-21)

Trigésima primeira rodada da P4 (academia), a pedido do developer, depois
da entrega da trigésima rodada:

| Entrega | O quê |
|---|---|
| #515 | aviso do cruzamento IDEB × Censo também na edição mais recente, com a distância, a consequência para modelos e a edição do INSE (QY-01) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise da BA, rede municipal, blocos "Etapas" e "Porte"
    (`base-analise-BA-municipal-censo2025.csv`) e o catálogo dos
    blocos;
  - a comparação de redes (`/municipio/compare`) e os indicadores dela;
  - as ajudas da base e da comparação de redes;
  - o banco local, só leitura (`clean.censo_matriculas`, para medir o que a
    base não traz).
- **O trabalho que ela faria:** responder à primeira pergunta do perfil
  dela, "municípios de porte e região semelhantes têm oferta parecida?",
  com a educação infantil, na BA, entre os municípios de 10 a 20 mil
  habitantes.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Procurou as matrículas na base.** Os blocos trazem as etapas
   oferecidas (`oferece_creche`, `oferece_pre`… de 0 ou 1), a população e o
   porte do município, a região, e proporções calculadas sobre as matrículas
   (tempo integral, educação especial, EJA, alunos por sala). O número de
   matrículas não sai em nenhum bloco. No Censo carregado, as matrículas
   existem por etapa, por turno, por idade e por cor.
2. **Mediu a oferta como a base deixa:** quantas escolas municipais de cada
   município oferecem creche.
   - Nos 182 municípios de 10 a 20 mil habitantes da BA, a correlação de
     postos entre esse número e as matrículas em creche (do banco) é de
     0,36.
   - **Mirante** (10.526 habitantes) e **São José do Jacuípe** (10.576)
     têm 3 escolas com creche cada: 106 e 329 matrículas em creche.
   - **Serra Preta** (18.754) e **Pindobaçu** (19.601) têm 14 escolas com
     creche cada: 132 e 806 matrículas.

   Pela base, ela diria que os pares têm a mesma oferta.
3. **Tentou a comparação de redes.** Ela mostra as matrículas por etapa,
   mas:
   - de um município por vez (as redes dentro dele), sem arquivo para baixar;
   - a educação infantil sai num número só, sem separar creche e
     pré-escola, que têm metas diferentes no PNE.

   Para os 182 municípios, ela teria de abrir um por um e copiar à mão.
4. **Anotou o que fica fora do produto:** a taxa de atendimento pede a
   população por idade (0 a 3 anos, 4 a 5), que não está carregada; com as
   matrículas, ela compararia matrículas por habitante, uma aproximação.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a base para medir a oferta | a base não traz o número de matrículas, e contar escolas que oferecem a etapa não mede a oferta (QX-01); a comparação de redes tem o número, mas junta creche e pré-escola e não exporta (QX-02) |

## O que funciona

- **O porte e a região** do município estão na base, o recorte por porte
  sai direto.
- **As etapas oferecidas** separam creche e pré-escola.
- **As proporções sobre as matrículas** (tempo integral, educação especial)
  dizem o denominador.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QX-01 | atrapalha | **A base não traz o número de matrículas.** Só as etapas oferecidas (0 ou 1) e proporções sobre as matrículas. Para comparar a oferta entre municípios, contar escolas engana. Pedido: um bloco "Matrículas" com as matrículas da escola por etapa (creche, pré-escola, anos iniciais, anos finais, médio, EJA, educação profissional, educação especial) e em tempo integral, do mesmo Censo, para somar por município; na ajuda, o exemplo da soma por município e que a taxa de atendimento pede a população por idade, que não está carregada. | BA, municípios de 10 a 20 mil: correlação de 0,36 entre escolas com creche e matrículas em creche. Mirante e São José do Jacuípe: 3 escolas cada, 106 e 329 matrículas | P4, P2, P6 |
| QX-02 | detalhe | **A comparação de redes junta creche e pré-escola e não exporta.** As matrículas da educação infantil saem num número só, um município por vez, e não há arquivo para baixar. Pedido: creche e pré-escola separadas; e, se a base passar a ter as matrículas (QX-01), um link da comparação para a base do município. | "Infantil" num número só em `/municipio/compare` | P4, P2 |

## Encaminhamento

Issue **#516** (QX-01 e QX-02 juntas), aberta com a aprovação do
developer.

## Andamento

- 2026-11-21: #516 (PR #517) mergeado: QX-01 e QX-02 resolvidos.
  - A base tem o bloco "Matrículas", com 10 colunas do mesmo Censo (total,
    creche, pré-escola, anos iniciais e finais, médio, profissional, EJA,
    especial e tempo integral); o dicionário diz que as etapas não somam o
    total.
  - A comparação de redes separa creche e pré-escola e tem o link para a
    base do município com as etapas e as matrículas.
  - A ajuda mostra a soma por município no R e diz que a taxa de
    atendimento pede a população por idade, que não está carregada.
