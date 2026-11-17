# Reavaliação: P4 e o agrupamento por desempenho (2026-11-17)

Décima quarta rodada da P4 (academia), em modo autônomo (delegação do
developer até 7h de 18/11), depois da entrega da décima terceira rodada:

| Entrega | O quê |
|---|---|
| #480 | comparação de redes só com escolas em funcionamento; escolas com dado no perfil e na linha do IDEB; ajuda nova (RP-01 a RP-04) |

- **Avaliou:** só a P4.
- **Material:**
  - a página de agrupamento (`/cluster/geotag`), as execuções guardadas e o
    CSV de uma execução (`/api/cluster/execucoes/:run_id/csv`);
  - a ajuda `agrupamentos-de-escolas.md` e a de base de análise;
  - o banco local com os dados reais, só leitura.
  - **O trabalho que ela faria:** usar o agrupamento por "Desempenho dos
    alunos" do ES (K-Means, 4 grupos, IDEB 2023, execução guardada) como
    tipologia de escolas num artigo, conferindo o que separa os grupos.
    Antes, conferiu as contas que a ajuda da base dá (a da infraestrutura
    básica bate com o ranking em 627 de 627 escolas de Teresina).
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Abriu a execução guardada do ES** (1.172 escolas, "Desempenho dos
   alunos": nota média, matemática, português, IDEB e aprovação). Os quatro
   grupos vão de "Muito baixo" a "Muito alto desempenho".
2. **Cruzou os grupos com as etapas** em que cada escola teve nota no IDEB
   2023.

   | Grupo | Só anos iniciais | Só anos finais | Só ensino médio | Médio e finais | IDEB médio | Matemática |
   |---|---|---|---|---|---|---|
   | Muito alto | 177 | 5 | 0 | 0 | 6,60 | 255 |
   | **Alto** | **0** | 77 | **67** | **151** | **5,15** | **274** |
   | **Baixo** | **210** | 10 | 0 | 0 | **5,50** | **224** |
   | Muito baixo | 20 | 25 | 4 | 10 | 4,78 | 235 |

   - O grupo "Alto desempenho" tem IDEB **menor** que o "Baixo".
   - Nenhuma das 407 escolas só de anos iniciais está no "Alto"; 67 das 71
     só de ensino médio estão.
3. **Achou a causa no método.**
   - Para o agrupamento, a nota de cada escola é a **média entre as etapas**
     em que ela teve nota.
   - A escala do SAEB cresce com a série: no Brasil, em 2023, matemática
     217 nos anos iniciais, 250 nos finais e 268 no médio. O IDEB faz o
     contrário: 5,66, 4,74 e 4,26.
   - Com as etapas misturadas, a correlação entre matemática e IDEB é 0,40.
     Dentro de cada etapa, é de 0,89 a 0,96.
   - O agrupamento separa, sobretudo, **a etapa que a escola oferece**, e o
     rótulo "Alto/Baixo desempenho" diz outra coisa. A ajuda não fala de
     etapa (RO-01).
4. **O conjunto "Infraestrutura escolar".**
   - Usa `in_esgoto_rede_publica` e `in_energia_rede_publica`, em que 0 não
     quer dizer "sem" (fossa, poço, gerador). A base já avisa isso desde a
     #452.
   - 70.538 escolas em funcionamento têm esgoto fora da rede pública, e só
     4.636 não têm esgoto. No agrupamento, as 70 mil contam como "sem
     esgoto" e puxam o grupo para "Baixa qualidade de infraestrutura"
     (RO-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o agrupamento por desempenho | a base e as outras telas continuam servindo; mas o agrupamento por desempenho mede a etapa oferecida e rotula como desempenho (RO-01), e ela não o usaria como tipologia |

## O que funciona

- **A execução se reproduz:** link, parâmetros, edição dos dados e o CSV
  com o grupo de cada escola (os achados da #427 e da #428 seguem
  resolvidos). Foi isso que deixou a conferência possível.
- **As contas da ajuda da base** batem com o ranking.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RO-01 | atrapalha | **O agrupamento por "Desempenho dos alunos" mistura as etapas.** A nota de cada escola é a média entre as etapas, e a escala do SAEB cresce com a série, enquanto o IDEB cai. Os grupos separam a etapa oferecida, e o rótulo diz "desempenho". Pedido: escolher a etapa (anos iniciais, anos finais ou ensino médio) no agrupamento por desempenho, só com as escolas que têm nota nela, com a etapa nos parâmetros guardados, no rótulo e na ajuda. | ES, IDEB 2023: "Alto" com IDEB 5,15 e "Baixo" com 5,50; 0 de 407 escolas só de anos iniciais no "Alto", 67 de 71 só de ensino médio; correlação matemática × IDEB 0,40 misturado, 0,89 a 0,96 por etapa | P4, P2, P6 |
| RO-02 | detalhe | **O agrupamento por infraestrutura conta fossa, poço e gerador como falta.** Usa os itens "da rede pública". Pedido: os itens "inexistente" (sem esgoto, sem energia) no lugar dos "da rede pública", como na infraestrutura básica do ranking. | 70.538 escolas com esgoto fora da rede, 4.636 sem esgoto | P4, P1, P2 |

## Encaminhamento

Modo autônomo: abri a issue **#481** (RO-01 e RO-02 juntas), decidi o plano
e sigo para a implementação, com aviso pelo Telegram.

## Andamento

- 2026-11-17: #481 (PR #482) mergeado em modo autônomo: RO-01 e RO-02
  resolvidos (agrupamento por IDEB/SAEB numa etapa, obrigatória; etapa no
  rótulo, no link e no CSV; infraestrutura com os itens "inexistente"). ES,
  anos iniciais: IDEB por grupo 5,25 / 5,63 / 6,13 / 7,02, em ordem.
  Fechamento em
  [`../ciclos/2026-11-17-agrupamento-etapa.md`](../ciclos/2026-11-17-agrupamento-etapa.md).
  Nenhum achado aberto.
