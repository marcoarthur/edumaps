# Ciclo 2026-11-12: planos de gestão acompanháveis

- **Período:** 2026-11-11 (spec e issues) a 2026-11-12 (último merge).
- **Épico:** #368. Issues fechadas: #369 a #374 (sprint), #383 a #385
  (achados da avaliação), #392 (página "Sobre o Refactor").
- **PRs:** #377 a #382 (sprint), #386 a #391 (avaliação e reavaliação das
  personas), #393 (remoção do "Sobre o Refactor").
- **Avaliações:** [primeira](../avaliacoes/2026-11-12-planos-de-gestao.md) e
  [reavaliação](../avaliacoes/2026-11-12-planos-de-gestao-reavaliacao.md),
  pelas personas P1 e P2.
- **Engenharia:** notas técnicas 190, 191 e 192.

## Resumo

O plano da escola deixou de ser só um arquivo guardado e passou a ser
**acompanhado**: objetivos, metas medidas (por indicador oficial ou pela
escola), ações com responsável e prazo, evidências, alertas por e-mail e um
relatório para prestar contas. A avaliação das personas no meio do ciclo
mudou o rumo das últimas entregas: a barreira que fazia a diretora desistir
não aparecia em nenhum teste.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria com ressalvas → **adotaria**.

**O que mudou para ela:**

- Um lugar para o **plano de ação, o plano de gestão ou o PPP** com objetivos,
  metas e ações, a partir do painel do gestor.
- **O que está atrasado e o que vence na semana** aparece no topo do plano, e
  um **e-mail diário** avisa só quando há novidade.
- **Metas com indicador oficial** (IDEB, matrículas, infraestrutura, IVET) se
  atualizam sozinhas, com a fonte e o ano. As metas da escola recebem
  medições à mão. Meta sem medição aparece como **"Sem medição"**, nunca
  como 0%.
- **Evidências** sem reenviar arquivo: a ata da reunião, a versão do documento
  ou uma nota.
- **Relatório pronto para imprimir** ou salvar em PDF, para o conselho escolar.
- Depois da avaliação:
  - **corrigir** ação, meta e objetivo sem perder as evidências;
  - o **PDF do plano** ligado à página dele;
  - o gráfico da meta com anos e legenda;
  - textos e unidades corretos ("12%");
  - letra legível.

**Impacto para ela:** responde na própria plataforma "o que está atrasado e
quem é o responsável?" e "como mostro ao conselho o que fizemos?", sem
planilha à parte. O primeiro erro de digitação deixou de ser motivo de
desistência.

**Pendente:**

- Confirmar com 2 ou 3 diretoras reais se objetivos → metas → ações cabe no
  plano delas.
- A reavaliação não abriu barreira nova para ela.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria com ressalvas, quando a #375 existir → **mantido**.

**O que mudou para ele:**

- O **relatório de acompanhamento** de cada escola tem:
  - a fonte e o ano de cada indicador oficial e "N de M metas medidas";
  - o custo previsto **por fonte de recurso** (PDDE, Fundeb...) com o total, sem
    contar ação sem custo como R$ 0;
  - as ações por situação e as evidências;
  - o arquivo do plano;
  - a data de emissão.
- Uma **linha de base ajustada pela escola** numa meta oficial aparece marcada,
  com o valor oficial ao lado, na tela e no relatório. O andamento não pode
  mais parecer maior sem que ele saiba.

**Impacto para ele:** o relatório que um diretor entrega passa a aguentar a
pergunta "de onde veio esse número?", e a adoção pelas escolas sustenta a
renovação na rede. O valor que justifica o contrato dele, a visão consolidada
da rede, ainda não existe.

**Pendente (todos na #375):**

- visão da rede (P2-PG-01);
- metas comparáveis entre escolas (P2-PG-03);
- cargo de quem emitiu o relatório (P2-PG-04);
- custo **executado**, e não só o previsto (P2-PG-06).

## P3 — Rede privada (mantenedor)

**Sem impacto direto neste ciclo.** O plano acompanhável segue o formato da
escola pública (PDDE, PDE Escola, PPP), e não é o que o perfil usa
(captação, benchmark de mercado). Não houve avaliação. Reavaliar se a rede
privada pedir acompanhamento de metas por unidade.

## P4 — Academia (pesquisadora)

**Sem impacto direto neste ciclo.** O plano é dado interno da escola, sem
agregação nem exportação para pesquisa. Não houve avaliação.

## P5 — Órgãos de controle e conselhos

**Sem impacto direto neste ciclo.** O conselho e o tribunal recebem o
relatório **do município**, mas não usam a ferramenta, e o posicionamento
sobre vender ao fiscal segue sem decisão (plano de negócios). Não houve
avaliação. Fica registrado que a marca de "base ajustada pela escola"
(P2-PG-05) protege também quem recebe o relatório.

## P6 — Terceiro setor e jornalismo de dados

**Sem impacto direto neste ciclo.** O plano não é público, e o perfil usa
dado aberto e citável. Não houve avaliação.

## Para todos os públicos

- Saiu a página **"Sobre o Refactor"** e o link dela no menu (#392). O
  endereço antigo `/about` leva à página inicial. O menu ficou só com o que
  é produto.

## O que este ciclo ensinou

- A avaliação pelas personas achou o que os testes não achavam: uma barreira
  de uso (não poder corrigir), não um defeito. Ela entra como passo do fim de
  cada funcionalidade que muda o que um público vê.
- A primeira avaliação gerou 3 issues e uma correção; a reavaliação, 2
  correções pequenas e uma decisão de produto (a base ajustada). O ciclo
  fechou com a P1 adotando e a P2 dependente da #375.
