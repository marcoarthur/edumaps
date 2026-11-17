# Ciclo 2026-11-16: versão citável dos índices do EduMaps

- **Período:** 2026-11-16.
- **História:** #462 (PR #464), achado RX-01 da
  [quinta avaliação da P4](../avaliacoes/2026-11-16-p4-indices-e-cobertura.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 217.

## Resumo

- Os seis índices calculados pelo EduMaps ganharam versão citável:
  `indices-v2`, de 16/11/2026. A `indices-v1` é a fórmula original.
- A versão aparece em `/fontes` (com o histórico do que mudou), na tela do
  ranking de escolas e no CSV (coluna `versao_indice`). Toda mudança de
  fórmula sobe a versão.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a nota da escola num
índice vem com a versão, e a queda da diversidade fica explicada pela
mudança de fórmula, não por uma piora da escola.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
equipe técnica sabe se dois CSVs do ranking de escolas são comparáveis antes
de juntar as séries.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RX-01. O índice pode ser
citado com a versão e a data, e o histórico diz o que mudou entre as
versões. **Ficam** da quinta avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
número usado num parecer fica rastreável à versão da fórmula.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a matéria pode citar
"índice de diversidade do EduMaps, versão indices-v2", e uma correção de
fórmula deixa de parecer contradição entre duas matérias.

## O que este ciclo ensinou

- Um índice próprio é uma fonte como as outras: precisa de versão, data e
  histórico no mesmo lugar onde o leitor procura as fontes. A regra só se
  sustenta com um teste que compara os dois lugares onde a versão vive.
