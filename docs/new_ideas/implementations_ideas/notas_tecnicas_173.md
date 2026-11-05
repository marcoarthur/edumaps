# Nota técnica 173: permissões explícitas do papel de leitura

PR #PR_NUM (2026-11-05). Continuação da change `leitor_sem_tabelas_sensiveis`
(PR #341).

## Contexto

O papel `edumaps_leitor` é a conexão somente-leitura do motor R. Ele serve a
três consumidores:

- o Assistente do Censo (SQL gerado por LLM, filtrado pelo `dicionario.yml`);
- os relatórios, que leem pelas ferramentas do eduBR tabelas fora do
  dicionário;
- o perfil escolar, que cria views em `analytics` e dá `GRANT` nelas.

A change `edumaps_leitor_role` deu `SELECT` em tudo de `clean` e `analytics`
e configurou `ALTER DEFAULT PRIVILEGES` nos dois schemas. Com isso, toda
tabela nova de `clean` já nascia legível pelo papel. A `leitor_sem_tabelas_sensiveis`
revogou o acesso a 54 tabelas internas e com dados pessoais, mas a proteção
dependia de lembrar de revogar a cada tabela nova.

## Decisão

- **Fechado por padrão em `clean`.** A change `leitor_grants_explicitos`
  remove os privilégios automáticos do papel em `clean`. Ela percorre o
  `pg_default_acl` e revoga com `FOR ROLE` cada dono que os concedeu, porque o
  usuário de deploy não é o mesmo em todo ambiente (`devel` no Docker, o
  `db_user` do Rexfile no LXC).
- **As permissões existentes ficam.** As 58 relações públicas continuam
  legíveis, então nada muda para o Assistente nem para os relatórios.
- **Uma lista só com o dicionário foi descartada.** Liberar apenas as tabelas
  do `dicionario.yml` quebraria os relatórios, que leem outras tabelas.
- **`analytics` continua automático.** Só tem agregados públicos, e as views
  materializadas são recriadas: sem o automático, cada recriação tiraria o
  acesso do Assistente.
- **Nada é criado em `clean` em tempo de execução**, a não ser as tabelas do
  Minion, que já estão entre as sensíveis. O perfil escolar escreve em
  `analytics`.

## Gate

`backend/t/02-models/leitor_grants.t` exige uma decisão para cada tabela,
view ou view materializada de `clean`:

- ou o papel tem `SELECT`, concedido pela migração da tabela;
- ou ela está na lista de sensíveis do teste, a mesma da change do PR #341.

O teste falha com tabela sem decisão, com tabela sensível legível e com
privilégio automático de volta em `clean`. Roda no banco de fixtures do CI.

O verify da change confere três coisas:

- não sobrou privilégio automático em `clean`;
- `clean.censo_escolas` continua legível;
- `analytics` mantém o automático.

## Regra para migrações novas

- Tabela **pública** em `clean`: `GRANT SELECT ON clean.<t> TO edumaps_leitor`
  na própria migração.
- Tabela **com dado pessoal ou interna**: sem `GRANT`, e o nome entra na
  lista do teste.

A regra está no `AGENTS.md`, na seção Database.

## Validação

- **Docker local.** Deploy e verify passaram. Tabela nova em `clean` nasce sem
  leitura e em `analytics` com leitura. O teste falha antes da change e com
  uma tabela esquecida, e passa depois.
- **Banco limpo do CI.** Deploy, verify, teste, revert `--to`
  `auth_falhas_telegram` (o teste falha) e redeploy passaram, assim como o
  gate `ci_db.sh verify`.

## Deploy

`deploy_db_dev` no LXC, junto da fila de 2026-11-09.
