# Nota técnica 200: análises públicas legíveis, ausência honesta e worker `analytics` local (#421, #422, #423)

Ciclo aberto pela curadoria P3–P6 das análises públicas
(`docs/personas/publicos/avaliacoes/2026-11-14-analises-publicas.md`). Três PRs:

| PR | Issue | Merge |
|---|---|---|
| #424 | #423 worker `analytics` no Docker local | `dba9fa8` |
| #425 | #421 leitura numérica (roscas, sinais, semelhantes) | `f696e01` |
| #426 | #422 ausência e cobertura no financeiro e na folha | `758a8b2` |

## #423: a stack local sem worker da fila `analytics`

O agrupamento, o Assistente do Censo e os relatórios vão para a fila
`analytics`, servida no LXC por `edumaps-minion-analytics`. No compose só
havia o `minion` (fila `default`), e os jobs ficavam `inactive` para sempre.

- `docker-compose.yml`: o `minion` virou âncora (`&minion`), e o serviço
  `minion-analytics` herda dela, trocando só o nome e o comando
  (`minion -q analytics`).
- `docker-entrypoint.sh`: `minion` repassa os argumentos ao
  `minion worker`.
- **Achado no caminho:** o novo contêiner mudou o IP do `backend`, e o nginx
  do frontend respondia 502. O nginx resolve o nome do `upstream` só na
  subida. A correção usa `resolver 127.0.0.11 valid=10s` com
  `proxy_pass $backend_api` (variável e sem URI, para preservar o caminho).
  Teste: IP antigo ocupado, backend recriado em outro IP, resposta 200.

Fora do escopo: a fila `speculative` (resumo da cidade) não tem worker em
nenhum ambiente.

## #421: números e sinais lidos ao contrário

1. **Total das roscas.** O Carbon espera `donut.center.number` numérico. As
   telas passavam o texto já formatado: `"77.662"` virava 77 e
   `"R$ 8,9 mi"` virava `NaN`. O helper `centroRosca(label, valor,
   formatar)` devolve o número cru (0 se não for finito) e um
   `numberFormatter`. Quatro telas o usam, e um teste varre os `.svelte` à
   procura de `center: { … number: format…` para pegar a repetição.
2. **Sinais de atenção v2** (edumapsr). A v1 marcava todo indicador no
   quartil inferior, sem olhar o sentido. Pegava "sem especialização 4%" como
   ruim e disparava com escola e grupo em 0%. Agora:
   - `PROFILE_DIRECAO` declara o sentido por indicador:
     `prop_sem_especializacao` e `ratio_aluno_docente` são "menor é melhor";
   - atenção = quartil do lado ruim **e** estritamente pior que a mediana
     (empate com p50 não acende);
   - a coluna `direcao` vai no payload, e `regra_sinais = 2` vai no metadata.
   - **Dois caches** guardavam perfis da v1: o do R
     (`read_school_profile_cache`) e o `analytics.analysis_cache` do backend.
     A regra entra nos dois: o R descarta o payload com outra `regra_sinais`,
     e o backend põe `$PERFIL_REGRA_SINAIS` na chave. Um teste Perl confere
     que o número bate com o do arquivo R.
   - No frontend, `sentidoIndicador.js` pinta a variação do perfil da rede
     pelo sentido (queda de alunos por docente fica verde) e mostra a
     variação de proporções em p.p.
3. **Escolas semelhantes.** O embedding tem só 6 escores, e escolas de etapas
   diferentes ficam próximas: creche aparecia para escola de fundamental. O
   `similar_to` agora exige ao menos uma etapa em comum entre as 10
   colunas `in_*` do censo, com um `CROSS JOIN` na escola consultada. A escola
   sem nenhuma etapa marcada fica sem o filtro. A tela não mostra mais
   "Distância: 0.00" (valores de 0,0006 a 0,002 não diziam nada) e explica o
   critério.

## #422: ausência dita, e um vazamento corrigido

O `/api/school/:inep/finance` ganhou dois campos:

- **`ausencia`**, com o motivo da falta de dado: `escola_inexistente`,
  `nao_municipal`, `escola_sem_folha` (o município tem folha, a escola não) e
  `municipio_sem_carga`;
- **`cobertura`**, os municípios com folha carregada, os anos e o número de
  escolas (sem contar o agregado `99999999`).

O componente `FinanceAusencia` mostra os dois. A página da folha trata o 404
como ausência e leva ao financeiro, em vez de "Erro ao carregar".

**Vazamento.** O fallback "Folha da Secretaria" filtrava só pelo município
da escola e somava todas as linhas, para qualquer rede. Uma escola estadual de
Cuiabá (51036614) mostrava a folha municipal inteira, 13.547 profissionais.
Agora o fallback só vale com o SIOPE habilitado para a escola (rede
municipal) e só soma o agregado `cod_inep = 99999999`. O
`t/04-api/school/finance_ausencia.t` falha contra o código antigo. Usa os
municípios falsos 6000172 e 6000181 e INEPs 60001701–05.

Cobertura atual da folha: Cuiabá (168 escolas), Taubaté (só o agregado) e
Alta Floresta D'Oeste (18 escolas).

## Validação

- R: 2213 expectativas; Perl `-j4`: 186 arquivos; vitest: suíte completa. Os
  três passaram em cada branch e no CI.
- Navegador na stack local, com as imagens reconstruídas: as roscas, o perfil
  da escola e da rede, as semelhantes, o financeiro e a folha da escola
  estadual e da escola sem folha.
- Depois do merge, as imagens `backend minion minion-analytics frontend
  analytic` foram reconstruídas do `main`. O `up -d` não recriou o
  `analytic` mesmo com imagem nova (`--force-recreate`). A API pelo nginx
  devolve `ausencia: nao_municipal` para a 51036614.

## Deploy

Entra no LXC na segunda, 16/11 (roteiro `docs/admin/deploy-lxc-2026-11-16.md`,
passos 3 a 5 atualizados). O LXC já tem o `edumaps-minion-analytics`.
