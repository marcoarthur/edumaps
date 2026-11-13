# Avaliação: visão da rede (2026-11-13)

Fim do sprint #394 a #398 (história #375, épico #368), PRs #399 a #403.
Protocolo em [`../README.md`](../README.md).

- **Personas:** P2 (a funcionalidade é dela) e P1 (ganhou o custo executado
  e passou a ter o plano lido pela secretaria).
- **Material:**
  - a ficha e a ajuda da rede e do gestor;
  - a spec;
  - as telas com os dados de demonstração, como os testes de tela as montam:
    painel, metas comparáveis, custos, relatório pela rede e convite.

Desta vez não houve sessão no navegador com os mocks.

⚠️ Continua sendo um ensaio com personas simuladas: não substitui a conversa
com uma secretaria real.

## Vereditos

| Persona | Antes | Agora | Por quê |
|---|---|---|---|
| P2 | adotaria com ressalvas, quando a #375 existir | **adotaria, em piloto numa rede** | a visão consolidada que justifica o contrato existe; faltam o recorte por exercício e um documento da rede para o conselho |
| P1 | adotaria | **adotaria** (mantido) | o custo executado responde ao conselho escolar; saber que a secretaria lê o plano não a afasta, mas ela quer ver o aviso na tela, não só na ajuda |

## P2 — Secretário municipal de educação

**O que resolve para ele:**

- **P2-PG-01 resolvida.** O painel mostra todas as escolas da rede com o plano
  vigente, o andamento ("N de M metas medidas", nunca 0% sem medida), as ações
  atrasadas e as evidências. Os filtros "sem plano vigente" e "com ações
  atrasadas" respondem "onde a equipe técnica vai esta semana?".
- **P2-PG-03 resolvida.** As metas que seguem o mesmo indicador oficial
  aparecem lado a lado, com o andamento médio só das medidas e a base ajustada
  marcada. Metas manuais ficam à parte, e ele não compara número que não fecha.
- **P2-PG-04 resolvida.** O relatório diz o cargo de quem o emitiu, sem o nome.
- **P2-PG-06 resolvida.** O relatório da escola e o painel da rede mostram
  previsto × executado por fonte (PDDE, Fundeb...):
  - os números da rede são os mesmos do relatório de cada escola;
  - ação sem valor aparece como "—" e é contada à parte;
  - os planos encerrados ficam fora do total, numa linha própria.
- Conta própria por convite, ligada pelo administrador. Ele não vê escola de
  outra rede e não altera o plano: é o controle que ele exigia.

**Barreiras novas:**

| Id | Gravidade | Barreira | Evidência |
|---|---|---|---|
| P2-RD-01 | atrapalha | O custo não tem **recorte por exercício**. A prestação do Fundeb e do PDDE é anual, e a soma junta tudo o que o plano vigente prevê, de qualquer ano. A data da execução existe na ação, mas o painel não filtra por ela. | seção de custos do painel |
| P2-RD-02 | atrapalha | Não há **documento da rede** para imprimir ou exportar (o painel, os custos, as metas comparáveis). O relatório por escola imprime; o consolidado, que o conselho municipal pede, não. | painel `/rede`, sem "Imprimir" nem planilha |
| P2-RD-03 | incomoda | O andamento das metas oficiais só ganha o valor novo quando a **escola abre o plano**. Escola que não entra fica com o número antigo no painel, e a tela só avisa no rodapé. | rodapé do painel e das metas comparáveis |
| P2-RD-04 | incomoda | A rede estadual organizada por **diretoria regional** vira um vínculo por município, que o administrador concede um a um. Funciona para o município, mas fica pesado para a regional. | ajuda do administrador, "Contas de rede" |

**Veredito:** **adotaria, em piloto numa rede.** Ele usaria o painel com a
equipe técnica e cobraria o executado das escolas. Ele não levaria o painel
ao conselho municipal antes do recorte por exercício (P2-RD-01) e do
documento consolidado (P2-RD-02).

## P1 — Diretora de escola municipal

**O que muda para ela:**

- **Custo executado e data** na ação, ao lado do previsto. No relatório, o
  conselho escolar vê quanto foi gasto por fonte, e o que ela ainda não
  registrou aparece como "—", não como R$ 0.
- **Sugestão do indicador oficial** quando uma meta manual lembra um deles:
  menos digitação, e a meta passa a valer na comparação da rede.
- A ajuda diz que **a secretaria vê o plano e o relatório**, só para leitura,
  e pede o cargo, não o nome, no campo responsável.

**Barreiras novas:**

| Id | Gravidade | Barreira | Evidência |
|---|---|---|---|
| P1-RD-01 | incomoda | A **tela do plano não avisa** que a secretaria da rede lê o plano e o relatório. Só a ajuda diz isso, e a tela só cita a secretaria na sugestão de indicador. Ela escreveria o responsável de outro jeito se soubesse. | página do plano; ajuda, seção "Privacidade" |

Nenhuma barreira a faz desistir. Ela anota que o executado vira cobrança da
secretaria: é bom para o plano, mas é mais um campo a manter.

**Veredito:** **adotaria** (mantido).

## Não se aplica

- **P3 (rede privada):** o vínculo da rede é por dependência pública e
  município do Censo. Uma rede privada de várias unidades pediria o mesmo
  painel com outro critério de vínculo, que não existe.
- **P4, P5, P6:** o plano é dado interno da escola e da secretaria. Não há
  dado aberto nem acesso fora da conta de rede. P5 segue sem decisão de
  posicionamento (spec, decisão 5).

## Achados e encaminhamento

| Achado | Proposta | Situação |
|---|---|---|
| P2-RD-01 | filtro por exercício (ano da execução / do prazo) na seção de custos | #404 |
| P2-RD-02 | "Imprimir / salvar PDF" do painel e dos custos da rede, no padrão do relatório da escola | #405 |
| P2-RD-03 | sincronizar as medições oficiais em lote (job), não só ao abrir o plano | #406 |
| P1-RD-01 | uma linha no topo do plano: "a secretaria da sua rede vê este plano, só para leitura" | #407, entregue no PR #408 |
| P2-RD-04 | vínculo por diretoria regional (change nova, já prevista na spec como risco) | registrar no backlog; só com uma rede estadual real |
