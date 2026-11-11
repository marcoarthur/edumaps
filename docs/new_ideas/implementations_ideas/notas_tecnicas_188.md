# Nota técnica 188: acidentes da ANTT situados por município

PR #365 (2026-11-11), avança a #168. A issue continua aberta até a carga real
da camada de km.

## O problema

O PR #275 (18/10) carregou 958.043 acidentes da ANTT em
`clean.antt_acidente_trecho`, mas nenhum chegava a uma escola. A
`analytics.mobilidade_escola` ligava o acidente ao município por
`antt_trecho_geodados`, uma tabela desenhada para uma geometria de trecho
(LineString) que a ANTT não publica. O acidente traz só o trecho
(`BR-393/RJ`) e o km.

## Decisões do developer (2026-11-11)

1. **Localizar o acidente pelos marcos de km**, em vez de esperar uma
   geometria de trecho.
2. **Fonte da geometria: a camada de pontos de km da própria ANTT.** Tem a
   mesma licença CC-BY dos acidentes. O SNV do DNIT foi descartado (a licença
   tem uma contradição pendente) e o OSM também (não tem marcos de km
   confiáveis).
3. **Remover as três tabelas sem fonte** por change nova:
   - `antt_trecho_geodados`: não há geometria de trecho;
   - `antt_contagem_equipamento`: a fonte de volume não traz código de trecho;
   - `antt_od_municipio`: o MONITRIIP só existe em grão de viagem individual,
     negado por LGPD.

## O que mudou

### Change `antt_acidente_geolocalizacao`

- `clean.antt_marco_km`: um ponto por `(rodovia, uf, km)`, em EPSG 4674.
- O acidente ganha `rodovia` e `uf` (lidas do trecho), além de `geom`,
  `codigo_ibge` e `geo_metodo`. Uma CHECK garante que o ponto e o método andam
  juntos.
- `clean.antt_geolocalizar_acidentes(tolerância = 2 km)`:
  - **marco exato** → o ponto é o do marco;
  - **km entre dois marcos vizinhos** da mesma rodovia e UF, com no máximo
    2 km entre eles → ponto interpolado (`ST_LineInterpolatePoint`);
  - o município é o polígono da `malha_municipio` que contém o ponto; na
    divisa entre dois municípios, vale o de menor código, para o resultado
    ser determinístico;
  - devolve o balanço por situação: `marco`, `interpolado`, `sem_marco`,
    `sem_km`, `trecho_ilegivel` e `fora_da_malha`. Nenhum acidente é
    atribuído a um município por aproximação (#154).

### Change `antt_sem_fonte`

- Remove as três tabelas e as linhas delas no `import_metadata`.
- Recria a `mv_mobilidade_escola` e a fachada:
  - saem `antt_od_saida`, `antt_od_entrada` e `status_conexao_antt` (de 31
    para 28 colunas);
  - os acidentes são contados pelo `codigo_ibge` do próprio acidente;
  - sai o filtro por `dt_carga`: o job substitui o recorte de cada
    concessionária, então a tabela inteira já é o estado atual;
  - "fatal" passa a ser **acidente com morto**, porque a fonte não usa o
    rótulo "fatal";
  - a fonte da view conta **só os acidentes localizados**: sem nenhum,
    `acidentes_12m` fica NULL, e não 0.

### Verifies antigos

O `sqitch verify` roda o verify de todas as changes contra o banco final,
então cinco verifies antigos falharam com a remoção:
- os das três tabelas removidas;
- o de `analytics_ausencia_visivel`, que conferia o contrato de 31 colunas e o
  `status_conexao_antt`;
- o de `import_metadata_uniq_table_name`, cujo piso de 31 linhas caiu para 28.

Os cinco passam a reconhecer a remoção (`to_regclass(...) IS NULL`), e o
contrato novo é conferido em `verify/antt_sem_fonte.sql`. Editar um verify
não muda o `change_id`. Foi a primeira vez que uma change deste repositório
removeu uma tabela que outros verifies conferiam.

### Job ANTT

- Lê a camada de km com `ogr2ogr` e **GeoJSON com `-lco RFC7946=NO`**. Medido:
  no GeoJSONSeq e no modo RFC 7946, o GDAL ignora o `-t_srs EPSG:4674` e
  grava em WGS 84, só com um aviso.
- Os campos são resolvidos por uma lista de nomes alternativos
  (`%CAMPOS_MARCO`). Se faltar rodovia ou km, o job **aborta listando os
  campos que encontrou**: a camada real ainda não foi medida.
- A tabela de marcos é substituída inteira. O COPY é protegido do SIGALRM do
  watchdog, como no COPY dos acidentes.
- O balanço da localização vai para as notas do `import_metadata` do acidente.
- `--arg marcos=<arquivo>` carrega a camada de um arquivo local, e
  `--arg apenas_marcos` troca só os marcos e relocaliza, sem baixar os 44 CSVs
  de novo.
- O dataset CKAN (`MARCOS_PKG`) está **vazio de propósito**: em 2026-11-11 o
  portal estava em timeout, e um id não medido não entra no código.

### Dependências

- `gdal-bin` entrou na imagem do backend/minion. O minion local não tinha
  `ogr2ogr`, então os jobs de MapBiomas e de setores do Censo também não
  rodavam nele.
- No CI, os testes de integração com GDAL deixaram de ser pulados.
- `File::Temp` foi trocado por `Mojo::File::tempdir`; o gate do cpanfile
  apontou o módulo não declarado.

## Testes

- `t/02-models/antt_geolocalizacao.t` (banco, numa transação desfeita no fim):
  14 asserções. Cobrem cada situação do balanço, o ponto a meio caminho entre
  dois marcos, ponto no mar sem município, a view sem multiplicar linhas
  (`REFRESH` dentro da transação) e o zero real nos demais municípios.
- `t/05-tasks/antt_loader.t`: 77 asserções, incluindo um shapefile real gerado
  e lido pelo GDAL.
- Revert até `staging_schema` seguido de novo deploy e verify, no banco do CI.
- Suíte completa do backend contra o banco do CI: 1.301 testes. O CI do PR
  passou.

## Diagramas

Os diagramas 05 e 07 foram atualizados e validados contra o banco do CI. Os
SVG foram regenerados com o **mermaid-cli 12.0.0**, agora fixado no README:
medido, as 11.4.2 e 11.12.0 recusam o ponto em `clean.malha_municipio`.

## Pendente

1. Quando o portal da ANTT voltar:
   - identificar o dataset da camada de km e preencher `MARCOS_PKG` e a
     allowlist;
   - conferir os nomes dos campos;
   - `--arg apenas_marcos` no LXC e medir o balanço;
   - fechar a #168.
2. Levar `acidentes_12m` ao IVET é uma decisão de produto. Cobre só as
   rodovias federais concedidas.
