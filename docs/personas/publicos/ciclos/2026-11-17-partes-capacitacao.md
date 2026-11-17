# Ciclo 2026-11-17: partes do índice de capacitação docente na base

- **Período:** 2026-11-17.
- **História:** #469 (PR #470), achados RW-01 e RW-02 da
  [oitava avaliação da P4](../avaliacoes/2026-11-17-p4-indices-v3.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 220.

## Resumo

- A base de análise traz as quatro partes do índice de capacitação docente:
  ensino superior, pós-graduação, concursados e formação continuada. Com
  elas, o índice é refeito no R e cada parte pode ser analisada à parte.
- A ajuda e o dicionário dizem que os pesos dos índices são uma escolha do
  EduMaps, não estimados contra o IDEB.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não usa a base
da UF.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
equipe técnica vê qual parte puxa a capacitação da rede para baixo: falta de
superior, de pós ou de concursados.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RW-01 e RW-02. O índice se
decompõe no próprio arquivo e se refaz exatamente. No modelo do IDEB, o
superior e a pós somam (+0,25 e +0,16) e os efetivos subtraem (−0,33), o
que explica o índice inteiro sem efeito. **Ficam** da oitava avaliação:
nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
parecer sabe que os pesos são normativos antes de usar o índice como meta.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** uma matéria sobre
formação docente pode citar a proporção com superior ou com pós, que é mais
fácil de explicar que o índice.

## O que este ciclo ensinou

- Um índice composto precisa vir com as partes. O número único escondia duas
  associações de sinais opostos, e só a decomposição mostrou isso.
- `LEAST(1, NULL)` é 1 no Postgres. Uma guarda esquecida transformou a
  ausência em 100%, o oposto do erro da #467. O teste com uma escola real
  sem docentes pegou o erro antes do PR.
