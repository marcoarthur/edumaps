---
titulo: Bot Telegram
modulo: plataforma
status: parcial
audiencia: [admin]
relacionadas: [painel-configuracao, observabilidade]
---

# Bot Telegram

> Módulo: `plataforma` · Status: 🟡 parcial · Público: `admin`

## Resumo

A plataforma pode enviar notificações e alertas por Telegram a partir de um bot
configurado pela administração da instalação, restringindo quais eventos
disparam mensagem.

## Para quem

Administradores da instalação e equipes de operação que acompanham o
funcionamento da plataforma (ingestão de dados, jobs, saúde do sistema).

## O que o sistema permite

- Sistema permite configurar o bot Telegram no Painel de Configuração: token do
  bot (guardado cifrado, nunca exibido), chat de destino e ativação/desativação
  do envio.
- Sistema permite escolher, por marcação, quais ações estão autorizadas a
  disparar mensagem no chat (alertas de sistema e de ingestão, notificações a
  usuários e administradores, entre outras).
- Sistema envia **automaticamente** mensagens para o chat configurado quando
  terminam os jobs de ingestão — sucesso (`ingest_done`), falha
  (`ingest_failed`) ou ingestão parada sem progresso (`ingest_stall`) — sempre
  respeitando a ativação e as ações autorizadas pela administração.
- Sistema permite enviar uma mensagem de teste para o chat configurado, usando
  as credenciais já gravadas, para validar a entrega.
- Sistema permite (em fase futura) receber mensagens do chat e responder — hoje
  o bot é somente de envio.

## Valor

A equipe de operação acompanha a saúde da plataforma sem estar presa a um
painel: eventos críticos (ex.: ingestão parada, job com falha) chegam no
Telegram, no chat escolhido, e apenas para as ações que a administração
autorizou.

## Relacionadas

- [Painel de Configuração](../plataforma/painel-configuracao.md)
- [Observabilidade de erros](../plataforma/observabilidade.md)