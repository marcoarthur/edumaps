# Especificação de Requisitos — E-mail e LGPD nas listas com QR (Fase 2)

**Data:** 2026-10-12
**Autor:** Tech Lead / Product Engineer (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #214
**Depende de:** listas com QR (#208, PR #209) e confirmação de posse (#212, PR #213)
**Specs anteriores:** [Fase 0](./2026-10-11-listas-qr-autoinscricao-contatos.md) ·
[Fase 1](./2026-10-11-confirmacao-posse-listas-qr.md) — esta spec **estende** os
contratos delas sem quebrá-los.

---

# ENTREGÁVEL 1 — ISSUE

## Título

**E-mail e LGPD nas listas com QR: campos por lista, exclusão a pedido, retenção e consentimento versionado (Fase 2)**

## Contexto

As listas com QR coletam **nome + telefone** (Fase 0) e confirmam a posse do
telefone por Telegram ou WhatsApp (Fase 1). O núcleo de Canais já tem o
`Channel::Email` (SMTP, validação e código de confirmação), a agenda já guarda
e-mail (`clean.contatos.email`, único por escola) e o consentimento é hoje uma
constante `'1.0'` no código. Não há exclusão a pedido nem expurgo: todo dado
coletado fica para sempre.

## Problema

1. Escolas que se comunicam por e-mail (responsáveis, professores) não conseguem
   coletá-lo pela lista.
2. A plataforma coleta dados pessoais sem cumprir partes centrais da LGPD:
   o titular não consegue pedir a exclusão por conta própria, não há prazo de
   retenção e não há como provar **qual texto** de consentimento a pessoa
   aceitou.
3. Validade e limite de usos do QR existem na API, mas o gestor não consegue
   defini-los pela interface.

## Objetivo

- O gestor escolhe **o que cada lista coleta** — telefone, e-mail ou ambos — e
  o e-mail pode ser **confirmado por código** enviado por e-mail.
- O titular pode **remover os próprios dados** por um link pessoal; o gestor
  também pode remover um inscrito. A remoção **anonimiza** e deixa só um registro
  mínimo de auditoria.
- Um **expurgo automático** aplica prazos de retenção configuráveis.
- O texto de consentimento passa a ter **versões imutáveis** publicadas pela
  administração, e cada inscrição registra a versão e o hash do texto aceito.
- O gestor define **validade e limite de usos** do QR na interface.

## Escopo (Fase 2)

1. Campos coletados por lista e e-mail na inscrição (dedupe não destrutivo).
2. Confirmação de posse do e-mail por código (reusa a ref da Fase 1).
3. Exclusão a pedido: link pessoal do titular + ação do gestor; anonimização.
4. Retenção: job periódico com prazos no AppConfig.
5. Consentimento versionado: versões pela administração, vigente na página
   pública, versão + hash gravados na inscrição.
6. Expiração e `max_usos` do QR na interface do gestor.
7. Página `/privacidade` atualizada (texto vigente, prazos, como excluir).

## Fora de escopo (Fase 2)

- Envio em massa, campanhas, opt-out por mensagem (Fase 3).
- Consentimento por escola (decisão: versões da instalação).
- Portabilidade/relatório de dados do titular (direito de acesso) — anotado como
  pergunta em aberto.
- Confirmação retroativa de membros existentes (continua fora, como na Fase 1).
- Provedores de e-mail transacional por API (SES, SendGrid): o envio segue por
  SMTP (`canais.email.*`).

## Requisitos Funcionais

### RF-201: Campos coletados por lista — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve permitir que o gestor escolha, por lista, quais
contatos são coletados: `telefone`, `email`, `ambos` (os dois obrigatórios) ou
`qualquer` (os dois exibidos, pelo menos um obrigatório).
**Aceite:**
- [ ] Criar e editar lista aceitam `coleta` ∈ {`telefone`,`email`,`ambos`,`qualquer`};
      default `telefone` (Fase 0/1 intactas).
- [ ] `GET /api/canais/inscricao/:token` devolve `campos` (os exibidos) e
      `obrigatorios` (os exigidos), além do que já devolve.
- [ ] `exige_confirmacao` passa a valer para **cada** contato coletado.

### RF-202: Inscrição com e-mail — Essencial
**Ator:** inscrito.
**Descrição:** O sistema deve aceitar o e-mail na inscrição conforme a `coleta`
da lista, validando o formato e aplicando o modelo não destrutivo da Fase 0.
**Aceite:**
- [ ] E-mail validado pelo `Channel::Email` (`400` se inválido); normalizado em
      minúsculas; bruto e normalizado gravados na inscrição.
- [ ] Campo obrigatório ausente → `400`.
- [ ] Dedupe por e-mail na escola (índice único existente); telefone e e-mail
      apontando para contatos diferentes → reusa o do telefone e marca
      `conflito` (nada é sobrescrito ou apagado).
- [ ] Contrato da Fase 0/1 preservado para listas de telefone.

### RF-203: Confirmação do e-mail por código — Essencial
**Ator:** inscrito.
**Descrição:** Em lista que exige confirmação e coleta e-mail, o sistema deve
oferecer o canal `email`: envia um código de 6 dígitos ao e-mail informado e
confirma quando o código confere.
**Aceite:**
- [ ] `confirmacao.canais` inclui `{canal:"email"}` quando o SMTP está
      configurado e ativo e a inscrição tem e-mail.
- [ ] `POST /api/canais/confirmacao/:ref/email` → `202`; `…/email/verificar
      {codigo}` → `200`/`400`/`410`; limites iguais aos do WhatsApp (`429`).
- [ ] O estado passa a ser **por contato**: `telefone` e `email` têm
      `confirmado_em/via` próprios; o estado geral é `confirmado` quando todos os
      contatos coletados estão confirmados, `parcial` quando só parte, senão
      `pendente`.
- [ ] Gestor vê o estado por contato e o geral; filtro inclui `parcial`.

### RF-204: Exclusão a pedido pelo titular — Essencial
**Ator:** titular (não autenticado).
**Descrição:** O sistema deve entregar ao titular um **link pessoal de
exclusão** e, ao ser usado, anonimizar seus dados naquela escola.
**Aceite:**
- [ ] Na inscrição, o sistema gera um token de exclusão (128 bits, só hash no
      banco, sem validade) e o devolve na resposta do POST como
      `exclusao_url`; a página de sucesso mostra o link e sugere guardá-lo; as
      mensagens de confirmação (e-mail) incluem o link.
- [ ] `GET /api/canais/exclusao/:token` → `200 {escola_nome, lista_nome}`
      (sem PII); `404` genérico.
- [ ] `POST /api/canais/exclusao/:token {confirmar:true}` → anonimiza (RF-206)
      → `200 {ok:1}`; reutilizar o token → `200` idempotente.
- [ ] Página pública `/privacidade/exclusao/:token` com confirmação explícita.

### RF-205: Exclusão pelo gestor — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve permitir que o gestor remova um inscrito
(atendendo pedido feito à escola), com confirmação e motivo.
**Aceite:**
- [ ] `DELETE /api/gestor/:cod_inep/canais/listas/:id/membros/:membro_id
      {motivo}` → anonimiza (RF-206) → `200`; `403/404` fora da escola.
- [ ] Ação na tabela de membros, com diálogo de confirmação.

### RF-206: Anonimização com registro mínimo — Essencial
**Ator:** sistema.
**Descrição:** A exclusão deve apagar os dados pessoais e manter apenas um
registro mínimo, sem PII, que prove que houve inscrição e exclusão.
**Aceite:**
- [ ] No contato (`clean.contatos`) da escola: nome vira `[removido]`,
      telefone/e-mail viram `NULL`; o contato é desvinculado de **todas** as
      listas da escola (a pessoa pediu para sair da escola, não de uma lista).
- [ ] Nas inscrições do contato: nome, telefone, e-mail (bruto e normalizado),
      `ip_anon` e `user_agent` apagados; ficam data, lista, versão do
      consentimento e `anonimizado_em`.
- [ ] Refs de confirmação e códigos pendentes do contato invalidados;
      `telegram_chat_id` apagado.
- [ ] Registro em `canal_exclusoes`: escola, contagem de itens afetados,
      origem (`titular`|`gestor`|`retencao`), quem (gestor) e quando — **sem
      PII**.
- [ ] Nova inscrição da mesma pessoa depois da exclusão cria um contato novo.

### RF-207: Retenção e expurgo automático — Importante
**Ator:** sistema / administrador.
**Descrição:** O sistema deve aplicar periodicamente prazos de retenção
configuráveis.
**Aceite:**
- [ ] Config `canais.retencao.*`: `enabled` (default `true`),
      `metadados_dias` (90), `pendentes_dias` (180), `listas_inativas_meses` (12).
- [ ] Job Minion diário:
      - apaga `ip_anon` e `user_agent` de inscrições mais antigas que
        `metadados_dias`;
      - anonimiza (RF-206, origem `retencao`) inscritos **nunca confirmados**
        de listas que exigem confirmação, após `pendentes_dias`;
      - anonimiza os membros de listas desativadas há mais de
        `listas_inativas_meses` (só se o contato não estiver em outra lista ativa).
- [ ] Cada execução registra contagens em `canal_exclusoes` e no log; execução
      idempotente.
- [ ] Admin vê a última execução e pode dispará-la manualmente.

### RF-208: Consentimento versionado — Essencial
**Ator:** administrador da instalação; inscrito.
**Descrição:** O sistema deve manter versões imutáveis do texto de
consentimento, com uma vigente, e registrar em cada inscrição a versão e o
hash do texto aceito.
**Aceite:**
- [ ] Admin cria versão (`versao`, `texto` em markdown simples) como rascunho,
      edita enquanto rascunho, e **publica** (vira vigente; a anterior fica
      arquivada). Publicada é imutável.
- [ ] Migration cria a versão `1.0` com o texto atual (compatível com as
      inscrições existentes).
- [ ] `GET /api/canais/inscricao/:token` devolve `consentimento {versao, texto}`
      vigente; o POST envia `consentimento_versao`; versão diferente da
      vigente → `409` (a página recarrega o texto).
- [ ] Inscrição grava `consentimento_versao` e `consentimento_hash` (sha256 do
      texto exibido).
- [ ] `/privacidade` mostra o texto vigente, os prazos de retenção e como
      excluir os dados.

### RF-209: Validade e limite do QR na interface — Importante
**Ator:** gestor.
**Descrição:** O sistema deve permitir definir validade e limite de usos ao
gerar ou rotacionar o QR, e mostrar quando o QR está esgotado ou expirado.
**Aceite:**
- [ ] `QRModal` ganha campos opcionais "Válido até" e "Limite de inscrições".
- [ ] Estado do QR na UI: ativo, expirado, esgotado (`usos >= max_usos`), revogado.
- [ ] Backend já aceita os campos (Fase 0); validações: data futura, limite > 0.

## Requisitos Não Funcionais

- **RNF-201 (LGPD):** exclusão e expurgo não deixam PII recuperável no banco da
  aplicação; o registro de auditoria não contém PII. Backups estão fora do
  escopo e devem ser tratados na política de backup.
- **RNF-202 (Segurança):** token de exclusão de 128 bits, só hash no banco, sem
  enumeração (erros genéricos); rate limit nos endpoints públicos novos.
- **RNF-203 (Não destrutivo × LGPD):** a regra "nunca descartar" das fases
  anteriores vale para **dedupe e conflito**; exclusão a pedido e retenção são
  as **únicas** vias que removem PII, sempre auditadas.
- **RNF-204 (Compatibilidade):** listas existentes ficam com `coleta=telefone`;
  contratos das Fases 0/1 preservados (campos só acrescentados); migrations
  novas, nenhuma change deployada editada.
- **RNF-205 (E-mail):** falha de SMTP nunca derruba a inscrição; o envio fica
  em `canal_mensagens`; o corpo gravado não contém o código.

## Critérios de Aceite (visão do usuário)

- [ ] Gestor cria "Responsáveis 8º" coletando **telefone e e-mail** e exigindo
      confirmação.
- [ ] O responsável se inscreve, confirma o telefone pelo Telegram e o e-mail
      pelo código; o gestor vê **Confirmado** nos dois.
- [ ] A página de sucesso mostra o link "Remover meus dados"; usando-o, o
      responsável some das listas da escola e o gestor vê a exclusão no
      histórico, sem nome nem telefone.
- [ ] O admin publica a versão 1.1 do consentimento; novas inscrições gravam
      1.1; as antigas continuam com 1.0.
- [ ] O gestor gera um QR válido até sexta e limitado a 30 inscrições; ao
      atingir 30, a página pública informa que as inscrições se encerraram.

## Riscos

| # | Risco | Impacto | Mitigação |
|---|-------|---------|-----------|
| R1 | Anonimização incompleta (PII esquecida em alguma tabela) | Alto | inventário de colunas com PII na spec; teste que varre as tabelas após a exclusão |
| R2 | Link de exclusão perdido pelo titular | Médio | e-mail de confirmação inclui o link; exclusão pelo gestor como alternativa |
| R3 | Link de exclusão vazado (terceiro remove dados alheios) | Baixo | só remove (não lê) dados; confirmação explícita; auditoria |
| R4 | Expurgo apaga dados ainda necessários | Médio | prazos configuráveis, só pendentes nunca confirmados e listas inativas; `enabled` desligável; auditoria por execução |
| R5 | SMTP de dev indisponível | Baixo | provedor simulado nos testes; e-mail só aparece como canal se SMTP ativo |
| R6 | Contato compartilhado por várias listas da escola | Médio | exclusão a pedido remove de todas (decisão); expurgo de lista inativa só anonimiza se o contato não estiver em lista ativa |
| R7 | Texto de consentimento alterado depois de aceito | Alto | versões publicadas imutáveis + hash gravado na inscrição |

## Dependências

- Fases 0 e 1 (tabelas `canal_*`, `Canal::Listas`, `Canal::Confirmacao`, página pública).
- `Channel::Email`, `Channel::Confirmation`, `Channel::History`; AppConfig (`canais.email.*`).
- Minion (job diário, mesmo padrão autorreagendável da `telegram_polling`).
- Painel de Configuração/Admin (versões de consentimento, retenção).

## Métricas de sucesso

- % de listas que coletam e-mail; taxa de confirmação de e-mail.
- Nº de exclusões por origem (titular, gestor, retenção) e tempo de atendimento.
- Volume expurgado por execução; zero PII em registros de exclusão (teste).
- % de inscrições com `consentimento_hash` (meta: 100% das novas).

## Decisões já tomadas (com o developer, 2026-10-12)

1. **E-mail por campos configuráveis por lista** (`telefone`/`email`/`ambos`/`qualquer`).
2. **Exclusão**: autoatendimento por link pessoal **e** pelo gestor; **anonimiza**
   e mantém registro mínimo de auditoria.
3. **Retenção configurável com defaults**: metadados 90 dias, pendentes 180
   dias, listas inativas 12 meses.
4. **Consentimento**: versões imutáveis mantidas pela **administração da
   instalação**, uma vigente.

## Perguntas em aberto

1. Direito de acesso/portabilidade (o titular ver os próprios dados) — entra
   nesta fase ou numa próxima?
2. Texto definitivo do consentimento 1.0/1.1 e da página `/privacidade` —
   revisão jurídica da escola/rede.
3. Exclusão a pedido deve também remover o contato de reuniões/relações onde
   ele aparece (`clean.contatos` é compartilhado com o módulo gestor)?
   Proposto: o contato é anonimizado (nome `[removido]`, sem telefone/e-mail),
   o que já cobre as outras telas, sem apagar reuniões.

---

# ENTREGÁVEL 2 — PLANO DE IMPLEMENTAÇÃO

## Inventário de PII (base do RF-206 e do teste de varredura)

| Tabela | Colunas com PII | Na exclusão |
|---|---|---|
| `clean.contatos` | `nome`, `telefone`, `email` | `[removido]`, `NULL`, `NULL` |
| `clean.canal_inscricoes` | `nome`, `telefone`, `telefone_norm`, `email`, `email_norm`, `ip_anon`, `user_agent` | apagadas (`nome='[removido]'`, demais `''`/`NULL`) + `anonimizado_em` |
| `clean.canal_lista_membros` | `telegram_chat_id` (vínculo) | linhas do contato removidas |
| `clean.canal_confirmacao_refs` | `telegram_chat_pendente` | invalidadas, chat apagado |
| `clean.canal_confirmacoes` | `endereco` | pendentes do endereço expiradas; `endereco` substituído por hash |
| `clean.canal_mensagens` | destinatário, corpo | destinatário e corpo apagados para mensagens do contato |

## Modelo de dados

Change nova `canal_email_lgpd [canal_confirmacao_listas]`, anexada ao fim do
plano.

```sql
ALTER TABLE clean.canal_listas
  ADD COLUMN coleta text NOT NULL DEFAULT 'telefone'
    CHECK (coleta IN ('telefone','email','ambos','qualquer'));

ALTER TABLE clean.canal_inscricoes
  ALTER COLUMN telefone DROP NOT NULL,
  ALTER COLUMN telefone_norm DROP NOT NULL,
  ADD COLUMN email          text,
  ADD COLUMN email_norm     text,
  ADD COLUMN consentimento_hash text,       -- sha256 do texto aceito (novas inscrições)
  ADD COLUMN exclusao_hash  text UNIQUE,    -- sha256 do token de exclusão
  ADD COLUMN anonimizado_em timestamptz;

ALTER TABLE clean.canal_lista_membros
  ADD COLUMN email_confirmado_em  timestamptz,
  ADD COLUMN email_confirmado_via text CHECK (email_confirmado_via IN ('email'));
-- confirmado_em/via existentes passam a significar "telefone confirmado".

CREATE TABLE clean.consentimento_versoes (
  id           bigserial PRIMARY KEY,
  versao       text NOT NULL UNIQUE,
  texto        text NOT NULL,
  texto_hash   text NOT NULL,
  status       text NOT NULL DEFAULT 'rascunho'
    CHECK (status IN ('rascunho','vigente','arquivada')),
  criado_por   bigint REFERENCES clean.gestores (id) ON DELETE SET NULL,
  publicada_em timestamptz,
  created_at   timestamptz NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX uq_consentimento_vigente
  ON clean.consentimento_versoes ((true)) WHERE status = 'vigente';
-- seed: versão '1.0' vigente com o texto atual da página pública.

CREATE TABLE clean.canal_exclusoes (       -- auditoria SEM PII
  id          bigserial PRIMARY KEY,
  cod_inep    bigint NOT NULL,
  origem      text NOT NULL CHECK (origem IN ('titular','gestor','retencao')),
  regra       text,                         -- retencao: metadados|pendentes|lista_inativa
  gestor_id   bigint REFERENCES clean.gestores (id) ON DELETE SET NULL,
  motivo      text,
  contatos    integer NOT NULL DEFAULT 0,
  inscricoes  integer NOT NULL DEFAULT 0,
  membros     integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT NOW()
);
```

`canal_confirmacoes.canal` já aceita `email`. Retenção usa
`canal_listas.updated_at` quando `ativo=false` (desativação) — conferir se o
soft-delete atualiza `updated_at`; senão, `desativada_em` nesta mesma change.

## Endpoints da API

**Público**

| Método | Rota | Mudança |
|---|---|---|
| GET | `/api/canais/inscricao/:token` | + `campos`, `obrigatorios`, `consentimento {versao, texto}` |
| POST | `/api/canais/inscricao/:token` | + `email`, `consentimento_versao` (409 se não vigente); resposta + `exclusao_url` |
| POST | `/api/canais/confirmacao/:ref/email` | novo — `202`/`404`/`409`/`429` |
| POST | `/api/canais/confirmacao/:ref/email/verificar` | novo — `200`/`400`/`410` |
| GET | `/api/canais/confirmacao/:ref` | `estado` ganha `parcial`; + `contatos {telefone:{estado,via}, email:{estado,via}}` |
| GET | `/api/canais/exclusao/:token` | novo — `200 {escola_nome, lista_nome}` · `404` |
| POST | `/api/canais/exclusao/:token` | novo — `{confirmar:true}` → `200 {ok:1}` |
| GET | `/api/canais/consentimento` | novo — versão vigente `{versao, texto, publicada_em}` (para `/privacidade`) |

**Gestão**

| Método | Rota | Mudança |
|---|---|---|
| POST/PATCH | `/listas`, `/listas/:id` | + `coleta` |
| GET | `/listas/:id/inscricoes` | + `email`, estado por contato, `estado` geral com `parcial` |
| DELETE | `/listas/:id/membros/:membro_id` | novo — exclusão pelo gestor `{motivo}` |
| GET | `/exclusoes` | novo — histórico de exclusões da escola (sem PII) |

**Admin**

| Método | Rota | Função |
|---|---|---|
| GET/POST | `/api/admin/consentimento/versoes` | listar / criar rascunho |
| PUT | `/api/admin/consentimento/versoes/:id` | editar rascunho (`409` se publicada) |
| POST | `/api/admin/consentimento/versoes/:id/publicar` | publica (arquiva a vigente) |
| GET | `/api/admin/canais/retencao` | última execução + prazos |
| POST | `/api/admin/canais/retencao/executar` | dispara o job (`202`) |

## Fluxos

**Inscrição com e-mail e confirmação:** POST com `nome`, `telefone?`,
`email?`, `consentimento_versao` → valida contra `coleta` → dedupe (telefone,
depois e-mail) → membro → ref (se exige) → `canais` inclui `email` se houver
e-mail e SMTP ativo → página mostra Telegram/WhatsApp para o telefone e
"Receber código por e-mail" para o e-mail → estado geral por polling.

**Exclusão pelo titular:** página de sucesso mostra `exclusao_url`
(`/privacidade/exclusao/<token>`) → GET mostra escola/lista → confirmar → POST →
`Canal::Exclusao->anonimizar_contato(contato_id, origem=>'titular')` numa
transação → registro em `canal_exclusoes`.

**Retenção:** task `canais_retencao` diária (autorreagendável, lock único),
três regras em transações separadas, contagens por regra em `canal_exclusoes`.

## Telas/UX mínimas

- **ListasPage:** seletor "Coletar: Telefone · E-mail · Ambos · Qualquer um";
  colunas de e-mail e estado por contato; ação "Remover inscrito" (diálogo com
  motivo); aba/seção "Exclusões" com o histórico (data, origem, contagens).
- **QRModal:** "Válido até" (data/hora) e "Limite de inscrições" ao gerar;
  estado expirado/esgotado.
- **InscricaoPublicaPage:** campo e-mail conforme a lista; texto de
  consentimento vigente (expansível) com a versão; na confirmação, bloco "Receber
  código por e-mail"; página de sucesso com o link "Remover meus dados".
- **ExclusaoPage (`/privacidade/exclusao/:token`):** escola e lista,
  explicação do que será removido, botão confirmar, estado concluído.
- **PrivacidadePage:** texto vigente do consentimento, prazos de retenção (da
  config), como excluir.
- **Admin (`/config` ou `/admin`):** versões de consentimento (lista, rascunho,
  editar, publicar) e retenção (prazos, última execução, executar agora).

## Testes

- `t/02-models/canal_exclusao.t`: anonimização completa — **varredura** das
  colunas do inventário de PII depois da exclusão; registro sem PII;
  idempotência; nova inscrição cria contato novo.
- `t/02-models/canal_retencao.t`: as três regras com datas manipuladas;
  idempotência; contato em lista ativa preservado.
- `t/02-models/consentimento.t`: rascunho → vigente → arquivada; imutável após
  publicar; vigente única.
- `t/04-api/canais/`: inscrição com e-mail por `coleta` (400 por obrigatório,
  dedupe, conflito), `409` de versão de consentimento, confirmação por e-mail
  (SMTP simulado), exclusão pública (200/404/idempotente), regressão das Fases 0/1.
- `t/04-api/gestor` e `t/04-api/admin`: `coleta`, exclusão pelo gestor,
  histórico, versões de consentimento, retenção.
- Frontend (`vitest`): campos por `coleta`, consentimento com versão e 409,
  e-mail na confirmação, link de exclusão, `ExclusaoPage`, `QRModal` com
  validade/limite, admin de consentimento/retenção.
- E2E (CDP): lista `ambos` → inscrição → e-mail confirmado com SMTP de teste
  (ou simulado) → exclusão pelo link → gestor vê o histórico.

## Estratégia de rollout

1. Migration com `coleta='telefone'` e consentimento 1.0 vigente: nada muda para
   listas existentes.
2. Retenção vem com `enabled=true` mas só age sobre dados além dos prazos; em
   dev, conferir a primeira execução manualmente pelo endpoint admin.
3. Deploy: `deploy_db_dev` → `deploy_backend_dev` + `deploy_minion_dev` →
   `deploy_frontend_dev` (com `EDUMAPS_CONFIG_MASTER_KEY` exportada); imagens
   locais `sqitch`, `backend`, `minion`, `frontend`.
4. Rollback: `canais.retencao.enabled=false`; listas voltam a `coleta=telefone`.

## Execução sugerida (ondas)

| Onda | Trilha | Itens |
|---|---|---|
| 1 | db/backend | migration; consentimento versionado; `coleta` + e-mail na inscrição; confirmação por e-mail |
| 1 | frontend | `coleta` na ListasPage; e-mail e consentimento na página pública; QRModal com validade/limite |
| 2 | backend | exclusão (titular + gestor, anonimização, auditoria); retenção (job + admin) |
| 2 | frontend | `ExclusaoPage`, link de exclusão, remover inscrito + histórico, admin de consentimento e retenção, `/privacidade` |
| 3 | coord. | integração, e2e, docs funcionais, deploy, PR |

O registro mutável fica em `2026-10-12-email-lgpd-listas-qr.execucao.md`,
criado no início da execução.
