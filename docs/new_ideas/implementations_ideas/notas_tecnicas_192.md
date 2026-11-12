# Nota técnica 192: personas de público e o ajuste fino dos planos

PRs #386 a #389 (2026-11-12). Fecham a #383, a #384 e a #385, abertas a partir
da primeira avaliação das personas de público. Continua as notas 190 (backend
dos planos) e 191 (interface, evidências e relatório).

## Personas de público

- As seis personas dos públicos do plano de negócios (P1 gestor escolar a P6
  terceiro setor) ficam em `docs/personas/publicos/`, com perfil e memória
  por persona, como a do Tech Lead. Elas avaliam **funcionalidades**, não o
  acervo nem o pacote de dados.
- O protocolo (README) tem uma **matriz de aplicabilidade**: cada
  funcionalidade é avaliada só pelas personas a que se aplica, e as outras
  registram o motivo. Nos planos: P1 e P2 (parcial); P3 a P6 não se aplicam.
- **Material da avaliação:** ficha, ajuda, spec e as telas com os dados de
  demonstração. Os mocks do MSW existem mas estão desligados no `main.js`;
  para não mexer no repositório, uma cópia do frontend no scratchpad liga o
  `enableMocking()`, e o Vite dela roda na porta 5199 com a sessão de
  fixture. A stack local (8080) não é tocada.
- Achado só vira issue com a aprovação do developer, e a consolidação separa
  **defeito** (corrigir) de **lacuna** (issue) e do que já está no backlog.
- São simulações: a avaliação prepara a conversa com gestores reais, sem
  substituí-la.

## O que a avaliação encontrou e o que foi feito

| Achado | Gravidade | Entrega |
|---|---|---|
| P1-PG-04: espaços faltando no texto | detalhe | PR #386 |
| P1-PG-01: não dava para corrigir ação, meta ou objetivo | **bloqueia** | PR #387 (#383) |
| P1-PG-03 e -05: gráfico sem legenda; termos sem explicação | atrapalha / detalhe | PR #387 |
| P2-PG-02: relatório sem custo nem fonte de recurso | atrapalha | PR #388 (#384) |
| P1-PG-02: plano sem o arquivo dele | atrapalha | PR #389 (#385) |
| P2-PG-01 e -03: visão da rede, metas comparáveis | — | critérios na #375 |

A barreira que bloqueava (P1-PG-01) não aparecia em nenhum teste: a API
aceitava a edição desde a #369, mas a tela nunca a ofereceu. Os testes eram
de fluxo de criação; a avaliação percorreu o uso de uma diretora que erra um
prazo.

## Decisões de implementação

- **Espaços no Svelte (#386).** O Svelte descarta o espaço do início de um
  bloco `{#if}` (ou de um `<span>`) colado a uma expressão: "alvo 6pontos".
  Os separadores passaram a ser expressões explícitas (`{" · "}`), e os
  testes conferem o texto montado. Esses testes falham com o código antigo.
- **Edição (#387).** Os formulários de meta e de ação viraram snippets, usados
  na criação (no topo) e na edição (no lugar do item). Um estado com `id`
  edita, sem `id` cria. Medições e evidências ficam visíveis durante a
  edição. A meta oficial não troca de indicador na edição (trocar apagaria as
  medições oficiais): para isso, cria-se outra meta.
- **Custos no relatório (#388).** O backend soma por fonte de recurso só as
  ações **não canceladas com custo informado**. Ação com custo e sem fonte
  entra como "fonte não informada"; ação sem custo é contada à parte. Sem
  custo nunca vira R$ 0, a mesma regra da #154 para a ausência de dado.
- **Arquivo do plano (#389).** O campo `documento_id` existia desde a #369. O
  detalhe passou a devolver o nome e a versão atual. A escolha usa a lista que
  Documentos e planos já oferece, sem rota nova. O download pega a versão
  atual, diferente da evidência, que fica presa à versão ligada.

## Processo

- Na #384, o usuário validou enquanto o rebuild das imagens ainda rodava, e
  viu a versão anterior. A conferência do md5 e do bundle, antes de abrir o
  PR, pegou o problema. A regra agora é confirmar o rebuild **antes** de pedir
  a validação.
- O check "build/deploy" que aparece em alguns PRs é do workflow
  `docs-pages` (só roda quando o PR mexe em `docs/`), não um build do
  frontend.

## Pendências

- Reavaliar os planos com a P1 e a P2 depois destas entregas, e mostrar a
  funcionalidade a 2 ou 3 diretoras reais.
- #375 (visão da rede) e #376 (rendimento do INEP) seguem no backlog do
  épico #368.
- O LXC recebe tudo no próximo deploy completo: as quatro changes dos planos,
  o backend com o minion e o frontend.
