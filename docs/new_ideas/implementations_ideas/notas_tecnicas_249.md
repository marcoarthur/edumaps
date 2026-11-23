# Nota técnica 249: docentes por etapa na base (#529)

Achado QS-01 da trigésima sexta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-22-p4-ideb-docencia.md`). A
avaliação, a issue e o PR foram feitos sozinho, a pedido do developer
(ausente). Um PR: #530 (merge `9f36d0a`).

## O problema

- **QS-01 (atrapalha).** As proporções do bloco Docência são sobre todos
  os docentes da escola. Num modelo do IDEB dos anos iniciais, a escola que
  também tem anos finais ou ensino médio entra com a formação de
  professores dessas etapas.
  - Em SP, isso acontece em 1.725 das 5.779 escolas, com mediana de 55% do
    quadro nos anos iniciais.
  - O efeito estimado dos concursados vai de +0,02 (escolas só de anos
    iniciais) a −0,30.
  - O Censo tem os docentes por etapa (`qt_doc_inf`, `qt_doc_fund_ai`,
    `qt_doc_fund_af`, `qt_doc_med`), mas a base não os entregava.

## Decisões

- **Contagens, não proporções:**
  - `qt_docentes_infantil`, `_ai`, `_af` e `_em` no fim do bloco, sem mudar
    a posição das colunas antigas;
  - vazias sem docentes, e 0 quando a escola não tem a etapa;
  - quem dá aula em duas etapas conta nas duas, então a soma pode passar
    de `qt_docentes`, e o dicionário diz isso. A parte da etapa que a
    pesquisadora calcula é um teto.
- **A formação por etapa não existe no Censo agregado por escola.** Por
  isso a resposta é separar ou ponderar as escolas, e não oferecer uma
  proporção "da etapa".
- **Ajuda:** seção própria "Docência num modelo por etapa", fora de lista
  por causa do python-markdown, com o código R (parte do quadro nos anos
  iniciais, corte de 80%, ou a parte como peso ou controle).

## Validação

- **O bloco R da ajuda** rodou sobre a base de SP gerada pelo backend do
  branch: 5.781 escolas em `ai` e 3.386 em `so_ai`. Nestas, o efeito dos
  concursados é +0,03 (p = 0,51).
- **Docker local, depois do merge:** o CSV de Franca termina o bloco em
  `qt_docentes_infantil … qt_docentes_em`.
- **Testes:** Perl, 1.821 testes (posição, valores com a dupla contagem,
  vazio e o dicionário); CI do PR verde (Perl e build; R e vitest não rodam
  sem mudança nessas áreas).

## Pendências

- No LXC: `deploy_backend_dev` (sem change nova).
