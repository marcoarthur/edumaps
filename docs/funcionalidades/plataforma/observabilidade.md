---
titulo: Observabilidade de erros
modulo: plataforma
status: parcial
audiencia: [gestor, admin]
relacionadas: [privacidade-lgpd]
---

# Observabilidade de erros

> Módulo: `plataforma` · Status: 🟡 parcial · Público: gestor, admin

## Resumo

A plataforma pode registrar erros internos (falhas de API, jobs de análise e
erros no navegador) num repositório central (Sentry), para diagnóstico proativo
sem depender de o usuário reportar.

## Para quem

Equipe técnica da instalação e administradores que precisam investigar falhas.

## O que o sistema permite

- Sistema pode reportar erros HTTP (5xx) dos serviços com contexto da rota,
  método e status.
- Sistema pode reportar falhas de jobs de análise (fila), com a tarefa e
  argumentos sanitizados — nunca CPF, salários SIOPE nem segredos.
- Sistema pode reportar erros de JavaScript no navegador (exceções não
  tratadas e respostas de API ≥ 500), com dados pessoais redigidos.
- Sistema pode ativar/desativar a captura por configuração (sem chave de
  projeto, nada é enviado).

## Nota de status

A instrumentação de backend, jobs e frontend está implementada, mas a captura
só é ativada quando uma conta/repositório sentry.io (DSN) for configurado na
instalação — daí 🟡 parcial.

## Valor

Diagnóstico rápido e proativo de falhas, reduzindo o tempo de correção e a
dependência de relatos manuais.

## Relacionadas

- [Privacidade e LGPD](privacidade-lgpd.md)