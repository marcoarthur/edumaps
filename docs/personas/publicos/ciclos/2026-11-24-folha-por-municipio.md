# Ciclo 2026-11-24: o Fundeb da folha inteira e a folha por município

- **Período:** 2026-11-24 (modo autônomo autorizado pelo developer).
- **História:** #579 (PR #581) e #580 (PR #582), achados QG-01 e QG-02 da
  [quarta avaliação da P6](../avaliacoes/2026-11-24-p6-comparar-prefeituras.md).
- **Avaliação:** a quarta da P6 (adotaria, mantido).
- **Engenharia:** nota técnica 274.

## Resumo

- **O Fundeb da folha inteira:** a frase do fechamento, na tela da base,
  diz a divisão por fonte da folha toda do município, com a Secretaria.
- **A folha por município num arquivo:** um CSV por UF, com uma linha por
  município e ano e 26 colunas, e o dicionário.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante.**

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto
pequeno:** o Fundeb da folha inteira da própria rede, e a rede ao lado das
vizinhas num arquivo.

## P3 — Rede privada (mantenedor)

**Veredito:** adotaria, em piloto, para escolher a cidade (mantido).
**Impacto pequeno:** o salário da rede das cidades candidatas numa tabela.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a folha por
município pronta para juntar a outras bases municipais.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** a
matriz de achados por município sai de um arquivo, com o SHA-256 da carga.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Resolvido:** QG-01 e QG-02. A tabela
das prefeituras sai do arquivo, com a parte do Fundeb das quatro.

## O que este ciclo ensinou

- Quando os números de uma tela passam de um punhado, a tela vira índice
  e o arquivo vira o produto.
