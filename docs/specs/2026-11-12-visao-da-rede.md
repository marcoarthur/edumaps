# Especificação de Requisitos — Visão da rede sobre os planos de gestão

**Data:** 2026-11-12
**Autor:** engenharia de requisitos (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #375 (parte do épico #368)
**Base:** spec dos planos de gestão (`docs/specs/2026-11-11-planos-de-gestao.md`),
avaliações das personas P2 (`docs/personas/publicos/avaliacoes/`) e plano de
negócios (P2, secretaria municipal, alvo principal).

---

## 0. Sprint proposto

| Ordem | Issue | Cobre |
|---|---|---|
| 1 | #394 — Papel de rede: conta por convite, vínculo e autorização | RF-101, RF-102, RF-103 |
| 1 (paralelo) | #395 — Custo executado na ação e cargo de quem emite o relatório | RF-107, RF-108 |
| 2 | #396 — Painel da rede e relatório da escola pela rede | RF-104, RF-105 |
| 3 (paralelo) | #397 — Metas comparáveis por indicador | RF-106 |
| 3 (paralelo) | #398 — Custo por fonte na rede (previsto × executado) | RF-109 |

O 1 e o 1 (paralelo) não dependem um do outro. O 2 depende do papel de rede.
O custo na rede depende do custo executado e do painel.

---

## 1. Contexto e objetivo

### 1.1 A lacuna

O sprint #369–#374 deu à escola o plano acompanhável e o relatório para
prestar contas. A secretaria (P2) depende de cada diretor imprimir e mandar o
relatório: é a "planilha por escola" que ela quer evitar (P2-PG-01). O valor
que justifica o contrato da rede, a visão consolidada, não existe.

Hoje não há papel de rede: `access_role` aceita `gestor` (uma escola,
`gestores.cod_inep`) e `admin` (código de escola reservado 0). Toda rota do
gestor confere que a escola da URL é a da sessão (`_gestor_inep_ok`).

### 1.2 Objetivo

A secretaria acompanha os planos de **todas as escolas da sua rede**, acha as
que precisam de apoio (sem plano, atrasadas, sem andamento), compara metas que
seguem o mesmo indicador oficial e presta contas do recurso previsto e
executado, por fonte.

### 1.3 Decisões do developer (2026-11-12)

1. **Papel de rede por vínculo concedido pelo admin.** Novo `access_role`
   `rede` e uma tabela de vínculos: pessoa → (dependência, município). Uma
   pessoa pode ter mais de um vínculo (ex.: uma diretoria regional). O admin
   concede e revoga pelo painel de administração, com auditoria.
2. **A rede vê o agregado e o relatório de cada escola**, o mesmo que o
   diretor imprime, com o responsável em texto livre. **Só leitura:** a rede
   não edita o plano da escola.
3. **Primeira entrega completa:** painel da rede, metas comparáveis por
   indicador (P2-PG-03), custo por fonte na rede e custo executado (P2-PG-06).
4. **O relatório mostra o cargo de quem o emitiu** (P2-PG-04), sem o nome.
5. **Fora daqui:** órgãos de controle (P5). O posicionamento continua sem
   decisão no plano de negócios.

### 1.4 Atores

| Ator | O que faz |
|---|---|
| Técnico ou secretário da rede (P2) | acompanha os planos das escolas da rede, só leitura |
| Administrador da instalação | cria a conta de rede, concede e revoga vínculos |
| Gestor escolar (P1) | registra o custo executado das ações; o relatório leva o cargo dele |

---

## 2. Requisitos formais

### RF-101: Conta de rede por convite

**Ator:** administrador
**Descrição:** O admin cria uma conta de rede com nome, e-mail e cargo. O
sistema gera um **link de convite de uso único**, válido por 7 dias, que o
admin copia e envia por fora (o mesmo padrão de "convite copiável" das
reuniões). Ao abrir o link, a pessoa define a própria senha. Ninguém além
dela conhece a senha.
**Critérios de aceitação:**
- [ ] O token do convite é guardado só como hash e vale uma vez.
- [ ] Convite vencido ou já usado: mensagem clara e pedido de novo convite ao
  admin.
- [ ] E-mail já usado por outra conta: o admin é avisado, e nada é criado.
- [ ] O admin pode gerar um convite novo, e o anterior deixa de valer.

### RF-102: Vínculo com a rede

**Ator:** administrador
**Descrição:** O admin liga a conta de rede a uma ou mais redes: dependência
(municipal ou estadual) e município. A escola pertence à rede quando, no
Censo mais recente, `tp_dependencia` e `co_municipio` batem com o vínculo.
**Critérios de aceitação:**
- [ ] Conceder e revogar ficam na auditoria (quem, quando, qual rede).
- [ ] Revogar tira o acesso na hora (as sessões seguem válidas, mas a
  autorização é conferida a cada pedido).
- [ ] Federal e privada não são redes concedíveis aqui.

### RF-103: Autorização da rede

**Descrição:** As rotas da rede (`/api/rede/...`) exigem sessão com papel
`rede` e conferem, a cada pedido, que a escola pedida pertence a um vínculo
ativo. Escola fora da rede: **403**. A conta de rede não acessa as rotas de
escrita do gestor.
**Critérios de aceitação:**
- [ ] Teste de autorização: escola de outro município ou de outra
  dependência dá 403; gestor de escola e admin sem vínculo não entram nas
  rotas da rede.
- [ ] Nenhuma rota da rede altera dado de plano.

### RF-104: Painel da rede

**Ator:** rede
**Descrição:** Uma tela lista **todas as escolas da rede** com:
- o plano vigente (ou "sem plano");
- o andamento das metas, com "N de M metas medidas";
- as ações atrasadas e as que vencem em 7 dias;
- as evidências;
- a última atualização do plano.

Há filtro e ordenação para achar quem precisa de apoio (sem plano, mais
atrasadas, sem andamento).
**Critérios de aceitação:**
- [ ] Escola sem plano aparece **na lista**, marcada "sem plano", e não some.
- [ ] Andamento sem metas medidas aparece como texto, nunca como 0% (#154).
- [ ] Totais da rede no topo: escolas, com plano vigente, sem plano, ações
  atrasadas.
- [ ] Responde em menos de 2 s para uma rede de 300 escolas (consulta
  agregada, sem N+1).

### RF-105: Relatório da escola pela rede

**Descrição:** Do painel, a rede abre o **relatório de acompanhamento** de
cada escola (RF-009 do sprint anterior), em modo só leitura, com impressão
em A4.
**Critérios de aceitação:**
- [ ] O mesmo conteúdo que o diretor imprime, com o responsável em texto livre.
- [ ] Escola fora da rede: 403.
- [ ] Sem nenhum botão de edição.

### RF-106: Metas comparáveis por indicador (P2-PG-03)

**Descrição:** Na visão da rede, as metas que seguem o **mesmo indicador do
catálogo** se consolidam. Por indicador, a tela mostra:
- quantas escolas têm meta;
- quantas já mediram;
- o andamento médio;
- a lista das escolas.

Metas manuais não entram na comparação; a tela mostra quantas existem. Na
tela da escola, ao criar uma meta manual cuja descrição lembra um indicador do
catálogo, a tela sugere o indicador.
**Critérios de aceitação:**
- [ ] A consolidação usa só metas oficiais; a base ajustada pela escola
  (P2-PG-05) aparece marcada.
- [ ] A sugestão na tela da escola não bloqueia: a escola pode manter a meta
  manual.

### RF-107: Custo executado na ação (P2-PG-06)

**Ator:** gestor escolar
**Descrição:** A ação ganha **valor executado** e **data da execução**. O
relatório mostra previsto × executado por fonte de recurso.
**Critérios de aceitação:**
- [ ] Executado sem valor não é R$ 0 (mesma regra do custo previsto).
- [ ] Ação cancelada fica fora das somas (como no previsto).
- [ ] Auditoria registra a mudança.

### RF-108: Cargo de quem emitiu o relatório (P2-PG-04)

**Descrição:** O relatório mostra o **cargo** de quem o emitiu (do cadastro do
gestor ou da conta de rede), sem o nome. Sem cargo cadastrado, não mostra nada.
**Critérios de aceitação:**
- [ ] Nenhum nome de pessoa a mais no relatório.

### RF-109: Custo por fonte na rede

**Descrição:** O painel da rede mostra previsto × executado por fonte de
recurso, **por escola e consolidado**, com o número de ações sem custo
informado.
**Critérios de aceitação:**
- [ ] Mesmas regras do RF-107 e do relatório da escola.
- [ ] Soma só de planos vigentes (encerrados em linha separada).

---

## 3. Decomposição arquitetural

### 3.1 Banco (Sqitch, changes novas)

- `access_role` aceita `rede` (troca do CHECK).
- `clean.rede_vinculos` (gestor_id, tp_dependencia, co_municipio,
  concedido_por, concedido_em, revogado_por, revogado_em). Um vínculo ativo
  por (gestor, dependência, município).
- `clean.rede_convites` (gestor_id, token_hash, expira_em, usado_em,
  criado_por).
- `clean.planos_acoes`: `custo_executado numeric`, `executado_em date`.
- Escolas da rede: view ou função sobre `clean.censo_escolas` do ano mais
  recente (`tp_dependencia`, `co_municipio`).
- Tudo interno, sem GRANT ao `edumaps_leitor`; os nomes entram na lista de
  sensíveis do `leitor_grants.t`.

### 3.2 Backend (Perl)

- Role `Gestor::Rede` (helpers com prefixo próprio, por causa da colisão
  silenciosa de roles), controller `Rede` e plugin de rotas `/api/rede`.
- `_require_rede` (sessão com papel `rede`) e `_rede_escola_ok` (escola em
  vínculo ativo, conferido a cada pedido).
- Admin: criar conta de rede, gerar convite, conceder e revogar vínculo,
  listar contas e vínculos.
- Público: abrir o convite e definir a senha (rota sem sessão, com limite de
  tentativas).
- Painel em **uma consulta agregada** por rede (planos vigentes, contagens,
  progresso por meta oficial calculado no SQL ou em lote).

### 3.3 Frontend (Svelte)

- Admin: seção "Contas de rede" (criar, copiar convite, vínculos).
- `/rede/convite/:token` (pública, sem menu): definir a senha.
- `/rede` (painel), `/rede/escolas/:inep/planos/:id/relatorio` (relatório
  só leitura, reaproveitando `PlanoRelatorio`), `/rede/indicadores`.
- Gestor: campos de custo executado na ação; sugestão de indicador na meta
  manual.
- Menu: "Rede" para quem tem o papel; o login leva ao painel da rede.

---

## 4. Riscos e suposições

- **[SUPOSIÇÃO] Município + dependência basta para a rede municipal.** A rede
  estadual se organiza por diretorias regionais; aqui ela é modelada como
  vários vínculos por município. Se não servir, um vínculo por regional é uma
  change nova.
- **A escola muda de rede no Censo seguinte** (municipalização, por exemplo):
  o vínculo segue o Censo mais recente, então o acesso acompanha.
- **Convite copiado e repassado:** vale uma vez e vence em 7 dias. O admin
  revoga a conta se o link vazar.
- **Desempenho do painel:** o progresso por meta hoje é calculado em Perl por
  plano. Para 300 escolas, calcular em lote é obrigatório (RF-104).
- **Privacidade:** o responsável em texto livre vai para a rede, como já vai
  no papel. A ajuda do gestor deve dizer que a secretaria vê o relatório.

---

## 5. Critérios de aceitação globais

- [ ] Testes de API para cada RF, com a autorização (403 por município, por
  dependência, por vínculo revogado).
- [ ] Testes de tela para o painel, o relatório pela rede e o convite.
- [ ] Ajuda: página nova em `docs/ajuda/` para a rede, e a do gestor
  atualizada (a secretaria vê o relatório; custo executado).
- [ ] Ficha nova da funcionalidade em `docs/funcionalidades/`.
- [ ] Avaliação da P2 ao fim, e fechamento do ciclo por público.
