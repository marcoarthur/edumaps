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
| P1-PG-04 | detalhe | Faltam espaços: "alvo 6pontos (0 a 10)", "prazo 05/03/2026· Coordenação", "anos iniciais(aumentar, …)" | página do plano (`PlanoDetailPage`), relatório (`PlanoRelatorio`) |

### Lacunas do que foi entregue

| Id | Gravidade | O quê | Encaminhamento proposto |
|---|---|---|---|
| P1-PG-01 | **bloqueia** | Editar ação (descrição, responsável, prazo, custo, fonte), meta (descrição, base, alvo, prazo) e objetivo (título) na tela. Hoje só há a situação da ação e o ✕, e excluir perde as evidências. A API já aceita a edição parcial. | issue nova, só frontend, prioridade alta |
| P2-PG-02 | atrapalha | Custo previsto e fonte de recurso no relatório (por ação e o total por fonte) | issue nova, pequena (backend já tem os campos) |
| P1-PG-02 | atrapalha | Ligar o plano ao arquivo dele em Documentos e planos (o campo existe na API) | issue nova, pequena |
| P1-PG-03 | atrapalha | Legenda e anos no gráfico da meta | junto da P1-PG-01 ou issue pequena |
| P1-PG-05 | detalhe | Explicar "sentido" e "linha de base" no próprio formulário | junto da P1-PG-01 |
| P2-PG-04 | detalhe | Cargo de quem emitiu o relatório | avaliar com a #375 (decisão de privacidade) |

### Já no backlog

| Id | O quê | Onde |
|---|---|---|
| P2-PG-01 | Visão da rede (secretaria) | #375 |
| P2-PG-03 | Metas comparáveis entre escolas: orientar o uso do catálogo de indicadores | entra na #375 |

## O que as duas personas confirmam

- "Sem medição" em vez de 0%, com "N de M metas medidas", é o que dá
  credibilidade tanto para a diretora quanto para o secretário.
- Fonte e ano em cada indicador oficial sustentam a prestação de contas.
- Evidência que aponta para a ata e para a versão do documento, sem reenvio,
  evita retrabalho e responde a "como sabem que foi feito?".

## Próximos passos (dependem do developer)

1. Corrigir o defeito P1-PG-04 (PR pequeno de `fix`).
2. Abrir as issues de P1-PG-01 (com P1-PG-03 e P1-PG-05), P2-PG-02 e
   P1-PG-02 no épico #368.
3. Registrar P2-PG-03 e P2-PG-04 como critérios da #375.
4. Mostrar o plano a 2 ou 3 diretoras reais e comparar com esta avaliação.
