# Nota técnica 164 — cadastro do gestor só cria conta; pesquisas com sessão

PR #333 (merge `fa051d5`, 2026-11-02). Achado durante a escrita da ajuda do
gestor (nota 163), ao conferir o cadastro contra o código.

## O problema

O módulo de pesquisas nasceu na "fase 1" sem login: o e-mail era a identidade.
O cadastro (`/perfil`) fazia **upsert por e-mail**, e o assistente de pesquisa
reenviava o cadastro a cada uso. Quando o login (fase 2) chegou, o cadastro
virou a porta de entrada de todas as contas, mas continuou anônimo e
continuou fazendo upsert — e a gestão das pesquisas continuou anônima,
recebendo `gestor_id` do navegador. Os resultados foram a única parte
protegida.

## Decisões

- **Rota anônima nunca altera conta existente.** `cadastrar_gestor` é
  `INSERT ... ON CONFLICT DO NOTHING`; e-mail existente responde 409 antes,
  com mensagem que orienta a entrar. Revela que o e-mail existe — custo aceito
  pela mensagem útil; o login segue sem revelar.
- **A trava está no banco, não só no código.** Índice único em `lower(email)`
  (change `gestores_email_unico_sem_caixa`): "Fulano@x" e "fulano@x" são a
  mesma conta. Pré-condição medida antes (nenhuma duplicata por caixa nas duas
  bases). Login e checagem também passaram a `lower()`.
- **Escopo vem da sessão.** Pesquisas: `gestor_id` do corpo é ignorado; escola
  = escola da sessão; pesquisa de outra escola é **404** (não revela que
  existe); lista de outra escola é 403, como os resultados.
- **Sem passo de cadastro no assistente.** A página carrega `/me`; sem sessão,
  o mesmo `GestorLoginCard` das reuniões. A identidade antiga por escola no
  `localStorage` (nome, e-mail, telefone) é apagada em `restaurarSessao`.

## Verificação

- Testes que afirmavam o comportamento vulnerável ("mesmo e-mail reutiliza o
  gestor", "upsert/re-login continua permitido") foram invertidos; o novo
  `pesquisa.t` falha sem a correção.
- Nas bases: as contas alteradas após criadas e o admin com escola eram de
  teste (seed, dev, e2e) — sem sinal de abuso.
- Validação no LXC com conta descartável pela API, removida no fim.

## Lição

O detalhe do achado foi escrito em `memory.md` e na nota 163 num repositório
**público** antes da correção (corrigido no commit `7966f8c`; o histórico
guarda). Achado de segurança aberto se registra sem rota nem mecanismo até a
correção sair.

## Pendências

- ~~#334 — hash de senha lento~~ — PR #337 (nota 165).
- ~~#335 — limite de tentativas de login~~ — PR #338 (nota 166).
- ~~#336 — "esqueci minha senha"~~ — PR #339 (nota 167).
