# Nota técnica 169: sessão do gestor com hash e leitura do Assistente só no curado

PR #341 (merge `ca81319`, 2026-11-05). Item solto das notas 166–168 (token de
sessão em texto puro).

## O problema

1. **Token de sessão legível no banco.** `clean.sessoes.token` guardava o
   bearer (uuid) como estava. Quem lesse a tabela podia usar qualquer sessão
   aberta (30 dias) para agir como o gestor.
2. **O Assistente do Censo podia ler a tabela de sessões.** Esse caminho
   tornava o problema 1 concreto: o papel `edumaps_leitor` executa o SQL que
   o modelo de linguagem gera a partir da pergunta do gestor.
   - O papel tinha `GRANT SELECT ON ALL TABLES IN SCHEMA clean`, mais
     `ALTER DEFAULT PRIVILEGES`, que estende o grant a toda tabela nova.
   - Ele lia `sessoes`, mas também `gestores` (hash de senha, CPF),
     `contatos`, os canais (telefones, tokens de QR), as conversas de outros
     gestores e as filas.
   - O validador `chat_validate_sql` só conferia o **schema**
     (`clean`/`analytics`). A whitelist de tabelas existia só no prompt e no
     `dicionario.yml`.
   - Uma pergunta manipulada (prompt injection) podia trazer um token válido.
     A conclusão vem da leitura do código e dos grants; o ataque não foi
     executado.

## Decisões

### Parte A: hash do token

- O token nasce no Perl: 32 bytes de `Crypt::URandom` em hex (64 chars,
  dentro do limite de 64 que `sessao_valida` já aplicava). O banco guarda
  `sha256_hex(token)`.
- **SHA-256 simples, sem HMAC nem Argon2.** O token tem 256 bits aleatórios e
  não há o que adivinhar, diferente da senha. Também não há segredo do app a
  rotacionar.
- **Change `sessoes_token_hash`:**
  - converte no lugar (`encode(sha256(convert_to(token,'UTF8')),'hex')`) e
    renomeia a coluna para `token_hash`;
  - adiciona o CHECK `^[0-9a-f]{64}$`, que impede gravar token em claro por
    engano;
  - as sessões existentes seguem válidas: o backend calcula o hash do uuid
    recebido com a mesma fórmula;
  - o revert apaga as sessões, porque o token não é recuperável.
- Frontend sem mudança: o cliente guarda e envia o mesmo bearer.

### Parte B: papel de leitura só no curado

- **Change `leitor_sem_tabelas_sensiveis`:**
  - aplica `REVOKE ALL` a 54 tabelas de `clean` (contas e sessões,
    `auth_falhas`, `senha_redefinicoes`, contatos, `canal_*`, `chat_*`,
    módulos do gestor, `minion_*`, `event_store`, `session_tracking`,
    `mojo_migrations`);
  - usa `to_regclass` para tolerar banco sem alguma delas;
  - o verify falha se alguma voltar a ser legível e se `censo_escolas`
    deixar de ser.
- **Validador do R:** `chat_validate_sql(sql, permitidas =
  chat_tabelas_permitidas())`. Toda referência de FROM/JOIN precisa estar na
  seção `tabelas` do `dicionario.yml`.
- **Duas camadas, com papéis diferentes.** O banco é a defesa de fato. O
  validador evita gastar uma consulta que o banco recusaria e mantém o
  modelo dentro do que foi curado.
- O R não lê nenhuma das tabelas retiradas (conferido por grep). O backend
  não usa o `edumaps_leitor`.
- Saiu do `dicionario.yml` uma dica que citava `clean.municipios_sp`, tabela
  fora da whitelist que o validador agora recusaria.

## Pendência conhecida

- `ALTER DEFAULT PRIVILEGES ... GRANT SELECT ON TABLES TO edumaps_leitor`
  continua valendo: **toda tabela nova em `clean` nasce legível pelo
  Assistente.**
  - Tabela nova com dado pessoal precisa entrar na lista por change nova.
  - O caminho limpo é inverter a regra: tirar o default e dar grant
    explícito nas tabelas do dicionário (mais as que o R lê fora do chat).
    Fica para um ciclo próprio.
- Tokens públicos de pesquisas (`gestor_pesquisas.token`) e de QR
  (`canal_qrcodes.token`) seguem em claro. São links públicos por desenho,
  agora fora do alcance do Assistente.

## Armadilha encontrada

- O papel `Gestores` ganhou um helper `_token_hash($token)`. O papel
  `SenhaRedefinicao` já tinha um método `_token_hash($self, $token)`.
- Os dois são compostos no modelo `Pesquisa`, e o Role::Tiny **não acusou
  conflito**: o primeiro aplicado venceu e o outro foi ignorado em silêncio.
- O e-mail de redefinição de senha passou a morrer com "Too many arguments";
  quem pegou foi o `senha_redefinicao.t`.
- Correção: renomear para `_sessao_token_hash`.
- **Lição:** em papéis compostos no mesmo modelo, funções auxiliares
  privadas também viram métodos. Nomear com o prefixo do papel.

## Testes e validação

- `t/04-api/gestor/sessao_hash.t`, com 5 subtestes:
  - banco com o hash;
  - o hash não serve de bearer;
  - logout;
  - uuid convertido segue válido;
  - CHECK de formato.
- testthat: 2113 testes, 0 falhas.
- Banco de CI do zero: deploy, verify, revert `--to auth_falhas_canais` (o
  grant volta) e redeploy, convertendo uma sessão uuid.
- Localhost (LXC fora até 2026-11-09):
  - login, painel, reuniões, sair e sessão antiga na SPA;
  - `permission denied` com `SET ROLE edumaps_leitor`;
  - validador no container `analytic`;
  - nenhuma pergunta enviada ao Assistente.
- Deploy LXC pendente: `deploy_db_dev` + backend + minion + analytics.
