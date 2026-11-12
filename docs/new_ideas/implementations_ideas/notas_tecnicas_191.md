# Nota técnica 191: interface, evidências e relatório dos planos de gestão

PRs #380, #381 e #382 (2026-11-12). Fecham a #371, a #372 e a #374, do
épico #368, e completam o sprint. O
backend da estrutura, dos indicadores e dos alertas está na nota 190.

## Interface (#371)

- Duas telas: a lista de planos (`/gestor/planos`) e o plano
  (`/gestor/planos/:id`), onde o acompanhamento e a edição convivem. Não há
  uma tela separada de edição: o gestor ajusta a meta no mesmo lugar onde vê o
  andamento.
- **O "atrasada" vem do backend** (dia de Brasília). A tela só calcula "vence
  em 7 dias", com a data local, que serve apenas para destacar.
- Cada mudança recarrega o plano inteiro, porque o progresso do objetivo e do
  plano é recalculado no servidor. Assim a tela não duplica a regra.
- O histórico da meta é um SVG simples (`MetaHistorico`), sem biblioteca de
  gráficos: bastam alguns pontos por ano, com as linhas de base e de alvo.
- Os mocks do MSW têm **estado** (`resetPlanosMock`) e reproduzem as regras
  que a tela precisa mostrar (plano encerrado com 409, progresso por sentido,
  "N de M metas medidas"). Os testes exercitam o fluxo, não só a renderização.
- **Ajuda:** a página dos planos só aparecia no índice. Antes do PR, ela foi
  ligada ao painel do gestor, a documentos e planos e à ajuda guiada, e os dois
  roteiros entraram na tabela de roteiros.

## Evidências (#372)

- **A evidência aponta, não copia.** A ata aponta para a reunião, e o
  documento aponta para uma **versão** específica, não para o documento: uma
  versão nova depois não troca a prova do que foi apresentado.
- **Origem apagada não apaga a prova.** As referências usam `ON DELETE SET
  NULL`, e o título da origem é guardado no vínculo (`origem_titulo`). A
  evidência continua, com o título antigo, sem link e marcada "origem
  removida". Apagar o documento remove as versões em cascata, o que zera a
  referência pelo mesmo caminho.
- O CHECK do banco garante um dono só (ação **ou** meta) e que cada tipo use
  apenas a sua referência. Ele não exige a referência preenchida, porque ela
  pode virar NULL depois.
- **A posse da escola é conferida na origem:** reunião ou versão de documento
  de outra escola dá 403. Uma origem inexistente dá 400, e a duplicata (mesma
  origem na mesma ação ou meta) dá 409. Plano encerrado é só leitura também
  para as evidências.
- As origens do seletor vêm de uma rota própria, a
  `.../planos/evidencias/origens`. Ela traz as reuniões não canceladas e todas
  as versões de documento da escola, em vez de o seletor montar a lista com as
  rotas de reuniões e de documentos (uma chamada por documento).
- A auditoria do plano ganhou a entidade `evidencia`. A change nova troca o
  CHECK da tabela de auditoria, e o revert apaga essas linhas antes de
  restaurar o CHECK antigo.

## Relatório de acompanhamento (#374)

- **Uma rota de dados, sem gerar PDF no servidor.** `GET
  .../planos/:id/relatorio` reaproveita o `plano_detalhe` (mesma árvore e
  mesmo progresso) e acrescenta a escola, as ações agrupadas por situação e a
  data de emissão. O PDF sai pelo `window.print` do navegador, no mesmo layout
  `relatorio-imprimivel` (A4) do Assistente de Relatório. Não há biblioteca
  de PDF no backend, e a impressão foi conferida pelo usuário.
- **A atrasada tem precedência:** uma ação em andamento com prazo vencido vai
  para "Atrasadas", não para "Em andamento". Cada ação aparece num grupo só.
- **A emissão usa o horário de Brasília** (`NOW() AT TIME ZONE
  'America/Sao_Paulo'`), o mesmo critério do "hoje" dos planos.
- **Privacidade por construção:** o relatório só tem o que o plano tem. O
  único nome possível é o responsável da ação, texto livre. Um teste confere
  que o e-mail e o nome do gestor não aparecem na resposta.
- O 0% só aparece em meta **medida**: uma meta oficial cuja linha de base é o
  próprio último valor da escola começa em 0% legitimamente. Meta sem
  medição aparece como "Sem medição".

## Observações

- A suíte do backend rodada com `prove -j4` falha em quatro arquivos de canais
  e envios, que dividem estado no banco. Em série, eles passam. O CI roda em
  série. Depois de uma rodada em paralelo, o `canal_listas.t` falhou também
  em série, porque a configuração ficou gravada no banco de fixtures. O
  remédio foi recriar o banco (`ci_db.sh down` e `up`).
- A conta de teste local não tinha reuniões nem documentos. Para a validação,
  foram criados uma reunião (direto no banco, porque o cadastro pela API exige
  participantes) e um documento (pela API).

## Pendências

- Sprint concluído (#369–#374). O épico #368 segue aberto pelo backlog: #375
  (papel da rede) e #376 (rendimento INEP). A spec recomenda mostrar o editor
  a 2 ou 3 gestores antes de seguir.
- O LXC recebe as changes dos planos (`planos_gestao`, `planos_indicadores`,
  `planos_alertas`, `planos_evidencias`), o minion com a tarefa de alertas e
  o frontend no próximo deploy completo.
