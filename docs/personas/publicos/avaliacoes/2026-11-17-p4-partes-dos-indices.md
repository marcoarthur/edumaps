# Reavaliação: P4 com as partes dos índices na base (2026-11-17)

Décima segunda rodada da P4 (academia), depois da entrega da décima primeira
rodada:

| Entrega | O quê |
|---|---|
| #476 | capacidade gestora com "gestores por aluno" vazia sem matrícula e "acesso ao cargo" vazio nas privadas, peso redistribuído (`indices-v6`, `ivet-v1.8`); partes da gestora na base (RR-01, RR-02) |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md` e `rankings.md`, e o dicionário da base;
  - `/fontes` e o ranking de escolas;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** a pergunta do perfil "quanto da variação
    do IDEB se associa à infraestrutura, controlando por rede?", agora com
    as partes de todos os índices. Baixou a BA e a MG com todos os blocos e
    copiou da ajuda as expressões que refazem os índices.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A versão nova** (RR-01 e RR-02 resolvidos).
   - Os arquivos terminam em `indices-v6`. `/fontes` e o ranking de escolas
     dizem `indices-v6`, e o método da capacidade gestora diz que o acesso
     ao cargo só conta na rede pública.
   - Capacidade gestora média: estaduais 5,49, federais 5,82, municipais
     5,39 e privadas 4,73. A parte do acesso está vazia em todas as
     privadas e em nenhuma pública.
2. **Refez os índices com as expressões da ajuda** (32.016 escolas).

   | Índice | Escolas com o índice | Refeito igual (±0,01) |
   |---|---|---|
   | capacitação docente | 31.662 | 31.662 |
   | diversidade discente | 31.703 | 31.703 |
   | capacidade de atendimento | 31.703 | 31.703 |
   | **capacidade gestora** | 32.016 | **6.593** |

   - A expressão R da capacidade gestora, copiada da ajuda, erra por até
     4,1 pontos, e a média do erro é 1,8.
   - **A causa é a precedência do `!` em R:** o `!` vale menos que `*` e
     `+`, e `0.2 * !is.na(p3) + 0.1 * !is.na(...)` é lido como
     `0.2 * !(is.na(p3) + 0.1 * !is.na(...))`. O divisor sai errado.
   - Com parênteses (`0.2 * (!is.na(p3))`), a conta bate em 32.016 de
     32.016. A base está certa, e o erro é só do texto da ajuda (RQ-01).
   - Ela só achou porque conferiu. Quem copia a expressão para um artigo
     publica um índice errado, que parece vir do EduMaps.
3. **Tentou refazer a infraestrutura e a sustentabilidade.**
   - A infraestrutura usa 27 itens do Censo, em quatro grupos (básico,
     salas e equipamentos, acessibilidade e tecnologia). A base traz 11
     deles. Uma regressão do índice nesses 11 itens explica 82% da
     variação: perto, mas não é a fórmula.
   - A sustentabilidade usa energia renovável, reciclagem, área verde,
     plantio e educação ambiental, e **nenhum** desses itens está na base.
   - A ajuda diz que "não dá para refazê-los só com as colunas da base",
     com o exemplo dos órgãos colegiados. Hoje quatro dos seis se refazem,
     e os colegiados estão na base. O texto ficou velho, e não diz quais
     dois não se refazem (RQ-02).
4. **O modelo do IDEB** (anos iniciais, escolas públicas da BA e da MG;
   7.445 escolas; com rede, localização, UF e INSE).
   - **Com os seis índices** (R² 0,48): a infraestrutura se associa ao
     IDEB (+0,027 por ponto, p = 0,005), a sustentabilidade (+0,018,
     p < 0,001), a diversidade (+0,051, p = 0,004) e a capacidade gestora
     (+0,014, p = 0,015). A capacidade de atendimento sai negativa (−0,031,
     p = 0,005), e a capacitação docente não se associa (p = 0,17).
   - **Com as partes** (R² 0,49): na capacidade gestora, a formação dos
     gestores (+0,09, p = 0,005) e os gestores por aluno (+0,16,
     p < 0,001) somam, mas o **acesso ao cargo por seleção sai negativo**
     (−0,17, p < 0,001). Como os efetivos da capacitação docente na oitava
     rodada, uma parte com peso positivo se associa no sentido oposto. Não
     é causal, mas só as partes mostram isso.
   - A infraestrutura entra só como índice. Ela não consegue dizer se o
     que se associa ao IDEB é o básico (água e esgoto) ou os equipamentos
     (laboratório e internet), que é a pergunta do perfil.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido) | quatro índices se refazem e se decompõem pela base, e o modelo com as partes responde mais do que o índice; mas a expressão da ajuda para a capacidade gestora dá números errados (RQ-01), e a infraestrutura, centro da pergunta dela, não se decompõe (RQ-02) |

## O que funciona

- **Versão em todo lugar:** arquivo, `/fontes`, ranking e método dizem
  `indices-v6`.
- **Base certa:** as partes dos quatro índices compostos refazem cada
  índice em todas as escolas.
- **Partes que contam outra história:** o acesso ao cargo e os efetivos se
  associam ao IDEB ao contrário do peso que têm.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RQ-01 | atrapalha | **A expressão R da ajuda que refaz a capacidade gestora está errada.** Em R, `!` tem precedência menor que `*` e `+`: o divisor `0.7 + 0.2 * !is.na(p3) + 0.1 * !is.na(...)` sai errado. Pedido: parênteses em `(!is.na(...))` e um teste que rode as expressões R da ajuda contra a base, para nenhuma delas divergir do índice. | 6.593 de 32.016 escolas batem; erro de até 4,1 pontos; com parênteses, 32.016 de 32.016 | P4, P6 |
| RQ-02 | atrapalha | **A infraestrutura e a sustentabilidade não se decompõem pela base, e a ajuda não diz isso.** A base traz 11 dos 27 itens da infraestrutura e nenhum da sustentabilidade. A ajuda ainda diz que nenhum índice se refaz, com o exemplo dos colegiados, que já estão na base. Pedido: as partes dos dois índices na base (os quatro grupos da infraestrutura e as quatro partes da sustentabilidade), com as expressões da MV, e o texto da ajuda atualizado. | infraestrutura ~ 11 itens da base: R² 0,82; sustentabilidade: 0 itens | P4, P1, P2 |

## Encaminhamento

Issue aberta com a aprovação do developer (2026-11-17): **#477** (RQ-01 e
RQ-02 juntas).

### Proposta

1. **RQ-01:** fix de texto e um teste novo. O teste roda, no `testthat`,
   cada expressão R da ajuda da base contra uma base de exemplo e compara
   com o índice. Não muda a fórmula nem a versão. Urgente, porque a ajuda
   errada já está publicada no main.
2. **RQ-02:** as partes na base, como nas #469, #471, #473 e #475.
   - **Infraestrutura:** `infra_basico`, `infra_pedagogico`,
     `infra_acessibilidade` e `infra_tecnologia` (0 a 1, média de cada
     grupo), mais os itens que faltam no bloco Infraestrutura, se o
     developer preferir.
   - **Sustentabilidade:** `energia_renovavel`, `reciclagem`,
     `area_verde_plantio` e `educacao_ambiental`.
   - O texto da ajuda diz que os seis se refazem. A fórmula não muda, e a
     versão não sobe.
3. Podem ir juntas numa issue, como as anteriores, ou a RQ-01 sozinha
   antes, por ser um erro publicado.
