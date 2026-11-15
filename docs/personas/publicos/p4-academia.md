# Persona P4: pesquisadora em políticas educacionais

> Público **P4 — Pesquisadores e academia** 🥈 do plano de negócios
> (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** economista da educação, doutora em políticas públicas, num
  programa de pós-graduação ou instituto. Usa microdados do Censo Escolar,
  IDEB e IBGE para estudar desigualdades regionais.
- **Quem paga:** agência de fomento, instituto ou assinatura institucional
  (R$ 20 mil a 80 mil por ano, dados ou API).
- **Dor central:** montar bases de análise **reprodutíveis** sem escrever SQL
  nem federar fontes à mão.
- **Perguntas típicas:**
  - "Municípios de porte e região semelhantes têm oferta parecida?"
  - "Quanto da variação do IDEB se associa à infraestrutura, controlando por
    rede?"
  - "Como o perfil docente muda entre regiões?"
- **O que usa:** clusters, ranking, escolas similares, comparação de redes,
  fontes de dados, busca de análises, histórico de conversas.
- **O que valoriza:** metodologia explícita e citável, versão dos dados
  fixada, dado ausente tratado como ausente (#154), possibilidade de refazer
  a conta.
- **O que a faz desistir:** número sem método, base que muda sem aviso,
  resultado que não se reproduz.
- **Fonte de leitura:** a pesquisadora educacional do repositório `eduBR` (só
  leitura) é a mesma figura do lado do pacote de dados.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — fluxo do INEP](ciclos/2026-11-13-fluxo-inep.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — escolas semelhantes em dia](ciclos/2026-11-13-embedding-diario.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — botão de salvar sem réplica](ciclos/2026-11-14-duplo-envio.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — envio sem duplicidade no servidor](ciclos/2026-11-14-envio-sem-duplicidade.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — suíte em paralelo e backend sem o PDL](ciclos/2026-11-14-build-e-testes.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-15 — análises públicas legíveis e ausência honesta](ciclos/2026-11-15-analises-legiveis.md#p4--academia-pesquisadora): não adotaria por ora (mantido; sem reavaliação). Regra dos sinais versionada; ficam AN-05, AN-08, AN-09.

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas (2026-11-14): reavaliar com AN-08 (fontes e versão na
  tela), AN-09 (agrupamento reprodutível) e AN-05 (universo do agrupamento).

## Entradas

### 2026-11-14 — Análises públicas (primeira avaliação)

**Material:** agrupamento, escolas semelhantes, ranking, perfil da escola e
da rede, comparação de redes, numa sessão no navegador com a stack local
(Vitória, ES). Consolidação em
[`avaliacoes/2026-11-14-analises-publicas.md`](avaliacoes/2026-11-14-analises-publicas.md).

**O que tentou:** agrupar as escolas de Vitória por infraestrutura e
relacionar com o IDEB; ver onde a escola fica contra o município, a rede e
o Brasil.

**O que funciona para ela:** o perfil diz o Censo usado (2025) e quando foi
atualizado; a evolução do IDEB e do SAEB vem desde 2005; o ranking diz o
universo ("de 180").

**Barreiras:**
- AN-09 (bloqueia): o agrupamento não se reproduz. A URL não guarda os
  parâmetros, e não há exportação nem lista das escolas.
- AN-08 (bloqueia): não há página pública de fontes, metodologia e versão dos
  dados.
- AN-05 (atrapalha): 167 escolas no mapa, 180 no resumo e 226 no município,
  sem dizer quem ficou de fora. Para ela, o dado ausente tem que aparecer
  como ausente.
- AN-02 (atrapalha): o sinal de atenção lê ao contrário os indicadores em
  que menor é melhor.
- AN-03 (atrapalha): a distância das escolas semelhantes aparece como
  "0.00", sem método.

**Veredito:** **não adotaria** por ora. Usaria para explorar, não para
publicar: número sem método e resultado que não se reproduz são o que a faz
desistir.
