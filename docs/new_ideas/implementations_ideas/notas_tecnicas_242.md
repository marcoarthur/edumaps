# Nota técnica 242: aviso de anos também na edição mais recente do IDEB (#514)

Achado QY-01 da trigésima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-ideb-infraestrutura.md`).
Um PR: #515 (merge `9431005`).

## O problema

- A P4 respondeu pela base de análise à pergunta do perfil dela ("quanto da
  variação do IDEB se associa à infraestrutura, controlando por rede?"). A
  base serviu:
  - leitura no R com `read.csv2`;
  - IDEB refeito pela nota média vezes o rendimento;
  - os seis índices refeitos pelo bloco R da ajuda, com 0 diferenças;
  - modelo dos anos finais com 2.271 escolas.
- **QY-01 (detalhe).** Só o Censo mais recente está carregado (2025). O
  aviso do cruzamento entre o IDEB e o Censo (#444) só aparecia com uma
  edição antiga do IDEB. A edição padrão (2023) também é de dois anos antes
  do Censo:
  - o modelo explica o IDEB com uma infraestrutura medida depois da prova;
  - as escolas fechadas no meio-tempo saem: 254 das 41.295 com IDEB dos
    anos iniciais em 2023, ou 0,6%.

## Decisões

- **A regra é "anos diferentes", não "edição antiga":**
  - `descricao_ano_ideb` traz a ressalva sempre que o ano do IDEB for
    diferente do ano do Censo, com a distância por extenso ("dois anos
    depois");
  - quando o Censo é posterior, diz que as escolas fechadas não entram e
    que, num modelo, o que vem do Censo foi medido depois do IDEB;
  - no mesmo ano, fica o texto curto.
- **`descricao_ano_inse`:** o INSE sai do questionário do SAEB e só existe
  na edição mais recente carregada. Com o IDEB na base, a descrição de
  `ano_inse` diz se é a mesma edição do IDEB ou outra.
- **Tela:**
  - o aviso amarelo usa a mesma regra (`anosDiferentes`, antes
    `idebAntigo`), com a distância e a consequência;
  - com o bloco INSE marcado, diz a edição do SAEB;
  - aparece no padrão, ao lado do seletor da edição e no passo de baixar.
- **Ajuda:** o item "Edição antiga do IDEB" virou "IDEB e Censo de anos
  diferentes". Ele explica o efeito num modelo, dá a medida das escolas
  fechadas e sugere um teste de robustez com os itens que mudam pouco (água,
  energia, esgoto).

## Validação

- **Docker local (BA, IDEB 2023):** a tela e o dicionário mostram os textos
  novos ("dois anos antes"; "a mesma do IDEB"); validação visual do
  developer.
- **Testes:**
  - Perl: `base_analise.t` (edição mais recente com a ressalva; a regra
    com anos fixos; o INSE); 202 arquivos e 1.771 testes;
  - vitest: 1.374 testes;
  - CI do PR verde.
- **Nota de processo:** a primeira espera pelo CI do PR terminou antes de o
  GitHub registrar os checks ("no checks reported") e mandou o aviso sem
  conferir nada. A espera certa aguarda os checks aparecerem antes de
  aguardar que terminem.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`, sem change de banco.
- Os rankings e a lista de escolas também cruzam o IDEB 2023 com o Censo
  2025; ficam como estão, pois já dizem a regra das escolas em
  funcionamento.
