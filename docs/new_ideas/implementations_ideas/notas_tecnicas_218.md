# Nota técnica 218: índices do EduMaps na base de análise (#465)

Achados RY-01 e RY-02 da sexta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-versao-e-selecao.md`).
Um PR: #466 (merge `48056d2`).

## O problema

- **RY-01 (atrapalha):** os seis índices do EduMaps só saíam no ranking de
  escolas, um município por vez: 417 downloads para cobrir a BA. A base de
  análise não os trazia, e não dá para refazê-los com ela, porque a base não
  tem todos os itens da fórmula.
- **RY-02 (detalhe):** o CSV do ranking de escolas trazia a versão na coluna
  `versao_indice`, mas não no nome do arquivo. A base já leva os anos no nome.

## Decisões (developer, 2026-11-16)

- **Colunas `indice_*`,** uma por índice, na escala 0 a 10 da MV, mais a
  coluna `versao_indice` no fim da linha.
- **A infraestrutura básica (0 a 4) fica fora do bloco.** É uma contagem de
  itens que a base já traz no bloco de infraestrutura. A ajuda mostra a soma
  em R.

## O que foi construído

- **Bloco "Índices do EduMaps"** (`indices`, fonte `indices_edumaps`), entre o
  desempenho e o INSE:
  - `LEFT JOIN clean.mv_escolas_scores` pela escola **e pelo ano do Censo da
    base**. Depois de uma carga nova do Censo, sem a MV recalculada, os
    índices saem vazios em vez de pertencerem a outro ano;
  - o dicionário traz o método de cada índice, tirado do `%METODO`, com `;`
    trocado por `,`, porque o leitor do dicionário quebra no `;`. Traz também
    o que significa o vazio e a versão.
- **Versão:** `anos.indices` no catálogo (`indices-v2`), no nome do arquivo
  (`base-analise-BA-censo2025-indices-v2.csv`) e na linha da versão da tela
  ("Censo Escolar 2025 · índices indices-v2."). Só entra quando o bloco foi
  escolhido.
- **RY-02:** `nomeCsvEscolas` no `exportar.js`. O nome fica
  `ranking-escolas-<ibge>-<indicador>-<ano>-indices-v2.csv` quando o
  indicador tem versão. O IDEB e a infraestrutura básica ficam como antes.
- **Ajuda:**
  - `base-de-analise.md`: citar com a versão; os índices não se refazem com a
    base; o vazio depois de um Censo novo; a infraestrutura básica em R;
  - `rankings.md`: a versão no nome e o apontador para a base.

## Armadilha

- **Interpolação em Perl:** `"s.score_$_::float8"` lê a variável de pacote
  `$_::float8`, sai vazia e quebra o SQL sem aviso de compilação. O certo é
  `"s.score_${_}::float8"`. O teste que compara os valores com a MV pegou o
  erro.

## Validação

- Perl: suíte inteira, 194 arquivos, 1718 testes. Vitest: 1335 testes.
- BA com o bloco: 16.106 linhas, nenhum índice vazio, `indices-v2` em todas
  as linhas. A média da diversidade (4,38) é igual à da MV.
- Local, depois do merge: `/api/base-analise/csv?uf=AC&blocos=indices`
  responde 200 com `base-analise-AC-censo2025-indices-v2.csv`, as seis
  colunas `indice_*` e `versao_indice`.

## LXC

- Sem change de banco. `deploy_backend_dev` e `deploy_frontend_dev`. Passos
  no roteiro `docs/admin/deploy-lxc-2026-11-16.md`.
