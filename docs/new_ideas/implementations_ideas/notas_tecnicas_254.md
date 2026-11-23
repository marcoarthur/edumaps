# Nota técnica 254: fontes do ranking pelo indicador (#539)

Achado QN-01 da quinta avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-23-p6-creche-nordeste.md`).
Issue aberta com a aprovação do developer; plano aprovado com a opção A1.
Um PR: #540 (merge `39578d7`).

## O problema

- **QN-01 (atrapalha).** Com o indicador da creche ou da pré-escola (#535),
  o rodapé "Fonte:" do ranking:
  - não citava a população por idade do Censo Demográfico 2022, que é o
    denominador da taxa;
  - listava as bases do IDEB (IDEB e SAEB, INSE, Índices do EduMaps), que
    não entram na conta.
- O texto do topo falava do INSE, e a tabela da taxa não tem INSE.
- A jornalista precisava ir a `/fontes` para citar a fonte.

## Decisões

- **A1, no catálogo:** as telas de cada base continuam em
  `EduMaps::Fontes`, a única fonte da verdade. A tela nova
  `ranking_atendimento` vale para as três bases da conta: Censo Escolar,
  estimativa da população (coluna População e porte) e população por
  idade. `/fontes` diz que a população por idade é usada no "ranking da
  educação infantil".
- **A tela `ranking` não muda.** O IDEB e a aba de escolas mantêm o rodapé.
- **`FonteDado` reativo:** ele buscava e filtrava no `onMount`, então
  trocar o indicador não mudava o rodapé. Agora busca o catálogo uma vez
  (o `getFontes` já tinha cache) e filtra num `$derived` da `tela`.
- **Texto do topo pelo indicador:** na taxa de atendimento, "compare os
  municípios… pela taxa de atendimento… quem está mais longe da meta
  aparece primeiro", sem o INSE.
- **De passagem:** a ajuda de fontes dizia que nenhum cartão trazia os
  arquivos baixados, e o da população por idade já traz. Corrigido.

## Validação

- **Docker local:** no Nordeste, com mais de 500 mil habitantes, o rodapé
  mostra o Censo Escolar 2025, a estimativa de 2025 e a população por
  idade de 2022, sem IDEB, INSE nem Índices.
- **Testes:**
  - Perl, 1.852 testes, com `fontes.t` conferindo as bases de
    `ranking_atendimento`;
  - vitest, 1.395: o `FonteDado` refiltra sem buscar de novo, e o rodapé e
    o texto do topo trocam junto com o indicador;
  - CI do PR verde (Perl, vitest e build).

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #454 (registro da carga do IDEB em `/fontes`) segue aberta.
