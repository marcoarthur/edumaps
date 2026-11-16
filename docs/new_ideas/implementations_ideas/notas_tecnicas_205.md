# Nota técnica 205: ranking com salto atípico, mínimo ajustável e ordem crescente (#437)

PR #440 (merge `4366b50`), fecha a #437: achados RV-01 e RV-04 da reavaliação
P4/P6 (`docs/personas/publicos/avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`).

## O problema

No ranking das redes do Brasil ordenado pela variação (IDEB anos finais), o
topo era de redes pequenas com saltos grandes. Exemplo: Santana do Mundaú
(AL), 3 escolas, de 6,9 a 7,2 em 2021 para 9,3 em 2023, com aprovação de
100%. Conferido no banco: o dado é o publicado pelo INEP (nota média igual ao
IDEB e aprovação de 100%), não um erro de carga. Mas a tela não dizia que o
resultado foge do comum. Na outra ponta, "onde estão as escolas sem
infraestrutura?" pedia o fim da lista, que só se lia de cima para baixo.

## Decisões (aprovadas no plano)

- **Salto atípico:** |variação − média| > 2 × desvio padrão (amostral) das
  variações das redes do recorte, nos dois sentidos. Com menos de 3 variações
  ou desvio zero, ninguém é marcado; com poucos pontos, um valor isolado nem
  consegue passar de 2 desvios. O cálculo é em Perl, sobre as linhas já
  agregadas (mesma resposta, sem outra consulta).
- **Mínimo de escolas:** o padrão continua 3 (`$MIN_ESCOLAS_REDE`), e a tela
  oferece 3, 5, 10 ou 20. A API aceita inteiros de 3 a 30; 2, 31 e 3,5 dão 400.

## Entregas

- A resposta ganha `atipico` (desvios, média e desvio da variação, limites
  inferior e superior e quantas redes foram marcadas), e cada rede ganha o
  campo `atipico`.
- **Tela:**
  - rótulo "salto atípico" em âmbar neutro, com uma explicação ao passar o
    mouse;
  - a nota de método cita a regra, os limites e o número de redes marcadas;
  - seletor de mínimo;
  - **Maior/Menor primeiro** nas duas abas. A ordenação é feita no navegador,
    sobre a lista completa; quem não tem valor (variação "–") fica sempre no
    fim; a coluna `#` mantém a posição publicada;
  - a URL guarda `minimo` e `sentido`;
  - o CSV traz `salto_atipico`, o nome com `-min<N>` e sai na ordem da tela.

## Validação

- Perl: `ranking_recorte.t` com 8 redes fictícias (UF XY), em que só a que
  salta 3 pontos é marcada; suíte `-j4`: 192 arquivos, 1700 testes. vitest:
  151 arquivos, 1299 testes.
- Navegador, IDEB anos finais do Brasil:
  - 1.759 redes, das quais 61 marcadas (cerca de 3,5%, perto do esperado para
    2 desvios);
  - limites de −0,94 a +0,93;
  - União dos Palmares, Tamboril e Santana do Mundaú, no topo, aparecem
    marcadas.

## Deploy

No LXC: `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`.
