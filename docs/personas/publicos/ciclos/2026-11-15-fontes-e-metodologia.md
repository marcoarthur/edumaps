# Ciclo 2026-11-15: fonte, ano e versão dos dados na tela

- **Período:** 2026-11-15.
- **História:** #428 (PR #435), achado AN-08 da
  [curadoria das análises públicas](../avaliacoes/2026-11-14-analises-publicas.md).
- **Avaliação:** sem rodada nova das personas; os vereditos ficam os mesmos.
- **Engenharia:** nota técnica 203.

## Resumo

- Toda análise pública traz, no pé, a base, o ano do dado e a data da carga,
  com link para **Fontes e metodologia**.
- A página nova `/fontes` lista cada base com o link oficial, a metodologia
  do órgão, a data da carga e os arquivos com o SHA-256.
- O agrupamento de escolas diz o ano do Censo e do IDEB que usou.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Impacto indireto:** o perfil da escola diz de que edição é cada número, o
que ajuda a mostrar os dados ao conselho escolar.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Impacto indireto:** a comparação de redes e a folha dizem o ano, o que
facilita levar os números a um relatório oficial.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido).

**Sem impacto na dor central** (mercado local, #429).

## P4 — Academia (pesquisadora)

**Veredito:** não adotaria por ora (mantido; **reavaliação pendente**).

**Resolvido:** o último bloqueio listado (AN-08).
- Há uma página pública de fontes, com versão e hash.
- O ano aparece em cada tela.
- O agrupamento guarda a versão dos dados.

**Próximo passo:** reavaliar a P4 contra o produto atual. Os três bloqueios
dela (AN-05, AN-08 e AN-09) estão resolvidos.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido).

**Resolvido:** a fonte e a data estão na tela, e há rastro da carga.
**Fica:** a cobertura da folha (AN-12) depende de carga de dados.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria com ressalvas, só a comparação de redes (mantido).

**Resolvido:** o ano do dado está na tela, e há uma página citável.
**Fica:** a #430 (ranking de redes).

## O que este ciclo ensinou

- O ano que vale é o da própria base, não um texto escrito à mão: a página
  calcula o ano e não envelhece.
- Dizer "carga não registrada" é melhor do que inventar uma data: a lacuna
  fica visível e se fecha sozinha na próxima carga.
