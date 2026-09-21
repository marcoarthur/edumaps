# Nota técnica — Catálogo de Funcionalidades (`docs/funcionalidades/`)

> Data: 2026-09-21 · Ciclo: documentação (docs-only)

## 1. Contexto

Com o EduMaps maduro (busca, análise e gestão), faltava um **ponto central** que
listasse as funcionalidades de alto nível para sínteses (PDF, wiki,
apresentações) e para orientar o desenvolvimento. Além disso, não havia no
Workflow a obrigação de manter essa documentação em dia.

## 2. Decisões

- **Markdown como fonte** — permite derivar outros formatos.
- **Um arquivo por capacidade** (Opção B), agrupado por módulo
  (`busca`, `analise`, `gestor`, `comunidade`, `plataforma`).
- **Front-matter YAML** (`titulo`, `modulo`, `status`, `audiencia`,
  `relacionadas`) para síntese automática.
- **Alto nível** — capacidades de negócio, **sem** rotas/arquivos/funções
  (anti-padrão documentado).
- **Status/roadmap**: 🟢 ativo · 🟡 parcial · ⚪ planejado · 🔴 descontinuado
  (inclui capacidades planejadas, ex.: `busca/pessoas`, `busca/analises`).
- **Workflow**: novo passo dedicado **após a Execução** (entra na Aprovação).

## 3. Solução

```
docs/funcionalidades/
├── README.md        # índice/síntese (Módulo · Capacidade · resumo · status)
├── _template.md     # modelo (front-matter YAML)
├── busca/           escolas · similaridade · analises⚪ · pessoas⚪
├── analise/         painel-escola · ranking · clusters · rede-municipal
│                    financeiro · folha-pagamento
├── gestor/          acesso · painel · pesquisas · reunioes-atas
│                    contatos-grupos · inventario · relacoes-institucionais
├── comunidade/      resposta-pesquisa
└── plataforma/      fontes-de-dados · privacidade-lgpd
```

### Processo (`AGENTS.md`)
- **Workflow** renumerado para 1–8, com o passo **3. Documentação funcional**:
  *"sempre que uma funcionalidade mudar ou uma nova for criada, atualizar o
  arquivo da capacidade e o `README.md`"*.
- Nova seção **"Documentação funcional (`docs/funcionalidades/`)"** com
  estrutura, template, status e anti-padrão.
- `docs/indice.md` (acervo do Tech Lead) ganhou a seção "11. Funcionalidades".

## 4. Validação

- Docs-only: **sem deploy** (nenhum artefato de código).
- Conferência: 22 arquivos markdown (20 capacidades + README + template);
  front-matter consistente; índice com links relativos.
- **PR #85** → `main` (merge `a154a1b`).

## 5. Próximos passos

- Ao evoluir um módulo, atualizar a capacidade correspondente (regra do passo 3).
- Considerar um gerador de síntese (PDF/wiki) a partir do front-matter.
- Revisar periodicamente o status das capacidades ⚪ planejadas
  (`busca/pessoas`, `busca/analises`).
