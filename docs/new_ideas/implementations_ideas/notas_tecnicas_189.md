# Nota técnica 189: camada de km da ANTT medida e carga real

PR seguinte ao #365 (2026-11-11). Fecha a #168.

## Contexto

O #365 deixou o job pronto para a camada de km, mas o portal da ANTT estava
fora do ar e a camada não pôde ser medida. Ele voltou no mesmo dia.

## O que a camada real mostrou

- O dataset é o `quilometro-principal` ("Quilômetro Pista Principal",
  CC-BY), recurso **SHP "Ponto"**: um zip de 8,9 MB com 299.759 pontos em
  WGS 84 e 24 concessionárias. O KMZ do mesmo dataset é de **linha**, e o
  CSV tem 74 bytes, ou seja, está vazio.
- **O SHP fica numa pasta dentro do zip.** O GDAL 3.6 não abre o zip pela
  raiz nesse caso ("not recognized as being in a supported file format").
- **Campos:** `concession` (o DBF trunca o nome em 10 caracteres),
  `ano_do_pnv`, `rodovia` (`BR-381/SP`, **com a UF**), `km_m`, `sentido`,
  `latitude` e `longitude`. **Não há campo de UF.**
- **Repetição na chave (rodovia, UF, km):** 119.647 grupos, em geral um ponto
  por sentido. A distância entre os pontos repetidos é de p50 0 m, p90 27 m e
  p99 238 m. Em 220 grupos ela passa de 1 km, até 10 km (BR-392/RS e
  BR-116/PR).

## O que mudou no job

- `MARCOS_PKG = 'quilometro-principal'`, e a descoberta pega só o recurso
  SHP. O dataset entrou na allowlist.
- `fonte_gdal` acha o `.shp` dentro do zip (`IO::Uncompress::Unzip`, módulo
  core, declarado no cpanfile) e passa `/vsizip/<zip>/<pasta>/<arquivo>.shp`.
- **O GDAL passa a gerar CSV com X/Y, lido linha a linha, em vez de
  GeoJSON.** Com 300 mil pontos, o GeoJSON inteiro na memória custaria
  cerca de 1 GB, e o driver CSV respeita o `-t_srs EPSG:4674`.
- Nomes de campo `km_m` e `concession` acrescentados à lista. A UF sai da
  rodovia.
- **Pontos repetidos:** a até 1 km uns dos outros viram a **média**. Acima
  disso, o km é **descartado** e contado: um marco ambíguo não localiza
  acidente. Antes, ficava o primeiro ponto, o que era arbitrário.

## Carga real (banco local, 2026-11-11)

| etapa | resultado |
|---|---|
| acidentes | 963.199 (44 concessionárias; 1.877 repetidos por sentido descartados) |
| marcos | 164.618 (130.552 pontos fundidos; 214 km ambíguos descartados; 4.161 linhas sem rodovia/km) |
| localizados | **772.252 (80,2%)**: 450.632 pelo marco, 321.620 interpolados |
| `sem_marco` | 177.505: BR-040 RJ/MG/GO/DF sem camada (~113 mil); BR-116/PR com acidentes além do km 211, último marco |
| `trecho_ilegivel` | 11.226: estaduais do PR (`151/PR`, `092/PR`) e `PT`, `Contorno`, `CT-UDI-MG` |
| `fora_da_malha` / `sem_km` | 1.804 / 412 |
| view | 145.734 escolas (uma linha cada); 31.726 em município com acidente em 12 meses |

A relocalização com `--arg apenas_marcos` deu exatamente o mesmo resultado,
ou seja, é determinística.

## Tempo e memória

- **Job completo:** 552 s, pico de **1,67 GB** de RSS.
- **Só marcos e localização** (`--arg apenas_marcos`): 320 s, pico de
  **415 MB**.

O 1,67 GB vem da carga dos acidentes, que existe desde o PR #275: o job lê os
963 mil eventos para a memória antes do COPY. Não é desta mudança, mas é um
risco para o minion do LXC e fica registrado. Ler em fluxo, concessionária
por concessionária, resolveria. A localização é **um único comando SQL** de
cerca de 4 min, bem abaixo do `stall_timeout` de 1.800 s.

## Pendente

- Rodar no LXC depois do deploy de quinta (12/11), com `deploy_db_dev` e
  `deploy_minion_dev`.
- Avaliar a memória da carga de acidentes no minion do LXC.
