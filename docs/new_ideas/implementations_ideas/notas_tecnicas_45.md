# Nota técnica — Painel de Inventário Escolar (recursos e serviços)

> Data: 2026-09-20 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

O gestor escolar precisa inventariar **materiais pedagógicos** e **recursos de
gestão** (computadores, giz, lousas, salas) e **serviços/fornecedores** (contas
de água/luz/internet, manutenção). O Censo já traz um baseline desses recursos;
o EduMaps passa a exibi-lo e a permitir que o gestor **acrescente** o que não
está no Censo — sem nunca alterar os dados do Censo.

## 2. Problema / decisões de desenho

- **Censo intocado**: `clean.censo_escolas` é apenas lido. O baseline é derivado
  em tempo real (`inventario_censo`) e, quando o gestor quer, é **importado**
  para itens manuais via `censo_ref` (reimportação idempotente).
- **Sem engessar o schema**: a variedade de recursos/serviços é enorme, então
  não se criam colunas por tipo. Categorias têm **nome livre** e cada item pode
  carregar `atributos jsonb` arbitrários — criar uma categoria/item novo não
  exige DDL.
- **Recursos e serviços unificados**: o `tipo` (`recurso`/`servico`) fica na
  categoria; itens de serviço usam `fornecedor_id`, `identificador`,
  `periodicidade` e `valor` (conta/contrato). Isso evita duas tabelas quase
  idênticas.
- **Taxonomia semeada**: no primeiro acesso, 9 categorias do Censo são criadas
  (`origem='censo'`) — Computadores, Notebooks, Tablets, Impressoras e
  periféricos, Equipamentos audiovisuais, Materiais pedagógicos, Espaços e
  salas, Infraestrutura e serviços básicos, Conectividade — todas editáveis.
- **Anexos no v1**: fotos e notas fiscais, **vários por item** (diferente de
  Reuniões, que guarda um por tipo). Arquivo físico em `upload_dir`.

## 3. Solução

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Migração | `data_pipeline/{deploy,revert,verify}/inventario_escolar.sql` | categorias, fornecedores, itens (JSONB + `censo_ref`) e anexos |
| Backend | `Roles/Business/Gestor/Inventario.pm` (novo) | baseline do Censo, semeadura, import idempotente, CRUD e anexos |
| Backend | `Controller/Gestor.pm` | ações `inventario_*`, validação (decimais com vírgula) e guarda de erros de banco |
| Backend | `Plugin/API/Gestor.pm` | rotas `/api/gestor/:cod_inep/inventario[/...]` (constraints arrayref) |
| Frontend | `features/gestor/api/gestorInventarioApi.js` | cliente do módulo (inclui upload/download) |
| Frontend | `features/gestor/pages/InventarioPage.svelte` | abas Do Censo/Recursos/Serviços/Fornecedores, modais, atributos livres e anexos |
| Frontend | `features/gestor/{constants,mocks}/inventario*` | unidades/estados/periodicidades + MSW |
| Frontend | `app/routes.js`, `features/gestor/index.js`, `GestorPanelPage.svelte` | rota `/gestor/inventario` + link no painel |

### Modelo de dados (flexível)
- `inventario_categorias(id, cod_inep, gestor_id, tipo, nome, origem)` —
  `UNIQUE (cod_inep, tipo, lower(nome))`.
- `inventario_fornecedores(id, cod_inep, gestor_id, nome, tipo_servico, email,
  telefone, site, documento, observacoes, atributos jsonb)`.
- `inventario_itens(id, cod_inep, gestor_id, categoria_id, fornecedor_id, nome,
  descricao, quantidade, unidade, estado, identificador, periodicidade, valor,
  data_aquisicao, censo_ref, atributos jsonb)` — GIN em `atributos`, único
  parcial `(cod_inep, censo_ref)`.
- `inventario_anexos(id, item_id, nome_original, caminho, mime, tamanho)`.

## 4. Armadilhas encontradas (importante)

- **Colisão de métodos entre roles**: `Reunioes.pm` e `Inventario.pm` definiam
  `registrar_anexo`/`anexo_row` com assinaturas diferentes. O `Role::Tiny`
  resolve conflito mantendo a **primeira** role composta — o Inventário chamava
  a versão de Reuniões e retornava `undef`. Renomeados para
  `registrar_anexo_item`/`anexo_item_row`/`delete_anexo_item`/
  `item_anexos_caminhos`/`list_anexos_item`.
- **Constraint de rota aninhada**: `[ @$check, [ anexo_id => qr/\d+/ ] ]` é lista
  aninhada e não casa — constraints devem ser **lista plana**:
  `[ @$check, anexo_id => qr/\d+/ ]`.
- **`num` do Mojolicious só aceita inteiro** (`/^-?[0-9]+$/`): `valor`/`quantidade`
  decimais falhavam. Fix: `like(qr/^\d+(?:[.,]\d{1,3})?$/)` + normalizar vírgula
  pt-BR para ponto no controller (`_dec`).
- **Dois bancos em dev**: o backend em container usa `Database`
  (`ssh root@database.edumaps`, user `edumaps`/`change_me`); os testes locais usam
  `ubatexu.lan` (user `devel`/`senhaboa123`). A migração precisou ser aplicada
  nos **dois** (o smoke real falhou com "relation does not exist" até aplicar em
  `Database`).
- **MSW multipart**: em jsdom o `File` do multipart não expõe `name` de forma
  confiável; o client anexa `_original_nome` como fallback (mesmo padrão de
  Reuniões).

## 5. Validação

- Backend: `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` — **53/53 PASS**
  (`inventario.t` cobre baseline, semeadura, import idempotente, CRUD, JSONB,
  anexos, ownership e validação).
- Frontend (container): `npx vitest run src/features/gestor` — **102/102 PASS**;
  suite completa 274/278 (as 4 falhas são pré-existentes).
- Smoke real (nginx): `GET /inventario` → 9 categorias + baseline; `POST
  /importar-censo` → 39 itens; reimport → 0; `GET /itens` → 39.
- Deploy: migração em `ubatexu.lan` + `Database`; `deploy_backend_dev` +
  `deploy_frontend_dev` → **PR #78** (merge `dc16c3c`).

## 6. Próximos passos

- **Catálogo compartilhado** entre escolas (fora do v1) e categorias globais.
- **Histórico/manutenção** de itens (baixa, conserto, transferência) e alertas
  de vencimento de contas.
- **Importação de nota fiscal** com OCR/parsing para preencher itens.
- **Relatórios** de inventário (exportação CSV/PDF) e comparação com o Censo
  (o que a escola declarou × o que o gestor registrou).
