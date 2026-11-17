# Reavaliação: P4 e a comparação de redes do município (2026-11-17)

Décima terceira rodada da P4 (academia), depois da entrega da décima segunda
rodada:

| Entrega | O quê |
|---|---|
| #478 | bloco R testado que refaz os seis índices; partes da infraestrutura e da sustentabilidade na base (RQ-01, RQ-02) |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - a ajuda `comparar-redes.md` (revisada em 25/10/2025) e a de rankings;
  - as telas `/municipio/compare` (comparação das redes do município) e
    `/municipio/perfil` (perfil analítico), e as respostas que as alimentam;
  - a base de análise de Salvador e o banco local com os dados reais, só
    leitura.
  - **O trabalho que ela faria:** comparar as redes de um município (federal,
    estadual, municipal e privada), o que o perfil lista em "o que usa" e que
    ela não avaliava desde 14/11. Conferir os números da tela com a base que
    ela já usa.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Comparou as redes de Salvador** na tabela e conferiu com a base.

   | Rede | Escolas (comparação) | Escolas ativas (base e perfil) | Docentes (as duas) | % superior (as duas) |
   |---|---|---|---|---|
   | Federal | 2 | 2 | 338 | 97,04 |
   | Estadual | **219** | **200** | 6.368 | 92,23 |
   | Municipal | **417** | **414** | 7.825 | 99,73 |
   | Privada | 816 | 816 | 10.475 | 72,21 |

   - Docentes e proporções batem exatamente.
   - **O número de escolas não bate.** A comparação conta as escolas
     paralisadas e extintas: na estadual, 200 em funcionamento, 16
     paralisadas e 3 extintas.
2. **Mediu no Brasil** (Censo 2025).
   - A comparação soma 214.192 escolas. Em funcionamento são 180.540: as
     33.652 a mais (16%) são paralisadas (29.780) ou extintas (3.872), e
     nenhuma tem matrícula.
   - Em 3.012 dos 5.571 municípios, o total de escolas da comparação passa
     o de escolas em funcionamento em 10% ou mais.
   - Pior caso: a rede municipal de Formoso (MG) aparece com 56 escolas, e 4
     funcionam.
   - Erram junto: "Escolas", "Alunos por escola" (dividido por escolas que
     não têm aluno) e o gráfico "Escolas por rede".
   - A mesma rede tem três números no produto: 417 na comparação, 414 no
     perfil analítico e 414 na base (RP-01).
3. **Abriu o perfil analítico** de Salvador (todas as redes).
   - O cabeçalho diz 1.432 escolas, e a ajuda da tela diz que "cada
     indicador é a média das escolas ativas do recorte".
   - **Mas o IDEB só existe em 406 delas (28%).** As 816 privadas não têm
     nenhum, e a tela não diz em quantas escolas cada média se apoia.
   - O IDEB do perfil é a "média entre etapas" de cada escola (anos
     iniciais, finais e ensino médio juntos), o que só o comentário da
     coluna no banco diz. Para ela, uma média que mistura etapas não se
     compara entre redes com etapas diferentes: a municipal tem anos
     iniciais, e a estadual tem ensino médio (RP-02).
4. **A linha do IDEB por rede** (2005 a 2023).
   - As médias por rede e etapa batem com a base.
   - A tela não mostra em quantas escolas cada ponto se apoia. A resposta
     traz um `numero_escolas` que conta as escolas da planilha do IDEB,
     inclusive as sem nota: no ensino médio estadual de 2023, 131 escolas,
     das quais 69 têm IDEB (RP-03).
   - Na resposta do resumo, a privada traz o IDEB do ensino médio de 2017
     na mesma linha em que as públicas trazem 2023. A tela não mostra esse
     valor, então não chega à pessoa. Fica para quem usa os dados diretos.
5. **Leu a ajuda "Comparar redes".**
   - É de outubro de 2025 e diz "funcionalidade de comparação (quando
     disponível)". Não diz o que conta como escola, que as médias são
     médias simples das escolas, nem de que ano é cada número (RP-04).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a comparação de redes | a base continua sendo a ferramenta dela; a comparação conta escolas fechadas (RP-01) e o perfil não diz em quantas escolas apoia cada média (RP-02), então ela não cita essas telas |

## O que funciona

- **Docentes e proporções** da comparação batem com a base, escola por
  escola.
- **O IDEB por rede e etapa** da linha do tempo bate com a base.
- **O selo de fonte** está na tela.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RP-01 | atrapalha | **A comparação de redes conta as escolas paralisadas e extintas.** "Escolas", "Alunos por escola" e "Escolas por rede" usam todas as escolas do Censo, e o perfil, o ranking e a base usam só as em funcionamento. Pedido: só as escolas em funcionamento, como no resto do produto. | Brasil: 214.192 contra 180.540 (+16%); 3.012 municípios com 10% ou mais a mais; Formoso (MG) municipal 56 contra 4; Salvador estadual 219 contra 200 | P4, P2, P6, P5 |
| RP-02 | atrapalha | **O perfil analítico não diz em quantas escolas cada média se apoia, e o IDEB mistura etapas.** O cabeçalho diz 1.432 escolas, e o IDEB existe em 406. O IDEB é a média entre as etapas da escola. Pedido: o número de escolas com valor em cada indicador e, no IDEB e no SAEB, a etapa (ou a média por etapa) e a edição. | Salvador: IDEB em 406 de 1.432 escolas; privadas sem IDEB | P4, P2 |
| RP-03 | detalhe | **A linha do IDEB por rede não mostra em quantas escolas cada ponto se apoia,** e o `numero_escolas` da resposta conta escolas sem nota. Pedido: o número de escolas com IDEB em cada ponto (no tooltip). | ensino médio estadual de Salvador, 2023: 131 contadas, 69 com IDEB | P4 |
| RP-04 | detalhe | **A ajuda "Comparar redes" é genérica e antiga.** Pedido: o que a tela mostra, o que conta como escola, que as médias são simples (escola com peso igual), de que ano é cada número e a ligação com o perfil analítico. | revisada em 25/10/2025, "quando disponível" | P4, P2 |

## Encaminhamento

Aguarda a aprovação do developer para abrir a issue.

### Proposta

1. **RP-01:** filtrar as escolas em funcionamento em
   `analytics.mv_rede_escolas`, numa change nova (a MV vem de
   `analytics_rede_escolas` e `rede_escolas_etapas`). Conferir quem mais lê
   a MV (ranking de redes, painel da rede) antes de mudar.
2. **RP-02 e RP-03:** o número de escolas com valor por indicador no perfil
   (a consulta já tem `count(*)`, falta `count(coluna)`) e no tooltip da
   linha do IDEB; a etapa e a edição do IDEB no perfil.
3. **RP-04:** reescrever a ajuda da comparação.
4. Podem ir numa issue só, como as anteriores. A RP-01 é a que muda
   números publicados.
