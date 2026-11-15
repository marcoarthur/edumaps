# Ciclo 2026-11-15: busca por município com UF, menus em PT-BR e menos jargão

- **Período:** 2026-11-15.
- **História:** #431 (PR #432), achados AN-06 e AN-07 da
  [curadoria das análises públicas](../avaliacoes/2026-11-14-analises-publicas.md).
  Os achados AN-05 a AN-11 viraram as issues #427 a #431.
- **Avaliação:** sem rodada nova das personas; os vereditos ficam os mesmos.
- **Engenharia:** nota técnica 201.

## Resumo

- Escolher "Vitória · ES" na busca traz só as escolas de Vitória (ES). Sem
  escolher, o município de nome igual vem primeiro, e acento não atrapalha.
- Os menus dos gráficos ("Exportar CSV", "Ver como tabela") estão em
  português.
- A página de Análises fala de "grupos", não de "clusters" nem de "geotag".
- O IDEB do perfil diz de que ano e de que etapa é o valor da escola.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Impacto indireto:** acha a própria escola mais rápido pelo município, e o
perfil diz de que etapa é o IDEB que ela vê.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Impacto indireto:** a busca e a comparação de redes acham o município certo
de primeira, e a página de agrupamento fica legível para a equipe técnica da
secretaria.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido; sem reavaliação).

**Sem impacto na dor central** (mercado local, #429). A busca por município
ficou mais direta.

## P4 — Academia (pesquisadora)

**Veredito:** não adotaria por ora (mantido; sem reavaliação).

**Resolvido:** o IDEB do perfil diz a edição e a etapa, e o nome técnico de
cada algoritmo continua na tela. **Fica:** #427 (agrupamento reprodutível) e
#428 (fontes e versão).

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido).

**Sem impacto direto.** Os pedidos dele estão na #428 (fonte e data na tela)
e na #430 (ranking de redes).

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria com ressalvas, só a comparação de redes (mantido; sem
reavaliação).

**Resolvido:** o menu de exportação em português e o município certo em 1º
lugar na comparação de redes. **Fica:** #428 (ano do dado) e #430 (ranking
de redes).

## O que este ciclo ensinou

- Texto que explica precisa de lugar: a frase do algoritmo dentro do campo
  foi cortada, e só a validação na tela mostrou isso.
- Rótulo honesto às vezes é parcial: a etapa do IDEB vale para a escola, não
  para as médias, e o texto diz isso em vez de prometer uma comparação que não
  existe.
