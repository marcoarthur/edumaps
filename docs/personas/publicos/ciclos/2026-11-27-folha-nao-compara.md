# Ciclo 2026-11-27: a folha que não se compara ao ano anterior

- **Período:** 2026-11-26 a 2026-11-27.
- **História:** #604 (PR #608), achado QD-02 da
  [sétima avaliação da P2](../avaliacoes/2026-11-26-p2-custo-do-piso.md).
- **Avaliação:** a sétima da P2 (adotaria, em piloto; mantido).
- **Engenharia:** nota técnica 285.

## Resumo

- **Um salto que não é da rede:** quando a folha do magistério de um ano
  não se compara à do anterior (o magistério declarado ou a parte paga só
  pela Secretaria mudou muito), o painel, a lista do ano e a base avisam,
  com o que mudou e a contagem do ano anterior. Cuiabá: 6 abaixo do piso em
  2025, 1.559 em 2026, com o magistério de 3.485 para 6.578. A folha por
  município ganha a coluna `comparavel_ano_anterior`.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** o painel da escola
mostra a rede; o aviso evita comparar o salário da rede entre anos.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Resolvido:**
QD-02. Não leva ao prefeito "de 6 para 1.559" como piora da rede. QD-01
(o custo até o piso), QD-03 e QD-04 seguem nas #605 a #607.

## P3 — Rede privada (mantenedor)

**Veredito:** adotaria, em piloto, para escolher a cidade (mantido).
**Impacto pequeno:** a evolução do salário da rede de uma cidade vem com o
aviso quando os anos não se comparam.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto médio:** a coluna
`comparavel_ano_anterior` marca as séries com quebra antes de uma análise
entre anos.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto médio:** o
tribunal vê na tela que o salto pode ser da declaração ao SIOPE, e que vale
pedir ao município a explicação.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto médio:** evita a manchete
"abaixo do piso salta de 6 para 1.559".

## O que este ciclo ensinou

- Um número certo em cada ano pode virar errado entre anos: a forma de
  declarar muda. O critério do aviso usa o volume declarado, não o próprio
  número que se quer comparar.
