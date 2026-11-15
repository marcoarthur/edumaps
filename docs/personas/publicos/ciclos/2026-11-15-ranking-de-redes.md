# Ciclo 2026-11-15: ranking de redes municipais e de escolas por município

- **Período:** 2026-11-15.
- **História:** #430 (PR #436), achado AN-11 da
  [curadoria das análises públicas](../avaliacoes/2026-11-14-analises-publicas.md).
  As decisões de produto foram tomadas na ausência do developer e informadas
  por Telegram.
- **Avaliação:** sem rodada nova das personas; os vereditos ficam os mesmos.
- **Engenharia:** nota técnica 204.

## Resumo

- A página nova **Rankings** compara as redes municipais de um estado (ou do
  Brasil) pelo IDEB/SAEB: o valor da edição mais recente, quanto mudou desde a
  anterior e o contexto socioeconômico (INSE).
- A mesma página lista as escolas de um município por qualquer indicador, com
  CSV e link.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Impacto indireto:** vê as escolas do próprio município em ordem, com o INSE
ao lado.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Impacto direto:** vê a própria rede entre as do estado, a variação e a
comparação com municípios de contexto parecido. É o argumento de "fazemos
mais com o que temos" ou o alerta de que não fazemos.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido).

**Impacto pequeno:** o ranking de escolas filtra a rede privada no município.
A dor central continua sendo o mercado local (#429).

## P4 — Academia (pesquisadora)

**Veredito:** não adotaria por ora (mantido; reavaliação pendente).

**Impacto:** o CSV das redes com o INSE serve de recorte exploratório. A nota
diz que a média é das escolas, e não o IDEB oficial da rede.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido).

**Impacto direto:** "este município entrega parecido com os semelhantes?" tem
resposta, com o contexto ao lado.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria com ressalvas, só a comparação de redes (mantido;
**reavaliação pendente**).

**Resolvido:** o ranking de redes (AN-11), com ano, universo, mínimo de
escolas, CSV e link. Era o pedido que faltava.

## O que este ciclo ensinou

- Ranking sem contexto premia o CEP. O quinto de INSE ao lado muda a
  pergunta de "quem está em cima" para "quem faz mais com o que tem".
- Índice que começa pela coluna errada vira segundos: a primeira versão
  levava 15 s no Brasil inteiro, e um join a reduziu a 0,2 s.
