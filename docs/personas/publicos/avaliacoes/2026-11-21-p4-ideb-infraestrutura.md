# Reavaliação: P4 relaciona IDEB e infraestrutura pela base (2026-11-21)

Trigésima rodada da P4 (academia), a pedido do developer, depois da entrega
da vigésima nona rodada:

| Entrega | O quê |
|---|---|
| #513 | folha da base de análise pelo ano da UF, cobertura na tela e em `/fontes`, magistério por mês e auxiliares educacionais (QZ-01 a QZ-03) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise da BA, rede pública (municipal, estadual e federal),
    blocos "Etapas", "Infraestrutura", "IDEB e SAEB" (2023), "Índices" e
    "INSE" (`base-analise-BA-publica-censo2025-ideb2023-inse2023-indices-v6.csv`),
    e a da rede municipal com "Docência";
  - o R do host (`read.csv2`, `lm`) e o bloco R da ajuda que refaz os seis
    índices;
  - a ajuda da base de análise e o dicionário;
  - o banco local, só leitura.
- **O trabalho que ela faria:** responder a uma das perguntas do perfil
  dela, "quanto da variação do IDEB se associa à infraestrutura,
  controlando por rede?", na BA, do download ao modelo.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Conferiu a junção.** A tabela do IDEB não tem linha repetida por
   escola, edição e etapa. A rede da escola vem do Censo; em 2023, a rede do
   IDEB diverge da do Censo em 83 das 97.111 escolas em funcionamento.
2. **Leu no R com a instrução da ajuda** (`read.csv2`): 13.366 escolas.
   - INEP e código IBGE vêm como número; IDEB, índices e coordenadas, como
     decimal; o vazio, como `NA`.
   - O INSE existe para 3.392 das 3.395 escolas com IDEB dos anos iniciais.
3. **Refez o IDEB** pela nota média e pelo rendimento:
   6,29 × 0,986 = 6,2, e o mesmo nas outras escolas que conferiu.
4. **Refez os seis índices** com o bloco R da ajuda, na rede municipal:
   nenhuma diferença nas 11.932 escolas, e o vazio cai nas mesmas.
5. **Rodou o modelo.**
   - Nos anos iniciais, 3.380 das 3.395 escolas com IDEB são municipais:
     não há como controlar por rede.
   - Ela foi para os anos finais: `ideb_af ~ indice_infraestrutura +
     inse_media + rede`, com 2.271 escolas. O INSE domina (0,81 por ponto);
     a infraestrutura fica pequena (0,045 por ponto do índice) e
     significativa; a rede municipal não difere da estadual depois do INSE.
6. **Olhou os anos.** O arquivo diz em cada linha o Censo (2025), o IDEB
   (2023) e o INSE (2023). Ainda assim, o modelo explica o IDEB de 2023 com
   a infraestrutura de 2025: o preditor é medido depois do resultado, e as
   escolas que fecharam entre 2023 e 2025 saem da base.
   - A tela e o dicionário só avisam do cruzamento quando a edição do IDEB
     não é a mais recente (ex.: 2019).
   - Com a edição mais recente, que é o padrão, não há aviso, e a distância
     é a mesma: dois anos.
   - O efeito no número de escolas é pequeno: no Brasil, 254 das 41.295
     escolas com IDEB dos anos iniciais em 2023 não estão em funcionamento
     no Censo 2025 (0,6%); na BA, 36 (1%).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com a base para a pergunta do perfil | do download ao modelo sem SQL nem junção à mão, e as contas se refazem; só falta dizer o cruzamento de anos também na edição mais recente do IDEB (QY-01) |

## O que funciona

- **A base lê no R** com a linha da ajuda, sem ajuste de tipo.
- **O IDEB se refaz** pela nota média e pelo rendimento; **os seis índices
  se refazem** pelo bloco R da ajuda, sem nenhuma diferença.
- **A rede vem do Censo**, e a junção do IDEB não duplica escola.
- **Cada linha diz o ano** de cada fonte, e o nome do arquivo também.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QY-01 | detalhe | **O cruzamento de anos só é dito com uma edição antiga do IDEB.** Só o Censo mais recente está carregado (2025). Com a edição mais recente do IDEB (2023), que é o padrão, a infraestrutura, a docência e a lista de escolas vêm de dois anos depois da prova, e as escolas fechadas nesse meio-tempo saem. A tela, o dicionário (`ano_ideb`) e a ajuda só avisam quando a edição não é a mais recente. Pedido: o aviso sempre que o ano do IDEB for diferente do ano do Censo, com a distância em anos; na ajuda, a consequência para modelos (preditor medido depois do resultado; escolas fechadas fora) e que o INSE é da mesma edição do SAEB. | Base da BA com IDEB 2023: sem aviso. Brasil: 254 de 41.295 escolas com IDEB dos anos iniciais em 2023 fora do Censo 2025 em funcionamento (0,6%); BA: 36 | P4, P6 |

## Encaminhamento

Aguarda a aprovação do developer para abrir a issue (QY-01).
