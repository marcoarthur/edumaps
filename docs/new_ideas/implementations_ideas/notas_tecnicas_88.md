# Nota técnica 88 — Contrato de conectividade (#163), gate da CI (#177) e Fase 1A do Bot Telegram (#183)

**Data:** 2026-10-07
**Issues:** #163 (`chore(data): contrato de conectividade`), #177 (gate CI, passo 3), #183 (Bot Telegram, Fase 1A)
**PRs:** #182, #185, #184
**Âmbito:** `data_pipeline/scripts/check_fontes.pl`, `backend/lib/EduMaps/Bots/`, `backend/lib/EduMaps/Config/Bot.pm`, `.github/workflows/backend-tests.yml` (já na #181)

---

## 1. O que se fez

### 1.1 PR #182 — Verificador de contrato de conectividade (#163)

`data_pipeline/scripts/check_fontes.pl` (Perl executável) faz **um fetch real**
por cada uma das 11 fontes e classifica o resultado numa taxonomia fechada:
`ok`, `http_4xx`, `http_5xx`, `dns_morto`, `tls_invalido`, `sem_api`,
`auth_requerida`, `e_sic_pendente`.

- DNS decidido por **8.8.8.8** (Net::DNS), nunca pelo resolver local — regra do issue.
- Saída texto (legível) e `--json` (legível por máquina, com `dt`).
- `--check-diverg` compara o `host` do código com o `allowlist.yaml`.
- Primeiro relatório versionado: `data_pipeline/contrato_conectividade_20261007.json`.

**Medição real (2026-10-07):** 6 `ok`; CGU e OPENSTREETMAP `http_4xx`;
INEP/CENSO `http_5xx` (HTTP 500 na raiz); ANAC `sem_api` (404).

⚠️ **Divergência honesta com o issue:** o texto do #163 previa `INMET` como
`sem_api` e hosts antigos como `dns_morto`. A medição mostrou `portal.inmet.gov.br`
respondendo **200** hoje. O verificador reporta o que foi medido, não o que se
esperava medir — classificar INMET exigirá testar o *path* da API (o que o #171
já documentou como retirado), não a raiz do portal.

**Armadilhas encontradas:**
1. `LWP::UserAgent` sem `LWP::Protocol::https` devolve **HTTP 501** para URLs
   `https://` — nenhum teste acusou; todos os 11 "falhavam" com 501 até instalar
   o módulo. Um verificador de conectividade precisava do seu próprio transporte HTTPS.
2. Bug sutil de precedência Perl em `grep { } @lista ? 1 : 0` (ver §3).

### 1.2 PR #185 — Passo 3 da #177: remoção de `SchoolDerived.pm`

O gate `perl -c` (PR #181) ficou **vermelho em `main`** porque
`lib/EduMaps/Model/Rank/SchoolDerived.pm` faz `use` de 6 modelos de indicador
que não existem no repositório (`IdebAI`, `IdebAF`, `NotaMatematica`,
`NotaPortugues`, `Infra`, `Aprovacao`).

Decisão do developer (perguntada explicitamente, dado que a #177 prevê
"apagar **ou** implementar"): **apagar**. Evidência apresentada:

- zero referências a `SchoolDerived` em `lib/`, `t/`, `script/`;
- o ranking real usa `Rank/School.pm` + `RankingEscola`, com testes próprios
  (`t/02-models/school/rank.t`, `t/04-api/school/rank.t`);
- os 6 indicadores em `Model/Indicator/School/` são outro esquema
  (`IAI`, `IFS`, `IGE`, …), não os nomes que o módulo esperava.

Gate local: **233/234 → 234/234**. Commit separado da mudança de workflow,
conforme a nota da própria issue (não somar passo 3 ao passo 1 — a mesma
armadilha da #160).

### 1.3 PR #184 — Fase 1A do Bot Telegram (#183)

Issue #183 criado no ciclo com plano em **4 fases** (1A base → 1B persistência+API
→ 1C frontend → 1D integração), cada fase com PR próprio. Entregue na Fase 1A:

| Módulo | Papel |
|---|---|
| `EduMaps::Bots::Base` | classe base de canais (`enabled`, `can_send`, `can_receive`) |
| `EduMaps::Bots::Role::Sender` | Role/interface de envio (`send_text` requerido) |
| `EduMaps::Bots::Telegram` | concreta: `sendMessage` via `Mojo::UserAgent` |
| `EduMaps::Config::Bot` | config **isolada** do bot (separada da do EduMaps) |
| `EduMaps::Bots::Policy::Actions` | whitelist de 7 ações classificadas |

Bidirecional **por design, unidirecional por fase**: `can_receive` retorna 0 e
`receive_updates` aborta com erro explícito — não há webhook/long-polling na fase 1.

Testes: `t/05-tasks/bot_telegram.t` (10 asserts, PASS).

## 2. Decisões de design

1. **Roles com `Role::Tiny::With`** — em classes concretas
   (`use Mojo::Base 'ClasseBase'`), o `with` não é exportado pelo Mojo::Base;
   o padrão do próprio repositório (`Model/Pesquisa.pm`) é importar
   `Role::Tiny::With` explicitamente. Seguiu-se o padrão existente.
2. **Policy separada de Config** — `Policy::Actions` é a taxonomia (o que
   *pode* ser enviado); `Config::Bot` é o estado (o que *está* habilitado).
   Misturar os dois tornaria impossível adicionar um canal sem tocar na política.
3. **Falha explícita vs. silêncio** — `send_text` sem token/chat_id morre com
   `die`; sem lista de ações, nada é permitido. Nenhum caminho devolve sucesso falso.

## 3. Lições

1. **Um PR vermelho por causa pré-existente não se contorna — resolve-se o
   bloqueio em PR separado.** O PR #184 falhou no gate por causa da #177;
   a sequência correta foi: #185 (apagar código morto) → rebase → #184 verde.
   O `gh run rerun` **não resolve**: reusa o merge commit antigo, ainda com o
   arquivo apagado no histórico do merge. Rebase é o caminho.
2. **Precedência Perl: `grep { } @lista ? 1 : 0` não é o que parece.** O `?:`
   não fica fora do grep como se espera; dois testes falharam e o bug só cedeu
   com `scalar(grep { ... }) ? 1 : 0`. Padrão a usar em qualquer validação de lista.
3. **`PERL5LIB` no prefixo do `find` não passa ao `xargs`.** `VAR=x find ... | xargs`
   aplica a env só ao `find`; o gate local só fica verde com
   `find ... | env PERL5LIB=... xargs ... perl -c`.
4. **`prove -l` e `perl -Ilib` podem divergir** — durante o debug do teste do bot,
   `perl -Ilib` passou onde `prove -l` falhou (contexto de `require` dentro de
   `require_ok` após falha anterior em cascata). Valide sempre nos dois.
5. **Estado informal de fonte ≠ estado medido.** O issue #163 trouxe expectativas
   históricas (INMET morto) que a medição derrubou (200 na raiz). O verificador
   existe justamente para isso: reportar o presente, não a memória.

## 4. Estado ao fim do ciclo

| Item | Estado |
|---|---|
| #163 | resolvido (PR #182), fechado com comentário |
| #177 | passos 1 e 3 ✅; passo 2 (inventário de dependências) ⏳ — issue aberta |
| #183 | Fase 1A ✅ (PR #184); fases 1B/1C/1D ⏳ — issue aberta |
| CI `main` | verde (gate 234/234 + suíte) |
| Deploy | `rex prepare` + `deploy_backend_dev` executados; imagens locais `backend`/`minion` em rebuild |
