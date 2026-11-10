# Nota técnica 178: schema staging e testes que dependem do R do host

PR #353 (2026-11-07). Lote 2 da limpeza das falhas antigas (nota 177).

## O que se descobriu

- O schema `staging` não é só dos testes: o cálculo de similaridade
  (`EduMaps::Roles::DB::ProcessedJob`), os jobs de clustering/similaridade, o
  `Task::CityAnalytics` e três repositórios do motor R gravam nele tabelas de
  trabalho. **Nenhuma migração o criava**; uma instalação nova (Docker local,
  CI) ficava sem ele.
- Com o schema criado à mão, os cinco testes do grupo C avançavam e caíam no
  passo seguinte: o job executa o R **no host** (`R::Pipe`/`Rscript`) e o R do
  host **nunca teve o pacote `edumapsr`** (nenhuma das bibliotecas 4.3–4.6 do
  usuário). Ou seja, o grupo C e parte do D têm a mesma raiz.

## O que mudou

1. Change `staging_schema`: `CREATE SCHEMA IF NOT EXISTS staging` com
   comentário. Onde o schema já existe, nada muda. O revert só apaga o schema
   se estiver vazio (testado: com uma tabela dentro, mantém e avisa). O papel
   `edumaps_leitor` não recebe acesso.
2. `CI->skip_r_host('motivo')` em `t/lib/CI.pm`: no CI, mesma razão do
   `skip_r`; fora dele, pula quando o `Rscript` do host não carrega o
   `edumapsr` ("exige o pacote edumapsr instalado no R do host"). Usado só nos
   cinco testes que executam o R no host (`clustering*.t`, `similarity.t`,
   `dbic/inject*.t`). O `skip_r` não mudou: ele também marca testes que passam
   sem o R do host (ex.: `City.t`), e checar o pacote ali os esconderia.
3. `AGENTS.md` (Running tests, backend): como instalar o pacote no host para
   rodar esses testes de verdade.

## Duas falhas que apareceram no caminho

- `school/cluster.t` sorteia um município entre os "com nota", mas o critério
  do helper `city_id_with_grades` não batia com a consulta de clustering: ela
  também exige `vl_nota_media_2023`, normaliza por `(max - min)` (uma escola só
  ou valores iguais dão vazio) e faz `JOIN clean.escolas` no resultado. O
  helper passou a usar os mesmos filtros; conferido em **todos** os 3.867
  candidatos do banco local (antes, 91 de 4.146 davam vazio).
- `admin/telemetry.t`: o ranking de rotas (limite 10) pode deixar uma rota
  semeada de fora **antes** de semear (contava 0 e depois somava os acessos
  reais). A checagem agora vale para as duas leituras.

## Validação

- Change: deploy/verify no Docker local; no banco limpo do CI, deploy, verify,
  revert vazio (apaga), revert com tabela (mantém), redeploy e
  `ci_db.sh verify`.
- Os cinco testes do grupo C são pulados com o motivo no local e no CI.
- Banco limpo do CI: `cluster.t` e `telemetry.t` passam.
- Suíte completa local: 15 → 10 falhas (restam o grupo D, R local, e o E,
  rede/expectativas); config idêntica.

## Deploy

`deploy_db_dev` (change `staging_schema`) na fila do LXC de 2026-11-09.

## Correção (2026-11-10, nota 183)

O diagnóstico do R do host acima estava errado. O `edu_maps.conf` do host usa
o motor `http`: esses cinco testes chamam o serviço R do Docker, não o
`Rscript` do host. O pacote que o `skip_r_host` procurava (`edumapsr`) nem
existe com esse nome — o pacote do projeto se chama `edumapsAnalytics`. Com o
skip removido, os testes falhavam porque esperavam o contrato do motor legado
`pipe`. A nota 183 troca o skip por `skip_analytics` e reescreve os contratos.
