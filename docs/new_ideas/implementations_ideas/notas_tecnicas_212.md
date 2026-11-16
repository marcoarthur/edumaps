# Nota técnica 212: itens inexistentes de infraestrutura e coordenadas na base (#452)

Achados VJ-01 e VJ-04 da terceira avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-16-p6-jornalismo.md`). Um PR:
#455 (merge `d418e9d`). Só backend e documentação: a tela lê o catálogo.

## VJ-01: "rede pública = 0" não é "sem"

O bloco de infraestrutura repetia as 11 colunas do agrupamento. Energia e
esgoto vinham só como "da rede pública", e a pauta "escolas sem
infraestrutura básica" saía errada: no Piauí, 2.725 escolas têm esgoto fora
da rede pública, e só 179 não têm esgoto nenhum (energia: 43 contra 10).

- `in_agua_inexistente`, `in_energia_inexistente` e `in_esgoto_inexistente`
  entram no bloco, cada uma ao lado do serviço. São colunas do próprio
  Censo (`clean.censo_escolas`), preenchidas em todas as escolas em
  funcionamento.
- As descrições de `in_agua_potavel`, `in_energia_rede_publica` e
  `in_esgoto_rede_publica` dizem que 0 não quer dizer "sem" e apontam a
  coluna certa. O aviso vai no dicionário, que viaja com o arquivo, e
  também na ajuda.
- O agrupamento não muda: as 11 colunas dele são o conjunto pronto de
  indicadores, e a base tem 3 a mais.

## VJ-04: coordenadas

- `latitude` e `longitude` entram no fim da identificação, como declaradas
  ao Censo e sem verificação. A célula fica vazia quando o Censo não traz:
  145.734 das 180.540 escolas em funcionamento têm coordenada (81%). Duas
  estão fora do Brasil e saem como estão, pela mesma regra do resto da base
  ("publicados pelo INEP, sem correção").
- **Formato:** o gerador de CSV escrevia os números com 6 dígitos
  significativos, o que corta −10,123456 em −10,1235 (cerca de 11 m).
  - O quarto campo da definição de coluna, que dizia só "numérica", passa a
    aceitar `coord`: 6 casas fixas (cerca de 0,1 m) e vírgula.
  - As outras colunas não mudam.
- É a coordenada da escola, a mesma do Catálogo de Escolas do INEP: não é
  dado pessoal.

## Validação

- **Perl** (`base_analise.t`):
  - uma escola com fossa (fora da rede, com esgoto) e outra sem esgoto;
  - a ordem das colunas;
  - a coordenada com mais casas sai `-9,974321`, e sem coordenada a célula
    fica vazia;
  - os avisos no dicionário e o bloco com 14 colunas.
- **Suíte:** 193 arquivos e 1712 testes. CI verde.
- **Dados reais (PI):**
  - 4.017 escolas e 25 colunas;
  - 21 sem água, 10 sem energia e 179 sem esgoto;
  - 3.196 com coordenada, e a primeira confere com o banco.

## Deploy

Só backend, sem migração. Entra no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
