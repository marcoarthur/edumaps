# Ciclo 2026-11-14: suíte de testes em paralelo e build sem o PDL

- **Período:** 2026-11-14. Merges e fechamento no mesmo dia.
- **História:** PR #418 (sem issue) e #419 (PR #420).
- **Avaliação:** não houve rodada das personas. Infraestrutura de teste e
  build, sem mudança no que os públicos veem.
- **Engenharia:** nota técnica 199.

## Resumo

Os testes automáticos do backend rodam em cerca de um terço do tempo, e cada
nova versão do backend fica pronta para publicar alguns minutos mais cedo.
Nenhuma tela, dado ou relatório mudou.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido; sem nova avaliação).

**Sem impacto direto neste ciclo.** Indireto: correções chegam mais rápido.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido; sem nova avaliação).

**Sem impacto direto neste ciclo.**

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.**

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.** O agrupamento de escolas continua no
motor estatístico em R; saiu só uma versão antiga em Perl, que o produto não
usava.

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.**

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.**

## O que este ciclo ensinou

- Testes em paralelo expõem o que os testes compartilham: a configuração
  global e as escolas de teste com o mesmo código. A regra ficou escrita e há
  um teste que a vigia.
- Dependência que ninguém usa ainda custa: o PDL pesava em todo build.
