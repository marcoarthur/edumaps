# Nota técnica 201: busca por município com UF, menus em PT-BR e menos jargão (#431)

PR #432 (merge `e8b3b0d`), fecha a #431: achados AN-06 e AN-07 da curadoria
P3–P6 (`docs/personas/publicos/avaliacoes/2026-11-14-analises-publicas.md`).
No mesmo ciclo, os achados AN-05 a AN-11 viraram as issues #427 a #431.

## Busca por município

A busca de escolas fazia `no_municipio ILIKE '%texto%'` e ordenava pelo nome
da escola. "Vitória" trazia Porto Vitória (PR) e União da Vitória (PR) na
primeira página e espalhava Vitória (ES) por 85 páginas.

- O formulário guarda a sugestão escolhida (código e nome). Se o texto do
  campo ainda é o nome escolhido, envia `codigo_ibge`, e o backend filtra
  `co_municipio = ?`. Se a pessoa editou o campo depois, o código é
  descartado.
- O texto livre usa `contrib.unaccent` dos dois lados e ordena por um `CASE`
  (nome igual = 0, prefixo = 1, resto = 2), e só depois pelo nome da escola.
- As sugestões de município (`/api/city/suggestions`), usadas pela busca e
  pela comparação de redes, têm a mesma ordem e devolvem a sigla da UF
  (`COALESCE(sigla_estado, nome_estado)`). Antes vinha o nome do estado, e
  Vitória (ES) era a 8ª sugestão.
- Teste `t/04-api/school/search_municipio_ordem.t`: três municípios falsos
  (6000191–93: "Xurupitá", "Porto Xurupitá", "Xurupitá do Norte"), INEPs
  60001901–03. Falha contra o código antigo.

## Gráficos em PT-BR

O Carbon Charts aceita `options.locale.translations` (toolbar,
`tabularRep`). O `localeCarbon.js` define os textos, e o `comLocale(options)`
mescla, com a tradução própria da tela tendo precedência. Os quatro wrappers
(rosca, linhas, barras, radar) passam as options por um `$derived(comLocale(...))`,
então nenhuma tela precisa lembrar disso. O stub de teste do Carbon expõe
`data-export-csv`.

## Parâmetro do município

O perfil da rede passou a `?codigo_ibge=`, como a comparação. O `?ibge=`
continua aceito porque há links antigos em relatórios e no registro e2e.

## Jargão

A página `/cluster/geotag` virou "Agrupar escolas com perfil parecido", com
"Recorte", "Nº de grupos", "Agrupar escolas" e "Resumo dos grupos". `eps` e
`min_pts` ganharam rótulo explicativo. Cada algoritmo mantém o nome técnico
(a pesquisadora precisa dele) e ganha uma frase abaixo do campo. A primeira
versão punha a frase no `<option>`, e o campo estreito a cortava; a correção
veio no mesmo PR, depois da validação no navegador. A rota ficou a mesma,
para não quebrar links. O tour e a ajuda foram atualizados.

## IDEB com edição e etapa

O `.profile_pop_body` pega, para cada escola, a edição mais recente do IDEB
e, com mais de uma etapa, a de maior `nota_media`. A tela dizia só "IDEB
observado". Agora:

- `.school_profile_ideb_etapa` repete a regra para a escola-alvo e põe
  `ideb_etapa` e `ideb_ano` no metadata;
- `.profile_labels` rotula IDEB e nota SAEB como "IDEB observado 2023
  (escola: anos iniciais)". A etapa fica atribuída **só à escola**, porque as
  médias de município, rede, Brasil e grupo usam a etapa principal de cada
  escola. A ajuda e o "?" da tabela dizem isso;
- `PROFILE_REGRA_SINAIS` foi a 3 e virou, na prática, a versão do perfil (o
  nome do campo no payload ficou, para não quebrar o que já está gravado). O
  cache do R e a chave do backend (`$PERFIL_REGRA_SINAIS`) mudam juntos, e o
  teste de paridade de `t/03-plugins/analytics.t` confere.

**Fica em aberto, sem issue:** o `ORDER BY nota_media DESC` põe `NULL`
primeiro, e as comparações misturam etapas. Uma comparação etapa a etapa
exigiria a população por etapa (referências e clustering), escopo bem maior
que o da #431.

## Validação

- Perl `-j4`: 188 arquivos, 1684 testes; vitest: 145 arquivos; R: 2219, 0
  falhas. CI verde no PR.
- Navegador na stack local, com as imagens reconstruídas:
  - a busca "Vitória · ES" traz 180 escolas, todas de Vitória (ES);
  - o menu do gráfico mostra "Exportar CSV/PNG/JPG";
  - a página de Análises aparece com os textos novos;
  - o perfil da 32040164 mostra "IDEB observado 2023 (escola: anos
    iniciais)", com o cache antigo descartado;
  - o link antigo `?ibge=` abre.
- Depois do merge, as imagens foram reconstruídas do `main` e o ID da imagem
  de cada contêiner conferido.

## Deploy

No LXC: `deploy_backend_dev`, `deploy_frontend_dev` e
`deploy_analytics_dev`, já no roteiro de 16/11.
