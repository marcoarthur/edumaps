# Ciclo 2026-11-13: visão da rede

- **Período:** 2026-11-12 (spec e issues) a 2026-11-13 (último merge).
- **História:** #375, parte do épico #368. Issues fechadas: #394 a #398.
- **PRs:** #399 a #403.
- **Avaliação:** [visão da rede](../avaliacoes/2026-11-13-visao-da-rede.md),
  pelas personas P2 e P1.
- **Engenharia:** nota técnica 193.

## Resumo

A secretaria ganhou uma **conta própria** e passou a acompanhar os planos de
**todas as escolas da rede** num painel só, sem pedir planilha a cada diretor.
No painel ela vê:

- quem está sem plano, atrasado ou sem metas medidas;
- as metas que seguem o mesmo indicador oficial, lado a lado;
- o relatório de cada escola, só para leitura;
- o custo previsto e o **executado** por fonte de recurso, na rede e por
  escola.

A escola passou a registrar quanto gastou em cada ação.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria → **adotaria** (mantido).

**O que mudou para ela:**

- **Custo executado e data da execução** em cada ação. O relatório mostra
  previsto × executado por fonte. O que ela não registrou aparece como "—",
  não como R$ 0.
- O relatório diz o **cargo** de quem o emitiu, sem o nome.
- A tela **sugere o indicador oficial** quando uma meta manual lembra um deles.
- A **secretaria da rede lê** o plano e o relatório, sem editar. A ajuda diz
  isso.

**Impacto para ela:** responde ao conselho escolar "quanto foi gasto, de qual
recurso?" sem planilha à parte. O plano dela passa a contar na visão da
secretaria, o que dá peso a mantê-lo em dia.

**Pendente:**

- Nenhum. O aviso, na tela do plano, de que a secretaria o lê (P1-RD-01)
  entrou no PR #408 (#407).

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria com ressalvas, quando a #375 existir → **adotaria, em
piloto numa rede**.

**O que mudou para ele:**

- **Conta de rede por convite**, ligada pelo administrador à rede (municipal
  ou estadual, por município). Ele vê só as escolas da rede dele e não altera
  nada.
- **Painel da rede:** em cada escola, o plano vigente, o andamento ("N de M
  metas medidas"), as ações atrasadas e as que vencem em 7 dias, e as
  evidências. Filtros e ordenação para achar quem precisa de apoio.
- **Relatório de cada escola**, o mesmo que o diretor imprime, com o cargo de
  quem emitiu.
- **Metas comparáveis por indicador oficial**, com o andamento médio só das
  medidas e a base ajustada marcada.
- **Custo por fonte de recurso**, previsto × executado:
  - na rede e por escola;
  - com os mesmos números do relatório de cada escola;
  - sem contar ação sem valor como R$ 0;
  - com os planos encerrados à parte.

**Impacto para ele:** existe o valor que justifica o contrato da rede: a
visão consolidada. Ele deixa de depender de cada diretor mandar o relatório,
e a equipe técnica sabe onde ir primeiro. P2-PG-01, -03, -04 e -06
resolvidas.

**Pendente:**

- custo **por exercício** (P2-RD-01, #404);
- um **documento consolidado** da rede para o conselho municipal (P2-RD-02, #405);
- valores oficiais que se atualizam **sem a escola abrir o plano**
  (P2-RD-03, #406);
- vínculo por **diretoria regional**, para a rede estadual (P2-RD-04, só com
  uma rede estadual real).

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** O vínculo da rede é por dependência
pública e município do Censo. Uma rede privada com várias unidades pediria o
mesmo painel com outro critério de vínculo, que não existe. Não houve
avaliação. Fica registrado que o painel é a base reaproveitável se o perfil
pedir acompanhamento por unidade.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.** O plano e a visão da rede são dados
internos da escola e da secretaria, sem exportação nem dado aberto. Não houve
avaliação.

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.** O acesso de órgão de controle ficou fora
do escopo por decisão do developer (spec, decisão 5): o posicionamento segue
sem decisão no plano de negócios. Não houve avaliação.

Indiretamente, o conselho passa a receber da secretaria números com fonte e
com o executado por fonte de recurso. Falta o documento consolidado
(P2-RD-02).

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.** Nada da visão da rede é público. Não
houve avaliação.

## O que este ciclo ensinou

- A visão da rede somou o que já existia na escola, sem criar um segundo
  cálculo:
  - o painel usa o mesmo andamento das metas;
  - os custos usam a mesma soma do relatório.

  Por isso "os números da rede batem com os da escola" é um teste, não uma
  promessa.
- A regra "ausência não é zero" foi a que mais pesou para a P2: é ela que
  deixa um total de rede ser levado a sério.
- As barreiras novas da P2 já não são de dado faltando. São de **uso
  institucional** (exercício fiscal, documento para o conselho): o produto
  passou da fase de "mostrar" para a de "prestar contas".
