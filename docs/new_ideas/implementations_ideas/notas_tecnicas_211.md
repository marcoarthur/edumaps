# Nota técnica 211: município destacado no ranking de redes (#449)

Achado RG-03 da quarta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-ranking-regiao.md`). Um PR:
#451 (merge `c06a351`), com dois commits: a funcionalidade e uma correção da
rolagem achada na validação no navegador.

## O problema

Para responder "municípios de porte e região semelhantes **ao meu**", a
pesquisadora precisava:

1. saber o porte do município;
2. escolher a região;
3. procurar a linha com Ctrl+F entre 519 redes.

Quando a rede não estava na lista, nada dizia por quê.

## Backend: o motivo vem do servidor

Só o servidor sabe quantas escolas da rede têm dado na edição. Por isso o
motivo é calculado lá, e não deduzido na tela.

- `GET /api/ranking/redes?...&destaque=<código IBGE>` acrescenta o bloco
  `destaque`, montado por `_destaque_rede`:
  - nome e UF, do IDEB e, na falta, do Censo;
  - população e porte;
  - escolas com dado na edição;
  - a posição, quando a rede está na lista.
- `situacao` segue uma ordem fixa: `no_ranking` → município desconhecido
  (`sem_dado`) → `fora_do_recorte` (UF, ou região por `Regiao->de_uf`) →
  `sem_populacao` / `fora_do_porte` (só com filtro de porte) → `sem_dado`
  (nenhuma escola) → `poucas_escolas`.
- O cálculo do ranking não muda. São quatro consultas pequenas, só quando
  `destaque` vem na URL.
- `destaque` precisa ter 7 dígitos, senão 400. Um município desconhecido
  vem como `sem_dado`, não como erro: o link continua abrindo.

## Tela

- O campo **Destacar município** usa o mesmo autocomplete da aba de escolas.
  O município vai na URL como `destaque=`, separado do `codigo_ibge` da aba
  de escolas. Ao trocar de aba, ele segue como o município escolhido.
- A linha fica marcada (`aria-current`), e a marca continua quando a ordem
  muda.
- O quadro de resumo mostra a posição ou o motivo, e as sugestões de recorte:
  - **Comparar com os de mesmo porte na região**: liga a região e o porte do
    município;
  - **Comparar na UF**.

  As sugestões não trocam o recorte sozinhas e somem quando o recorte já é
  aquele.
- **Rolagem até a linha:**
  - a primeira versão, `scrollIntoView` suave num `$effect`, parava no topo
    da tabela no navegador real: a página ainda estava montando;
  - virou rolagem direta depois do próximo quadro
    (`requestAnimationFrame` + `setTimeout`);
  - o botão **Ver na tabela** fica como garantia;
  - o jsdom não rola, então o teste confere a chamada.

## Validação

- **Perl:** no ranking com posição, poucas escolas, fora do recorte, fora do
  porte, sem população, município desconhecido, sem o bloco quando não há
  `destaque`, e 400. vitest: 5 casos.
- **Suítes:** Perl com 193 arquivos e 1711 testes; vitest com 153 arquivos e
  1321 testes. CI verde.
- **Dados reais:**
  - Vitória: 38ª de 67 no ES, e 67ª de 132 no Sudeste de 100 a 500 mil;
  - Fortaleza com o recorte do ES: fora do recorte;
  - Brejetuba: poucas escolas (2, com mínimo de 3);
  - Simplício Mendes: 59ª de 519 no Nordeste de 10 a 20 mil.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
