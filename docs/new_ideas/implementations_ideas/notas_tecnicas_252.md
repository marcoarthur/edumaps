# Nota técnica 252: taxa de atendimento no ranking de redes (#535)

Achado QO-01 da segunda avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-23-p5-auditoria-cuiaba.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #537 (merge `df55911`).

## O problema

- **QO-01 (atrapalha).** A taxa de atendimento da creche e da pré-escola
  (#533) só existia na comparação de redes de cada município. O tribunal
  de contas fiscaliza o estado inteiro e precisa da lista dos municípios
  abaixo da meta 1 do PNE. O ranking de redes recusava o indicador ("use
  um do IDEB/SAEB").

## Decisões

- **Leitura própria, mesma rota.** O ranking de redes do IDEB é a média
  das escolas municipais, com mínimo de escolas, variação nas mesmas
  escolas, salto atípico e quintos de INSE. Nada disso vale para a taxa.
  `redes_municipais` desvia `atendimento_creche` e `atendimento_pre` para
  `atendimento_municipios`, que reaproveita o recorte (UF, região,
  nacional), o porte e o destaque. A resposta traz `tipo: atendimento`.
- **Cada linha é um município, não a rede municipal.** As matrículas vêm
  da `analytics.mv_rede_escolas` (escolas em funcionamento, todas as
  redes) e as crianças, da `clean.populacao_idade` (Censo 2022).
- **A1:** a posição sai da taxa de todas as redes, que é a conta da meta.
  A taxa da rede municipal e o teto com as conveniadas (#520) vêm como
  colunas, e o teto só aparece quando o município tem conveniadas.
- **B1:** a posição vai da menor taxa para a maior (1ª = mais longe da
  meta), e a tela abre com menor primeiro. Trocar de indicador volta à
  ordem de fábrica de cada um, e a URL só guarda o sentido quando ele foge
  dessa ordem.
- **Meta na resposta:** o valor (0,5 ou 1) e quantos municípios do recorte
  estão abaixo dele. Cada linha diz se está abaixo.
- **Sem mínimo de crianças.** Município pequeno tem taxa instável, e a
  nota e a coluna de crianças dizem isso, sem esconder ninguém.
- **`media` = taxa** em cada linha, para a ordenação e o destaque
  genéricos da página funcionarem sem um ramo novo.
- **Taxas com uma casa decimal sempre** (45,0%, e não 45%), corrigido
  depois de ver a tela.

## Validação

- **Docker local:** em MT, 116 dos 141 municípios ficam abaixo dos 50% na
  creche. Cuiabá é a 101ª, com 44,9% em todas as redes, 34,3% na
  municipal e 38,1% com as conveniadas.
- **Teste Perl novo** (`t/04-api/ranking_atendimento.t`): a MV não aceita
  escola de teste, então o teste grava só a população por idade de
  municípios das fixtures (RO e Taquarituba, que tem conveniadas) e
  confere as taxas contra as matrículas que estão na MV.
- **Testes:** Perl, 1.833 testes; vitest, 1.391; CI do PR verde (Perl,
  vitest e build).

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`, depois da carga
  `IBGEPopulacaoIdade` da #533.
- #536 (QO-02, nomes acentuados quebrados na folha de Cuiabá) segue
  aberta e precisa baixar de novo do SIOPE.
