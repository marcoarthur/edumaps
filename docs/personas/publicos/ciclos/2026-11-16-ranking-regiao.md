# Ciclo 2026-11-16: recorte por região no ranking de redes

- **Período:** 2026-11-16.
- **História:** #445 (PR #447), achado BA-02 da
  [terceira avaliação da P4](../avaliacoes/2026-11-16-p4-base-analise.md).
- **Decisão de produto:** a região entra só no ranking. A base de análise
  segue uma UF por vez, e a região ou o Brasil inteiro na base ficam com a
  assinatura de dados.
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 209.

## Resumo

- O ranking de redes municipais compara as redes de uma região (Norte,
  Nordeste, Sudeste, Sul, Centro-Oeste), além de uma UF ou do Brasil.
- A posição, o INSE parecido e o salto atípico são calculados dentro da
  região. A região combina com o porte: "municípios de porte e região
  semelhantes" tem resposta direta.
- A ajuda da base de análise diz como montar uma região juntando as UFs.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto:** a diretora olha a escola
dela, não o ranking de redes da região.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** o
secretário compara a rede dele com as de porte parecido da região, e não só
do estado.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto:** o ranking é das redes
municipais; a dor central segue na #429.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido em parte:** BA-02.
- "Municípios de porte e região semelhantes" se responde com região e porte
  no ranking.
- "O perfil docente entre regiões" continua pedindo os downloads por UF.
  Isso é decisão de produto (base por região na assinatura), e a ajuda diz
  como juntar os arquivos.

**Fica:** nenhum achado aberto das avaliações da P4. Voltar quando houver
séries (mais de um Censo) ou base nacional.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto direto:** um
conselho regional pode usar o recorte, mas a dor central (prestação de
contas) não muda.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a matéria "as redes
que mais melhoraram no Nordeste" sai de um link, com o salto atípico medido
na região.

## O que este ciclo ensinou

- Quando a pergunta da persona cabe em duas telas e a decisão de produto
  limita uma delas, entregar onde é barato e dizer, na outra, como chegar lá
  com o que existe.
