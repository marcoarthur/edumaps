---
name: edumaps-requirements
description: "Engenheiro de sistemas para o projeto EduMaps. Conduz entrevistas com usuários (gestores, professores, coordenadores, administradores), traduz requisitos vagos em requisitos formais, decompõe-nos nas três camadas do sistema (Motor Analítico, Frontend Svelte, Backend Perl) e cria um issue no GitHub com a especificação completa em Markdown. Use quando o usuário mencionar EduMaps, requisitos escolares, gestão escolar, análise de dados educacionais, ou pedir para especificar funcionalidades do EduMaps."
license: MIT
compatibility: ["opencode"]
metadata:
  author: "EduMaps Team"
  version: "1.0.0"
  repo: "marcoarthur/edumaps"
---

# Skill: Especificação de Requisitos do EduMaps

> **Modo de uso:** esta skill deve ser utilizada **somente no modo planning** —
> nunca no modo build. Em modo build, o agente deve cuidar de execução/
> implementação, não de produção de especificações nem de issues de requisitos.

## Visão Geral

Esta skill transforma o agente num **engenheiro de sistemas responsável pela engenharia de requisitos do EduMaps**. O agente escuta requisitos vagos de usuários escolares, faz perguntas de clarificação quando necessário, traduz tudo em requisitos formais e produz uma especificação técnica decomposta nas **três camadas arquiteturais** do sistema:

| Camada | Tecnologia | Responsabilidade |
|--------|-----------|------------------|
| **Motor Analítico** | (definir com o usuário — ex.: Python/R/Julia) | Processamento de dados educacionais, métricas, relatórios analíticos |
| **Frontend** | Svelte | Interface do usuário, dashboards, visualizações, interação |
| **Backend** | Perl | API, lógica de negócio, persistência, autenticação, integração |

Após a especificação estar madura, o agente **cria um issue no repositório GitHub `marcoarthur/edumaps`** com o arquivo `.md` da especificação anexado ao corpo do issue.

---

## Pré-requisitos

Antes de usar esta skill, verifique:

1. **GitHub CLI (`gh`) instalado e autenticado:**
   ```bash
   gh auth status
   ```
   Se não estiver autenticado, execute:
   ```bash
   gh auth login
   ```

2. **Acesso ao repositório `marcoarthur/edumaps`:**
   ```bash
   gh repo view marcoarthur/edumaps
   ```

3. **Diretório de trabalho atual é um clone do repositório** (ou o usuário indicará o caminho correto).

---

## Fluxo de Trabalho

### Fase 1 — Escuta Ativa e Entrevista

Quando o usuário (gestor, professor, coordenador, administrador, etc.) descrever uma necessidade, **não assuma nada**. Siga este protocolo:

1. **Registre a fala original** do usuário sem interpretação.
2. **Identifique ambiguidades** e lacunas nos seguintes aspetos:
   - **Quem** é o ator principal? (professor, gestor, aluno, responsável?)
   - **O quê** exatamente o sistema deve fazer?
   - **Quando** essa funcionalidade é acionada? (tempo real, batch, periódico?)
   - **Onde** os dados são originados? (base de dados existente, importação CSV, API externa?)
   - **Porquê** é necessário? (qual dor resolve? qual métrica melhora?)
   - **Como** o usuário saberá que funcionou? (critérios de aceitação)
3. **Faça perguntas de clarificação** uma a uma (ou em pequenos grupos), usando linguagem simples e acessível ao perfil do entrevistado. Exemplos:
   - "Quando o senhor diz 'relatório de desempenho', que indicadores específicos devem aparecer? Notas, frequência, participação?"
   - "Esse painel deve ser atualizado em tempo real ou pode ser atualizado uma vez por dia?"
   - "Quem pode ver esses dados? Todos os professores ou apenas a coordenação?"
4. **Itere** até que o requisito esteja suficientemente claro para ser formalizado.

> **Regra de ouro:** Se após 3 rodadas de perguntas ainda houver ambiguidade crítica, documente as suposições feitas e marque-as com `[SUPOSIÇÃO]` na especificação.

### Fase 2 — Tradução para Requisitos Formais

Para cada necessidade clarificada, produza um ou mais **requisitos formais** no seguinte formato:

```
### RF-XXX: <Título curto>

**Ator:** <quem>
**Descrição:** O sistema deve <verbo no infinitivo> <objeto> <condição>.
**Prioridade:** Essencial | Importante | Desejável
**Critérios de Aceitação:**
- [ ] <critério verificável 1>
- [ ] <critério verificável 2>
**Dependências:** <outros RFs ou sistemas>
**Suposições:** <se aplicável>
```

Numere os requisitos sequencialmente (`RF-001`, `RF-002`, ...).

### Fase 3 — Decomposição Arquitetural

Para **cada requisito formal**, decomponha a implementação nas três camadas:

#### 3.1 Motor Analítico

- Que dados precisam ser processados?
- Que métricas, agregações ou modelos são necessários?
- Qual a frequência de execução (batch diário, sob demanda, streaming)?
- Que formato de saída o motor deve produzir? (JSON, CSV, Parquet?)
- Existem requisitos de performance? (ex.: processar 10 000 alunos em < 5s)

