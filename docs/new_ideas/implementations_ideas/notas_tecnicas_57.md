# Nota técnica — Importar contatos da folha de pagamento

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) + frontend (Svelte 5)

## 1. Contexto

Ao agendar uma reunião, a lista de contatos mostrava os **grupos vazios** (o
gestor via "Professores", "Administrativos", "Outros", mas sem ninguém para
convidar).

## 2. Diagnóstico

- A folha de pagamento criava apenas **grupos** (`clean.contato_grupos` com
  `origem='folha'`) a partir das categorias de `clean.remuneracao_municipal` —
  eram **rótulos**, sem contatos.
- O módulo nunca teve import de **pessoas** da folha: os contatos só entravam
  por cadastro/colagem manual. Escolas com apenas grupos `folha` ficavam com
  **0 contatos**.
- `list_grupos` mostra `n_contatos`; os grupos `folha` apareciam com `0`.

## 3. Fix

- `Roles/Business/Gestor/Reunioes.pm#importar_contatos_folha($cod_inep, $gestor_id)`:
  - garante os grupos `folha` (`sincronizar_grupos_folha`);
  - lê `DISTINCT nome_profissional, categoria` de `clean.remuneracao_municipal`
    da escola;
  - para cada profissional, resolve o grupo via `_grupo_para_categoria` e cria um
    **contato** com `nome` + `cargo` (a folha não traz e-mail/telefone),
    vinculado ao `grupo_id`;
  - **idempotente**: pula se já existe contato com mesmo nome (case-insensitive)
    no mesmo grupo.
- Controller `contatos_importar_folha` + rota
  `POST /api/gestor/:cod_inep/contatos/importar-folha` (registrada junto de
  `/contatos/import`, antes de `/:id`).
- Frontend: botão **"Importar da folha"** na seção de importação da
  `ContatosPage`, recarregando contatos e grupos.

## 4. Validação

| Item | Resultado |
|------|-----------|
| Model no container (escola `35245239`, 206 registros de folha) | **21 contatos** importados |
| Gupos antes vazios | `Administrativos=4`, `Outros=2` (agora com contatos) |
| 2ª rodada | `n_inseridos=0` (idempotente) |
| Backend | `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` → 71 ok |
| Frontend | `ContatosPage.test.js` 4 ok; suite 302 ok (4 pré-existentes) |

Deploy: `deploy_backend_dev` + `deploy_frontend_dev` → **PR #90** (merge `2febbc9`).

## 5. Lições

- **"Grupo" ≠ "pessoas"**: pré-listar grupos a partir da folha não popula a
  agenda. Se a expectativa é ter quem convidar, é preciso importar os
  **profissionais** como contatos.
- A folha (`remuneracao_municipal`) não tem e-mail/telefone — o contato nasce com
  nome + cargo; a UNIQUE de e-mail é parcial, então homônimos são permitidos.
- A deduplicação usa **nome + grupo** (case-insensitive), não o CPF (que vem
  mascarado na base).
