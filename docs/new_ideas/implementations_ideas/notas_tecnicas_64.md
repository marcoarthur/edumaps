# Nota técnica — Verificação do histórico de conversas: `meta` jsonb

> Data: 2026-09-27 · Ciclo: backend (Perl/Mojolicious) · PR #100
> Origem: verificação do commit `9fd4a0e` (histórico de conversas), que
> havia sido entregue sem validação nem deploy.

## 1. Contexto

O commit `9fd4a0e` entregou o histórico de conversas do Assistente do
Censo (salvar, listar, buscar, detalhar, apagar, exportar). Ele foi
direto na `main`, sem PR, e provavelmente nunca foi implantado: o hook
de auto-deploy do repositório está quebrado (aborta na linha 32, antes
do `rex prepare`, por usar `$GIT_DIR` sem exportá-lo — `$GIT_DIR` não é
exportado para hooks).

Sem ambiente de teste, 6 pontos ficaram pendentes de verificação, e um
deles aparecia na `memory.md` como o de maior risco: **suspeita de
double-encoding do `meta` jsonb**.

O ciclo refez o ambiente (Perl via perlbrew, banco em Docker com as 58
migrations aplicadas) e verificou a lista. Resultado: **1 dos 6 pontos
foi um bug real** — e a suspeita inicial estava errada na causa.

## 2. O diagnóstico (e onde ele errou)

A hipótese registrada era: `save_conversa` fazia `encode_json($meta)` e
passava a **string** para `add_to_mensagens`; o Postgres fazia cast
text→jsonb e gravava um **escalar** (`"{...}"`); a API devolvia string
onde o frontend espera objeto.

**A hipótese estava errada na causa.** O cast text→jsonb do Postgres faz
*parse* do JSON — o banco sempre gravou **objeto** jsonb correto
(`jsonb_typeof(meta) = 'object'`). O duplo-encodamento nunca existiu.

O defeito era **exclusivamente na leitura**, e por um motivo bem mais
simples:

- O DBIx::Class 0.0828 **não tem inflator json/jsonb**. Sob
  `InflateColumn` só existem `DateTime.pm` e `File.pm`.
- O projeto **não usava `is_json`** em lugar nenhum (verificado por
  grep) — os outros jsonb vão por SQL cru.
- Sem inflator, o Postgres entrega a coluna **já serializada** e o
  `$m->meta` sai como **texto**. `render(json => ...)` então emitia
  `"meta": "{\"timestamp\":...}"`.

Ou seja: um **defeito de leitura**, rotulado como um defeito de escrita.
O caminho de escrita estava certo desde o começo — e continua certo.

### 2.1 A armadilha de diagnóstico

O sintoma (string onde esperava objeto) é idêntico nos dois casos, mas
as causas e os consertos são opostos: um exigiria remover o
`encode_json`, o outro exige **não** mexer na escrita e tratar a coluna.
Para distinguir bastou ler o banco:

```sql
SELECT jsonb_typeof(meta) FROM chat_mensagens WHERE meta IS NOT NULL;
-- 'object'  => escrita ok, o problema é o inflator
```

**Lição para o projeto: `jsonb` no DBIC daqui precisa de
inflate/deflate explícito. O default devolve string, e a falha é
silenciosa** — some a metainformação sem erro na tela, porque
`JSON.parse` de um array de mensagens funciona e o `.meta` simplesmente
não existe depois.

## 3. Decisões

| Ponto | Decisão | Alternativa descartada |
|---|---|---|
| Onde tratar o jsonb | `inflate_column` no **Result** (`ChatMensagem`) | `decode_json` no **controller**, no ponto de leitura |
| Por que no Result | O defeito é da camada de acesso a dados; tratar no controller espalha o defeito por todo consumidor futuro da coluna. Também é a forma idiomática do DBIC. | Simplificava o diff, mas não corrige a coluna para quem lê direto. |
| `inflate` apenas | — | Só `inflate` não resolve: sem `deflate` o DBIC estoura *"No deflator found"* toda vez que a coluna recebe uma ref — que é justamente a gravação. Os dois são obrigatórios. |
| Onde declarar o componente | Segundo `Mojo::Base` base: `use Mojo::Base 'DBIx::Class::Core', 'DBIx::Class::InflateColumn', -signatures;` | Via `load_components` o C3 resolve o nome do componente **relativo** ao pacote da classe e não acha. |
| `meta` inválido na entrada | **400** no controller | Deixar o Postgres recusar (500 com página de erro HTML) |
| `meta` como *string* JSON | **400** (antes 201) | Aceitar, preservando o comportamento antigo — mas aceitar a string é o que produzia o escalar jsonb silencioso. Mudança de contrato deliberada. |
| Escopo do `inflate_column` | Só `ChatMensagem.meta` | Aplicar a todos os jsonb — `OsmLanduse.tags` tem o mesmo problema, mas `City/Profile.pm` não expõe `tags`, então não há impacto de API hoje. Ampliar seria churn sem efeito. |

