# Nota técnica 109 — Config da autoinscrição habilitada no painel (PR #211)

## Resumo

Último item das dívidas do ciclo de listas com QR (#208, notas 107/108). As
quatro folhas de configuração da autoinscrição (`canais.inscricao.enabled`,
`public_base_url`, `rate_max`, `rate_window_seconds`) estavam declaradas no
catálogo do `AppConfig` com `enabled => 0`. O painel as exibia com o selo
"Em breve" e o editor desabilitado, embora a funcionalidade estivesse ativa em
dev (valores gravados direto em `app_config.items`).

Entrega: 3 commits na branch `fix/config-inscricao-habilitada` → **PR #211**
(merge `c424ae4`).

## Decisões

- **`enabled` da folha é metadado de apresentação.** Ele não protege a escrita:
  `config_validate`/`config_put` ignoram a flag. Por isso a correção é só
  virar a flag; não houve mudança de API nem de regra de negócio. A semântica
  "Em breve" continua valendo para itens realmente não implementados
  (Aparência, Comportamento etc.).
- **Teste no modelo, não na UI.** A asserção nova está em
  `t/02-models/app-config.t` (a árvore expõe as 4 folhas do grupo
  `canais_inscricao` habilitadas). A fixture do frontend foi alinhada para que
  o mock não diverja do backend, como já se fez no PR #210.
- **Sem migração.** O catálogo vive em código (`%TREE`), não no banco.

## Validação

- Backend: 5 arquivos / 33 testes PASS contra o CI DB (`ci_db.sh`, porta 5433,
  `EDUMAPS_CONF=./t/ci/edu_maps.conf`).
- Frontend: `vitest run` 82 arquivos / 463 testes PASS.
- Deploy dev (backend + frontend) e validação visual em `/admin/config`
  aprovada pelo developer.

## Observação operacional

Uma mudança que só toca mocks de teste do frontend não altera o `dist`. A
imagem `leaflet-frontend` reconstruída é, portanto, idêntica à anterior
(mesmo id e data de criação), e o `docker compose up` não recria o
contentor. Isso não indica build obsoleto.
