# Reavaliação: P4 e o ranking de escolas pelo IDEB (2026-11-19)

Vigésima quinta rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima quarta rodada:

| Entrega | O quê |
|---|---|
| #502 | versão citável dos índices coerente nos textos e conferida por teste; ajuda honesta sobre os arquivos da carga (RE-01, RE-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a aba **Escolas de um município** de `/ranking` e a resposta
    `/api/ranking/escolas` (IDEB e taxa de aprovação dos anos iniciais,
    Salvador);
  - a ajuda `rankings.md` e a `comparar-redes.md` ("Só escolas em
    funcionamento");
  - o código (`EduMaps::Model::Rank::School::escolas_do_municipio`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** listar as escolas de um município pelo IDEB
  dos anos iniciais para escolher casos (as de cima e as de baixo) e
  descrever a distribuição num relatório.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.
- Descartado nesta rodada, sem achado: a linha do IDEB por rede (acompanha a
  variação nas mesmas escolas: Salvador, 2021→2023, −0,04 contra +0,04) e a
  taxa de aprovação (é a do conjunto dos anos iniciais, em %). O Assistente
  do Censo é só para gestores e não se aplica à P4.

## O que ela fez

1. **A nota da lista.** Para o IDEB, a nota diz só "257 escolas de Salvador
   (BA) com IDEB – Anos Iniciais em 2023". Os índices do Censo trazem "Como
   se calcula"; o IDEB não traz método nem cobertura.
2. **Quem fica de fora.** Em Salvador, 794 escolas em funcionamento oferecem
   os anos iniciais: 282 públicas e 512 privadas. Têm IDEB 2023 243 públicas
   e nenhuma privada. A lista não diz quantas ficam de fora nem por quê.
   - No Brasil, das 77.318 escolas públicas que oferecem os anos iniciais,
     **40.309 (52%)** têm IDEB 2023. Entre as rurais, 31.118 de 41.197
     (**76%**) ficam sem.
   - A falta não é aleatória: a base de análise avisa ("o IDEB falta
     sobretudo nas escolas pequenas, rurais e sem infraestrutura"); o
     ranking, não.
3. **Escolas que não funcionam mais.** O ramo do IDEB lê a tabela do IDEB e
   não filtra a situação no Censo; os índices do Censo e a infraestrutura
   básica filtram.
   - Salvador: 10 das 257 escolas da lista não estão em funcionamento no
     Censo 2025 (1 paralisada, 1 extinta, 8 fora do Censo 2025).
   - Brasil, anos iniciais: 254 escolas com IDEB 2023 estão paralisadas,
     extintas ou fora do Censo 2025 (0,6%).
   - A ajuda de comparação de redes diz que só entram escolas em
     funcionamento e que é "a mesma contagem do perfil, do ranking e da base
     de análise".

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem a lista de escolas pelo IDEB para descrever o município | a lista não diz quantas escolas da etapa ficam de fora nem que a falta não é aleatória (RD-01); entram escolas que não funcionam mais, contra o que a ajuda diz (RD-02) |

## O que funciona

- **A posição com empate** e o **INSE ao lado**.
- **O filtro de rede** e o **CSV com o município e a rede** em cada linha.
- **A infraestrutura básica** com os itens que faltam.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RD-01 | atrapalha | **A lista pelo IDEB não diz a cobertura.** "257 escolas com IDEB" sem dizer quantas escolas em funcionamento oferecem a etapa, que as privadas quase nunca têm IDEB e que a falta se concentra nas pequenas e rurais. Pedido: na nota, quantas escolas do município oferecem a etapa e quantas têm o indicador (por rede, ou ao menos públicas e privadas), o aviso de que a falta não é aleatória (como a base de análise), e o método do IDEB/SAEB como nos índices (fonte, edição, etapa). | Salvador: 794 oferecem os anos iniciais, 243 com IDEB 2023 (0 privadas); Brasil: 52% das públicas, 24% das rurais | P4, P6, P2 |
| RD-02 | detalhe | **Entram escolas que não funcionam mais.** O ramo do IDEB não filtra a situação no Censo. Pedido: só escolas em funcionamento no Censo mais recente, como os índices, ou a situação marcada na linha; e a ajuda coerente. | Salvador: 10 de 257; Brasil (anos iniciais): 254 com IDEB 2023 | P4 |

## Encaminhamento

Aguardando a aprovação do developer para abrir a issue.
