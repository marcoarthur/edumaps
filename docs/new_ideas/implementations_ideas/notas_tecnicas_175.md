# Nota técnica 175: profile.t e event_logger.t independentes

PR #PR_NUM (2026-11-06). Os dois pendentes da nota 174, só testes, sem deploy.

## `school/profile.t` intermitente

- **Causa.** O teste usava o INEP 99999999 como escola inexistente. Os testes
  `gestor/contatos.t`, `gestor/documentos.t` e `pesquisa.t` criam essa mesma
  escola e só a apagam no `END`. Uma suíte interrompida (`pkill`, Ctrl-C)
  deixa a escola no banco, e o `profile.t` falha até um desses testes rodar
  de novo e limpar. O log da falha de 2026-11-05 confirma: a verificação que
  falhou foi "código inexistente retorna undef".
- **Correção.** O exemplo de escola inexistente passa a ser 00000001: não há
  UF 00, e nenhum teste cria esse código.
- **De carona.** A checagem das coordenadas era
  `number_gt(-90) && number_lt(90)`. O `&&` do Perl entre dois objetos de
  checagem devolve só o segundo, então o limite inferior nunca foi conferido
  (latitude -100 passava). Agora é `check_set(number_gt(...), number_lt(...))`,
  que exige os dois.

## `event_logger.t` apagava os jobs SIOPE

- **Causa.** O teste emite `city.details.requested` para São Paulo. O
  middleware `SiopeTask` do EventBus reage e chama `get_siope`, que enfileira
  um job `query_siope` na fila padrão; o minion local o executaria contra a
  rede. Para limpar, o `END` apagava **todos** os jobs `query_siope` do banco.
- **Correção.** O teste é do EventLogger, não do SIOPE: `get_siope` vira um
  stub dentro do teste, que só anota a chamada e devolve 0. Nenhum job é
  criado, e a limpeza global saiu.

## Validação

- `profile.t` com a escola 99999999 presente (sobra simulada): a versão
  antiga falha, a nova passa.
- Checagem das coordenadas: latitude -100 passava na antiga e falha na nova;
  10 passa nas duas.
- `event_logger.t` duas vezes: jobs `query_siope` iguais antes e depois; o
  log mostra o stub chamado ("Job #0").
- Banco limpo do CI: os dois passam.
- Suíte completa: só as falhas antigas; config idêntica.

## Fica para depois

Sem a limpeza global do `event_logger.t`, aparece um acúmulo que ela
escondia: cada suíte deixa ~5 jobs `query_siope` na fila `default` do banco
local, e o minion local os executa. Vêm de `05-tasks/siope.t`,
`gestor/finance_siope.t` e de testes de API que pedem detalhes de cidade
(o `SiopeTask` reage). O caminho é o mesmo da nota 167: fila própria por
teste (`minion_filas`) e limpeza só dos jobs criados.
