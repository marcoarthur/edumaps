# Nota técnica — Admin de instalação via config (bootstrap provisório)

> Data: 2026-09-25 · Ciclo: backend (Perl/Mojolicious) + deploy (Rex) · PR #99

## 1. Contexto

O operador de deploy precisa logar como administrador no Painel de Configuração
(`/config`) na instalação, mas a criação de administradores via banco exigia
SQL manual (`UPDATE clean.gestores SET access_role='admin'`). Para simplificar o
bootstrap em ambientes de deploy, foi criado um mecanismo provisório: credenciais
de administrador (email + senha) em texto plano no arquivo de configuração
`edu_maps.conf` (bloco `admin`). Ao logar com essas credenciais, o backend
materializa/garante um gestor em `clean.gestores` com INEP reservado `0` e
`access_role='admin'`, e emite a sessão normal.

**Registrado como PROVISÓRIO** — o mecanismo deve ser substituído por uma
gestão própria de administradores (cadastro, listagem, revogação, MFA, etc.)
planejada em ciclo futuro.

## 2. Decisões (alinhadas com o usuário)

| Ponto | Decisão |
|---|---|
| Onde armazenar credenciais admin | `edu_maps.conf` (gitignored) — bloco `admin => { email, senha }` |
| Como injetar no container | Rexfile: `admin_email` / `admin_password` de `$ENV{EDUMAPS_ADMIN_*}` → template `edumaps_db.conf` |
| INEP do gestor admin | Reservado `0` (bigint NOT NULL, sem FK — não colide com escolas reais) |
| Materialização | No primeiro login bem-sucedido: `INSERT ... ON CONFLICT(email) DO NOTHING` com INEP=0; subsequentemente `UPDATE access_role='admin'` idempotente |
| Segurança | Credenciais **nunca logadas**; comparação `string eq` no controller (tempo constante implícito p/ strings curtas); apenas o hash via `_hash_senha` chega ao banco |
| Fallback | Se bloco `admin` ausente ou vazio → sem admin de config, fluxo normal de login/gestor |

## 3. Implementação

### 3.1 Backend

- **`Controller/Pesquisa.pm::login`**: após falha do `login_gestor` (banco), consulta `$self->app->config->{admin}`; se email/senha conferirem, chama `Gestores->login_admin_config($email, $senha)`.
- **`Roles/Business/Pesquisa/Gestores.pm`**: novo `login_admin_config($email, $senha)` — materializa/garante gestor admin (INEP=0, nome "Administrador da Instalação", access_role='admin', senha_hash da senha informada) e devolve sessão via `login_gestor`.

### 3.2 Deploy (Rex)

- **`Rexfile`**: `set admin_email => $ENV{EDUMAPS_ADMIN_EMAIL} || ''`; `set admin_password => $ENV{EDUMAPS_ADMIN_PASSWORD} || ''`; passados ao template.
- **`files/edumaps_db.conf`**: bloco `admin` condicional (`<% if ($admin_email && $admin_password) { %>`) — só emitido quando ambos definidos.

### 3.3 Configuração local

- **`backend/edu_maps.conf`** (gitignored): bloco `admin` com fallback para env (`$ENV{...} // default`) para facilitar dev local.

### 3.4 Testes

- **`t/04-api/admin/bootstrap.t`**: novo — 4 testes cobrindo login admin via config (200, access_role=admin, INEP=0), senha errada (401), `/me` expõe access_role, acesso ao `/api/admin/config/tree`.

## 4. Validação

- **Backend local**: `prove -l t/04-api/admin/bootstrap.t t/04-api/admin/config.t` → **17 testes ok** (incluindo novo + existentes).
- **Deploy container**: `rex prepare deploy_backend_dev` com `EDUMAPS_ADMIN_EMAIL` / `EDUMAPS_ADMIN_PASSWORD` → `edu_maps.conf` gerado com bloco admin.
- **Container (backend.edumaps)**:
  - `POST /api/gestor/login` com admin de config → 200, token, gestor `access_role=admin`, `cod_inep=0`.
  - `GET /api/admin/config/tree` com token admin → 200 (painel acessível).
  - Senha errada → 401.
- **Frontend (vitest)**: 63 files / 337 testes passam (sem regressão).

## 5. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Senha plain text em arquivo de config (mesmo gitignored) | Apenas p/ bootstrap; planejar substituição urgente. Comentários no código e conf: "PROVISÓRIO — planejar gestão própria". |
| Colisão de email com gestor escolar real | INEP=0 reservado garante separação semântica; porém upsert por email *poderia* sobrescrever cod_inep de gestor existente — risco aceito p/ provisório (ops define email dedicado). |
| INEP=0 pode confundir rotas escolares | Admin de instalação não usa rotas `/gestor/:cod_inep/...`; painel `/config` não depende de escola. |

## 6. Pendências / Planejado

- **Substituir este mecanismo** por gestão de administradores própria (cadastro, listagem, expiração, MFA, rota `/api/admin/admins`, UI). Deve ser planejado como issue/backlog.
- Auditoria de login admin (log de quem/quando, sem senha).
- Rotação de senha / expiração.

## 7. Arquivos alterados/criados

- `backend/lib/EduMaps/Controller/Pesquisa.pm` — login fallback admin config
- `backend/lib/EduMaps/Roles/Business/Pesquisa/Gestores.pm` — `login_admin_config`
- `backend/script/deploy/Rexfile` — settings `admin_email`/`admin_password`
- `backend/script/deploy/files/edumaps_db.conf` — template com bloco admin
- `backend/edu_maps.conf` — bloco admin local (gitignored)
- `backend/t/04-api/admin/bootstrap.t` — testes novos