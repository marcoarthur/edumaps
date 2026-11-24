# Ciclo 2026-11-24: a carga que não parece em horas

- **Período:** 2026-11-24.
- **História:** #572 (PR #574), achado QI-02 da
  [quarta avaliação da P3](../avaliacoes/2026-11-24-p3-salario-rede-municipal.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 271.

## Resumo

- **Sem salário inflado:** onde a carga declarada não parece estar em
  horas semanais (a maioria abaixo de 20), as contas por 40 horas ficam
  vazias e a tela avisa; o salário sem conversão e a carga ficam.
- **Taubaté:** carga 18 em 94% dos pagamentos, com o aviso no painel.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante.**

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto
pequeno:** vê como a carga declarada pela rede é lida.

## P3 — Rede privada (mantenedor)

**Veredito:** adotaria, em piloto, para escolher a cidade (mantido).
**Resolvido:** QI-02. A conta por 40 horas de Taubaté não sai inflada.
Com o QI-01 (#571), os dois achados da rodada estão entregues.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** as colunas por 40
horas não misturam municípios com carga em horas e em aulas.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** a
contagem do piso não sai baixa demais onde a carga está em aulas.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a pauta do piso não
compara números feitos com cargas diferentes.

## O que este ciclo ensinou

- A unidade de um campo pode mudar de município para município. Uma
  conversão que supõe a unidade precisa checar antes de converter.
