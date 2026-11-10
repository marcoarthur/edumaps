# Nota técnica 184: IQD corrigido e avaliado por construto

PR #360 (2026-11-10). Segue a revisão de metodologia da nota 183.

## O que se descobriu

O `t/02-models/indicators/quality.t` cobrava que o IQD (qualificação docente)
previsse o IDEB em São José dos Campos. Medido em 22.698 escolas de DF, SP,
BA, PA e RS, o problema estava na fórmula do próprio indicador:

- o terceiro componente, a razão alunos/docentes (peso 3), não fica em
  `[0,1]` (média 18, máximo 149) e dominava a nota: o IQD valia em média 7,2
  (máximo 56) e tinha ρ = 0,999 com essa razão. Media tamanho de turma, não
  qualificação;
- a fração com pós-graduação somava títulos (especialização, mestrado,
  doutorado); como um docente pode ter mais de um, passava de 1 em 2,4% das
  escolas;
- no IVET, o componente opcional `qualificacao_docente_c` clampava o IQD para
  `[0,1]` e, com valores perto de 7, zerava o componente para quase toda
  escola. Como é opcional e desligado por padrão, o painel não foi afetado.

## O que mudou

- **IQD:** dois componentes, frações do quadro da educação básica: superior
  completo (peso 3) e alguma pós-graduação, contada como graduados menos os
  sem pós (peso 2), com clamp em `[0,1]`. A razão alunos/docentes saiu:
  capacidade de atendimento já está em `score_capacidade_atendimento`
  (sistema B). O IQD só é usado em teste e no componente opcional do IVET.
- **Teste:** `indicators/quality.t` segue o molde do `indicators_quality.t`
  (nota 183). Cobra escala `[0,1]`, variação, teto/zero e cobertura dos campos
  de docentes; a relação com o IDEB sai por etapa, bruta e descontado o INSE,
  como diagnóstico. O ISE entra como referência (é o próprio INSE).
- **Documentação:** `docs/analises/ivet.md` §2.3.2 e comentários do IVET no
  pacote R, que ainda descreviam o defeito antigo.

## Resultado

| | IQD |
|---|---|
| Média (dp) | 0,76 (0,14) |
| Teto / zero | 1% / 0% |
| ρ com o INSE | 0,09 |
| ρ com o IDEB, bruto (médio / fund. I / fund. II) | −0,19 / 0,28 / 0,08 |
| β padronizado descontando INSE, UF e rede | 0,10 / 0,06 / 0,01 |

Diferente dos indicadores de infraestrutura, o IQD quase não depende do nível
socioeconômico. O efeito próprio no IDEB é pequeno e maior no ensino médio,
onde o bruto é negativo por composição de rede.

## Deploy

`deploy_backend_dev` (já na fila do LXC de 2026-11-12). Docker local: imagens
`backend` e `minion` reconstruídas. O pacote R só mudou comentários: sem
rebuild do `analytic`.
