---
modulo: gestor
nivel: basico
publico:
- gestor
- professor
- comunidade
- administrador
- desenvolvedor
status: ativo
titulo: Ajuda do EduMaps
ultima_revisao: '2026-10-25'
---

# Ajuda do EduMaps

> **Distinção importante:** `docs/funcionalidades/` responde *"o que o sistema faz"* (referência). `docs/ajuda/` responde *"como eu faço X"*, *"o que significa Y"* ou *"e se Z falhar"* (orientação por tarefa).

## Públicos
| Diretório | Público | Foco |
|---|---|---|
| [`gestor/`](gestor/README.md) | Diretor/coordenador de escola | Painel da escola, IVET, área de influência, financeiro/folha, comunicação |
| [`professor/`](professor/README.md) | Professor/docente | *(em definição)* |
| [`comunidade/`](comunidade/README.md) | Família/responsável/cidadão | Busca pública, painel público, privacidade |
| [`administrador/`](administrador/README.md) | Administrador da plataforma | Configurações, bot, fontes, jobs, LGPD |
| [`desenvolvedor/`](desenvolvedor/README.md) | Contribuidores | Visão geral e apontamentos para `AGENTS.md`/`memory.md` |

## Regras editoriais
1. **Sem jargão interno.** Nada de "view materializada", "Sqitch", "Minion", "matview", "JSONB".
2. **Task-first.** Comece pelo que o usuário quer fazer.
3. **Ausência nunca é zero (#154).** Sempre explique "n/d" quando aplicável.
4. **LGPD explícita.** Quando tocar PII, adicione bloco "Privacidade".
5. **Apontar para o catálogo.** Use o campo `funcionalidade` para vincular a `docs/funcionalidades/`.
6. **Limitações por escrito.** Seja transparente sobre cobertura parcial.

## Glossário
Veja [`_glossario.md`](_glossario.md) para termos compartilhados.

## Template
Use [`_template.md`](_template.md) ao criar novos artigos.
