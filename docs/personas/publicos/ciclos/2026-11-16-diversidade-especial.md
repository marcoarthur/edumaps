# Ciclo 2026-11-16: a diversidade discente usa a educação especial

- **Período:** 2026-11-16.
- **História:** #459 (PR #460). Achado ao escrever o método dos índices
  (#457).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 215.

## Resumo

- O índice de diversidade discente media "inclusão" pelas matrículas dos
  turnos, que são quase todas. Agora mede a proporção de alunos da educação
  especial em classe comum.
- **Efeito:**
  - a nota média caiu de 6,0 para 4,2;
  - o ranking de diversidade mudou em quase todas as escolas;
  - as escolas semelhantes mudaram na maioria dos casos.
- O IVET sobe para `ivet-v1.4`, com a mesma agregação e o insumo corrigido.
- A tela e a ajuda dizem a correção, e que as notas de antes não se
  comparam.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:**
- a nota de diversidade da escola dela cai e passa a refletir a inclusão de
  verdade;
- as escolas semelhantes do painel podem mudar.

A tela avisa que a nota antiga não se compara.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
a inclusão em classe comum vira um sinal que diferencia as escolas da rede.
Antes, todas tinham quase os mesmos pontos.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto direto:**
- o índice que ela usaria deixa de ter um componente constante;
- a versão do IVET sobe, e o resultado citado com `ivet-v1.3` fica
  distinguível do novo.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
conselho que acompanha a inclusão passa a ver o dado de educação especial
no índice.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** o ranking de
diversidade deixa de premiar o turno, e o método dito na tela diz a data da
correção para quem cita.

## O que este ciclo ensinou

- Uma coluna com o rótulo errado no loader sobrevive à correção do
  comentário. Corrigir o dicionário não corrige quem já tinha lido o rótulo
  antigo: é preciso procurar os consumidores.
