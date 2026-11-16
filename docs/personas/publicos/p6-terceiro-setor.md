# Persona P6: analista de fundação educacional e jornalista de dados

> Público **P6 — Terceiro setor, ONGs e jornalismo de dados** 🥉 do plano de
> negócios (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** analista de uma fundação educacional ou observatório, e o
  jornalista de dados que cobre educação num veículo regional.
- **Quem paga:** assinatura de dados ou API, ou projeto financiado (R$ 20 mil
  a 80 mil por ano). Ciclo curto a médio.
- **Dor central:** monitorar redes e produzir análise ou reportagem com dado
  **verificável e citável**.
- **Perguntas típicas:**
  - "Quais redes mais melhoraram (ou pioraram) no IDEB?"
  - "Onde estão as escolas sem infraestrutura básica?"
  - "Posso citar este número, e com qual fonte?"
- **O que usa:** busca de escolas, ranking, clusters, fontes de dados.
- **O que valoriza:** link estável para citar, fonte e data em cada número,
  exportação simples.
- **O que o faz desistir:** número sem fonte, dado que não se baixa, painel
  bonito que não se cita.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-13 — fluxo do INEP](ciclos/2026-11-13-fluxo-inep.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-13 — escolas semelhantes em dia](ciclos/2026-11-13-embedding-diario.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-14 — botão de salvar sem réplica](ciclos/2026-11-14-duplo-envio.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-14 — envio sem duplicidade no servidor](ciclos/2026-11-14-envio-sem-duplicidade.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-14 — suíte em paralelo e backend sem o PDL](ciclos/2026-11-14-build-e-testes.md#p6--terceiro-setor-e-jornalismo-de-dados): sem impacto direto.
- [2026-11-15 — análises públicas legíveis e ausência honesta](ciclos/2026-11-15-analises-legiveis.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria com ressalvas (mantido; sem reavaliação). Resolvido AN-01; ficam AN-08, AN-11.
- [2026-11-15 — busca por município, menus em PT-BR e menos jargão](ciclos/2026-11-15-busca-e-linguagem.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria com ressalvas (mantido). Exportação em PT-BR e município certo; ficam #428 e #430.
- [2026-11-15 — agrupamento que presta contas e se reproduz](ciclos/2026-11-15-agrupamento-reprodutivel.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria com ressalvas (mantido). Agrupamento com link e CSV; ficam #428 e #430.
- [2026-11-15 — fonte, ano e versão dos dados na tela](ciclos/2026-11-15-fontes-e-metodologia.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria com ressalvas (mantido). Ano do dado e página citável; fica #430.
- [2026-11-15 — ranking de redes municipais e de escolas por município](ciclos/2026-11-15-ranking-de-redes.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria com ressalvas (mantido; reavaliação pendente). AN-11 resolvido.
- [2026-11-15 — ranking com salto atípico, mínimo e ordem crescente](ciclos/2026-11-15-ranking-atipico.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria (mantido). RV-01 e RV-04 resolvidos.
- [2026-11-16 — versão dos dados no CSV do agrupamento](ciclos/2026-11-16-csv-versao.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria (mantido). Impacto pequeno: base da matéria com o ano no nome.
- [2026-11-16 — porte no ranking e base de análise](ciclos/2026-11-16-base-analise.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria (mantido). Impacto direto: base com versão e dicionário; comparação por porte.
- [2026-11-16 — avisos da base de análise](ciclos/2026-11-16-avisos-base.md#p6--terceiro-setor-e-jornalismo-de-dados): adotaria (mantido). Impacto pequeno: aviso do cruzamento entre anos.

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas: reavaliada em 2026-11-15 (adotaria). RV-01 e RV-04
  entregues (PR #440); sem pendência das análises.

## Entradas

### 2026-11-15 — Análises públicas (reavaliação)

**Veredito:** adotaria com ressalvas (só a comparação de redes) →
**adotaria**. Consolidação em
[`avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`](avaliacoes/2026-11-15-analises-publicas-reavaliacao.md).

- **Resolveu:**
  - "Quais redes mais melhoraram?" tem resposta (`/ranking`, ordem pela
    variação, Brasil ou UF), com ano, universo, CSV e link (AN-11).
  - Toda tela diz a fonte, o ano e a carga (AN-08).
  - O total da rosca está certo (AN-01).
- **Atrapalha:** RV-01, o topo ordenado pela variação é de redes pequenas
  com saltos atípicos sem aviso. É publicável só com cuidado.
- **Detalhe:** RV-04, o ranking de escolas não ordena do menor para o maior
  ("onde estão as escolas sem infraestrutura?").


### 2026-11-14 — Análises públicas (primeira avaliação)

**Material:** busca, comparação de redes, ranking e agrupamento, numa sessão
no navegador com a stack local (Vitória, ES). Consolidação em
[`avaliacoes/2026-11-14-analises-publicas.md`](avaliacoes/2026-11-14-analises-publicas.md).

**O que tentou:** "posso citar este número, e com qual fonte?", "onde estão
as escolas sem infraestrutura básica?", "quais redes mais melhoraram no
IDEB?".

**O que funciona para ela:** a comparação de redes tem link estável e
exporta cada gráfico em CSV, e o ranking diz o ano e o universo.

**Barreiras:**
- AN-08 (bloqueia): a comparação diz "Censo Escolar e IDEB" sem o ano, e não
  há página de fontes.
- AN-01 (atrapalha): o total de matrículas aparece como "77" (são 77.662). Ela
  citaria o número errado.
- AN-11 (atrapalha): não há ranking de redes nem de municípios.
- AN-09 (bloqueia): o agrupamento por infraestrutura não tem link nem lista
  das escolas para a reportagem.
- AN-06 (detalhe): a busca por "Vitória" não acha Vitória (ES).

**Veredito:** **adotaria com ressalvas**, só a comparação de redes, e
conferindo cada número na fonte original.
