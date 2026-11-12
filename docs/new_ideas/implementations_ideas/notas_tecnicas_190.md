# Nota técnica 190: backend dos planos de gestão

PRs #377, #378 e #379 (2026-11-12). Fecham a #369, a #370 e a #373, do épico
#368. A interface (#371) segue em branch própria, aguardando validação visual.

## Contexto

O plano de negócios e o inventário de capacidades apontaram o acompanhamento
dos planos de gestão da escola como uma das lacunas mais importantes: o
gestor guarda o PDF do PPP ou do plano de ação em Documentos e planos, mas
não acompanha nada do que está escrito nele. A spec está em
`docs/specs/2026-11-11-planos-de-gestao.md` (RF-001 a RF-009).

Decisões do usuário que moldaram o desenho:

- **um modelo genérico com tipos** (plano de gestão, plano de ação, PPP,
  outro), em vez de um esquema por tipo de plano;
- **o gestor agora e a rede depois**: o papel da secretaria ficou na #375;
- **metas oficiais e manuais**: a meta pode seguir um indicador que o EduMaps
  já calcula ou um valor que o gestor informa.

## Estrutura (#369)

- Hierarquia plano → objetivos → metas e ações, mais uma tabela de auditoria
  com quem mudou o quê. Todas são internas, sem GRANT ao `edumaps_leitor`, e
  entraram na lista de sensíveis do teste de grants.
- Os CHECKs do banco cobrem o domínio de tipo, situação, sentido da meta,
  situação da ação e fonte de recurso. Um trigger garante que a meta ligada a
  uma ação pertence ao mesmo objetivo.
- **Situação do plano:** rascunho, vigente e encerrado. Um plano encerrado
  só aceita a reabertura. Arquivar é separado da situação, e o arquivado sai
  da lista padrão.
- **"Hoje" é o dia de Brasília** (`NOW() AT TIME ZONE 'America/Sao_Paulo'`),
  e não o do servidor: perto da meia-noite UTC, uma ação venceria um dia antes.
- **Ação atrasada é calculada**, não gravada: prazo vencido e ação não
  concluída nem cancelada.
- As regras de negócio vivem num role do `Model::Gestor`. Como os roles
  compostos em sequência sobrescrevem em silêncio as subs de mesmo nome, os
  helpers internos levam o prefixo `_pl_`: um `_num` colidiu com o de
  SimilarSchools.
- Os erros de regra saem como exceção com status HTTP, e o controller só a
  traduz. Um PUT parcial valida apenas os campos enviados.

## Indicadores e progresso (#370)

- Um catálogo (`analytics.indicadores_meta_catalogo`, 22 códigos: IDEB,
  matrículas, infraestrutura, IVET...) diz qual indicador pode virar meta
  oficial, com o sentido esperado. A view `analytics.escola_indicadores_meta`
  entrega a série de cada escola.
- **A meta oficial sincroniza sozinha:** ao ler o plano, as medições novas do
  indicador entram como oficiais (uma por meta e ano, `ON CONFLICT DO
  NOTHING`). Plano encerrado não sincroniza, para a fotografia final não
  mudar. A linha de base sugerida é o último valor disponível.
- O sentido da meta precisa ser coerente com a base e o alvo: alvo abaixo da
  base em meta de "aumentar" dá 400.
- **O progresso é uma função pura** (base, alvo, último valor e sentido), e o
  resumo do plano mostra "N de M metas medidas". **Meta sem medição não é 0%**
  (regra da #154): ela fica sem progresso e conta como não medida.

## Alertas de prazo (#373)

- Tarefa do Minion que se reagenda (o mesmo padrão dos canais de retenção),
  todo dia às 7h de Brasília. Ela junta, por gestor, as ações atrasadas e as
  que vencem em 7 dias nos planos vigentes com o alerta ligado.
- **Só envia se houver novidade:** o resumo leva uma assinatura sha256, e um
  envio por gestor por dia fica registrado (`clean.planos_alertas_envio`).
  Resumo igual ao anterior não sai de novo.
- O envio usa o canal de e-mail já existente. O alerta é desligável por plano.

## Armadilha de processo

O `gh pr merge --delete-branch` do PR-base **fechou** o PR empilhado em cima
dele, em vez de mudar a base para o `main`. A saída foi recriar a branch,
reabrir o PR e trocar a base. Nos merges seguintes, o PR de cima foi apontado
para o `main` antes do merge.

## Pendências

- #371 (interface): validação visual e PR.
- #372 (atas e documentos como evidência) e #374 (relatório de
  acompanhamento) completam o sprint. #375 e #376 ficam no backlog.
- O LXC recebe as três changes e a tarefa do Minion no próximo deploy
  completo.
