# Nota técnica 277: o unzip na imagem e os setores do Censo 2022 (#587)

Modo autônomo autorizado pelo developer (2026-11-24, 18:50, até 25/11,
9h; downloads liberados às 18:58). Um PR: #588 (merge `1dba699`). Sem
avaliação de persona: achado de infraestrutura ao preparar a #429.

## O que aconteceu

- **A carga dos setores do Censo 2022** (preparação da #429, leitura de
  mercado local) rodou no ambiente local com o download liberado: seis ZIPs
  e o GPKG da malha (1,49 GB) do IBGE.
- A malha entrou (468.097 setores de 468.099; 30 geometrias reparadas; 2
  fora por município ausente da malha municipal).
- A parte do Censo falhou: "Nenhum CSV dentro de
  …basico_BR_20260520.zip". O ZIP tinha o CSV; faltava o programa `unzip`
  na imagem do backend/minion. `SetoresCenso2022` e `CGU` leem os CSVs com
  `unzip -Z1`/`unzip -p`.

## Decisões

- **#587:** `unzip` no `backend/Dockerfile`, junto do `gdal-bin`, e no
  `deploy_minion_dev` do Rexfile, com o comentário de quem usa.
- **A parte do Censo de novo, sem baixar:** `--arg so=censo --arg
  dir_zips=/srv/edumaps/raw/setorescenso2022/2026-11-24`. Em 573 s:
  468.097 setores; demografia, renda do responsável, cor/raça,
  alfabetização e saneamento em 458.772; 409.864 com alguma célula
  suprimida pelo IBGE (vazia, nunca 0).
- **Os totais conferem:** 202.561.627 moradores (o Censo diz 203.080.756;
  a diferença está nas células suprimidas) e 12.674.640 crianças de 0 a 4
  anos.
- **Cuidado com o minion:** a carga roda dentro do contêiner `minion`;
  recriá-lo no meio da carga a mataria. Durante a carga, os rebuilds
  recriaram só o backend e o frontend.

## Um crash do host

- Depois da carga, o host reiniciou (por volta de 00:57 de 25/11). A
  última consulta minha era uma leitura geográfica de exemplo (crianças num
  raio de 1 e 2 km de uma escola) com `ST_DWithin` sobre `geography` nos
  468 mil setores, sem índice que servisse. Não sei se causou o reboot. A
  próxima leitura usa o índice da geometria (SRID 4674) e um recorte por
  município.
- Na volta: o Postgres refez o WAL ("redo done"), os dados estavam
  íntegros (setores, folha, cargas registradas) e a stack subiu com as
  imagens do main.

## Pendências

- No LXC: `deploy_minion_dev` (o `unzip`) e a carga dos setores.
- A #429 continua dependendo de decisão de produto (público ou pago, raio
  ou isócrona ou setor); os dados agora existem no local.
