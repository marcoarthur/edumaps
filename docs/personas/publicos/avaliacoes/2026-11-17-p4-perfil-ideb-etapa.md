# Reavaliação: P4 e o IDEB do perfil da escola (2026-11-17)

Décima quinta rodada da P4 (academia), em modo autônomo (delegação do
developer até 7h de 18/11), depois da entrega da décima quarta rodada:

| Entrega | O quê |
|---|---|
| #482 | agrupamento por desempenho numa etapa; infraestrutura sem contar fossa como falta (RO-01, RO-02) |

- **Avaliou:** só a P4.
- **Material:**
  - o perfil da escola (`/api/school/:inep/profile`, a tela do perfil e as
    escolas semelhantes) e o perfil analítico da rede;
  - o banco local com os dados reais, só leitura.
  - **O trabalho que ela faria:** usar o perfil de uma escola como estudo de
    caso. Ela compara o IDEB da escola com o do Brasil, do município, da
    rede e das escolas semelhantes, e confere de onde vem cada número. É a
    pendência deixada na #479 e na #481: o perfil é a última tela com a
    regra "etapa de maior nota".
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Abriu o perfil de um colégio estadual de Salvador** (anos finais e
   ensino médio no IDEB 2023).
   - O rótulo diz "IDEB observado 2023 (escola: anos finais)": a escola tem
     4,5.
   - Ao lado: Brasil 5,33, município 4,89, rede 5,02 e o grupo de escolas
     parecidas 4,09.
2. **Conferiu de onde vêm as médias.**
   - A escola entra com a etapa de maior nota (anos finais). As médias de
     comparação usam a mesma regra para **cada** escola: a média do Brasil
     junta os anos iniciais de umas, os anos finais de outras e o ensino
     médio de outras.

   | Média do IDEB 2023 (escolas em funcionamento) | Valor |
   |---|---|
   | "Brasil" do perfil (etapas misturadas) | **5,33** |
   | só anos iniciais | 5,66 |
   | só anos finais | 4,74 |
   | só ensino médio | 4,26 |

   - A escola tem 4,5 nos anos finais. Contra os anos finais do Brasil
     (4,74), está 0,24 abaixo; o perfil mostra 0,83 abaixo.
   - Uma escola de ensino médio exatamente na média nacional aparece 1,07
     ponto **abaixo** do "Brasil". Uma de anos iniciais na média aparece 0,33
     **acima**.
   - O mesmo vale para o município e a rede: o 4,89 de Salvador mistura os
     anos iniciais da rede municipal com o ensino médio da estadual.
3. **Mediu o alcance.**
   - 59.445 escolas em funcionamento têm IDEB 2023. Em 22.602 delas (anos
     finais ou ensino médio), o perfil compara com uma média puxada para
     cima; nas 36.843 de anos iniciais, para baixo.
   - 21.197 escolas têm nota em duas ou mais etapas, e o perfil mostra só
     uma, a de maior nota.
4. **O perfil analítico da rede** (#479) usa a mesma regra; o rótulo já
   avisa ("etapa de maior nota de cada escola"), mas a comparação com o
   Brasil continua misturada.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o IDEB do perfil | a base, o ranking, a comparação e o agrupamento já separam a etapa; o perfil compara a escola com médias de etapas misturadas (RN-01), e ela não cita essas diferenças |

## O que funciona

- O rótulo diz a etapa e a edição da escola (#431).
- O perfil analítico diz em quantas escolas cada média se apoia (#479).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RN-01 | atrapalha | **O perfil compara o IDEB de uma etapa com médias de etapas misturadas.** A escola entra com a etapa de maior nota, e o Brasil, o município, a rede e o grupo entram com a etapa de maior nota de cada escola. Pedido: as médias de comparação na **mesma etapa** da escola (só as escolas com nota nela), no perfil da escola e no perfil analítico da rede (IDEB e SAEB por etapa, com a média do Brasil por etapa). | "Brasil" 5,33 contra 5,66 / 4,74 / 4,26 por etapa; escola de ensino médio na média aparece 1,07 abaixo; 59.445 perfis afetados | P4, P1, P2, P6 |
| RN-02 | detalhe | **O perfil mostra uma etapa só.** A escola com duas ou três etapas aparece com a de maior nota, e as outras somem. Pedido: o IDEB de cada etapa da escola, cada uma com a sua comparação. | 21.197 escolas com duas ou mais etapas | P1, P4 |

## Encaminhamento

Modo autônomo: abri a issue **#483** (RN-01 e RN-02 juntas) e sigo para o
plano e a implementação, com aviso pelo Telegram.

## Andamento

- 2026-11-17: #483 (PR #484) mergeado em modo autônomo: RN-01 e RN-02
  resolvidos (comparações do IDEB e do SAEB na mesma etapa no perfil da
  escola e no da rede; IDEB de cada etapa da escola). Colégio de Salvador,
  anos finais: Brasil 5,33 → 4,74. Fechamento em
  [`../ciclos/2026-11-17-perfil-ideb-etapa.md`](../ciclos/2026-11-17-perfil-ideb-etapa.md).
  Nenhum achado aberto.
