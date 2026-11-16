# Ciclo 2026-11-16: município destacado no ranking de redes

- **Período:** 2026-11-16.
- **História:** #449 (PR #451), achado RG-03 da
  [quarta avaliação da P4](../avaliacoes/2026-11-16-p4-ranking-regiao.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 211.

## Resumo

- Na lista de redes, dá para destacar um município: a linha fica marcada, a
  página vai até ela, e um quadro diz a posição no recorte.
- Quando a rede não está na lista, o quadro diz por quê: outra UF ou região,
  outro porte, sem população, poucas escolas com dado ou sem dado na edição.
- Os botões levam ao recorte do município: os de mesmo porte na região dele,
  ou a UF dele.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a diretora acha a rede
do município dela sem procurar na lista, e o município segue para a aba das
escolas.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:**
- "onde a minha rede está entre as de porte parecido na região" sai com um
  clique;
- quando a rede some da lista por ter poucas escolas com dado, a tela diz
  isso, em vez de parecer erro.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto:** o ranking é das redes
municipais; a dor central segue na #429.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RG-03. "Semelhantes ao meu"
vira recorte com um clique, e a ausência de uma rede tem motivo dito.
**Nenhum achado das avaliações da P4 fica aberto.** Voltar quando houver
séries (mais de um Censo) ou base nacional.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** um
conselho municipal acha a própria rede e o recorte de comparação; a dor
central (prestação de contas) não muda.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** o link com o município
destacado vai para a matéria e abre na linha dele.

## O que este ciclo ensinou

- A ausência numa lista também é um resultado. Quem sabe o motivo é quem
  calculou a lista, então o servidor diz, e a tela só traduz.
- A rolagem que passava no jsdom parou no navegador real. A validação na
  tela pegou o que o teste não podia ver.
