# Ciclo 2026-11-26: a lista do ano dos abaixo do piso

- **Período:** 2026-11-26.
- **Histórias:** #601 e #602 (PR #603), achados QC-01 e QC-02 da
  [sexta avaliação da P2](../avaliacoes/2026-11-26-p2-resposta-tce-ponta-a-ponta.md).
- **Avaliação:** a sexta da P2 (adotaria, em piloto; mantido).
- **Engenharia:** nota técnica 284.

## Resumo

- **O anexo do ofício:** a lista do ano de quem fica abaixo do piso na rede
  municipal, uma linha por pessoa (CPF mascarado, situação, carga, base por
  40 h, meses, onde recebeu), com a mesma regra e o mesmo total do painel,
  numa página pública com CSV. Aberta pelo painel da Secretaria e pela base
  de análise. Cuiabá 2026: 1.559 pessoas.
- **Ordenar de verdade:** a ordenação vale para a lista filtrada inteira,
  não só para a página.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a ordenação da folha
da escola passa a valer para a lista toda.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Resolvido:**
QC-01 e QC-02. A resposta ao tribunal sai da plataforma com o anexo nome a
nome; os dois achados da sexta rodada estão entregues.

## P3 — Rede privada (mantenedor)

**Veredito:** adotaria, em piloto, para escolher a cidade (mantido). **Sem
impacto relevante:** a lista pessoa a pessoa não muda a escolha.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Impacto pequeno:** o CSV do ano por
município, com a regra documentada, serve de recorte reproduzível.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto médio:** o
tribunal baixa os casos do ano da própria tela pública e confere com o
ofício.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto médio:** a pauta do piso tem a
lista do ano em CSV, sem a planilha do SIOPE.

## O que este ciclo ensinou

- A lista e a contagem nascem da mesma regra e o teste confere o total:
  é isso que deixa o anexo e o número do painel baterem no ofício.
