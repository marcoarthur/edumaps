# Ciclo 2026-11-24: o piso na rede inteira, com a Secretaria

- **Período:** 2026-11-24.
- **História:** #575 (PR #577), achado QH-01 da
  [quinta avaliação da P5](../avaliacoes/2026-11-24-p5-piso-cuiaba.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 272.

## Resumo

- **O piso na rede inteira:** a tela da base e o painel da Secretaria dizem
  quantos profissionais do magistério ficam abaixo do piso no mês típico,
  com a folha da Secretaria, e quantos deles estão só lá. Cuiabá 2026:
  1.559, 1.421 só na Secretaria.
- **Só quem recebeu 3 meses ou mais** conta, na rede e por escola.
- **A tela da base mais rápida:** o catálogo de 31 s para 4 s.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante:** o número fica
fora do painel da escola, de propósito.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto
pequeno:** vê, no painel da Secretaria, o tamanho da rede abaixo do piso,
antes do tribunal.

## P3 — Rede privada (mantenedor)

**Veredito:** adotaria, em piloto, para escolher a cidade (mantido).
**Sem impacto relevante.**

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a contagem por
escola com a mesma regra da rede; a tela da base carrega em segundos.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Resolvido:** QH-01. O
achado do piso tem o tamanho certo, com a folha da Secretaria. Segue
aberto o QH-02 (#576).

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a pauta do piso não
subestima a rede onde a folha é declarada sem escola.

## O que este ciclo ensinou

- A validação na tela pegou um problema que os testes não pegam: 31 s de
  espera. Medir cada parte achou a causa fora da mudança, numa função que
  todo mundo chamava.
