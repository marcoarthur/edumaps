# Reavaliação: planos de gestão acompanháveis (2026-11-12)

Depois dos PRs #386 a #389, que entregaram os achados da
[primeira avaliação](2026-11-12-planos-de-gestao.md). Mesmas personas
(P1 e P2) e mesmo material (ficha, ajuda e telas com os dados de
demonstração). Protocolo em [`../README.md`](../README.md).

⚠️ Continua sendo um ensaio com personas simuladas.

## Vereditos

| Persona | Antes | Agora | Por quê |
|---|---|---|---|
| P1 | adotaria com ressalvas | **adotaria** | a edição resolveu a barreira que bloqueava; sobrou acabamento |
| P2 | adotaria com ressalvas, quando a #375 existir | igual | o relatório por escola ficou completo; falta a visão da rede |

## Conferido nas telas

- Ligar o arquivo do plano: o bloco mostra "📄 PPP da escola.pdf (v2)" com
  Trocar e Desligar.
- Corrigir o prazo da ação atrasada pelo ✎: a ação sai de "Atrasadas", e a
  ata e o documento continuam ligados.
- Editar a meta oficial: o formulário diz que o indicador não muda; o
  gráfico mostra 2021 e 2023 e a legenda de base e alvo.
- Relatório: custo por fonte (PDDE R$ 1.500,00), total, "1 ação(ões) sem
  custo informado", colunas de custo e fonte.

Nota do ambiente de demonstração: o link do relatório recarrega a página, o
que zera o estado dos mocks no navegador. Por isso o relatório da
demonstração não mostrou o prazo corrigido nem o arquivo ligado. Não é
defeito do produto (os testes cobrem o arquivo no relatório), mas limita a
demonstração com mocks.

## Achados

### Resolvidos

P1-PG-01 a -05 e P2-PG-02 (PRs #386 a #389).

### Novos

| Id | Gravidade | O quê | Tipo | Encaminhamento proposto |
|---|---|---|---|---|
| P1-PG-06 | detalhe | "alvo 12 %": a unidade "%" sai separada do número | defeito | correção pequena (`fix`) |
| P1-PG-07 | detalhe | Legenda do gráfico e explicações em 10 a 11 px | defeito de leitura | junto da P1-PG-06 |
| P2-PG-05 | atrapalha | A base da meta oficial pode ser alterada pela escola sem marca no relatório | **decisão de produto** | escolher: (a) travar a base da meta oficial no valor da fonte; (b) permitir e marcar "base ajustada pela escola" no relatório e na tela; (c) mostrar as duas bases |
| P2-PG-06 | atrapalha | Só custo previsto, sem executado | **decisão de escopo** | avaliar com a #375: registrar o valor executado na ação (e a data) e mostrar previsto × executado por fonte |

### Continuam no backlog

P2-PG-01, -03 e -04, todos na #375.

## Encaminhamento (2026-11-12, aprovado pelo developer)

- P1-PG-06 e -07: corrigidos no PR #390.
- P2-PG-05: opção **(b)** entregue no PR #391 (marca "ajustada pela escola",
  com o valor oficial, na tela e no relatório).
- P2-PG-06: critério da #375.

## Próximos passos (proposta original)

1. Corrigir P1-PG-06 e -07 (PR pequeno).
2. Decidir a P2-PG-05: recomendação **(b)**. Ela não tira do gestor a
   correção de uma base errada, e a secretaria vê que houve ajuste.
3. Decidir se a P2-PG-06 vira issue agora ou entra na #375.
4. Mostrar o plano a 2 ou 3 diretoras reais.
