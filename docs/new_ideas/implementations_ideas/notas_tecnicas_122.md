# Nota técnica 122 — Ingestão real, P2: CGU, setores + Censo 2022 e SISAB (#238)

## Resumo

A fase **P2** do plano da #156 escreveu e rodou os loaders que **não
existiam** para quatro tabelas vazias desde 2026-09-30. As quatro foram
carregadas no produto:

| Tabela | Linhas |
|---|---|
| `transferencia_educ` (CGU 2025) | 146.325 |
| `malha_setor_censitario` | 468.097 |
| `censo2022_setor` | 468.097 |
| `sisab_aps` | 5.571 |

Os três loaders (jobs `CGU`, `SetoresCenso2022`, `SISAB`) foram escritos em
paralelo por agentes, cada um num worktree próprio. A base comum (allowlist
e GDAL) ficou num commit anterior, e a integração, a migration, o deploy e
as cargas ficaram centralizados.

## Levantamento que mudou o desenho

- **CGU:** o ZIP mensal traz o código **SIAFI** do município, e não o do
  IBGE.
  - Para prefeituras, o casamento é pelo CNPJ do favorecido, usando o mapa
    CNPJ→IBGE do SICONFI `/entes` (5.570 de 5.570).
  - O PDDE vai para as UEx. Para ele, o mapa SIAFI→IBGE é **derivado do
    próprio arquivo**, a partir das linhas de prefeitura: 5.568 códigos,
    sem conflito.
- **Censo 2022 por setor:** os Agregados por Setores publicam
  alfabetização, não nível de instrução, e não publicam rendimento.
  - As colunas `esc_*`, `rend_*` e `cor_sem_decl` ficam **NULL por
    desenho**, com COMMENT (decisão do developer).
- **SISAB:** a API pública é o consolidado **atual** do PMMB (Mais
  Médicos), sem série.
  - `cobertura` é **população coberta (pessoas)**, não percentual; o
    COMMENT antigo dizia "%".
  - A série se forma a cada execução, pelo `dt_snapshot`.
- **Malha:** o GPKG de 1,49 GB exige GDAL. O `gdal-bin` passou a ser
  instalado no backend via Rex (`deploy_minion_dev`).

## Achados da carga real (o dry-run não pegava nenhum)

1. **Setores multipartes.** São 472.780 feições para 468.099 setores (ilhas
   etc.). O upsert tocava a mesma linha duas vezes e abortava.
   - As partes agora são agrupadas por setor (`ST_Dump` + `ST_Collect`).
   - `ST_MakeValid` só entra se o conjunto ficar inválido.
2. **Watchdog de stall.** O `ogr2ogr` escreve só no banco e passou mais de
   600 s sem tocar `data/ingestao`; o Runner abortou o job como travado.
   - Agora o job declara o seu prazo (`has stall_timeout => 3600`).
   - O Runner usa o maior dos dois prazos, só durante aquele job.
3. **Programas sem nome.** `00PI` (PNAE, R$ 3,86 bi em 5.537 municípios),
   `00OW` e `00SU` caíam no fallback `ACAO_<código>`.
   - Os três agora estão mapeados.
   - Uma recarga no mesmo dia **substitui** o snapshot do período, para uma
     chave antiga não somar em dobro.
4. **Verify em contradição.** O verify de `comments_esic_pendente` exigia
   "NÃO CARREGADA" para sempre.
   - Ele passou a aceitar o comment que nomeia o loader (#238).
   - Editar um verify **não** muda o `change_id`: a regra do AGENTS.md
     vale para `requires` e para a ordem do plano.

## Validação

- **Censo:** população somada de 202.561.627 contra 203.080.756 oficiais
  (−0,26%), diferença que corresponde às células suprimidas. São 191.273
  setores com supressão e 5.570 municípios.
- **Malha:** 0 geometrias inválidas. A área é 8.497.333 km² contra
  8.510.418 km² do Brasil (−0,15%). Os 2 setores fora têm `CD_MUN` nulo no
  próprio GPKG.
- **CGU:** FUNDEB R$ 48,13 bi, PNAE 3,86 bi, PDDE 1,57 bi, PNATE 0,85 bi.
- **Migration nova** `comments_ingestao_p2`: deploy, revert e redeploy
  passam no banco de CI, e o verify global também.

## Decisões de design

- **Paralelismo com base comum.** Os arquivos compartilhados
  (`allowlist.yaml`, `Rexfile`, `sqitch.plan`) ficaram fora dos agentes:
  a base veio antes e a migration veio depois. Os três merges foram limpos.
- **Brutos e recarga.** Cada job aceita o bruto (`gpkg=`, `dir_zips=`,
  `json=`). As recargas da P2 reaproveitaram os brutos do dia, sem novo
  download.
- **Credenciais do `ogr2ogr`:** só via `PGPASSWORD` no ambiente. Um teste
  garante que a senha nunca aparece na linha de comando.

## Pendências

- **PDDE sem município:** R$ 534,9 mi (≈ 25% do PDDE de 2025) pagos a UEx
  sem código SIAFI. Estão no `cgu_orfaos.csv` e precisam de outra fonte
  (CNPJ → município) para serem atribuídos.
- **P3:** CNES e MapBiomas. **P4:** fechamento.
