# Nota técnica 217: versão citável dos índices do EduMaps (#462)

Achado RX-01 da quinta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-indices-e-cobertura.md`).
Um PR: #464 (merge `96e34e0`).

## O problema

- **Os seis índices do Censo** (infraestrutura, capacidade de atendimento,
  capacitação docente, diversidade discente, capacidade gestora e
  sustentabilidade) são calculados pelo EduMaps, mas não tinham versão.
- **A correção da diversidade (#459)** baixou a nota média de 6,0 para 4,2.
  Um CSV do ranking de escolas de antes e outro de depois não se distinguiam
  pelo arquivo.
- **`/fontes` só listava terceiros** (INEP, FNDE, IBGE). A única versão
  existente era a do IVET, e o comentário da MV citava a versão do IVET
  como se fosse a dos índices.

## Decisões (developer, 2026-11-16)

- **Formato `indices-vN`,** N inteiro que só sobe, com a data ao lado.
  Separado do IVET: o IVET muda por blocos territoriais que não mexem nos
  seis índices.
  - `indices-v1` (2026-06-04, commit `2b0b6d0`): a fórmula original;
  - `indices-v2` (2026-11-16): a inclusão da diversidade pela educação
    especial em classe comum (#459).
- **A versão vai também no COMMENT da MV,** por uma change nova só de
  comentário (`escolas_scores_versao`). Quem mudar a fórmula copia a última
  change, que traz o COMMENT, e encontra o lembrete onde trabalha.

## O que foi construído

- **Registro:** `$INDICES_VERSAO` e `@INDICES_HISTORICO` (versão, data, o que
  mudou) em `EduMaps::Model::Rank::School`, ao lado do `%METODO`.
- **API do ranking de escolas:** `indicador.versao` e `indicador.versao_data`
  só nos índices da fonte `mv`. IDEB (do INEP) e infraestrutura básica
  (contagem de itens, sem fórmula) ficam sem.
- **CSV:** coluna `versao_indice` em toda linha, só quando a resposta traz a
  versão. A tela mostra "Como se calcula (indices-v2, de 16/11/2026)".
- **`/fontes`:** entrada `indices_edumaps`, marcada `proprio`:
  - o período é o ano do Censo da MV; a "carga" é a última materialização
    (`max(data_atualizacao)`, por um `carga_sql` novo no catálogo);
  - versão, data e histórico vêm do registro (`EduMaps::Fontes->indices_versao`,
    com `require` em tempo de execução, porque o Model já usa o `Fontes`);
  - a página troca "Licença" e "Página oficial" por "Último cálculo", "O que
    cada índice mede" (ajuda dos rankings) e "Fórmula completa" (`ivet.md`
    §2.2), e abre o histórico num `<details>`.
  - Efeito colateral aceito: o selo "Fonte" das telas de ranking, perfil da
    escola e agrupamento lista também "Índices do EduMaps 2025".

## A regra e o gate

- **AGENTS.md (Database):** change que mude a fórmula de
  `clean.mv_escolas_scores` sobe a versão no registro e no COMMENT, no mesmo
  PR. Correção só de texto do `%METODO` não sobe.
- **`t/02-models/indices_versao.t`:** formato, histórico do mais novo ao mais
  antigo sem buraco, e a versão do COMMENT igual à do registro.
- **Verify da change:** `RAISE` se o COMMENT não tiver `VERSÃO indices-vN`.
- **O que o gate não pega:** uma mudança de fórmula que não suba nenhum dos
  dois. Comparar um hash do `pg_get_viewdef` foi descartado por ser frágil
  entre versões do Postgres; a regra fica na revisão.

## Validação

- Perl: suíte inteira, 194 arquivos, 1717 testes. Vitest: 153 arquivos, 1333.
- Sqitch no banco de fixtures: deploy, revert `--to escolas_scores_diversidade_esp`,
  deploy `--verify`. Aplicada no banco local.
- Local: `/api/fontes` e `/api/ranking/escolas?codigo_ibge=2204402&indicador=diversidade_discente`
  devolvem `indices-v2`; validação visual do developer.

## LXC

- `deploy_db_dev` (change `escolas_scores_versao`, só COMMENT, sem
  recálculo), `deploy_backend_dev`, `deploy_frontend_dev`. Passos no roteiro
  `docs/admin/deploy-lxc-2026-11-16.md`.
