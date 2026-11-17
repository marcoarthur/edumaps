# Ciclo 2026-11-17: capacidade gestora sem o zero imposto

- **Período:** 2026-11-17.
- **História:** #475 (PR #476), achados RR-01 e RR-02 da
  [décima primeira avaliação da P4](../avaliacoes/2026-11-17-p4-gestora.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 223.

## Resumo

- No índice de capacidade gestora, a parte que não se aplica fica de fora,
  e o peso dela vai para as outras:
  - "acesso ao cargo" por concurso, eleição ou seleção, nas privadas, onde o
    gestor é escolhido pela mantenedora;
  - "gestores por aluno", na escola sem matrícula.
- Média das privadas: 4,26 → 4,75. Públicas com matrícula: sem mudança.
- **Versões:** `indices-v6` e `ivet-v1.8`.
- **Base:** traz as cinco partes do índice, que o refazem.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a nota da escola
municipal com matrícula não muda. O acesso ao cargo segue contando, e a
indicação política segue aparecendo como 0 nessa parte.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
a comparação da rede municipal com as escolas privadas da cidade deixa de
ter 1 ponto de vantagem por construção.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto direto, fora da dor
central** (#429): a escola privada deixa de perder até 1 ponto na capacidade
gestora por uma categoria que o Censo não tem para ela. A dor central segue.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RR-01 e RR-02. A revisão dos
seis índices termina sem ausência virando valor, e as partes dos quatro
índices compostos estão na base. **Ficam** da décima primeira avaliação:
nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
parecer sobre gestão democrática pode usar a parte do acesso ao cargo só
nas públicas, onde ela mede algo.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a matéria "privadas
têm gestão pior" deixa de sair de uma parte que só existe na rede pública.

## O que este ciclo ensinou

- Uma parte que **não se aplica** a um grupo é outra forma de dado ausente.
  O Censo não tem a categoria, e o 0 media a categoria, não a escola.
- Com a mesma regra (parte vazia, peso redistribuído) em três índices, ela
  virou o padrão do EduMaps para partes que faltam.
