# Ciclo 2026-11-17: cor/raça sobre os declarados no índice de diversidade

- **Período:** 2026-11-17.
- **História:** #471 (PR #472), achados RT-01 a RT-03 da
  [nona avaliação da P4](../avaliacoes/2026-11-17-p4-regioes-e-diversidade.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 221.

## Resumo

- **A cor/raça é medida só com quem declarou a cor.** O índice de
  diversidade deixa de premiar a escola que não declara a cor dos alunos.
- **Com pouca declaração, a cor/raça fica de fora.** Com menos de metade
  das matrículas com cor declarada, o peso da cor/raça vai para as outras
  três partes.
- **Versões:** `indices-v4` e `ivet-v1.6`.
- **Base de análise:** traz as partes do índice de diversidade e diz por
  que o INSE fica vazio.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a nota de diversidade
da escola deixa de subir só porque a secretaria não preencheu a cor no Censo.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
rede que declara bem a cor dos alunos não perde mais posições no ranking de
diversidade para quem declara mal.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).
As privadas, com 24% de não declaração, eram as mais infladas.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o índice de diversidade.
**Resolvido:** RT-01 a RT-03.
- A correlação entre a parte racial e a cor não declarada cai de 0,78 para
  0,04.
- As partes refazem o índice exatamente.
- O efeito negativo da diversidade no modelo do IDEB vem da composição
  racial real, e a inclusão segue positiva.

**Ficam** da nona avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
conselho que cobra equidade racial não recebe mais um índice que confunde
diversidade com falta de registro.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a matéria "as escolas
mais diversas do estado" deixa de abrir com as escolas que não declaram a
cor dos alunos.

## O que este ciclo ensinou

- **Dado ausente no denominador vira valor.** Foi o terceiro caso em três
  ciclos: o 0 da #467, o `LEAST(1, NULL)` da #469 e a não declarada daqui.
  Toda proporção precisa dizer sobre quem ela é.
- **Rodar o `sqitch verify` global antes do PR,** a lição da #467, pegou
  dois defeitos que o CI só mostraria depois.
