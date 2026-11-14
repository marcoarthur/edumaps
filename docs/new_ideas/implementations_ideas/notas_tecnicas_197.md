# Nota técnica 197: botão de salvar trava até a resposta (PR #415)

Achado do developer no teste local da criação de metas e ações do plano.
Entregue no PR #415 (merge `2ffdf41`), sem issue.

## O problema

Entre o clique em salvar e o toast de confirmação, o botão continuava
clicável. Um segundo clique mandava outro POST e criava uma réplica.

No plano, todas as mudanças passam por `mudar()`, que esperava a API sem
marcar nada como ocupado; os botões não tinham `disabled`. A varredura dos
botões de ação da SPA mostrou que só 26 de 85 tinham alguma trava. O mesmo
padrão aparecia em Inventário, Relações, Contatos, Listas, Documentos,
Pesquisa (finalizar), Reuniões e Contas da rede ("Novo convite" gerava convite
em dobro).

## Decisões

1. **Uma peça só: `shared/utils/envio.svelte.js`.** `criarEnvio()` devolve
   `ocupado` (estado reativo), `rodar(fn, ...args)` e `travar(fn)`.
   - O guarda é **síncrono**: o segundo clique é ignorado na hora, antes de o
     `disabled` chegar ao DOM. Também cobre o Enter num formulário.
   - A trava solta no `finally`: depois de um erro, dá para tentar de novo.
   - Uma trava por tela, não por botão: enquanto uma mudança está em curso,
     as outras da mesma tela esperam. No plano isso é desejado, porque toda
     mudança recarrega o plano inteiro.
2. **O botão mostra que está ocupado:** fica desabilitado e troca o rótulo
   para "Salvando…", "Criando…" ou "Publicando…".
3. **Telas com trava própria não mudaram:** criar plano, editor de envios,
   configurações, relatório salvo, diálogos com `ocupado`. Os editores da
   árvore de Documentos fecham no primeiro clique; a trava ficou no
   `onAcao` da página, só para as ações que gravam.
4. **Sem trava no backend neste ciclo.** Ela protegeria contra rede lenta e
   dois navegadores abertos, mas é outra decisão (issue só se o developer
   pedir).

## Testes

- `envio.test.js`: segundo clique ignorado; trava solta depois de erro;
  travas independentes não se bloqueiam.
- `PlanoDetailPage.test.js`: duplo clique em "Salvar meta" e "Salvar ação"
  gera **um** POST, contado no `server.events` do MSW. Medição negativa: sem
  a trava, os dois testes falham com 2 POSTs.
- Suíte: 141 arquivos, 1243 testes; `vite build` ok. CI do PR verde.

## Regra daqui em diante

Todo botão que grava usa `criarEnvio()`: `disabled={envio.ocupado}` e o
handler embrulhado em `envio.travar(...)`.
