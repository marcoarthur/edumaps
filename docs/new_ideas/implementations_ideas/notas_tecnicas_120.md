# Nota técnica 120 — Ingestão real, P0: allowlist efetivo e estado de carga (PRs #232 e #231)

## Resumo

A #156 (ingestão real das fontes das Fases 0–6) foi replanejada em 2026-10-13:
`docs/specs/2026-10-13-ingestao-real-plano.md`. A medição na base do
**produto** mostrou que a issue estava desatualizada e que faltavam
pré-requisitos antes de qualquer carga. Este ciclo entrega dois itens:

- o **fix urgente do allowlist**: #230, PR #232, merge `f484c39`;
- a fase **P0** do plano: #231, branch `feat/ingestao-p0`.

## Achados que motivaram o desenho

- **Allowlist inerte.** `data_pipeline/allowlist.yaml` tinha as chaves
  `sources:` e `denied:` duplicadas. O YAML::XS fica com a última ocorrência:
  8 fontes sumiam e a lista `denied` ficava vazia. Por isso as 5 regras de
  LGPD não valiam. O teste passava porque usava um YAML sintético, e nenhum
  job de `Ingestion/` consultava o allowlist.
- **A CLI não repassava argumentos ao job.** O SICONFI só carregava SP.
- **`upsert_metadata` só rodava em caso de sucesso.** Não havia como
  registrar "não carregou, porquê".
- **Os ZIPs não eram preservados.** O `pg_restore` de 2026-10-08 apagou cargas
  feitas só no Docker local (BrazilCrime, RENAEST, RENAVAM), e os brutos não
  existiam mais.

## Decisões

1. **Allowlist.**
   - `Allowlist.pm` dá `croak` em chave de topo duplicada, estrutura inválida
     ou arquivo ausente. Falhar alto é melhor do que perder regras em
     silêncio.
   - O cache é por arquivo.
   - No casamento de caminho, o `.` é literal e o `*` é curinga.
   - Uma fonte com `active: false` é rejeitada.
   - Um teste roda sobre o **arquivo real**, não sobre YAML sintético.
2. **Estado separado da proveniência.**
   - `import_metadata` ganhou `ultimo_status` (`em_carga`, `ok`, `falhou`,
     `nao_carregada`), `ultimo_motivo`, `ultima_tentativa_em` e
     `raw_manifest`.
   - Uma falha atualiza só o estado. `row_count`, `loaded_at` e `license`
     continuam sendo os da **última carga boa**.
3. **"Não carregada" é um resultado, não um erro.**
   - A exceção `Ingestion::NaoCarregada` vira o status `nao_carregada` com o
     motivo, e a CLI sai com **exit 3** (≠ 1, falha).
   - Os jobs de e-SIC (INEP, Medidor, FNDE, Secretarias) declaram
     "e-SIC NÃO PROTOCOLADO". O developer confirmou que os pedidos ainda não
     foram feitos.
   - ANTT (host fora do ar), INMET (API retirada) e isócronas ficam fora do
     objetivo por ora.
   - O MapBiomas passa a "aguardando loader" (COG público da Coleção 11,
     #170).
4. **Brutos fora do banco.**
   - Os arquivos vão para `/srv/edumaps/raw/<fonte>/<data>/`, com um
     manifesto (URL, sha256, tamanho, data) no `raw_manifest`.
   - O Rex cria o diretório (0750) no `deploy_minion_dev`.
   - No compose, o minion monta `./raw` (no `.gitignore`).
   - O DVC (#135) pode apontar depois para o mesmo lugar.
5. **Downloads conferidos contra o allowlist** em `Job::Base`, antes da
   requisição.
6. **CLI.**
   - `--arg k=v` vai para o job: `uf`, `exercicio`, `anos`, com `arg_lista`
     para listas.
   - O dry-run passa a ser honesto: o IBGE faz uma única requisição de
     sanidade, e o dry-run do BrazilCrime, que sempre falhava, foi corrigido.
7. **Metadata coerente.**
   - O SICONFI grava a metadata uma única vez, no fim.
   - O FUNDEB ganhou a pseudo-linha `siconfi_receita#fundeb`, em vez de
     sobrescrever a receita.
   - O BrazilCrime não sobrescreve mais a licença.
8. **Migrations novas no fim do plano:** `import_metadata_estado` e
   `import_metadata_fontes_p0`. A segunda corrige os comments que atribuíam
   setores e Censo 2022 ao "e-SIC do INEP" (são IBGE) e as URLs mortas.
   Nenhuma change já deployada foi editada.

## Validação

- **CI DB:** verify em gate ok para as duas changes.
- **Backend:** 104 arquivos / 739 testes, só com as falhas antigas
  conhecidas. Testes novos em `t/05-tasks/ingestao_p0.t` e
  `t/02-models/allowlist_real.t`.
- **Dev (`database.edumaps`):**
  - `import_metadata` com 7 `nao_carregada` e 40 ainda sem tentativa;
  - `/srv/edumaps/raw` criado no backend;
  - `ingestion_runner.pl --job SICONFI --dry-run --arg uf=AC` terminou com
    exit 0.
- **Imagens locais** `sqitch`/`backend`/`minion` reconstruídas, com o
  allowlist e o `raw` montados no minion.

## Pendências (próximas fases da #156)

- **P1:** carregar no produto o que já tem loader (SICONFI em malha nacional,
  BrazilCrime, Transportes com os ZIPs preservados, IBGE), com relatório
  antes/depois.
- **P2:** CGU pelo ZIP mensal (#167 re-escopada), setores + Censo 2022, SISAB.
- **P3:** CNES (sanitizado e agregado, licença CC BY-ND 3.0 registrada) e
  MapBiomas (`sf` no analytic).
- **P4:** justificativas no `import_metadata`, #158 e relatório final.
- **Administrativo:** protocolar os 4 e-SICs (`docs/admin/esic-requests.md`).
