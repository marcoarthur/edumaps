---
titulo: Painel de Configuração
modulo: plataforma
status: parcial
audiencia: [administrador]
relacionadas: [assistente-censo, fontes-de-dados, canais-de-comunicacao, envios-email]
---

# Painel de Configuração

> Módulo: `plataforma` · Status: 🟡 parcial · Público: `administrador`

## Resumo

Área administrativa onde a instalação configura parâmetros globais da
plataforma — nome da instalação, fuso horário, aparência, comportamento dos
painéis, integrações e canais de comunicação — organizados em categorias e
grupos. Hoje estão ativas as Integrações (chave de API do Assistente do Censo e
Bot Telegram) e os Canais de comunicação (e-mail, WhatsApp, autoinscrição por
QR, retenção e limites de envio); as demais categorias estão previstas.

## Para quem

Administração da instalação do EduMaps (quem operacionaliza a plataforma na
rede), centralizando ajustes que hoje dependeriam de deploy ou acesso ao servidor.

## O que o sistema permite

- Sistema pode organizar as configurações da plataforma em categorias e grupos
  navegáveis (Sistema, Integrações, Canais de comunicação, Aparência,
  Comportamento, Outros).
- Sistema pode exibir cada item de configuração com descrição e exemplo, e
  sinalizar os itens ainda não disponíveis.
- Sistema pode guardar e gerenciar a chave de API do Assistente do Censo,
  cifrada e nunca exibida em claro, exibindo apenas se ela está ou não definida.
- Sistema pode aplicar a chave configurada ao Assistente do Censo, que passa a
  responder às perguntas do gestor usando o provedor da instalação.
- Sistema pode guardar e gerenciar a configuração do Bot Telegram: token
  (cifrado, nunca exibido), chat de destino, ativação e a lista de ações
  autorizadas a disparar mensagem.
- Sistema pode guardar e gerenciar a configuração dos canais de comunicação:
  credenciais de e-mail (SMTP) e de WhatsApp, com segredos cifrados.
- Sistema pode ligar ou desligar a autoinscrição pública por QR e ajustar seu
  endereço público e o limite antiabuso de submissões.
- Sistema pode guardar a configuração do bot público do Telegram e da mensagem
  oficial de código do WhatsApp usados na confirmação de telefone, exibir o
  estado do bot e acioná-lo (iniciar o recebimento de mensagens ou registrar
  o endereço de entrega).
- Administração pode publicar **versões do termo de consentimento** (rascunho,
  pré-visualização e publicação; versões publicadas não mudam) e definir os
  **prazos de retenção** de dados das listas, acompanhando a última limpeza
  automática ou disparando uma na hora.
- Administração pode definir os **limites dos envios por e-mail** das escolas —
  ligar ou desligar os envios, ritmo por minuto, cota diária por escola e teto
  de destinatários por envio.
- Administração pode acompanhar, num painel, o **volume de envios por escola**
  (hoje e nos últimos 30 dias, falhas, saídas e envios em andamento) e
  **suspender** uma escola com o motivo registrado — o que segura na hora os
  envios em curso e bloqueia novos — ou **reativá-la**, retomando os envios
  suspensos sem antecipar os que estavam agendados.

## Valor

Permite à administração ajustar a plataforma sem código, centralizando decisões
de infraestrutura e de contratação de serviço de linguagem em um único lugar
seguro, com segredos protegidos.

## Relacionadas

- [Assistente do Censo](../analise/assistente-censo.md)
- [Canais de comunicação](../plataforma/canais-de-comunicacao.md)
- [Envios por e-mail para listas](../gestor/envios-email.md)
- [Bot Telegram](../plataforma/bot-telegram.md)
- [Fontes de dados](../plataforma/fontes-de-dados.md)