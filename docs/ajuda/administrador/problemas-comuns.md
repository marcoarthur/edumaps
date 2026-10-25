---
titulo: "Problemas comuns (administrador)"
publico: [administrador]
modulo: administrador
nivel: intermediario
status: ativo
relacionadas: [execucao-de-jobs]
funcionalidade: ../../funcionalidades/plataforma/observabilidade.md
ultima_revisao: 2026-10-25
---

# Problemas comuns (administrador)

> **Para quem:** Administrador  
> **Tempo de leitura:** ~4 min

## Checklist rápido
| Sintoma | Possível causa | Ação sugerida |
|---|---|---|
| **Jobs parados/stall** | Concorrência/lock | Verificar execução, logs e dependências |
| **Bot sem resposta** | Webhook/token | Conferir configuração e status |
| **Fonte com falha** | Externa/credenciais | Verificar conectividade e última atualização |
| **Erro 502/timeout** | Sobrecarga/proxy | Verificar saúde dos serviços |

## Limitações conhecidas
Este é um checklist inicial. Em caso de incidente, seguir runbook interno.

## Veja também
- [Execução de jobs](execucao-de-jobs.md)
- [Fontes de dados](fontes-de-dados.md)
