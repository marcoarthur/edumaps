---
titulo: Painel de Configuração
modulo: plataforma
status: parcial
audiencia: [administrador]
relacionadas: [assistente-censo, fontes-de-dados]
---

# Painel de Configuração

> Módulo: `plataforma` · Status: 🟡 parcial · Público: `administrador`

## Resumo

Área administrativa onde a instalação configura parâmetros globais da
plataforma — nome da instalação, fuso horário, aparência, comportamento dos
painéis e integrações — organizados em categorias e grupos. Hoje está ativa a
configuração da chave de API do Assistente do Censo; as demais categorias estão
previstas.

## Para quem

Administração da instalação do EduMaps (quem operacionaliza a plataforma na
rede), centralizando ajustes que hoje dependeriam de deploy ou acesso ao servidor.

## O que o sistema permite

- Sistema pode organizar as configurações da plataforma em categorias e grupos
  navegáveis (Sistema, Integrações, Aparência, Comportamento, Outros).
- Sistema pode exibir cada item de configuração com descrição e exemplo, e
  sinalizar os itens ainda não disponíveis.
- Sistema pode guardar e gerenciar a chave de API do Assistente do Censo,
  cifrada e nunca exibida em claro, exibindo apenas se ela está ou não definida.
- Sistema pode aplicar a chave configurada ao Assistente do Censo, que passa a
  responder às perguntas do gestor usando o provedor da instalação.

## Valor

Permite à administração ajustar a plataforma sem código, centralizando decisões
de infraestrutura e de contratação de serviço de linguagem em um único lugar
seguro, com segredos protegidos.

## Relacionadas

- [Assistente do Censo](../analise/assistente-censo.md)
- [Fontes de dados](../plataforma/fontes-de-dados.md)