---
titulo: Painel de Administração
modulo: plataforma
status: ativo
audiencia: [admin]
relacionadas: [telemetria-de-sessao, painel-configuracao, observabilidade]
---

# Painel de Administração

> Módulo: `plataforma` · Status: 🟢 ativo · Público: admin

## Resumo

A administração da instalação pode acompanhar, num só painel e em tempo quase
real, o **fluxo de acesso e uso** da plataforma: quantos gestores diferentes
entraram, quantas sessões (logadas e anônimas) estão ativas, quais áreas são
mais visitadas, quantas buscas foram feitas e como os eventos se distribuem ao
longo do tempo. É a leitura de decisão sobre a telemetria já coletada — sempre
em números agregados, nunca sobre pessoas.

## Para quem

Quem administra a instalação e precisa de evidências quantitativas de adoção e
uso para priorizar melhorias, dimensionar capacidade e perceber tendências.

## O que o sistema permite

- Sistema pode mostrar quantos **gestores distintos** fizeram login nas últimas
  6, 12 e 24 horas, fixas e comparáveis entre si.
- Sistema pode mostrar quantas **sessões estão ativas** na janela escolhida e
  separá-las entre **logadas** (ligadas a um gestor) e **anônimas**.
- Sistema pode listar as **rotas mais acessadas** (páginas da plataforma) na
  janela, com o volume e a participação percentual de cada uma.
- Sistema pode contar as **buscas realizadas** — apenas o número de buscas, não
  o texto digitado — e o total de eventos no período.
- Sistema pode apresentar a **atividade ao longo do tempo**, por hora (janelas
  de até um dia) ou por dia (janelas de 7 e 30 dias), num gráfico contínuo.
- Sistema pode oferecer um **seletor de janela** (6 h, 12 h, 24 h, hoje,
  7 dias, 30 dias) que recalcula as métricas de atividade, enquanto os logins
  permanecem fixos em 6/12/24 h.
- Sistema pode **atualizar sozinho** o painel periodicamente e permitir uma
  atualização manual a qualquer momento.
- Sistema pode **restringir o painel a administradores** da instalação.

## Nota de status

O painel lê os eventos já persistidos pela telemetria (que chega em lotes, a
cada poucos segundos), portanto a leitura é **near-real-time**, não instantânea.
O acesso é restrito a perfis de administração. Nenhum dado individual é
exposto: não há IP, texto de busca, sessão identificável nem dado do gestor
além da contagem agregada.

## Valor

Transformar a telemetria em decisão: saber se a plataforma está sendo adotada,
onde estão os gargalos de navegação, quais áreas merecem investimento e como o
uso evolui — sem nunca transformar o painel numa ferramenta de vigilância.

## Relacionadas

- [Telemetria de sessão](telemetria-de-sessao.md)
- [Painel de Configuração](painel-configuracao.md)
- [Observabilidade de erros](observabilidade.md)
