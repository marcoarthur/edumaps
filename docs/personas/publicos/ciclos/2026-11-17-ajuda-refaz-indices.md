# Ciclo 2026-11-17: a ajuda refaz os seis índices, com teste

- **Período:** 2026-11-17.
- **História:** #477 (PR #478), achados RQ-01 e RQ-02 da
  [décima segunda avaliação da P4](../avaliacoes/2026-11-17-p4-partes-dos-indices.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 224.

## Resumo

- A conta da ajuda para refazer a capacidade gestora estava errada
  (publicada no ciclo anterior). Agora a ajuda tem um bloco único que refaz
  os seis índices, e um teste executa esse bloco contra uma amostra da base.
- A base traz as partes da infraestrutura (básico, salas e equipamentos,
  acessibilidade e tecnologia) e da sustentabilidade.
- A fórmula e a versão (`indices-v6`) não mudam.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** quem baixa a base vê
em que grupo da infraestrutura a escola perde pontos (básico, salas,
acessibilidade ou tecnologia).

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
a técnica da secretaria separa, na base, a falta de saneamento da falta de
equipamento, que pedem obras diferentes.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RQ-01 e RQ-02. Os seis
índices se refazem pela base, a conta da ajuda é testada, e a pergunta do
perfil tem resposta: o básico se associa ao IDEB, as salas e os equipamentos
não. **Ficam** da décima segunda avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
parecer sobre acessibilidade usa a parte da acessibilidade, não o índice
inteiro.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** quem copia a conta da
ajuda para uma matéria não publica mais um índice errado com o nome do
EduMaps.

## O que este ciclo ensinou

- Uma conta escrita na ajuda é código. Sem um teste que a execute, ela pode
  sair errada mesmo com a base certa e os testes verdes.
- O erro foi do mesmo ciclo que a pesquisadora acabara de aprovar: só
  apareceu porque ela refez as contas, e não só leu.
