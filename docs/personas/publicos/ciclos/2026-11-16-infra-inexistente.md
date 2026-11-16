# Ciclo 2026-11-16: itens inexistentes de infraestrutura e coordenadas na base

- **Período:** 2026-11-16.
- **História:** #452 (PR #455), achados VJ-01 e VJ-04 da
  [terceira avaliação da P6](../avaliacoes/2026-11-16-p6-jornalismo.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 212.

## Resumo

- A base de análise diz se a escola **não tem** água, energia ou esgoto,
  além de se o serviço vem da rede pública. O dicionário e a ajuda avisam
  que "fora da rede" não é "sem".
- A base traz a latitude e a longitude da escola, para mapas.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora não usa a base.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
a equipe técnica lista as escolas da rede sem esgoto ou energia, com o mapa,
para o plano de obras.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a variável de
infraestrutura básica deixa de confundir "fora da rede" com "sem", e as
coordenadas permitem análise espacial.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
conselho que fiscaliza a oferta conta as escolas sem esgoto com o número
certo; a dor central (prestação de contas) não muda.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Resolvido:** VJ-01 e VJ-04. A pauta
"escolas sem infraestrutura básica" sai com o número certo (179 sem esgoto
no PI, não 2.725), e o "onde" vira mapa. **Ficam:** #453 (VJ-02, VJ-03) e
#454 (VJ-05).

## O que este ciclo ensinou

- Uma coluna certa com o nome parecido com o da pergunta é uma armadilha. O
  aviso precisa estar ao lado dela, no dicionário, e a coluna que responde a
  pergunta tem de estar no arquivo.
