---
titulo: "Execução de jobs"
publico: [administrador]
modulo: administrador
nivel: intermediario
status: ativo
relacionadas: [fontes-de-dados, painel-de-administracao]
funcionalidade: ../../funcionalidades/plataforma/observabilidade.md
ultima_revisao: 2026-10-25
---

# Execução de jobs

> **Para quem:** Administrador  
> **Tempo de leitura:** ~5 min

## Em 30 segundos
Acompanhar jobs de ingestão/processamento, identificar falhas/stall e agir com segurança.

## Passo a passo
1. **Onde ir:** Administração → Jobs/Execução
2. **Verificar** status (rodando/concluído/erro)
3. **Analisar** logs quando houver erro
4. **Reexecutar** apenas se autorizado e seguro
5. **Monitorar** até estabilizar

## Limitações conhecidas
- Alguns jobs são longos
- Reexecução pode gerar duplicados se não idempotente
- Dependências externas podem falhar

## Privacidade
Não expor dados sensíveis em relatórios compartilhados.

## Perguntas frequentes
- **Job em "stall"?** Verificar logs e recursos antes de intervir.
- **Posso reexecutar?** Apenas com conhecimento do impacto.

## Veja também
- [Fontes de dados](fontes-de-dados.md)
- [Observabilidade](../../funcionalidades/plataforma/observabilidade.md)
