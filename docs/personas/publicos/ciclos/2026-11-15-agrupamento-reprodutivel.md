# Ciclo 2026-11-15: agrupamento que presta contas e se reproduz

- **Período:** 2026-11-15.
- **História:** #427 (PRs #433 e #434), achados AN-05 e AN-09 da
  [curadoria das análises públicas](../avaliacoes/2026-11-14-analises-publicas.md).
- **Avaliação:** sem rodada nova das personas; os vereditos ficam os mesmos.
- **Engenharia:** nota técnica 202.

## Resumo

- Cada agrupamento diz o seu universo, por exemplo "226 escolas no recorte,
  180 agrupadas, 46 fora (não funcionam mais)", e quantas não aparecem no mapa
  por falta de coordenada.
- Cada agrupamento tem um link que reabre o mesmo resultado por 90 dias, e um
  CSV com as escolas, o grupo e os valores dos indicadores.
- Grupo pequeno demais não recebe rótulo de qualidade.
- O resumo diz o que mais distingue cada grupo, com nomes legíveis e a média
  geral ao lado.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Sem impacto direto.** O agrupamento não está no fluxo da diretora.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Impacto indireto:** a equipe técnica pode agrupar as escolas da rede,
mandar o link para a reunião e abrir o CSV em planilha. Os números fecham.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido).

**Sem impacto na dor central** (mercado local, #429).

## P4 — Academia (pesquisadora)

**Veredito:** não adotaria por ora (mantido; sem reavaliação).

**Resolvido:** os dois bloqueios do agrupamento.
- AN-09: o resultado se cita (link estável por 90 dias) e se reproduz (CSV
  com os valores, parâmetros guardados, semente fixa).
- AN-05: o universo é explícito, com os motivos de exclusão.

**Fica:** #428 (fontes e versão dos dados). A persona provavelmente pede que
o CSV traga também a versão dos dados.

**Próximo passo:** reavaliar a P4 quando a #428 sair.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido).

**Impacto indireto:** o rastro da análise (parâmetros e universo guardados)
é o tipo de evidência que ela pede. **Fica:** a #428.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria com ressalvas, só a comparação de redes (mantido).

**Resolvido:** o agrupamento deixa de ser intransponível para uma matéria,
com link e CSV. **Fica:** #428 (ano do dado na tela) e #430 (ranking de
redes).

## O que este ciclo ensinou

- Resultado que não se guarda não se cita: o problema de fundo não era a
  tela, era o resultado viver numa tabela compartilhada.
- Contar o que fica de fora é parte do resultado: os três números que não
  fechavam eram três universos diferentes, e nenhum estava errado.
