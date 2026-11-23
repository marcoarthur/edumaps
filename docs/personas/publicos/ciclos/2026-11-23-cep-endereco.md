# Ciclo 2026-11-23: CEP, bairro e endereço na base

- **Período:** 2026-11-23.
- **História:** #531 (PR #532), achado QR-01 da
  [segunda avaliação da P3](../avaliacoes/2026-11-23-p3-concorrentes-locais.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 250.

## Resumo

- **Endereço na base:** a identificação traz `cep` (formato `00000-000`),
  `bairro` e `endereco` de todas as escolas, depois da longitude.
- **Aviso:** o dicionário diz em quantas escolas falta a coordenada (bem
  mais nas privadas) e a ajuda ensina a achar as escolas próximas em R.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante:** a base não é a
tela dela.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
a lista das escolas da rede sai com o endereço, útil para conferir com o
cadastro da secretaria.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido), mais perto. **Resolvido:** QR-01. As
privadas sem coordenada voltam à análise pelo CEP e pelo bairro. Segue
aberto o AN-10 (#429, mercado local).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a cobertura das
coordenadas por rede está no dicionário, e quem faz análise espacial sabe
que perde mais privadas.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto relevante.**

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** dá para chegar à
escola da reportagem pelo endereço, sem depender da coordenada.

## O que este ciclo ensinou

- Uma ausência que cai mais num grupo (coordenada nas privadas) vira viés
  na análise espacial. Entregar o campo que existe para todas (o CEP) e
  dizer onde a falta se concentra vale mais que a coordenada sozinha.
