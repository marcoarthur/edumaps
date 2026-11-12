# Persona P2: secretário municipal de educação

> Público **P2 — Gestor de rede: secretarias municipais** 🎯 do plano de
> negócios (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** secretário de educação de um município de médio porte (rede
  própria com 30 a 80 escolas), com uma equipe técnica pequena e orçamento
  escasso. Responde ao prefeito, ao conselho municipal e aos órgãos de
  controle.
- **Quem paga:** ele (secretaria ou prefeitura). Ticket de R$ 30 mil a 120 mil
  por ano, ciclo de venda de 6 a 18 meses.
- **Dor central:** priorizar escolas com recurso limitado **e prestar
  contas**. O novo Fundeb (VAAR) e a fiscalização pedem que o município
  **demonstre** resultado.
- **Perguntas típicas:**
  - "Quais escolas precisam de mais apoio, e por quê?"
  - "As escolas estão cumprindo os planos de ação? Onde estão atrasadas?"
  - "Quanto do PDDE e do Fundeb está previsto em cada ação?"
  - "Como mostro ao conselho e ao tribunal de contas que a rede avança?"
- **O que usa:** comparação de redes, ranking de escolas, clusters, painel
  financeiro, folha de pagamento.
- **O que valoriza:** visão consolidada da rede, número comparável entre
  escolas, rastro da fonte, relatório que se sustenta numa auditoria.
- **O que o faz desistir:** ter de pedir a cada diretor uma planilha diferente;
  dado que não fecha entre escolas; ferramenta que expõe a rede sem o controle
  dele.

## Pendências

- Avaliar a visão da rede quando a #375 existir: consolidação dos planos das
  escolas, metas oficiais comparáveis e custo por fonte de recurso.
- Rever a barreira P2-PG-02 (custo e fonte de recurso no relatório).

## Entradas

### 2026-11-12 — Planos de gestão acompanháveis (épico #368)

**Aplicabilidade:** parcial. A funcionalidade é da escola. O que já toca a
ele é o **relatório** que o diretor entrega e a preparação da **visão da
rede** (#375, backlog).

**Material:** ficha, ajuda, spec (§1 e RF-009) e o relatório com os dados de
demonstração.

**O que ele tentou fazer:** receber o relatório de uma escola e usá-lo na
prestação de contas; imaginar a consolidação de 40 escolas.

**O que funciona para ele:**

- **Relatório com a fonte e o ano** de cada indicador oficial e a data de
  emissão. Ele aguenta a pergunta "de onde veio esse número?".
- **"N de M metas medidas"**: não esconde metas sem dado, o que dá
  credibilidade perante o conselho.
- **Metas ligadas a indicadores do catálogo** (IDEB, matrículas,
  infraestrutura, IVET) são a base de uma visão de rede comparável.
- **Evidências** (atas, documentos) respondem a "como vocês sabem que foi
  feito?".

**Barreiras:**

| Id | Gravidade | Barreira | Evidência |
|---|---|---|---|
| P2-PG-01 | **bloqueia** (para ele) | Não há **visão da rede**: ele depende de cada diretor imprimir e enviar o relatório. É exatamente a "planilha por escola" que ele quer evitar. Já está no backlog (#375). | spec, "Ainda não disponível" na ficha |
| P2-PG-02 | atrapalha | O relatório **não traz custo previsto nem fonte de recurso** (PDDE, Fundeb...), embora a ação tenha os dois campos. Para prestar contas do Fundeb, é a informação que ele mais procura. | relatório de demonstração |
| P2-PG-03 | atrapalha | **Metas manuais em texto livre** não se somam entre escolas. Para a visão da rede, só as metas com indicador oficial serão comparáveis; vale orientar as escolas a usar o catálogo quando houver indicador. | formulário de meta |
| P2-PG-04 | detalhe | O relatório não diz **quem** emitiu (cargo). Para o arquivo da secretaria, ajuda; pela privacidade, o cargo basta, sem o nome. | cabeçalho do relatório |

**Veredito:** **adotaria com ressalvas, quando a #375 existir.** Hoje o
relatório por escola já ajuda o diretor a prestar contas a ele, e isso
sustenta a adoção na rede. Mas o valor que justifica o contrato dele é a
visão consolidada, com custo por fonte de recurso.
