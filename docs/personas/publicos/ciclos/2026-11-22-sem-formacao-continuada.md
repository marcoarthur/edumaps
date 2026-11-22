# Ciclo 2026-11-22: "sem especialização" é sem formação continuada

- **Período:** 2026-11-22.
- **História:** #522 (PR #523), achados QU-01 e QU-02 da
  [trigésima quarta avaliação da P4](../avaliacoes/2026-11-22-p4-perfil-docente-regioes.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 246.

## Resumo

- **Rótulo certo:** a linha "Docentes sem especialização" mede quem não fez
  formação continuada de 80 horas ou mais. Ela passou a se chamar "Docentes
  sem formação continuada" no perfil da escola e da rede, nos sinais de
  atenção, no agrupamento, nos comentários do banco, no Assistente e nas
  ajudas.
- **Nome novo na base:** a coluna é `prop_sem_formacao_continuada` (era
  `prop_sem_especializacao`), e o dicionário separa a contagem de cursos da
  de professores.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** o sinal de atenção do
perfil da escola falava em "sem especialização" e levava a pensar em
pós-graduação. Agora diz que é a formação continuada, que é a que a rede
oferece e a que ela pode pedir.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:** o
perfil da rede comparado com o Brasil passa a dizer formação continuada, a
política que a secretaria controla.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto pequeno:** o mesmo rótulo
no perfil das escolas privadas.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), sem a ressalva no perfil docente.
**Resolvido:** QU-01 e QU-02. Nenhum achado aberto da trigésima quarta
avaliação.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
indicador docente que dizia uma coisa e media outra deixa de ir para o
relatório.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** some a manchete "91%
dos professores sem especialização", que o dado não sustentava.

## O que este ciclo ensinou

- Um rótulo errado na origem (o comentário da coluna no banco) se copia para
  toda a plataforma. Conferir a variável no dicionário do INEP antes de dar
  nome a ela.
