# Nota técnica 124 — Ingestão real das fontes das Fases 0–6: o ciclo completo da #156 (P0–P4)

Esta é a nota de **fechamento do ciclo**: consolida as fases. As notas 120
(P0), 121 (P1), 122 (P2) e 123 (P3) guardam o detalhe de cada uma.

## De onde partimos

A #156 dizia "4/28 com dado — falta só rodar". O replanejamento de
2026-10-13 (`docs/specs/2026-10-13-ingestao-real-plano.md`) mediu outra
coisa:

- os números vinham do **banco errado** (`database.dev`);
- cargas feitas só no Docker local tinham sido **apagadas** por um
  `pg_restore`;
- o allowlist tinha as regras de LGPD **inertes** (chaves YAML duplicadas);
- a CLI não repassava argumentos aos jobs;
- **oito tabelas não tinham loader nenhum**.

"Só falta rodar" era falso.

## Resultado

| | Abertura | Fechamento |
|---|---|---|
| Entradas com dado | 4 / 28 | **19 / 28** |
| Vazias sem explicação | 22 | **0**: as 9 vazias são `nao_carregada` com motivo |

Volume carregado no produto:

| Tabela | Linhas |
|---|---|
| `ibge_agregados` | 2,56 mi |
| `renaest_sinistro` | 2,27 mi |
| `mapbiomas_cobertura` | 690 mil |
| `cnes_estabelecimentos` | 500 mil |
| malha + Censo 2022 por setor | 468 mil |
| `siconfi_receita` + `siconfi_despesa` | 276 mil |
| `transferencia_educ` | 146 mil |
| `brazilcrime_municipio` | 61 mil |
| `dados_ibge` | 56 mil |

Todas as tabelas carregadas têm o **arquivo bruto preservado** com sha256 no
manifesto, exceto o SICONFI, que vem de API por município.

## Fases

| Fase | Issue / PR | Entrega |
|---|---|---|
| Allowlist | #230 / #232 | Duplicata de chave YAML dá croak; teste sobre o arquivo real |
| P0 | #231 / #233 | `--arg` na CLI; estado da tentativa sem apagar a última carga boa; `NaoCarregada` (exit 3); brutos em `/srv/edumaps/raw` |
| P1 | #234 / #235, #236, #237 | SICONFI nacional, BrazilCrime, Transportes, IBGE |
| P2 | #238 / #239 | Loaders novos: CGU, setores + Censo 2022, SISAB/PMMB |
| P3 | #241 / #242 | MapBiomas (estatística oficial Col.10), CNES sanitizado |
| P4 | #156 / (este PR) | Views materializadas (#158), VMDA e Recife justificadas, relatório reexecutado |

## O padrão que se repetiu: a carga real encontra o que o dry-run não vê

Em todas as fases, a carga real revelou defeitos que testes e dry-run
deixavam passar:

- **Fonte com outra forma que a esperada:**
  - o RREO Simplificado deixava 41% dos municípios de fora;
  - o percentual do SIDRA era sobre o valor adicionado (0–100), não sobre
    o PIB;
  - setores multipartes: 472.780 feições para 468.099 setores;
  - a CGU traz o código SIAFI, não o IBGE;
  - a cobertura do PMMB é em pessoas, não em %.
- **PK violada só com volume real:**
  - não resolvidas do RENAEST repetidas por mês;
  - `classificacao` NULL no `ibge_agregados`;
  - setores multipartes no upsert.
- **Ambiente diferente:**
  - o GDAL 3.6.2 do backend ignora `-oo` que o 3.10 aceita;
  - o watchdog de stall não via progresso que só existe no banco.
- **Nomes não mapeados:** PNAE (R$ 3,86 bi) caía num `ACAO_<código>`
  genérico.

Duas práticas pagaram cada um desses achados:

1. **Snapshot + comparação com tolerância antes de manter uma carga.** Foi
   assim que a troca de unidade do IBGE foi pega antes de chegar a qualquer
   consumidor.
2. **Bruto preservado + `--arg <bruto>`.** Recargas que levariam horas de
   API (SIDRA, CGU) saíram do bruto em segundos ou minutos.

## Decisões de desenho que ficam

- **`ultimo_status` separado da proveniência.** Uma falha nunca apaga a
  última carga boa. "Não carregada" é um resultado, com motivo, e não um
  erro.
- **Sanitização por lista branca na entrada, inclusive no bruto (CNES).**
  Licença BY-ND tratada como subconjunto de colunas sem alterar valores.
- **Colunas sem fonte ficam NULL por desenho, com COMMENT.** Nunca zero,
  nunca estimativa.
- **Verifies antigos que exigiam "NÃO CARREGADA" para sempre** foram
  relaxados para aceitar o comment que nomeia o loader. Editar um verify não
  muda o `change_id`: a regra do AGENTS.md vale para `requires` e para a
  ordem do plano.
- **Views analíticas materializadas por fachada (#158).**
  - `analytics.mv_*` (MV com índice único) e o nome antigo como
    `SELECT * FROM mv`.
  - Consumidores e verifies que olham `information_schema` continuam
    válidos.
  - O runner refresca as MVs ao fim de cada carga real com sucesso.
  - Ganho: uma escola caiu de 2,4 s para 0,65 ms; a leitura completa, de
    1,3 s para 48 ms.
- **Paralelismo com base comum (P2/P3).** Arquivos compartilhados
  (`allowlist`, `Rexfile`, `sqitch.plan`) ficam fora dos agentes. A
  integração, a migration e a carga ficam centralizadas.

## P4 em detalhe

- `analytics_views_materializadas`: as MVs são criadas via
  `pg_get_viewdef` da view atual, sem duplicar a lógica. O revert devolve a
  definição a partir da própria MV.
- `import_metadata_fontes_p4`: VMDA e Recife passam a `nao_carregada`, com
  motivo e marcador para o revert.
- `Runner::refrescar_views`: só roda em execução real com pelo menos um
  sucesso. Dry-run não chama, banco sem a função não chama, e a falha é
  logada e notificada sem desfazer as cargas.
- Relatório `new_data_sources.Rmd`:
  - o perfil de nulos deixou o `to_jsonb(t)` (mais de 24 min só na malha de
    setores) e passou a uma passagem com `count(col)`/`count(DISTINCT col)`;
  - o render completo caiu para ~1 min;
  - ganhou uma nota datada de atualização sobre o diagnóstico original.

## Pendências que ficam fora da #156

- **#240:** PDDE sem município (R$ 535 mi a UEx sem código SIAFI).
- **e-SICs não protocolados** (INEP, Medidor, FNDE, Secretarias):
  `docs/admin/esic-requests.md`.
- **Fontes fora do objetivo**, que voltam em issue própria: ANTT,
  isócronas, VMDA, Recife.
- **RENAVAM:** 33 pares de grafia sem casa (~0,5%). Candidato a mapa de
  variantes.
- **Stack local:** o minion Docker não tem GDAL. `SetoresCenso2022` e
  `MapBiomas` só rodam no host deployado.
- **MapBiomas Coleção 11:** entra quando a estatística oficial for
  publicada.
