# Avaliação: planos de gestão acompanháveis (2026-11-12)

Épico #368, depois do sprint #369–#374 (PRs #377–#382). Protocolo em
[`../README.md`](../README.md).

- **Avaliaram:** P1 (diretora de escola municipal) e P2 (secretário municipal,
  avaliação parcial: relatório e preparação da visão da rede).
- **Não se aplica:** P3, P4, P5 e P6 (motivos na matriz do README).
- **Material:** ficha da funcionalidade, página de ajuda, spec e as telas com
  os dados de demonstração dos testes (lista, plano, relatório).
- ⚠️ É um ensaio com personas simuladas. Não substitui mostrar a
  funcionalidade a 2 ou 3 gestores reais (spec, §6).

## Vereditos

| Persona | Veredito | Motivo principal |
|---|---|---|
| P1 | adotaria com ressalvas | não consegue corrigir o que cadastrou |
| P2 | adotaria com ressalvas, quando a #375 existir | falta a visão da rede e o custo por fonte de recurso |

## Achados

### Defeitos (corrigir, sem decisão de produto)

| Id | Gravidade | O quê | Onde |
|---|---|---|---|
| P1-PG-04 | detalhe | Faltam espaços: "alvo 6pontos (0 a 10)", "prazo 05/03/2026· Coordenação", "anos iniciais(aumentar, …)" | página do plano e relatório: **corrigido** na branch `fix/planos-espacos` |

### Lacunas do que foi entregue

| Id | Gravidade | O quê | Encaminhamento proposto |
|---|---|---|---|
| P1-PG-01 | **bloqueia** | Editar ação (descrição, responsável, prazo, custo, fonte), meta (descrição, base, alvo, prazo) e objetivo (título) na tela. Hoje só há a situação da ação e o ✕, e excluir perde as evidências. A API já aceita a edição parcial. | **#383**: entregue no PR #387 |
| P2-PG-02 | atrapalha | Custo previsto e fonte de recurso no relatório (por ação e o total por fonte) | **#384**: entregue no PR #388 |
| P1-PG-02 | atrapalha | Ligar o plano ao arquivo dele em Documentos e planos (o campo existe na API) | **#385**: entregue no PR #389 |
| P1-PG-03 | atrapalha | Legenda e anos no gráfico da meta | entregue no PR #387 |
| P1-PG-05 | detalhe | Explicar "sentido" e "linha de base" no próprio formulário | entregue no PR #387 |
| P2-PG-04 | detalhe | Cargo de quem emitiu o relatório | critério registrado na **#375** |

### Já no backlog

| Id | O quê | Onde |
|---|---|---|
| P2-PG-01 | Visão da rede (secretaria) | #375 |
| P2-PG-03 | Metas comparáveis entre escolas: orientar o uso do catálogo de indicadores | critério registrado na **#375** |

## O que as duas personas confirmam

- "Sem medição" em vez de 0%, com "N de M metas medidas", é o que dá
  credibilidade tanto para a diretora quanto para o secretário.
- Fonte e ano em cada indicador oficial sustentam a prestação de contas.
- Evidência que aponta para a ata e para a versão do documento, sem reenvio,
  evita retrabalho e responde a "como sabem que foi feito?".

## Encaminhamento (2026-11-12, aprovado pelo developer)

1. P1-PG-04 corrigido na branch `fix/planos-espacos`.
2. Issues abertas no épico #368: **#383** (edição na tela, com P1-PG-03 e
   P1-PG-05), **#384** (custo e fonte no relatório) e **#385** (plano ligado
   ao arquivo).
3. P2-PG-03 e P2-PG-04 registrados como critérios na #375.
4. Pendente: mostrar o plano a 2 ou 3 diretoras reais e comparar com esta
   avaliação.

**Situação em 2026-11-12, fim do dia:** P1-PG-01 a -05 e P2-PG-02
entregues (PRs #386 a #389). Restam P2-PG-01, -03 e -04, todos na #375.
Próximo passo: reavaliar com a P1 e a P2.
