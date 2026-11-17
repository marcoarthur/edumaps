# Ciclo 2026-11-17: agrupamento por desempenho numa etapa

- **Período:** 2026-11-17.
- **História:** #481 (PR #482), achados RO-01 e RO-02 da
  [décima quarta avaliação da P4](../avaliacoes/2026-11-17-p4-agrupamento-desempenho.md).
- **Modo:** autônomo (delegação do developer até 7h de 18/11), com aviso
  pelo Telegram.
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 226.

## Resumo

- O agrupamento por desempenho passa a ser feito **dentro de uma etapa**
  (anos iniciais, anos finais ou ensino médio). Antes, a nota de cada escola
  misturava etapas de escala diferente, e os grupos separavam a etapa
  oferecida, com rótulos de "alto" e "baixo" desempenho trocados.
- O agrupamento por infraestrutura deixa de contar fossa, poço e gerador
  como falta.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a escola rural com
fossa deixa de cair no grupo de "baixa infraestrutura" só por não ter rede
de esgoto.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:**
um agrupamento das escolas da rede por desempenho passa a comparar escolas
da mesma etapa. Antes, as escolas de anos iniciais da rede apareciam todas
como "baixo desempenho", ao lado das de anos finais.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o agrupamento por
desempenho. **Resolvido:** RO-01 e RO-02. Os grupos ficam em ordem de IDEB, e
a etapa vai no rótulo, no link e no CSV. **Ficam** da décima quarta
avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** uma
tipologia de escolas num relatório não confunde etapa com desempenho.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a matéria "as escolas
de alto desempenho do estado" deixa de listar só as de ensino médio.

## O que este ciclo ensinou

- Um rótulo em linguagem natural dá autoridade ao número. "Alto
  desempenho" sobre uma média entre etapas parecia uma conclusão, e era a
  etapa oferecida.
- Foi a execução guardada com CSV (#427) que deixou a pesquisadora cruzar os
  grupos com as etapas. Prestar contas abre a porta para achar o próximo
  defeito.
