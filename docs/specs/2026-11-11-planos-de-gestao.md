# Especificação de Requisitos — Acompanhamento dos planos de gestão da escola

**Data:** 2026-11-11
**Autor:** engenharia de requisitos (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #368 (épico)
**Base:** plano de negócios e parecer de sprint de 10/10/2026
(`~/Documents/EduMaps/Business-Plan/`) + inventário de capacidades
(`docs/funcionalidades/`)

---

## 0. Sprint

| Ordem | Issue | Cobre |
|---|---|---|
| 1 | #369 — modelo de dados e API | RF-001, RF-002, RF-005 |
| 2 | #370 — indicadores oficiais, medições e progresso | RF-003, RF-004, RF-007 |
| 3 | #371 — interface do gestor | telas de RF-001/002/005, RF-007 |
| 4 (paralelo) | #372 — evidências (atas, documentos, notas) | RF-006 |
| 4 (paralelo) | #373 — alertas de prazo por e-mail | RF-008 |
| 4 (paralelo) | #374 — relatório de acompanhamento | RF-009 |

**Backlog (fora do sprint):** #375 (visão da rede, secretaria) e #376
(ingestão das taxas de rendimento e da distorção idade-série do INEP).

**Validação:** mostrar o editor (#371) a 2 ou 3 gestores antes de fechar o
sprint (§6).

---

## 1. Contexto e objetivo

### 1.1 A lacuna

O inventário tem a capacidade **"Documentos e planos escolares"**
(`gestor/documentos-planos.md`, 🟢): o gestor guarda o PPP e os planos como
**arquivos**, em pastas, com versões e tags. O plano fica arquivado, mas não
**acompanhado**: a plataforma não sabe quais são as metas, quais ações vencem
na semana, quem é responsável pelo quê, nem se a escola está avançando.

O plano de negócios aponta exatamente essa lacuna, sem nomeá-la como feature:

| Onde | O que diz |
|---|---|
| §4.2, P2 (secretarias, alvo principal) | o caso de valor é "governar com evidência — priorizar escolas, justificar investimentos, **acompanhar metas** e o uso do Fundeb" |
| §2.3 e P2 | o novo Fundeb (VAAR) e os órgãos de controle exigem que o município **demonstre** resultado: "quem tem evidência ganha orçamento" |
| §3.2, item 3 | o diferencial são os **dados transacionais próprios**, que "criam custo de troca (o histórico do gestor vive na plataforma)" |
| §4.2, P1 (gestor escolar) | é "o usuário que gera adoção. Sem ele usando, a licença da rede não renova" |
| parecer de sprint, §4 | alerta que o backlog tinha "**nenhuma** [issue] voltada ao cliente" |

O acompanhamento de planos junta essas quatro forças:
- é uso **recorrente** do gestor, porque um plano se acompanha toda semana;
- gera **dado transacional** que só existe na plataforma;
- produz a **evidência** de que a rede precisa para prestar contas;
- é o ponto de partida natural da visão de rede (P2).

### 1.2 Objetivo

Transformar o plano da escola de um arquivo num **objeto acompanhável**:

> **objetivos → metas** (com indicador, linha de base e alvo) **→ ações**
> (responsável, prazo, status, recurso) **→ evidências** (atas, documentos,
> notas)

Com:
- **progresso calculado**: metas ligadas a indicadores oficiais se atualizam
  sozinhas;
- **alertas de prazo**;
- um **relatório de acompanhamento** pronto para prestar contas à secretaria e
  ao conselho escolar.

### 1.3 Decisões do developer (2026-11-11)

1. **Modelo genérico com tipos:** plano de gestão do diretor, plano de ação
   (PDDE/PDE Escola), PPP e outro. A mesma estrutura serve a todos, sem um
   módulo por programa.
2. **Gestor agora, rede depois.** Este sprint é do gestor da escola (P1). A
   visão da secretaria, com os planos de várias escolas, fica numa issue
   própria: exige um papel de rede, que não existe (hoje `access_role` aceita
   só `gestor` e `admin`, e cada gestor tem uma escola em
   `gestores.cod_inep`).
3. **Metas oficiais + manuais.** A meta pode se ligar a um indicador oficial
   da plataforma, cujo valor atual se atualiza sozinho, ou ser manual, com o
   valor informado pelo gestor.
4. **Entram no sprint:** alertas de prazo, relatório de acompanhamento e
   vínculo das evidências com atas e documentos já existentes.

### 1.4 Atores

| Ator | Papel |
|---|---|
| **Gestor escolar** (P1) | cria, edita e acompanha os planos da sua escola |
| **Administrador** | suporte; vê os planos só para operação |
| Secretaria (P2) | **fora deste sprint** (issue própria) |
| Conselho escolar / comunidade | recebe o relatório impresso; sem acesso direto neste sprint |

---

## 2. Requisitos formais

### RF-001: Criar e manter planos da escola

**Ator:** gestor escolar
**Descrição:** O sistema deve permitir ao gestor criar, editar, encerrar e
arquivar planos da sua escola, cada um com tipo, título, período de vigência e
situação.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Tipos: `gestao` (plano de gestão do diretor), `acao` (plano de ação
  PDDE/PDE Escola), `ppp`, `outro`.
- [ ] Situação `rascunho → vigente → encerrado`; um plano encerrado fica só
  para leitura.
- [ ] Vários planos por escola, inclusive mais de um vigente (ex.: PPP + plano
  de ação PDDE).
- [ ] O plano pode apontar para o **arquivo** correspondente em Documentos
  (o PPP em PDF continua lá; o plano estruturado não o substitui).
- [ ] Um gestor só vê e edita planos da **própria** escola (403 nas demais).
- [ ] Toda alteração fica na auditoria do plano, com autor e data.

### RF-002: Objetivos e metas

**Ator:** gestor escolar
**Descrição:** O sistema deve permitir organizar o plano em objetivos e, em
cada objetivo, metas mensuráveis, com sentido (aumentar, reduzir ou manter),
linha de base, alvo e prazo.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Objetivo: título, descrição e ordem.
- [ ] Meta: descrição, unidade, sentido, linha de base, alvo e prazo.
- [ ] Meta sem linha de base ou sem alvo é aceita como **rascunho**, mas fica
  de fora do progresso (não vira 0%).

### RF-003: Metas ligadas a indicadores oficiais

**Ator:** gestor escolar
**Descrição:** O sistema deve oferecer um catálogo de indicadores oficiais da
escola. Uma meta ligada a um deles tem a linha de base sugerida pelo último
valor disponível e o valor atual atualizado sempre que a fonte é recarregada.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Catálogo inicial, só o que a plataforma já tem por escola e com série:
  - IDEB dos anos iniciais, dos anos finais e do ensino médio;
  - matrículas totais e por etapa;
  - itens de infraestrutura do Censo (biblioteca, laboratório, quadra,
    internet…), como sim/não;
  - IVET da escola.
- [ ] Cada valor mostra **ano de referência e fonte** (ex.: "IDEB 2023,
  INEP").
- [ ] Indicador sem valor para a escola aparece como **sem dado**, e não
  como 0 (#154).
- [ ] Ao recarregar a fonte, o valor atual muda e o histórico de medições
  guarda o anterior.

### RF-004: Metas manuais e medições

**Ator:** gestor escolar
**Descrição:** O sistema deve permitir metas sem indicador oficial, com o
valor informado pelo gestor em medições datadas.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Medição manual: data, valor e nota opcional.
- [ ] O progresso usa a medição mais recente.
- [ ] O histórico de medições aparece num gráfico simples da meta.

### RF-005: Ações com responsável, prazo e recurso

**Ator:** gestor escolar
**Descrição:** O sistema deve permitir cadastrar ações ligadas a uma meta ou a
um objetivo, com responsável, início, prazo, situação, custo previsto e fonte
do recurso.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Situação: `nao_iniciada`, `em_andamento`, `concluida` ou `cancelada`.
  **Atrasada** é derivada (prazo vencido e não concluída), não é gravada.
- [ ] Concluir grava a data de conclusão.
- [ ] Fonte do recurso: `pdde`, `fundeb`, `proprio`, `parceria` ou `outro`.
  O custo é opcional.
- [ ] Responsável em **texto livre**, como em `relacoes_tarefas` (a escola
  tem profissionais sem conta na plataforma).

### RF-006: Evidências ligadas a atas e documentos

**Ator:** gestor escolar
**Descrição:** O sistema deve permitir anexar evidências a uma ação ou meta:
uma reunião/ata já registrada, uma versão de documento já guardada, ou uma
nota de texto.
**Prioridade:** Importante
**Critérios de aceitação:**
- [ ] O vínculo aponta para a **versão** do documento e para a reunião. Não
  há reenvio de arquivo.
- [ ] A evidência mostra o título da reunião ou do documento, com link.
- [ ] Apagar a reunião ou o documento não apaga a evidência: ela fica
  marcada como "origem removida".

### RF-007: Painel de acompanhamento do plano

**Ator:** gestor escolar
**Descrição:** O sistema deve mostrar, por plano, o progresso de cada meta, as
ações por situação, as atrasadas e as que vencem nos próximos 7 dias.
**Prioridade:** Essencial
**Critérios de aceitação:**
- [ ] Progresso da meta = (atual − base) / (alvo − base), limitado a
  0–100%, respeitando o sentido. Sem base, alvo ou valor atual, mostra **sem
  medição**.
- [ ] Progresso do objetivo e do plano = média das metas medidas, sempre com
  a indicação "N de M metas medidas".
- [ ] Destaque para as ações atrasadas e as que vencem em 7 dias.
- [ ] O painel do gestor ganha um cartão "Planos" com o resumo dos planos
  vigentes.

### RF-008: Alertas de prazo

**Ator:** gestor escolar (destinatário)
**Descrição:** O sistema deve avisar o gestor, por e-mail, sobre as ações que
vencem nos próximos 7 dias e as que atrasaram, em no máximo um resumo por dia,
só quando houver novidade.
**Prioridade:** Importante
**Critérios de aceitação:**
- [ ] Tarefa Minion diária às 07:00 (America/Sao_Paulo), no padrão que se
  reagenda sozinho do `CanaisEnvio`.
- [ ] Sem novidade desde o último resumo, nada é enviado.
- [ ] O gestor desliga os alertas por plano, e o resumo traz o link para isso.
- [ ] O e-mail sai para o endereço da conta do gestor. Não envolve contatos
  da escola nem a comunidade.

### RF-009: Relatório de acompanhamento

**Ator:** gestor escolar
**Descrição:** O sistema deve gerar um relatório do plano, pronto para
imprimir ou salvar em PDF, para prestar contas à secretaria e ao conselho
escolar.
**Prioridade:** Importante
**Critérios de aceitação:**
- [ ] Conteúdo:
  - cabeçalho com a escola, o plano e o período;
  - progresso por objetivo e por meta, com a fonte e o ano dos indicadores
    oficiais;
  - ações concluídas, em andamento e atrasadas;
  - evidências;
  - data de emissão.
- [ ] Mesmo padrão dos relatórios existentes: visão de impressão e
  `window.print` (`RelatorioView`).
- [ ] O relatório não mostra dado pessoal além do responsável de cada ação,
  em texto livre.

---

## 3. Decomposição arquitetural

### 3.1 Motor analítico (R / views SQL)

- **RF-003:** view `analytics.escola_indicadores_meta`
  `(cod_inep, codigo, rotulo, unidade, ano, valor, fonte)`. Desempilha o que
  já existe (`clean.ideb_notas_escolas`, `clean.censo_matriculas`, a
  infraestrutura de `clean.censo_escolas`, `analytics.ivet_escola`), sem
  cálculo novo. É SQL, não R: o valor é lido, não modelado.
- **RF-007:** o progresso é aritmética simples e mora no backend. Não há
  modelo.
- **Fora do sprint (issue própria):** as taxas de rendimento do INEP
  (aprovação, reprovação, abandono) e a distorção idade-série por escola. São
  os indicadores mais usados em planos escolares e **não estão ingeridos**.
  Quando entrarem, viram códigos novos no catálogo, sem mudar o modelo.

### 3.2 Frontend (Svelte)

- `features/gestor/planos/`:
  - `PlanosPage` lista os planos;
  - `PlanoEditor` edita objetivos, metas e ações;
  - `PlanoAcompanhamento` mostra progresso, ações atrasadas e as próximas;
  - `MetaIndicadorPicker` escolhe no catálogo e mostra o valor e o ano;
  - `EvidenciaPicker` lista reuniões e versões de documento da escola;
  - `PlanoRelatorio` é a visão de impressão.
- Cartão "Planos" no painel do gestor.
- Testes vitest + MSW, no padrão das features do gestor (fixtures e handlers).
- Roteiro de ajuda guiada (`?tour`) para o primeiro plano.

### 3.3 Backend (Perl)

- **Migração Sqitch** com as tabelas da §4. São internas, com dado da gestão
  escolar e responsável em texto livre: **sem GRANT** ao `edumaps_leitor`, e
  os nomes entram na lista de sensíveis de `t/02-models/leitor_grants.t`.
- **Business role** `EduMaps::Roles::Business::Gestor::Planos` e rotas sob
  `/api/gestor/planos`, com a autorização por `cod_inep` do gestor que já
  existe.
- **Progresso** calculado no backend (RF-007), testado com metas de cada
  sentido e com metas sem medição.
- **Tarefa Minion** `planos_alertas` (RF-008).
- **Auditoria** no padrão de `escola_documentos_auditoria`.

---

## 4. Modelo de dados

```
clean.planos_gestao
  id, cod_inep, criado_por (gestor_id), tipo, titulo, inicio, fim,
  situacao (rascunho|vigente|encerrado), documento_id NULL -> escola_documentos,
  alertas_ativos bool, created_at, updated_at

clean.planos_objetivos      id, plano_id, titulo, descricao, ordem
clean.planos_metas          id, objetivo_id, descricao, unidade,
                            sentido (aumentar|reduzir|manter),
                            indicador_codigo NULL, linha_base, alvo, prazo
clean.planos_metas_medicoes id, meta_id, data_ref, valor,
                            origem (oficial|manual), ano_ref, nota, created_by
clean.planos_acoes          id, plano_id, objetivo_id NULL, meta_id NULL,
                            descricao, responsavel, inicio, prazo,
                            situacao, concluida_em, custo_previsto,
                            fonte_recurso
clean.planos_evidencias     id, acao_id NULL, meta_id NULL,
                            tipo (ata|documento|nota), reuniao_id NULL,
                            documento_versao_id NULL, texto NULL,
                            created_by, created_at
clean.planos_auditoria      id, plano_id, gestor_id, acao, detalhe jsonb,
                            created_at
clean.planos_alertas_envio  plano_id, data, assinatura   (idempotência do resumo)
```

- Uma ação pertence a uma meta **ou** a um objetivo (CHECK). O mesmo vale
  para a evidência, que pertence a uma ação ou a uma meta.
- `ON DELETE SET NULL` nas referências a reuniões e documentos (RF-006).
- O valor oficial é **gravado** como medição (`origem = oficial`) na
  recarga. O histórico, portanto, não depende de a fonte manter os anos
  anteriores.

## 5. Contratos de API (resumo)

| Método | Rota | Uso |
|---|---|---|
| GET/POST | `/api/gestor/planos` | listar / criar |
| GET/PUT/DELETE | `/api/gestor/planos/:id` | ler (com árvore e progresso) / editar / arquivar |
| POST/PUT/DELETE | `/api/gestor/planos/:id/objetivos[/:oid]` | objetivos |
| POST/PUT/DELETE | `/api/gestor/planos/:id/metas[/:mid]` | metas |
| POST | `/api/gestor/planos/:id/metas/:mid/medicoes` | medição manual |
| POST/PUT/DELETE | `/api/gestor/planos/:id/acoes[/:aid]` | ações |
| POST/DELETE | `/api/gestor/planos/:id/evidencias[/:eid]` | evidências |
| GET | `/api/gestor/indicadores-meta` | catálogo de indicadores oficiais da escola |
| GET | `/api/gestor/planos/:id/relatorio` | dados do relatório (RF-009) |

## 6. Riscos e suposições

- **[SUPOSIÇÃO] A estrutura objetivos → metas → ações cobre os planos reais.**
  Ela segue o formato comum do PDDE Interativo / PDE Escola e dos planos de
  gestão, mas **não foi validada com gestores**. O parecer de sprint recomenda
  3 a 5 conversas com gestores "antes de mais engenharia". **Recomendação:**
  mostrar o protótipo do editor (issue de frontend) a 2 ou 3 gestores antes de
  fechar o sprint.
- **Os indicadores oficiais são anuais** (IDEB a cada dois anos). Uma meta
  oficial mexe pouco dentro de um ano letivo, e o acompanhamento semanal vem
  das **ações** e das metas manuais. O painel deve deixar isso claro, com o
  ano de referência sempre visível.
- **Metas mais comuns sem indicador:** sem as taxas de rendimento (§3.1), a
  meta "reduzir o abandono" fica manual por enquanto.
- **LGPD:** o responsável em texto livre pode conter nome de servidor. O dado
  é interno (sem GRANT ao leitor), e o relatório mostra só o necessário. Não
  há dado de aluno.
- **Rede (P2) depois:** o modelo já guarda `cod_inep` e tipo, para a
  agregação por rede não exigir migração de dados.

## 7. Critérios de aceitação globais

- [ ] Um gestor cria um plano de ação com dois objetivos, três metas (uma
  ligada ao IDEB, duas manuais) e cinco ações, e vê o progresso calculado.
- [ ] Uma ação vencida aparece como atrasada no painel e no resumo do dia
  seguinte. Nenhum resumo sai sem novidade.
- [ ] O relatório impresso mostra a fonte e o ano de cada indicador oficial.
- [ ] Um gestor de outra escola recebe 403 em todas as rotas do plano.
- [ ] Ausência de dado nunca vira 0 (#154).
- [ ] Documentação: capacidade nova em `docs/funcionalidades/gestor/`, página
  de ajuda em `docs/ajuda/gestor/` e índice atualizado.