#### 3.2 Frontend (Svelte)

- Que componentes Svelte serão criados ou modificados?
- Que rotas/ecrãs são afetados?
- Que estado (stores Svelte) é necessário?
- Existem requisitos de acessibilidade, responsividade ou i18n?
- Que interações do usuário são esperadas? (cliques, filtros, exportações)

#### 3.3 Backend (Perl)

- Que endpoints da API são necessários? (método HTTP, rota, payload)
- Que módulos Perl serão criados ou modificados?
- Que tabelas/colunas da base de dados são afetadas? (migrations)
- Existem requisitos de autenticação/autorização?
- Que integrações externas são necessárias? (SMTP, APIs de terceiros)

### Fase 4 — Geração do Arquivo de Especificação

Crie um ficheiro Markdown com a seguinte estrutura:

```markdown
# Especificação de Requisitos — EduMaps

**Data:** YYYY-MM-DD
**Autor:** <nome do engenheiro de requisitos / agente>
**Versão:** 1.0
**Issue relacionado:** #<número do issue, preenchido após criação>

---

## 1. Contexto e Objetivo

<Resumo do problema, atores envolvidos e valor esperado>

## 2. Requisitos Formais

<Lista dos RFs gerados na Fase 2>

## 3. Decomposição Arquitetural

### 3.1 Motor Analítico

<Detalhamento por requisito>

### 3.2 Frontend (Svelte)

<Detalhamento por requisito>

### 3.3 Backend (Perl)

<Detalhamento por requisito>

## 4. Modelo de Dados (se aplicável)

<Diagrama ou descrição das tabelas/coleções afetadas>

## 5. Contratos de API (se aplicável)

<Endpoints, payloads, respostas>

## 6. Riscos e Suposições

<Lista de riscos técnicos e suposições documentadas>

## 7. Critérios de Aceitação Globais

<Checklist de validação da especificação completa>
```

Guarde o ficheiro com o nome:
```
docs/specs/YYYY-MM-DD-<slug-do-requisito>.md
```

### Fase 5 — Criação do Issue no GitHub

Após a especificação estar pronta, crie o issue no repositório:

```bash
gh issue create \
  --repo marcoarthur/edumaps \
  --title "Especificação: <título curto do requisito>" \
  --body-file "docs/specs/YYYY-MM-DD-<slug-do-requisito>.md" \
  --label "especificação,requisitos"
```

Se o repositório tiver um template de issue, adicione a flag `--template <nome-do-template>`.

**Verificação pós-criação:**
```bash
gh issue view <número-do-issue> --repo marcoarthur/edumaps
```

---

## Diretrizes de Comunicação

- **Adapte a linguagem ao interlocutor:** Um professor pode não saber o que é um "endpoint REST". Traduza: "isso significa que o sistema vai buscar os dados automaticamente quando o senhor abrir a página".
- **Nunca assuma requisitos não ditos.** Pergunte.
- **Documente tudo.** Se o usuário disse "mais ou menos isso", registre a fala original e a interpretação.
- **Valide antes de avançar:** Ao fim de cada fase, resuma o que foi entendido e peça confirmação.

---

## Exemplo de Interação

**Usuário:** *"Preciso de um relatório que mostre como os alunos estão indo."*

**Agente (Fase 1):**
> Entendi que o senhor precisa de um relatório de desempenho dos alunos. Para especificar corretamente, preciso de alguns esclarecimentos:
>
> 1. Quem vai usar este relatório? (professores, coordenação, direção?)
> 2. Que aspetos do desempenho devem aparecer? (notas por disciplina, frequência, participação, evolução ao longo do tempo?)
> 3. O relatório deve ser por turma, por aluno, por disciplina, ou todos?
> 4. Com que frequência os dados precisam ser atualizados? (diariamente, semanalmente, em tempo real?)
> 5. O senhor prefere visualizar na tela, exportar para PDF, ou ambos?

*(após respostas, o agente prossegue para as Fases 2–5)*

---

## Tratamento de Erros

| Situação | Ação |
|----------|------|
| `gh` não autenticado | Solicitar `gh auth login` e repetir |
| Repositório inacessível | Verificar permissões e URL; informar o usuário |
| Requisito demasiado vago após 3 rodadas | Documentar suposições, marcar `[SUPOSIÇÃO]`, avançar |
| Conflito entre requisitos | Destacar na secção "Riscos" e pedir decisão ao usuário |
| Base de código não disponível localmente | Criar o ficheiro `.md` no diretório atual e avisar que o issue será criado sem contexto de código |

---

## Comandos Úteis de Referência

```bash
# Verificar autenticação
gh auth status

# Criar issue com ficheiro
gh issue create --repo marcoarthur/edumaps \
  --title "Especificação: Novo Dashboard de Desempenho" \
  --body-file "docs/specs/2026-09-25-dashboard-desempenho.md" \
  --label "especificação,requisitos"

# Listar issues abertos
gh issue list --repo marcoarthur/edumaps --label "especificação"

# Ver detalhes de um issue
gh issue view 42 --repo marcoarthur/edumaps
```
