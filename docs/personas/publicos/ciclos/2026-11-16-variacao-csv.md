# Ciclo 2026-11-16: posição pela variação no CSV e motivo da variação vazia

- **Período:** 2026-11-16.
- **História:** #453 (PR #456), achados VJ-02 e VJ-03 da
  [terceira avaliação da P6](../avaliacoes/2026-11-16-p6-jornalismo.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 213.

## Resumo

- O CSV do ranking de redes traz as duas posições, pelo valor e pela
  variação, com nomes que dizem de qual ordem são.
- A tabela conta as redes sem variação e diz por quê: menos escolas com
  dado que o mínimo na edição anterior.
- O "−0" virou "0".

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não baixa o
ranking de redes.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
quando a rede dele aparece sem variação, a tela diz o motivo (poucas escolas
com IDEB em 2021), e ele não conclui que a rede ficou parada.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** o arquivo tem as duas
posições, e a ausência de variação tem regra dita.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto direto.**

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Resolvido:** VJ-02 e VJ-03.
- "A 1ª que mais melhorou" se cita pelo arquivo sem erro.
- A capital fora da lista de variação tem o motivo na tela.

**Fica:** #454 (VJ-05, registrar a carga do IDEB).

## O que este ciclo ensinou

- Quando a tela muda a ordem, o arquivo tem de dizer de qual ordem é cada
  posição. Uma coluna "posicao" sem dono é pior que nenhuma.
