# Nota técnica 240: painel público da escola como a base de análise (#510)

Achados RA-01 a RA-03 da vigésima oitava avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-painel-publico.md`).
Um PR: #511 (merge `4cfcf9d`).

## O problema

- **RA-01 (atrapalha).** O painel apagava o que a escola tem:
  - a resposta mandava as chaves `pre_infantil` e `quadra_esporte`, e a tela
    procurava `pre_escola` e `quadra_esportes`;
  - a acessibilidade não vinha;
  - esgoto e energia acendiam só com a rede pública: a fossa e o gerador
    apareciam como falta.

  Pelo Censo 2025, nas escolas em funcionamento: 98.010 escolas com
  pré-escola, 72.800 com quadra, 111.887 com rampas, 70.538 com outra
  solução de esgoto e 3.857 com outra fonte de energia.
- **RA-02 (atrapalha).** As matrículas somavam
  `qt_mat_bas + qt_mat_inf + qt_mat_eja + qt_mat_med`, mas o total da
  educação básica já contém as outras três.
  - A Amai Pro (29190231) aparecia com 357 matrículas no lugar de 285.
  - 148.190 escolas apareciam infladas, e 36.034 mudavam de porte.
  - As faixas de porte tinham sido "assumidas" no código, e o ano do Censo
    não aparecia.
- **RA-03 (detalhe).** Os cartões não diziam o empate que a página da
  posição passou a dizer (#506), e a ajuda do painel público não explicava
  os blocos.

## Decisões

- **O estado de cada item.** Etapas e infraestrutura vêm como um objeto, e
  não mais como a lista do que acende:
  - os valores são `1` tem, `0` não tem e `null` sem dado; o `null` aparece
    na tela como n/d, sem o ×;
  - as chaves são as de `ETAPAS_ORDER` e `INFRA_ORDER` (`icon-data.js`), e
    `t/06-tools/painel_chaves.t` lê o arquivo do frontend e falha se um lado
    só mudar;
  - as funções `panel_etapas` e `panel_infraestrutura` ficam no role
    `School::Profile`, com as listas `@PANEL_ETAPAS` e `@PANEL_INFRA`.
- **Esgoto e energia pela regra da base e do ranking de escolas:** "tem"
  quando `in_*_inexistente = 0`. O `detalhe` diz `rede_publica` ou
  `outra_solucao`, e a tela escreve isso embaixo do ícone.
- **A acessibilidade é a coluna da base** (`in_acessibilidade_rampas`), e o
  rótulo diz o que ela mede: "Rampas de acessibilidade". As outras partes
  seguem no índice de infraestrutura.
- **Matrículas = `qt_mat_bas`** do Censo mais recente, no cabeçalho e nas
  escolas semelhantes, com o `ano_censo` na resposta e na tela. A consulta
  filtra `nu_ano_censo`; antes pegava uma linha qualquer da escola.
- **Sem o porte da escola.** Não há classificação oficial, e as faixas
  200/700 não tinham fonte (decisão do developer no plano).
- **Cartões** com "empatada com N escolas" (N = `empate − 1`, como a página
  da posição), "acima de X% das outras escolas" e o link para a posição.
- **Cor do ícone.** O `colorClass` era `$derived(() => …)`, que guarda a
  função e não a classe, e a categoria das etapas estava como `stage` em vez
  de `etapa`. O ícone apagado ficava com a mesma cor do aceso; agora é
  `$derived.by`.
- **Ajuda** `painel-publico-da-escola.md` reescrita, com a tabela dos
  blocos, a fonte e o ano, e o significado de ×, n/d e "outra solução". A
  ficha `analise/painel-escola.md` foi atualizada.

## Validação

- **Docker local:**
  - Amai Pro: 285 matrículas (Censo 2025), pré-escola acesa;
  - Colégio João Hipólito Rodrigues (29211999, Abaíra/BA): pré-escola,
    quadra e rampas acesas, esgoto aceso com "outra solução", cartões com o
    empate;
  - validação visual do developer.
- **Correção da avaliação:** a avaliação e a issue diziam "empatada com 666"
  para a sustentabilidade 0 da Amai Pro. Os 666 da API incluem a própria
  escola, e o cartão diz 665.
- **Testes:**
  - Perl: `t/04-api/school_panel.t` (a rota não tinha teste) e
    `t/06-tools/painel_chaves.t`; 202 arquivos e 1.770 testes;
  - vitest: 1.370 testes;
  - CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`, sem change de banco.
- A busca de escolas semelhantes da área do gestor tem um porte próprio
  (fora do escopo).
