# Reavaliação: P4 associa o IDEB à formação docente (2026-11-22)

Trigésima sexta rodada da P4 (academia), rodada sozinha a pedido do
developer (ausente), depois das entregas:

| Entrega | O quê |
|---|---|
| #525 | concursados vazios nas privadas (`indices-v7`, `ivet-v1.9`) e o CSV do agrupamento com o nome da base (QT-01, QT-02) |
| #528 (PR aberto) | rótulos curtos no agrupamento e concursados sem comparação no perfil da privada (#526, #527) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise de SP (todas as redes), blocos Etapas, Docência, IDEB
    e SAEB por etapa, INSE e Porte (30.817 escolas;
    `base-analise-SP-censo2025-ideb2023-inse2023.csv`);
  - o dicionário desses blocos e a ajuda da base;
  - para conferir, a contagem de docentes por etapa do Censo
    (`clean.censo_docentes`, `qt_doc_fund_ai`, `qt_doc_fund_af`,
    `qt_doc_med` e `qt_doc_inf`), que não está na base;
  - o R do host (`lm`).
- **O trabalho que ela faria:** a segunda pergunta do perfil dela, aplicada
  à docência: "quanto da variação do IDEB se associa à formação dos
  professores, controlando por rede e INSE?". Ela modela o IDEB dos anos
  iniciais nas redes municipal e estadual em função das partes do índice de
  capacitação docente, do INSE e da rede.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Montou o modelo** com 5.779 escolas (municipais e estaduais com IDEB
   dos anos iniciais):
   - a base deu tudo numa leitura só;
   - as privadas ficam de fora sozinhas, porque não têm IDEB nem INSE;
   - `prop_efetivos` não tem vazio entre as públicas (#524).
2. **Resultado:** R² de 0,37, com o INSE dominante. Pós-graduação e
   concursados aparecem com efeitos de sinais opostos.
3. **Estranhou o efeito dos concursados (−0,11).** Separou as escolas que
   só têm os anos iniciais das que têm também anos finais ou ensino médio:

   | Escolas | n | Pós-graduação | Concursados |
   |---|---|---|---|
   | só anos iniciais | 4.054 | +0,22 | +0,02 (p = 0,51) |
   | com outras etapas | 1.725 | +0,47 | **−0,30** (p < 0,001) |

4. **Foi ver por quê.** O dicionário diz que as proporções são sobre o
   total de docentes da escola. Nas escolas com outras etapas, os docentes
   dos anos iniciais são só a metade do quadro (mediana de 55%; p25 de 43%,
   p75 de 64%). A formação e o vínculo que ela atribui ao IDEB dos anos
   iniciais são, em boa parte, dos professores dos anos finais e do ensino
   médio.
   - O Censo tem a contagem de docentes por etapa, que a plataforma já
     guarda (`qt_doc_fund_ai`, `qt_doc_fund_af`, `qt_doc_med`,
     `qt_doc_inf`). A base não a entrega, então ela não consegue
     ponderar nem separar as escolas pela parte do quadro em cada etapa.
   - A soma por etapa passa do total da escola em 40% delas: quem dá aula
     em duas etapas conta nas duas.
   - Nenhum texto da base diz que a docência mistura as etapas, o que pesa
     num modelo por etapa.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com ressalva em modelos por etapa | o modelo sai da base numa leitura; mas a docência é da escola inteira, e em 30% das escolas com IDEB dos anos iniciais ela mistura etapas sem que a base permita separar (QS-01) |

## O que funciona

- **Uma leitura só:** etapas oferecidas, docência, IDEB por etapa, INSE e
  porte vêm juntos, com o vazio dito no dicionário.
- **A ressalva de tempo** (docência de 2025, IDEB de 2023) está no
  dicionário de `ano_ideb`.
- **Concursados** sem vazio entre as públicas e vazios nas privadas (#524).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QS-01 | atrapalha | **A docência da base é da escola inteira, e num modelo por etapa mistura professores de outras etapas.** O Censo tem os docentes por etapa (`qt_doc_fund_ai`, `qt_doc_fund_af`, `qt_doc_med`, `qt_doc_inf`), mas a base não os entrega. Pedido: as contagens de docentes por etapa no bloco Docência (com o aviso de que quem dá aula em duas etapas conta nas duas) e, no dicionário e na ajuda, dizer que as proporções de formação e vínculo são da escola inteira, com o cuidado para modelos por etapa. | SP, IDEB dos anos iniciais: 1.725 das 5.779 escolas têm outras etapas, com mediana de 55% dos docentes nos anos iniciais; o efeito dos concursados é −0,30 nelas e +0,02 (p = 0,51) nas escolas só de anos iniciais | P4, P6 |

## Encaminhamento

Issue **#529** (QS-01), aberta sem esperar a aprovação, por autorização
do developer (ausente).
