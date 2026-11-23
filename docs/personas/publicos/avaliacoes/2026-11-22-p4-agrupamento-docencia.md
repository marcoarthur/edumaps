# Reavaliação: P4 agrupa as escolas de SP pela docência (2026-11-22)

Trigésima quinta rodada da P4 (academia), a pedido do developer, depois da
entrega da trigésima quarta rodada:

| Entrega | O quê |
|---|---|
| #523 | "sem especialização" passa a "sem formação continuada" na base (`prop_sem_formacao_continuada`), nos perfis, nos sinais, no agrupamento, no banco e nas ajudas (QU-01, QU-02) |

- **Avaliou:** só a P4.
- **Material:**
  - o agrupamento com o conjunto pronto "Qualidade de docência"
    (K-Means, 4 grupos, recorte Sudeste/SP), com o resumo dos grupos e o
    CSV da execução (30.295 escolas);
  - a base de análise de Franca (rede privada, blocos Docência e Índices)
    e o ranking de escolas de Franca pelo índice de capacitação docente;
  - a ajuda do agrupamento, a da base e o dicionário de variáveis do INEP
    (`data_pipeline/dicionarios/censo_inep_variaveis.csv`);
  - o R do host (`read.csv2`, `table`, `aggregate`).
- **O trabalho que ela faria:** separar as escolas de SP em perfis
  docentes e cruzar os grupos com a rede, para saber se o perfil docente
  da escola privada difere do da pública, e conferir se a correção da
  #523 chegou ao agrupamento.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Rodou o agrupamento** e baixou o CSV
   (`agrupamento-censo2025-ideb2023-<run_id>.csv`): ano do Censo e do IDEB
   no nome e nas últimas colunas, como a ajuda promete.
2. **Cruzou os grupos com a rede:**

   | Grupo | Estadual | Federal | Municipal | Privada |
   |---|---|---|---|---|
   | Muito alta qualidade da docência | 612 | 41 | 463 | 584 |
   | Alta qualidade da docência | 953 | 0 | 9.605 | 254 |
   | Baixa qualidade da docência | 3.940 | 2 | 2.748 | 9.513 |
   | Muito baixa qualidade da docência | 55 | 0 | 333 | 1.192 |

   - 92,7% das privadas caem em "Baixa" ou "Muito baixa", contra 23% das
     municipais.
3. **Procurou a causa.** A proporção de concursados (`prop_efetivos`) é
   **0 em todas as 11.543 privadas** de SP, e o conjunto pronto a conta
   como "maior é melhor".
   - No dicionário do INEP, o vínculo do docente (concursado, contrato
     temporário, terceirizado, CLT) é "apenas para docente de escola
     pública". Na privada, o Censo não pergunta. O 0 é ausência de
     pergunta, não ausência de concursados.
   - Nas 41.657 privadas do Brasil com o índice, nenhuma tem docente em
     qualquer vínculo.
4. **Viu o mesmo 0 no índice e na base:**
   - **Base:** `prop_efetivos` = 0 nas privadas, e o dicionário não diz que
     a pergunta é só da pública.
   - **Índice de capacitação docente:** os concursados valem 20%, e a
     privada fica com no máximo 8 de 10. Média no Brasil: 3,88 nas
     privadas contra 6,40 e 6,41 nas municipais e estaduais. Sem a parte que
     não existe para elas, com o peso redistribuído, a média das privadas
     seria 4,85.
   - **Ranking de escolas de Franca** por capacitação docente, que mistura
     as redes: 116 das 136 privadas estão na metade de baixo, e só uma
     entre as 30 primeiras.
   - A capacidade gestora já trata o mesmo caso: o acesso ao cargo fica
     vazio nas privadas e o peso vai para as outras partes (#475). A
     capacitação docente não.
5. **Conferiu a #523 no agrupamento:**
   - o CSV e a lista de indicadores trazem `prop_sem_especializacao`, e a
     base traz `prop_sem_formacao_continuada`. Quem junta o CSV do
     agrupamento com a base pelo INEP fica com dois nomes para a mesma
     medida, e nenhuma das duas ajudas diz isso;
   - na tela, "O que mais o distingue" monta o rótulo do comentário da
     coluna, tirando o que está entre parênteses. O comentário novo vira
     "Proporção de docentes sem formação continuada de no mínimo 80 horas .
     O nome da coluna é histórico: não é a pós-graduação", com o espaço
     antes do ponto e uma frase que só faz sentido para quem lê o banco.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com ressalva na comparação entre pública e privada | o agrupamento se reproduz e diz a versão dos dados; mas o 0 de concursados nas privadas, que o Censo não pergunta, empurra as privadas para baixo no agrupamento, no índice e no ranking (QT-01), e o agrupamento ainda fala o nome antigo da coluna (QT-02) |

## O que funciona

- **O CSV do agrupamento** diz a base no nome e nas colunas, e o resumo diz
  em que cada grupo se afasta da média.
- **O rótulo "sem formação continuada"** chegou ao perfil e ao comentário
  do banco que o agrupamento lê.
- **A capacidade gestora** já mostra o caminho para uma parte que não
  existe numa rede: vazia, com o peso redistribuído (#475).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QT-01 | atrapalha | **Concursados nas privadas: 0 onde o Censo não pergunta.** O vínculo do docente é só para escola pública (INEP), mas `prop_efetivos` sai 0 nas privadas. Isso derruba a privada no conjunto "Qualidade de docência" do agrupamento, no índice de capacitação docente (20%, teto de 8) e no ranking que mistura as redes. Pedido: vazio nas privadas (base, índice e agrupamento), com o peso redistribuído no índice, como na capacidade gestora (#475), e o dicionário e as ajudas dizendo por quê. | SP: 92,7% das privadas em "Baixa"/"Muito baixa" contra 23% das municipais; 0 concursados em 11.543 privadas. Brasil: média 3,88 nas privadas, 4,85 com o peso redistribuído. Franca: 116 das 136 privadas na metade de baixo do ranking | P4, P3, P6 |
| QT-02 | detalhe | **O agrupamento ainda fala "especialização".** O CSV e a lista de indicadores trazem `prop_sem_especializacao`, e a base `prop_sem_formacao_continuada`. O rótulo da tela vem do comentário inteiro do banco: "…80 horas . O nome da coluna é histórico: não é a pós-graduação". Pedido: o mesmo nome no CSV do agrupamento e na base (ou a ajuda dizendo a equivalência), e um rótulo curto na tela. | CSV da execução `run_1795351032_eba0c038`; `GET /api/cluster/columns` | P4 |

## Encaminhamento

Issue **#524** (QT-01 e QT-02), aberta com a aprovação do developer.

## Andamento

- 2026-11-22: #524 (PR #525) mergeado: QT-01 e QT-02 resolvidos.
  - Concursados vazios nas privadas na base, no agrupamento (as privadas
    saem do conjunto docência, e a caixa Universo as conta), nos perfis e
    no relatório por rede.
  - Capacitação docente da privada com o peso redistribuído (`indices-v7`,
    IVET `ivet-v1.9`): média no Brasil de 3,88 para 4,85, teto de 10. Em
    Franca, 108 das 136 privadas na metade de baixo do ranking (eram 116).
  - O CSV do agrupamento traz `prop_sem_formacao_continuada`; a tela
    mostra "Docentes sem formação continuada" e "Proporção de docentes
    concursados".
- 2026-11-23: sobras do ciclo resolvidas no PR #528. Os indicadores
  escolhidos no agrupamento aparecem com o rótulo curto (#526), e o perfil
  da escola privada mostra os concursados sem comparação e com o motivo
  (#527).
