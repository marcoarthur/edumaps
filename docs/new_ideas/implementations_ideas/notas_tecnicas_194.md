# Nota técnica 194: achados da avaliação da rede (#407, #404, #405)

PRs #408 a #410 (2026-11-13). Fecham a #407 (P1-RD-01), a #404 (P2-RD-01) e
a #405 (P2-RD-02),
abertas pela avaliação das personas da visão da rede. Continua a nota 193.

## #407: aviso de que a secretaria vê o plano (PR #408)

- **Onde aparece o aviso:**
  - no topo da página do plano;
  - no relatório da escola, com `print:hidden`, porque o documento impresso
    não precisa dele.
- **Texto:** é condicional ("se a secretaria da sua rede usa o EduMaps"). A
  escola não sabe se existe conta de rede ligada à rede dela, e escola
  privada nunca entra numa rede.
- **Campo responsável:** ganhou exemplo e dica (`aria-describedby`): cargo ou
  equipe em vez de nome, porque o responsável sai no relatório que a rede lê.

## #404: custos por exercício (PR #409)

- **Parâmetro:** `?exercicio=AAAA` no relatório da escola, no relatório pela
  rede e em `/api/rede/custos`.
  - Vazio é "todos os anos", o comportamento de antes e o padrão da tela
    (decisão do developer).
  - Ano fora de `^(19|20|21)\d{2}$` responde 400 (`_pl_exercicio`).
- **Regra, decidida pelo developer:**
  - o **previsto** entra pelo ano do **prazo** da ação;
  - o **executado** entra pelo ano da **data de execução**.
- **O que fica fora do ano, sem ano presumido e sempre contado:**
  - a ação sem prazo (`n_acoes_sem_prazo`);
  - o executado sem data (`n_executado_sem_data`).
- **Universo do recorte:** "sem custo" e "sem executado" contam as ações com
  prazo no exercício. Um executado com data no ano entra mesmo que o prazo da
  ação seja de outro ano: o dinheiro saiu naquele exercício.
- **`exercicios`:** os anos presentes nos prazos e nas execuções, para o
  seletor. Na rede, a lista junta os anos dos vigentes e dos encerrados.
- **Uma função só:** a regra vive em `_pl_custos($acoes, $exercicio)`. O
  `custos.t` confere que, por exercício, os custos de uma escola na rede são
  iguais aos do relatório dela.
- **Ausência não é zero (#154):** com o recorte, o total previsto pode ficar
  sem nenhum valor (só executado no ano). A tela mostra "—" nesse caso, em vez
  do `total: 0` que a API mantém por compatibilidade.
- **Frontend:**
  - o seletor `ExercicioSelect` é compartilhado pelo relatório (escola e rede)
    e pelo painel;
  - a troca de ano recarrega só os dados, sem esconder a página;
  - no painel, só a seção de custos é recarregada.
- **Mocks:** o mock dos planos espelha a mesma regra (`custosPorFonte`).

## #405: documento da rede (PR #410)

- **Página `/rede/documento`:** uma folha A4 para o conselho municipal com
  quatro partes:
  - o resumo;
  - as escolas e os planos vigentes;
  - os custos por fonte, consolidados e por escola;
  - as metas comparáveis.
- **Sem cálculo novo:** a página chama os mesmos quatro endpoints do painel
  (`me`, `painel`, `indicadores`, `custos`). Os números são os do painel por
  construção, e não houve mudança no backend.
- **Reaproveitamento:** os custos usam o próprio `RedeCustos`. O novo
  `sempreAberto` deixa a tabela por escola aberta e esconde o botão, e a
  coluna do link para o relatório não sai na impressão. O seletor de exercício
  continua, fora da impressão, e o título da seção diz o ano.
- **Emissão:**
  - **data:** a hora do navegador no fuso de Brasília (`Intl`), porque não
    havia um campo do servidor para isso. Se for preciso a hora do servidor,
    como no relatório da escola, é um campo a mais na API;
  - **quem emitiu:** só o cargo da conta de rede, sem o nome nem o e-mail
    (teste).

## Pendente

- #406: sincronização das medições oficiais em lote.
- Deploy LXC: o mesmo da nota 193, sem change nova de banco nestes dois PRs.
