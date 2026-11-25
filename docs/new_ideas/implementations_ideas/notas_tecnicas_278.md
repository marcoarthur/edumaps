# Nota técnica 278: o salário da escola ao lado do da rede (#589)

Achado P1-FL-03 da terceira avaliação da P1
(`docs/personas/publicos/avaliacoes/2026-11-25-p1-salario-escola-rede.md`).
Modo autônomo autorizado pelo developer (até 25/11, 9h). Um PR: #590.

## O problema

- **P1-FL-03 (atrapalha).** O painel da escola mostrava o salário do
  magistério da rede (#571), mas não o da escola. Na base, a escola está
  em média e por 40 horas: não se compara com a mediana por mês da rede. A
  diretora não conseguia dizer se a escola paga acima ou abaixo da rede.

## Decisões

- **A mesma conta:** `salario_escola` repete a de `salario_rede` (mediana
  por pessoa e mês, sem dezembro, total e base, carga mais comum), só com
  as linhas da escola.
- **A diferença no total:** "24% acima da rede no salário total". No
  total, e não no base, porque é o que a pessoa recebe.
- **Só no painel da escola:** no da Secretaria, a escola não existe.
- **A carga ao lado:** a EM Tancredo Neves tem carga mais comum de 40
  horas, contra 31 da rede; parte da diferença é jornada, e a linha mostra.

## Validação

- **Docker local:** EM Tancredo Neves (Ubatuba, 2026): rede R$ 7.186, escola
  R$ 8.946 (carga 40), "24% acima da rede".
- **Testes:** Perl, 211 arquivos; vitest, 1.464. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
