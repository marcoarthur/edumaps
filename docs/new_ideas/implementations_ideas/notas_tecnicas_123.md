# Nota técnica 123 — Ingestão real, P3: MapBiomas (estatística oficial) e CNES sanitizado (#241)

## Resumo

A fase **P3** do plano da #156 carregou as duas últimas tabelas do bloco B2:

| Tabela | Linhas | Recorte |
|---|---|---|
| `clean.mapbiomas_cobertura` | 690.340 | 5.571 municípios, 31 classes, 2015–2024 |
| `clean.cnes_estabelecimentos` | 500.233 | estabelecimentos ativos, sanitizados |

Os dois loaders foram escritos em paralelo, por agentes em worktrees. O CNES
foi integrado e carregado primeiro, para adiantar a carga longa estimada.
O MapBiomas entrou em seguida.

## Levantamento que mudou o desenho

- **MapBiomas.** O plano original era recortar o raster da Coleção 11 (COG
  de 30 m, ~760 MB por ano) pelos 5.570 municípios. O bucket público já tem
  a **estatística oficial por município da Coleção 10**: um xlsx de 78 MB,
  com 1985–2024, unidade ha e 31 classes-folha.
  - Decisão do developer: usar essa planilha, com os números do próprio
    MapBiomas e sem processar raster, carregando 2015–2024.
  - A Coleção 11 entra quando a estatística dela for publicada.
- **CNES.** A API devolve no máximo 20 registros por página (`limit` maior
  é ignorado) e traz PII.
  - Decisão do developer: só estabelecimentos ativos, todas as UFs.
  - Sanitização por lista branca, **também no bruto preservado**.
  - Licença CC BY-ND 3.0 registrada: guardar um subconjunto de colunas sem
    alterar valores não é obra derivada.

## Achados da carga real

1. **GDAL 3.6.2 × 3.10.** O agente validou a leitura do xlsx com o GDAL
   3.10 local. No backend (3.6.2), a open option `-oo HEADERS=FORCE` é
   ignorada: o cabeçalho com anos numéricos vira dado e as colunas saem
   `Field1..Field54`.
   - O **config option** `--config OGR_XLSX_HEADERS FORCE` funciona nas
     duas versões. O teste agora proíbe `-oo` no comando.
   - Lição: validar ferramentas externas na versão do host de destino. A
     stack local não substitui o deploy.
2. **Verify antigo em contradição** (de novo, como na P2).
   `comments_inmet_mapbiomas_pendente` exigia "NÃO CONSTRUÍDA/#170" para
   sempre. Agora aceita o comment que nomeia o loader (#241).
3. **Estimativa do CNES.** Com base numa amostra de ~1,1 s por requisição,
   a projeção era de 7 a 8 h. A carga real levou **70 min**.

## Validação

- **MapBiomas:**
  - área de 2024 = 8.506.835 km² (Brasil: 8,51 mi km²);
  - Formação Florestal 3,57 mi km², Pastagem 1,55 mi km².
- **CNES:**
  - 0 órfãos;
  - 18 registros sem coordenada válida (NULL, contados);
  - o bruto JSONL de 121 MB tem **0** ocorrências de campos de PII.
- **Migration** `comments_ingestao_p3`: deploy, revert, redeploy e verify
  global passam no banco de CI.

## Pendências

- **P4 (fechamento da #156):** justificar no `import_metadata` o que ficou
  fora (ANTT, isócronas, INMET, e-SICs), #158 (materializar as views) e o
  relatório final "28/28 ou justificado".
- **#240:** PDDE sem município.
- **Paridade da stack local:** o minion Docker não tem GDAL.
