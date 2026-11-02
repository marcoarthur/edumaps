# Nota técnica 165 — senha do gestor em Argon2id (#334)

PR #337 (merge `a0fdaaf`, 2026-11-02). Segunda de três issues de autenticação
abertas depois do PR #333 (nota 164).

## O que mudou

- `_hash_senha` grava **Argon2id** no formato padrão
  (`$argon2id$v=19$m=65536,t=3,p=1$sal$hash`), sal de 16 bytes do
  `/dev/urandom`.
- `_verify_senha` reconhece o formato pelo prefixo: `$argon2…` via
  `argon2_verify`; o antigo `<sal_hex>:<hmac_sha256_hex>` segue aceito, agora
  com comparação em tempo constante.
- **Re-hash no login**: senha conferida + hash antigo (ou Argon2id com custo
  abaixo do atual, via `argon2_needs_rehash`) → regrava em Argon2id. Senha
  errada nunca regrava. Ninguém precisa trocar senha.

## Escolha dos parâmetros

Medido no `backend.edumaps` (4 núcleos) com o próprio `carton exec`:

| Parâmetros | ms por hash |
|---|---|
| 19 MiB, t=2 (mínimo OWASP) | 22 |
| 32 MiB, t=3 | 59 |
| 64 MiB, t=2 | 93 |
| **64 MiB, t=3** | **128** |

Meta 100–300 ms por login: 64 MiB/t=3/p=1 (segunda opção da RFC 9106, com
p=1). No host de desenvolvimento (12 núcleos) o mínimo OWASP custava 13 ms —
medir no alvo, não no host, mudou a escolha. Login completo pela API:
0,16–0,25 s. Memória: 64 MiB por login simultâneo.

Subir um parâmetro no futuro é só mudar a constante: os hashes existentes são
regravados aos poucos, no login de cada um.

## Dependências

`Crypt::Argon2` (>= 0.019, por `argon2_needs_rehash`; traz o C do argon2 e
compila com `build-essential`) e `Crypt::URandom` no `backend/cpanfile` — a
mesma fonte para a imagem Docker (`carton install`), o LXC (Rex/carton) e o CI
(`cpanm --installdeps`). A imagem local recompila o módulo no build.

## Migração

Sem migração de dados (o banco não conhece as senhas). A change
`gestores_senha_argon2id` só atualiza o comentário da coluna. No LXC, no
deploy: 32 contas no formato antigo, convertidas conforme entram.

## Pendências

- Remover o suporte ao formato antigo quando só restarem contas paradas
  (medir: `senha_hash ~ '^[0-9a-f]{32}:'`).
- ~~Enumeração de e-mail por tempo no login~~ — resolvido no PR #338
  (hash fictício; nota 166).
- `edumaps-analytic.service` no `backend.edumaps` em `failed` desde
  2026-10-31 (fora deste ciclo).
- #335 (limite de tentativas) e #336 (esqueci minha senha) seguem abertas.
