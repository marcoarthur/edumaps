# Nota técnica 179: R::Pipe em UTF-8 e lote 3 das falhas antigas

PR #PR_NUM (2026-11-07). Lote 3 (grupo D, "motor R local") da limpeza das
falhas antigas (notas 177 e 178).

## Bug de produto: R::Pipe gravava o script R fora de UTF-8

`EduMaps::Analysis::R::Pipe` escreve o script R num arquivo temporário e chama
`Rscript --vanilla --encoding=UTF-8`. O `spew` gravava a string sem codificar:
um texto com acento ("ação") ia ao disco em Latin-1, e o R falhava ao ler —
ou imprimia `<ERRO: re-codificação falhou…>` antes do JSON, ou nem
interpretava o script (`unexpected end of input`). Agora o script é gravado com
`encode('UTF-8', ...)`. O `rpipe.t` ganhou um caso com acento, que falha sem a
correção. O `R::Pipe` é usado pelo motor legado dos jobs de clustering e
similaridade e pelos testes de qualidade dos indicadores.

## Testes corrigidos

- `analysis/rpipe.t`: lia o script na posição `[2]` do comando; com duas
  opções padrão (`--vanilla --encoding=UTF-8`), ele está na última posição.
- `03-plugins/analytics.t` e `05-tasks/analytics_engine.t`: gravavam o
  arquivo de porta (e o `.conf` temporário) num caminho fixo de outro ambiente
  (`/tmp/user/1000/opencode/`). Agora usam uma pasta temporária própria,
  removida pelo processo pai (o filho do `fork` não pode apagá-la ao sair).
  O `analytics.t` emula o Plumber em Perl e **não precisa de R**: o `skip_r`
  saiu e ele passa a rodar no CI. O `is_deeply` (inexistente no Test2::V1)
  virou `is`.
- `analytics_engine.t`: os jobs de clustering e similaridade corriam com o
  minion local. Os helpers `apply_clustering` e `apply_similarity` passaram a
  usar `minion_fila` (sem config, `default`: nada muda em produção) e o teste
  usa fila própria.
- `05-tasks/city_analyticis.t`: o worker pegava o primeiro job das filas, que
  podia ser um job inválido deixado por outra execução (a fila `speculative` não
  é consumida pelo minion local). Agora executa só o próprio job (`dequeue` por
  id) e remove no fim todos os que criou.
- `AGENTS.md`: no host, `ANALYTICS_URL=http://127.0.0.1:8000` (o padrão do
  `edu_maps.conf` é 8787; o contêiner `analytic` publica 8000).

## Relevância dos indicadores vira diagnóstico (decisão do usuário: opção b)

Com o R funcionando, `indicators/quality.t` e `indicators_quality.t` mostraram
um resultado de pesquisa: com os dados reais (Brasília, 584 escolas), os
indicadores da camada de *features* não explicam o IDEB.

| Indicador | rho (Spearman) | R² / ganho | Critério |
|---|---|---|---|
| ISE | 0,51 | ganho 0,222 | atinge |
| IQD | 0,24 | ganho 0,001 | não atinge (ganho < 0,09) |
| IFS | −0,09 | 0,00 | não atinge |
| IPS | −0,08 | 0,00 | não atinge |
| IGE | −0,08 | 0,01 | não atinge |
| IAI | −0,08 | 0,01 | não atinge |

Os testes passam a exigir só que o R rode e devolva estatísticas válidas (sem
NA); os critérios de relevância aparecem como `note` ("ATINGE"/"NÃO ATINGE").
A correlação fraca e **negativa** de IFS/IPS/IGE/IAI com o IDEB merece uma
revisão metodológica separada (esses índices alimentam a similaridade, não o
IVET).

## Fica aberto

- `city_analyticis.t` continua falhando por uma dependência real da
  funcionalidade: a análise de cidade pelo serviço HTTP lê
  `staging.censo_escolas` (tabela que não existe numa instalação nova) e
  parece ignorar o `schema` recebido — mesmo pedindo `clean`, o serviço
  consulta `staging`. Investigar em ciclo próprio.
- Grupo E (rede/expectativas): `municipio.t`, `osm.t`, `siope.t`,
  `network/schools.t`.

## Validação

- `rpipe.t` (com o caso de acento), `analytics.t`, `analytics_engine.t`,
  `indicators/quality.t` e `indicators_quality.t` passam no Docker local; sem
  pasta temporária sobrando.
- Banco limpo do CI: `analytics.t` passa (os outros são pulados lá).
- Imagens backend/minion reconstruídas; md5 de `R/Pipe.pm`, `Clustering.pm` e
  `Similarity.pm` bate; minion estável.
- Suíte completa local: 10 → 5 falhas; config idêntica.

## Deploy

`deploy_backend_dev` e `deploy_minion_dev` na fila do LXC de 2026-11-09.