## 4. Implementação

### 4.1 `Schema/Result/ChatMensagem.pm`

```perl
use Mojo::Base 'DBIx::Class::Core', 'DBIx::Class::InflateColumn', -signatures;

__PACKAGE__->inflate_column(
  meta => {
    inflate => sub {
      my ($value) = @_;
      return $value if !defined $value || ref $value;
      my $decoded = eval { decode_json($value) };
      return defined $decoded ? $decoded : $value;
    },
    deflate => sub {
      my ($value) = @_;
      return $value if !defined $value || !ref $value;
      return encode_json($value);
    },
  }
);
```

Dois detalhes deliberados:

- O `inflate` **nunca estoura**: um valor gravado por fora do schema
  (SQL cru, não-JSON) faria o `decode_json` explodir **no meio da
  leitura**, convertendo um dado tolerável em erro do DBIC. O `eval` com
  devolução do valor cru preserva o comportamento anterior nesse caso.
- O `deflate` é **pass-through** para valores não-ref, para não
  reencodar o que já é string.

Detalhe de implementação que economizou tempo: os hooks `inflate`/
`deflate` são invocados por `DBIx::Class::Row` (linhas ~352, ~546,
~670-673), então **só o registrador precisa estar em `@ISA`** — não o
hook. Os inflators são chamados como `($value, $row)`.

### 4.2 `Roles/Business/Chat/Conversas.pm`

`save_conversa` deixou de fazer `encode_json` à mão: a serialização é
da coluna, e a role entrega a estrutura. O import de `Mojo::JSON`
ficou sem uso e saiu.

### 4.3 `Controller/Chat.pm`

Validação antes de persistir — `meta` fora de objeto não tem tradução
para jsonb, e o Postgres recusaria com `invalid input syntax for type
json`:

```perl
my $meta = $msg->{meta};
return $self->render(json => { error => 'meta deve ser um objeto JSON' }, status => 400)
  if defined $meta && ref $meta ne 'HASH';
```

## 5. Validação

- `t/04-api/chat/conversas.t`: 10 → **11 subtests, 11/11 PASS**.
- Suíte completa: **57 arquivos, 345 testes**. Os **mesmos 9 arquivos**
  falhando com as **mesmas contagens** de antes da mudança — nenhuma
  regressão. As falhas são pré-existentes (serviços externos: `R::Pipe`,
  Minion, analytics) ou falta de dados (`clean.osm_landuse` vazia).
- Sonda gravou e reliu o `meta`: banco `object`, API devolvendo `HASH`
  (antes `SCALAR`).

### 5.1 Um teste que media a coisa errada

O subtest de detalhe pegava "a conversa mais recente da lista"
(`$list->{items}[0]{id}`). Com o subtest novo de `meta` inválido fazendo
POST no mesmo recurso, a ordenação (`created_at DESC`) passou a devolver
outro registro e o teste **verificava a conversa errada — com sucesso**.
Passou a usar o **id devolvido pelo próprio POST** (`$CONV_ID`).

Vale como regra: quando um subtest cria dado que outro consome por
ordenação, o consumidor não pode confiar na ordenação.

## 6. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| `meta` gravado fora do schema (SQL cru) quebra a leitura | `inflate` com `eval` devolve o valor cru em vez de estourar |
| Contrato do POST mudou (`meta` como string: 201 → 400) | O frontend envia objeto (`chatApi.js` monta `{timestamp, sql, resultado, origem}`); o comportamento antigo era gravar escalar jsonb em silêncio. Documentado no PR. |
| Mesmo padrão latente em `OsmLanduse.tags` | Sem impacto hoje (`City/Profile.pm` não expõe `tags`). Registrado na `memory.md` como armadilha conhecida. |
| Impacto do bug 1 era **latente**, não visível | `getConversa(id)` existe em `chatApi.js` mas **nenhum código chama** — a página de histórico só lista, busca, apaga e exporta. O bug só apareceria ao ligar "abrir conversa salva". A página de histórico, por outro lado, **não tem teste nem mock MSW** — é a pendência de maior risco que sobrou. |

