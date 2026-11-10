# Nota técnica 186: acesso do IVET em escala logarítmica e ES/MG fora do snapshot

PR #362 (2026-11-10), parte da #295. Continua a revisão de construto das notas
183 (IFS/IPS/IGE/IAI) e 184 (IQD), agora nos dois componentes de acesso do
bloco C do IVET.

## O que se descobriu

### ES e MG saíram do painel de acesso

A rodada 2 da #295 gravou SP, RJ e as 9 UFs do Nordeste no snapshot
`2026-10-21`. Para liberar disco no banco, o snapshot `2026-10-20`, o único com
ES e MG, foi apagado, e os dois não foram recarregados no novo. A view
`analytics.mobilidade_escola` lê só `max(dt_snapshot)`, então as 16.796
escolas de ES e MG passaram a ter o acesso `n/d` sem erro nenhum. A memória da
época registrou o snapshot como "superado", o que não era verdade.

Os CSVs extraídos de ES (`piloto_es_s2`, 2.898 escolas) e MG (`piloto_mg`,
13.900) continuam em `~/Code/Data/osm/`: recarregá-los não exige rotear de
novo. A confirmação no banco e a recarga ficam para a volta do LXC
(2026-11-12).

### A escala linear saturava

Medido nas 98.722 escolas dos cinco CSVs (Sudeste + Nordeste):

| | p10 | p50 | p90 | p99 |
|---|---|---|---|---|
| 15 min a pé | 57 | 6.829 | 32.819 | 59.732 |
| 45 min de carro | 23.337 | 389.528 | 10,8 mi | 19,3 mi |

Com `1 − clamp(pop/teto)` e os tetos de 65.000 e 20.000.000, 36% das escolas
ficavam ≥ 0,95 no acesso a pé e 63% no de carro. No de carro, a mediana marcava
0,98, quase o mesmo que uma escola isolada (0,999 no p10). O componente só
diferenciava escolas metropolitanas. Os p99 com ES e MG quase não mudam: o
problema era a escala, não o teto.

| escala | 15 min: média · dp · ≥0,95 | 45 min: média · dp · ≥0,95 |
|---|---|---|
| linear (ivet-v1.2) | 0,82 · 0,21 · 36% | 0,86 · 0,25 · 63% |
| log, piso/teto fixos (ivet-v1.3) | 0,28 · 0,23 · 1,7% | 0,36 · 0,22 · 1,7% |
| percentil nacional | 0,50 · 0,29 · 4,5% | 0,50 · 0,29 · 5% |

A ordem entre escolas não muda (ρ com o INSE igual nas três: −0,39 e −0,50).
O percentil foi descartado porque o valor de cada escola mudaria a cada região
carregada; os tetos do IVET são parâmetros de produto fixos.

## O que mudou

- **Fórmula `ivet-v1.3`**: os dois acessos usam
  `1 − clamp((log10(pop+1) − log10(piso+1)) / (log10(teto+1) − log10(piso+1)))`
  (`ivet_escala_log`). A pé: piso 0, teto 60.000 (≈ p99). De carro: piso 500
  (≈ p1), teto 20.000.000 (≈ p99). Exposição viária (sinistros, frota) segue
  linear.
- **Efeito**: a média dos dois acessos cai de 0,84 para 0,32, então o bloco C
  e o IVET ficam mais baixos em quase todas as escolas cobertas. Os valores da
  `v1.3` não se comparam com os da `v1.2`; a coluna `formula` do painel separa
  as duas. Por UF, o acesso de carro vai de 0,19 (RJ) a 0,60 (MA); antes ia de
  0,70 a 0,99.
- **Pacote R**: `ivet-mobilidade.R` (constantes `IVET_PISO_ACESSO_*`,
  parâmetro `piso` nos componentes e nos blocos), card do IVET (`escala: log`,
  `piso`), testes. Suíte do pacote no host: 341 testes, 0 falhas.
- **`db/isocrona/`**: `cobertura_snapshot.sh` lista escolas por UF em cada
  snapshot e marca **FORA DO PAINEL** a UF ausente do vigente; os três drivers
  o rodam no fim. `recarregar_csv.sh` recarrega um CSV já extraído no snapshot
  vigente (recusa outro snapshot). O README ganhou a regra: snapshot novo leva
  todas as UFs, e o antigo só sai quando o script não acusa nada.
- **Docs**: `ivet.md` §4.5.5, `ivet-coeficientes.md` (bloco C e tabela de
  tetos) e a ajuda do gestor (`docs/ajuda/gestor/ivet.md`).

## Pendente (2026-11-12, com o LXC)

1. `cobertura_snapshot.sh`: confirmar ES e MG fora do vigente; conferir o disco
   do banco (a recarga ocupa ~1 GB).
2. Recarregar ES e MG com `recarregar_csv.sh` no snapshot `2026-10-21`.
3. `deploy_analytics_dev` e reprocessar o painel IVET; conferir ES e MG com
   acesso calculado, a fórmula `ivet-v1.3` e os publicáveis.
4. Fechar a #295 e abrir a issue de Sul, Centro-Oeste e Norte (~47 mil
   escolas), condicionada a ampliar o disco do banco; no Norte, muitas escolas
   ribeirinhas não têm rota de carro.
