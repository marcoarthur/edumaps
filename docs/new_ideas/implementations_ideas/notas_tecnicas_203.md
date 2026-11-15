# Nota técnica 203: fonte, ano e versão dos dados nas análises públicas (#428)

PR #435 (merge `12e4067`), fecha a #428: achado AN-08 da curadoria P3–P6.
Nenhuma análise pública dizia o ano do dado, e a capacidade "Fontes de dados"
(com hashes e vigência) existia só na documentação e no painel do
administrador.

## Desenho

- **`EduMaps::Fontes`:** o catálogo público fica em código e é revisado por
  PR. São cinco bases: Censo Escolar, IDEB/SAEB, INSE, folha do SIOPE e malha
  do IBGE. Cada uma tem órgão, descrição, link oficial, link da metodologia,
  tabelas e telas.
  - O **ano ou período** sai de uma consulta à própria tabela
    (`max(nu_ano_censo)`, `min/max(ano)`), nunca de texto fixo; só a malha do
    IBGE tem o ano fixo (2024, o do arquivo).
  - A **carga** é a mais recente das tabelas da base em
    `clean.import_metadata` com `ultimo_status` ok.
- **O que sai e o que não sai** (decisão do developer): saem o nome do órgão,
  o período, a data da carga e os arquivos (url, SHA-256, bytes, data).
  - **Não saem** o caminho no servidor, as notas de engenharia e a licença com
    "não verificada", "pendente" ou "decisão". A licença só aparece quando
    verificada; nos outros casos, "consulte os termos do órgão".
  - Um teste confere o corpo da resposta contra `/srv/`, `/data/`, `caminho`,
    `notes` e `Loader`.
- **Sem data inventada:** IDEB e SIOPE foram carregados antes do
  `import_metadata` e aparecem como "carga não registrada" (decisão do
  developer). A próxima carga registra a data.
- **`GET /api/fontes`:** público, com cache de 10 min por processo e
  `Cache-Control` igual.
- **Frontend:**
  - página `/fontes` com "Como ler os números" e um cartão por base;
  - selo `FonteDado` no pé de seis telas: comparação de redes, financeiro,
    folha, perfil da escola, ranking e agrupamento. Uma promessa só por carga
    de página, e o selo some se a busca falhar;
  - rodapé com **Fontes e metodologia** e **Privacidade**.
- **Versão dos dados no agrupamento:** a execução guarda
  `parametros.dados`, com o ano do Censo e o do IDEB de fato usados
  (`ano_ideb_efetivo`, que pode ser o pedido ou o mais recente) e a carga. A
  caixa Universo mostra isso. Fecha o ponto da P4 que ficou da #427.

## Links oficiais

Conferidos um a um com `curl`:
- três estavam errados (página do SIOPE, INSE e nota técnica do IDEB) e foram
  trocados por páginas que respondem 200 com o título certo;
- a página de malhas do IBGE responde 403 a robôs, mas abre no navegador.

## Validação

- Perl `-j4`: 191 arquivos, 1696 testes. `fontes.t` passa no banco do CI e no
  dev, onde as licenças "Não verificada" são filtradas de fato. vitest: 149
  arquivos, 1286 testes.
- No navegador:
  - a página `/fontes`;
  - o selo da comparação de redes de Vitória ("Censo Escolar 2025 (INEP,
    carga em 14/10/2026) · IDEB e SAEB 2005–2023 (INEP, carga não registrada)
    · Malha municipal 2024 …");
  - o selo do financeiro (SIOPE 2024–2026).
- Um separador sem espaço ("2026)· IDEB") só apareceu no navegador, porque o
  Svelte apara o espaço no início do texto de um elemento. Foi corrigido com
  `{" · "}` e ganhou teste.

## Deploy

No LXC: `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`.
