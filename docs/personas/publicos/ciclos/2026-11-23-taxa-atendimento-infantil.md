# Ciclo 2026-11-23: taxa de atendimento da educação infantil

- **Período:** 2026-11-23.
- **História:** #533 (PR #534), achado QP-01 da
  [avaliação da P2](../avaliacoes/2026-11-23-p2-relatorio-conselho.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 251.

## Resumo

- **Taxa de atendimento:** a comparação de redes mostra a taxa de
  atendimento da creche e da pré-escola (a meta 1 do PNE), em todas as
  redes, na rede municipal e na municipal com as conveniadas (teto).
- **População por idade:** do Censo Demográfico 2022 (IBGE), com fonte e
  ano em `/fontes`, e na base de análise (bloco Porte).

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante:** a taxa é do
município, não da escola.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido), mais perto.
**Resolvido:** QP-01. O secretário leva ao conselho a taxa da meta do PNE,
com a parte da rede municipal e o teto com as conveniadas, e a fonte da
população.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto pequeno:** a taxa de todas
as redes mostra onde a oferta de creche e de pré-escola está abaixo da meta.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a população por
idade na base, com a fonte e o ano no dicionário, e o código R conferido.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto direto:** a meta
1 do PNE fica mensurável por município, com as três contas e os avisos (a
taxa pode passar de 100%, e o Censo Demográfico é de 2022).

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** "quantas crianças
estão na creche" vira um número por município, com a fonte citável.

## O que este ciclo ensinou

- Uma tabela que já existia, mas vazia (`clean.ibge_agregados`), e um job
  que só precisava de outra tabela do SIDRA bastaram. O trabalho maior foi
  conferir as somas antes de gravar e dizer, em cada coluna, de que ano é a
  população.
