---
titulo: Área de influência
modulo: gestor
status: ativo
audiencia: [gestor]
relacionadas: [painel, equipamentos-entorno, painel-escola]
---

# Área de influência

> Módulo: `gestor` · Status: 🟢 ativo · Público: gestor

## Resumo

O gestor vê, no mapa, a **área de influência da sua escola** — o entorno
considerado nas leituras de território da plataforma — já calculado, com um
polígono por raio e a legenda de para que serve cada um.

## Para quem

Gestores escolares que precisam entender **qual território** a plataforma
considera ao ler a escola (equipamentos, uso do solo, queimada, chuva) e que
querem uma leitura comum entre a escola e os órgãos públicos.

## O que o sistema permite

- Sistema pode **exibir a área de influência** da escola em três raios
  documentados, cada um para um grupo de leituras: **500 m** (feições locais,
  equipamentos e vias), **1 km** (uso do solo e densidade) e **2 km** (queimada
  e chuva).
- Sistema pode **desenhar no mapa** a escola e cada anel, com **legenda** que
  liga e desliga cada raio e mostra a **área em km²** de cada um.
- Sistema pode usar essa mesma área como base das **leituras de território** da
  escola — inclusive o **contexto socioeconômico do entorno** (**instrução** e
  **saneamento**: analfabetismo e água/esgoto/lixo/banheiro do setor censitário),
  lido por arealização da área de influência e reunido no IVET.
- Sistema pode informar a **proveniência** do dado — de que versão da
  metodologia veio e quando foi calculado.
- Sistema pode distinguir **"área ainda não calculada"** de um entorno vazio:
  quando a escola ainda não teve a área materializada, informa isso, sem
  desenhar um buffer inventado.
- Sistema pode **restringir a visão à própria escola**: a geometria por escola
  é dado sensível (localização), então só o gestor da escola a vê — não é dado
  público.

## Valor

Dá ao gestor a mesma **base territorial** usada nas análises da plataforma,
tornando concreto e auditável o que significa "o entorno da escola". Ajuda a
interpretar indicadores (por que um valor aparece), a planejar ações no bairro
e a dialogar com a rede e o poder público usando um recorte comum. Ao ser
somente leitura sobre uma camada única e versionada, garante que escola e
plataforma falem do **mesmo** território.

## Relacionadas

- [Painel do gestor](painel.md)
- [Equipamentos no entorno](equipamentos-entorno.md)
- [Painel da escola](../analise/painel-escola.md)
