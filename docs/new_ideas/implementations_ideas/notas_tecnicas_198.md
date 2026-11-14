# Nota técnica 198: POST com chave não cria duas vezes (#416)

Complemento do PR #415 (nota 197). Entregue no PR #417 (merge `8229bd2`).

## O problema

O #415 travou o botão na interface: o segundo clique é ignorado até a
resposta. Sobrava o servidor. Se o primeiro POST chegasse e a resposta se
perdesse (tempo esgotado, rede caindo), o novo clique criava uma réplica.

## Decisões

1. **Chave de idempotência, não bloqueio por conteúdo.** O bloqueio por
   conteúdo pegaria também duas abas, mas barraria repetições legítimas (duas
   medições iguais no mesmo dia) e exigiria regra por rota. A chave não cobre
   duas abas, e isso ficou registrado no PR.
2. **Uma entrada só:** o helper `idempotencia_inicio` fecha os quatro portões
   de login (`_require_sessao`, `_require_rede`, `_require_admin` e o de
   pesquisas), depois de o gestor estar no stash. Todo POST autenticado fica
   coberto sem tocar nas rotas.
3. **Estados da chave**, em `clean.idempotencia` (por conta):

   | Situação | Resposta |
   |---|---|
   | chave nova | grava "em andamento" e segue |
   | concluída, mesma rota e mesmo corpo | a resposta guardada, `Idempotent-Replayed: true` |
   | mesma chave, outra rota ou outro corpo | 422 (nunca devolve, calada, outro envio) |
   | em andamento | 409; com mais de 2 min, conta como abandonada |
   | pedido que falhou | a chave é apagada, a nova tentativa cria |

4. **Validade de 10 min, sem job:** as chaves vencidas da conta são apagadas a
   cada envio novo.
5. **Detalhes que o teste pegou ou que a medição pediu:**
   - o corpo do multipart não entra no hash: o navegador sorteia o boundary a
     cada envio, e o hash nunca bateria;
   - a resposta guardada é texto (UTF-8 decodificado) e volta codificada no
     replay; o teste confere acentos e travessão;
   - falha do banco na trava não derruba o envio: segue sem a trava, como sem
     o cabeçalho.
6. **Dado pessoal:** a resposta pode ter contato. A tabela não tem GRANT ao
   `edumaps_leitor` e está na lista de sensíveis do `leitor_grants.t`.
7. **Frontend:** `criarEnvio()` gera a chave; o `client.js` a põe só no
   **primeiro POST síncrono** do handler (`comChaveDeEnvio`). Um segundo POST
   no mesmo envio levaria a mesma chave a outra rota e tomaria 422. A chave é
   mantida depois de erro de rede ou 5xx (a nova tentativa a repete) e trocada
   depois de 2xx ou 422.

## Testes

- `t/04-api/gestor/idempotencia.t`: 18 asserções em 10 cenários (replay,
  chaves diferentes, chave por conta, 422 por rota e por corpo, 409 e
  abandono, falha libera, validade, formato, acentos).
- vitest: chave repetida após falha de rede e 503, trocada após 201 e 422, só
  o primeiro POST; o cabeçalho sai na tela do plano. Suíte 1246.
- CI do PR verde (Perl com `sqitch verify`, R, vitest, build).
- Smoke local via nginx: o segundo POST com a mesma chave voltou 201 com o
  mesmo id e `Idempotent-Replayed: true`; outro corpo, 422.

## Observação sobre a suíte local

A suíte Perl com `prove -j4` falhou em 7 arquivos de canais, por concorrência
no banco compartilhado; em série, os 7 passam. O CI roda em série.

## Deploy

Entra no deploy do LXC de 2026-11-16: `deploy_db_dev` (change
`idempotencia`), `deploy_backend_dev` e `deploy_frontend_dev`.