## 7. O que o ciclo **não** entregou

| Pendência | Motivo |
|---|---|
| **Deploy** | `ubatexu.lan` e `backend.edumaps` sem resposta. O passo de deploy do workflow não pôde ser cumprido; o hook segue desativado. |
| **Teste de frontend** | Rodam só no container `backend.edumaps`. |
| `per_page` sem clamp em `list_conversas` | Fora do escopo do conserto; registrado como backlog. |
| `/conversas/:id` malformado → 400 (convenção do projeto é 404) | Idem. |
| `save_conversa` devolve só `{id}`, comentário promete `{id, created_at}` | Idem. |
| `search`/`calendar`/`export` usam `storage->dbh` (DBI cru) com `LIMIT ?/OFFSET ?` sem tipo, em vez de `dbh_do` | Idem — divergência de padrão, funciona. |
| Warning do DBIC: *"Unable to properly collapse has_many in iterator mode"* (`Conversas.pm` linha 212) | Cosmético, mas indica sloppiness na query de detalhe. |

## 8. Ambiente (receita do banco local)

Para a verificação foi preciso um banco em **Docker**, já que
`ubatexu.lan` estava fora do ar.

- Base **`pgvector/pgvector:pg16-bookworm`** + `postgresql-16-postgis-3`
  + `postgresql-16-ogr-fdw`, espelhando o Rexfile (PG16 + PostGIS 3 +
  pgvector em Debian 12). A base anterior era
  `postgis/postgis:16-3.5` (bullseye).
- **`ca-certificates` é obrigatório**: a base `pgvector` não tem bundle
  de CA, e o GDAL falha com `error setting certificate file`.
- Porta em **`127.0.0.1:5432`** (só loopback, para o `prove -l` da
  máquina alcançar o banco).
- `sqitch deploy` completo: **exit 0**, 58 changes, `clean.escolas` com
  158.182 linhas.

**Migrations não podem ser editadas** — o sqitch valida checksum e um
arquivo já implantado quebraria. Todo problema de imagem foi resolvido no
`Dockerfile`.

### 8.1 O `/vsicurl` × Cloudflare

A migration `raw_countries` falhava com `unable to connect to data
source` — **com HTTP 200 no log do curl**. Causa: o
`cdn.jsdelivr.net` responde `Transfer-Encoding: chunked` sem
`Content-Length` conforme o edge, e o *write callback* do `vsicurl`
**recusa corpo chunked**. Nenhuma knob do GDAL resolveu de forma
confiável (`GDAL_HTTP_VERSION`, `GDAL_HTTP_HEADERS`, `CPL_VSIL_CURL_*`):
chegou a passar 3/3 e depois 0/6 **na mesma sessão**.

Solução adotada: espelho HTTPS **local e transitório** dentro do
container (nginx em 443 com `Content-Length` correto, CA própria no trust
store, `127.0.0.1 cdn.jsdelivr.net` no `/etc/hosts`). Montado por
`docker exec`, sem tocar no repositório nem na imagem; some quando o
container é recriado — só é preciso ao criar o banco do zero.

Detalhe que economizou tempo: `openssl s_server` **não serve** aqui
(single-connection, deadlock após a primeira requisição) — precisa de um
servidor HTTP de verdade para emitir `Content-Length`.

### 8.2 Recriar o cluster ao trocar a base da imagem

`pgdata` é do uid 999 (não apagável sem root — usar um container
throwaway com `rm -rf /data/*`) e um cluster `initdb` em bullseye
(collation 2.31) faz o Postgres **recusar `CREATE DATABASE`** no
bookworm (2.36). Trocar a base da imagem exige, portanto, **apagar e
reinicializar o cluster**.

## 9. Arquivos alterados

- `backend/lib/EduMaps/Schema/Result/ChatMensagem.pm` — `inflate_column`
- `backend/lib/EduMaps/Roles/Business/Chat/Conversas.pm` — sem `encode_json`
- `backend/lib/EduMaps/Controller/Chat.pm` — 400 para `meta` inválido
- `backend/t/04-api/chat/conversas.t` — 10 → 11 subtests
- `memory.md` — ambiente, diagnóstico corrigido e convenção do `inflate_column`

Fora do PR (modificados localmente, para review separado):
`.gitignore`, `db/Dockerfile`, `docker-compose.yml`.
