---
titulo: Canais de comunicação
modulo: plataforma
status: parcial
audiencia: [administrador, gestor]
relacionadas: [listas-autoinscricao, bot-telegram, painel-configuracao, privacidade-lgpd]
---

# Canais de comunicação

> Módulo: `plataforma` · Status: 🟡 parcial · Público: `administrador`, `gestor`

## Resumo

Capacidade da plataforma de **falar com a comunidade escolar por diferentes
canais** — e-mail, WhatsApp e Telegram — validando o endereço, confirmando que
ele pertence a quem o informou e mantendo um histórico do que foi enviado.

## Para quem

A gestão escolar e a administração da instalação: quem precisa avisar, convidar
ou lembrar a comunidade (responsáveis, professores, parceiros) sem depender de
ferramentas externas, e quem responde pelo uso correto desses dados.

## O que o sistema permite

- Sistema pode enviar mensagens à comunidade por **e-mail, WhatsApp e Telegram**,
  tratando cada canal com suas particularidades de endereço e entrega.
- Sistema pode **validar o endereço** de cada canal antes de usar e **confirmar a
  posse** dele por meio de um código de verificação — sem nunca guardar o código
  em claro.
- Sistema pode manter um **histórico das mensagens** enviadas: por qual canal, a
  que finalidade se referiam, para quem e com que resultado.
- Sistema pode organizar o uso dos canais por **operação/motivo** (aviso,
  informação, pedido, convite, confirmação, lembrete, alerta).
- Administração pode **ligar, desligar e parametrizar** cada canal (credenciais,
  remetente, provedor) no Painel de Configuração, com os segredos protegidos.
- Sistema pode **confirmar a posse do telefone** de quem se inscreve numa
  lista: pelo **Telegram**, com um bot próprio da instalação que recebe o
  contato compartilhado pela pessoa e confere o número, ou pelo **WhatsApp**,
  com um código de verificação enviado por mensagem oficial.
- Administração pode configurar o **bot público do Telegram** (separado do bot
  de notificações internas), escolher como ele recebe mensagens e acompanhar
  seu estado no Painel de Configuração.
- Sistema pode sustentar outras capacidades sobre esses canais — como as
  **listas com autoinscrição por QR** — sem expor os contatos da escola.

## Valor

Dá à escola um caminho **próprio e recordável** para alcançar a comunidade, em
vez de ações soltas e sem rastro. Centraliza credenciais e decisões de canal num
lugar seguro, permite auditar o que foi comunicado e prepara o terreno para
campanhas e confirmação de posse dos contatos, com atenção à privacidade (LGPD).

## Relacionadas

- [Listas com autoinscrição por QR](../gestor/listas-autoinscricao.md)
- [Painel de Configuração](../plataforma/painel-configuracao.md)
- [Bot Telegram](../plataforma/bot-telegram.md)
- [Privacidade e LGPD](../plataforma/privacidade-lgpd.md)
