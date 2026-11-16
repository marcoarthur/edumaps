# Persona P3: mantenedor de rede privada

> Público **P3 — Gestor de rede privada** 🥇 do plano de negócios
> (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** diretor de um grupo educacional privado com 4 a 15 unidades,
  ou mantenedor de uma escola de bairro que pensa em abrir outra unidade.
- **Quem paga:** a mantenedora. SaaS anual de R$ 1.200 a 4.800 por escola,
  decisão privada (sem licitação), ciclo curto.
- **Dor central:** **captação e retenção** num mercado que encolhe (a rede
  privada cresceu +1% de 2023 a 2024 enquanto a pública caiu), mais apoio a
  preço e expansão.
- **Perguntas típicas:**
  - "Quantas crianças em idade escolar há em volta da unidade, e quem as
    atende?"
  - "Quais concorrentes estão perto, e como se comparam?"
  - "Vale abrir uma unidade neste bairro?"
- **O que usa:** análise de mercado local (oferta, demanda, concorrentes),
  benchmark de captação e retenção, clusters, perfil analítico.
- **O que valoriza:** resposta rápida e mensurável, auto-serviço, dado de
  mercado que vira argumento comercial.
- **O que o faz desistir:** ferramenta pensada só para a escola pública;
  dado que ele não consegue transformar em decisão.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-13 — fluxo do INEP](ciclos/2026-11-13-fluxo-inep.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-13 — escolas semelhantes em dia](ciclos/2026-11-13-embedding-diario.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-14 — botão de salvar sem réplica](ciclos/2026-11-14-duplo-envio.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-14 — envio sem duplicidade no servidor](ciclos/2026-11-14-envio-sem-duplicidade.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-14 — suíte em paralelo e backend sem o PDL](ciclos/2026-11-14-build-e-testes.md#p3--rede-privada-mantenedor): sem impacto direto.
- [2026-11-15 — análises públicas legíveis e ausência honesta](ciclos/2026-11-15-analises-legiveis.md#p3--rede-privada-mantenedor): não adotaria (mantido; sem reavaliação). Resolvido AN-03; fica AN-10.
- [2026-11-15 — busca por município, menus em PT-BR e menos jargão](ciclos/2026-11-15-busca-e-linguagem.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-15 — agrupamento que presta contas e se reproduz](ciclos/2026-11-15-agrupamento-reprodutivel.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-15 — fonte, ano e versão dos dados na tela](ciclos/2026-11-15-fontes-e-metodologia.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-15 — ranking de redes municipais e de escolas por município](ciclos/2026-11-15-ranking-de-redes.md#p3--rede-privada-mantenedor): não adotaria (mantido). Impacto pequeno; dor central é a #429.
- [2026-11-15 — ranking com salto atípico, mínimo e ordem crescente](ciclos/2026-11-15-ranking-atipico.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-16 — versão dos dados no CSV do agrupamento](ciclos/2026-11-16-csv-versao.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-16 — porte no ranking e base de análise](ciclos/2026-11-16-base-analise.md#p3--rede-privada-mantenedor): não adotaria (mantido). Impacto pequeno: base da rede privada da UF; #429 continua.
- [2026-11-16 — avisos da base de análise](ciclos/2026-11-16-avisos-base.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-16 — recorte por região no ranking](ciclos/2026-11-16-ranking-regiao.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-16 — região na base e recorte nos CSVs](ciclos/2026-11-16-regiao-base-csv.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).
- [2026-11-16 — município destacado no ranking](ciclos/2026-11-16-destaque-municipio.md#p3--rede-privada-mantenedor): não adotaria (mantido). Sem impacto na dor central (#429).

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas (2026-11-14): reavaliar quando houver leitura de mercado
  local (AN-10). A etapa nas escolas semelhantes (AN-03) foi entregue no
  PR #425.

## Entradas

### 2026-11-14 — Análises públicas (primeira avaliação)

**Material:** busca, painel e perfil da escola, escolas semelhantes,
agrupamento e comparação de redes, numa sessão no navegador com a stack local
(Vitória, ES). Consolidação em
[`avaliacoes/2026-11-14-analises-publicas.md`](avaliacoes/2026-11-14-analises-publicas.md).

**O que tentou:** "quantas crianças há em volta da unidade e quem as
atende?", "quais concorrentes estão perto e como se comparam?".

**O que funciona para ele:** o perfil da escola compara a unidade com o
município, a rede, o Brasil e o grupo, com o Censo e a data da atualização. A
comparação de redes mostra o peso da rede privada no município (101 escolas,
28,6% das matrículas em Vitória).

**Barreiras:**
- AN-10 (bloqueia): não há leitura de mercado local. A população do entorno
  existe, mas só no painel do gestor.
- AN-03 (atrapalha): as "escolas semelhantes" de uma escola de fundamental
  trazem creches, e a distância aparece como "0.00". Ele não usaria isso como
  concorrência.
- AN-05 (atrapalha): o agrupamento tem nomes de variável e um grupo de uma
  escola só chamado "média qualidade".
- AN-07 (detalhe): jargão ("geotag", "K-Means", "motor R").

**Veredito:** **não adotaria.** A ferramenta ainda é pensada para a escola
pública, que é o que o faz desistir; o benchmark do perfil é o que o traria
de volta.
