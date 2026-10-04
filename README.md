# EduMaps

**Plataforma de análise educacional geoespacial para municípios brasileiros.**

[![backend-tests](https://github.com/marcoarthur/edumaps/actions/workflows/backend-tests.yml/badge.svg?branch=main)](https://github.com/marcoarthur/edumaps/actions/workflows/backend-tests.yml)
[![frontend-tests](https://github.com/marcoarthur/edumaps/actions/workflows/frontend-tests.yml/badge.svg?branch=main)](https://github.com/marcoarthur/edumaps/actions/workflows/frontend-tests.yml)

Integra dados oficiais de educação, geografia e segurança para responder a
perguntas que hoje só se respondem à folha de cálculo: **onde estão as escolas,
o que as rodeia, e como isso muda de município para município**. Cruza o Censo
Escolar (INEP), IDEB/SAEB, SIOPE, IBGE e OpenStreetMap, e está a ingerir dados
de segurança pública, mobilidade e frota de veículos.

## Stack

Perl (Mojolicious) · R · PostgreSQL/PostGIS · Sqitch · Leaflet.js

## Como está organizado

| Área | O que é |
|---|---|
| `backend/` | API Perl/Mojolicious: modelos, controllers, jobs de ingestão |
| `frontend/edumaps/` | SPA Svelte + Leaflet.js |
| `analysis/edumapsr/` | pacote R de analítica (ranking, similaridade, indicadores) |
| `data_pipeline/` | migrations Sqitch e esquema da base |
| `db/` | imagem da base e scripts auxiliares |
| `docs/` | catálogo funcional, notas técnicas, runbooks |

## Correr em desenvolvimento

```bash
docker compose up          # frontend :8080 · API :3000 · analytics :8000
```

Depois de mexer em código, **reconstruir a imagem afetada** — `docker compose up`
reutiliza a imagem anterior (ver `AGENTS.md`, "Database"):

```bash
docker compose build backend minion && docker compose up -d
```

## Testes

```bash
cd backend          && prove -rl t/        # Perl contra Postgres de fixtures
cd frontend/edumaps && npm run test:run     # vitest (jsdom + MSW)
```

As duas suítes correm também na CI, sem serviços externos: os testes que
dependem de R, rede ou do schema staging auto-pulam-se em modo fixtures.

## Deploy

Ambientes de containers LXC, sincronizados "as-is" a partir do working tree
local via Rex:

```bash
cd backend/script/deploy
rex prepare                                # rsync para os 3 hosts
rex -H backend.edumaps deploy_backend_dev  # a task da área alterada
```

## Autor

Marco Arthur <arthurpbs@gmail.com>

---

**Nota**: ainda não há ficheiro `LICENSE` neste repositório — por isso não há
badge de licença. Aproveniência e licença de cada fonte de dados estão
registadas em `docs/funcionalidades/plataforma/fontes-de-dados.md`.