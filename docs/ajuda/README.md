---
modulo: gestor
nivel: basico
publico:
- gestor
- comunidade
- administrador
- rede
- desenvolvedor
status: ativo
titulo: Ajuda do EduMaps
ultima_revisao: '2026-11-10'
---

# Ajuda do EduMaps

> **Distinção importante:** `docs/funcionalidades/` responde *"o que o sistema faz"* (referência). `docs/ajuda/` responde *"como eu faço X"*, *"o que significa Y"* ou *"e se Z falhar"* (orientação por tarefa).

## Públicos
| Diretório | Público | Foco |
|---|---|---|
| [`gestor/`](gestor/README.md) | Diretor/coordenador de escola | Painel da escola, IVET, área de influência, financeiro/folha, comunicação |
| [`rede/`](rede/README.md) | Secretaria de educação (municipal ou estadual) | Conta de rede por convite, escolas da rede |
| [`comunidade/`](comunidade/README.md) | Quem usa sem login: famílias, responsáveis, cidadãos, professores, pesquisadores e investidores | Busca pública, painel público, privacidade |
| [`administrador/`](administrador/README.md) | Administrador da plataforma | Configurações, bot, fontes, jobs, LGPD |
| [`desenvolvedor/`](desenvolvedor/README.md) | Contribuidores | Visão geral e apontamentos para `AGENTS.md`/`memory.md` |

### Quem fica de fora dos perfis

- **Professor não tem perfil próprio.** A plataforma não tem conta docente:
  só gestor, conta de rede e administrador entram com login. O professor aparece como
  contato que o gestor cadastra (grupos, reuniões, listas com QR, pesquisas)
  e usa a parte pública como qualquer pessoa, pela ajuda de
  [`comunidade/`](comunidade/README.md). Um acesso docente, se vier, será uma
  funcionalidade nova, com issue própria.
- **Pesquisador e investidor estão em `comunidade/`.** As fichas de
  `docs/funcionalidades/` citam esses públicos em `audiencia`; na ajuda eles
  correspondem a `comunidade`, porque usam as mesmas telas públicas.

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
