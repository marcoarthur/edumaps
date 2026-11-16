# Nota técnica 216: etapas oferecidas e cobertura do IDEB na base de análise (#461)

Achado RX-02 da quinta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-indices-e-cobertura.md`).
Um PR: #463 (merge `25eb372`).

## O problema

- **A ausência do IDEB é seletiva.** Entre as escolas públicas da BA e do
  ES que oferecem anos iniciais, 12,7% das que não têm algum item básico
  (417 escolas) têm IDEB 2023, contra 44,3% das completas (9.273 escolas).
- **O efeito no modelo da P4:** só 54 das 4.218 escolas com IDEB têm alguma
  falta básica, e a associação com a infraestrutura some por seleção.
- **A base não deixava ver isso:** sem as etapas oferecidas, o IDEB vazio
  misturava "não oferece a etapa" com "oferece e não teve nota".

## O bloco "Etapas oferecidas"

- **As colunas:** oito, de `clean.censo_escolas`, com 1 = oferece e 0 = não.
  - Etapas: `oferece_creche`, `_pre`, `_ai`, `_af`, `_em`, `_eja` e
    `_profissional`.
  - Mais `classe_especial_exclusiva`, que dá contexto à inclusão da #459.
- **Os nomes são derivados:** o sufixo casa com o do IDEB (`_ai`, `_af`,
  `_em`), e o dicionário diz a coluna de origem no Censo.
- **`oferece_em`:** é `GREATEST(in_comum_medio_medio, _integrado, _normal)`,
  porque o SAEB do médio inclui o integrado e o normal. O `GREATEST` ignora
  NULL: o resultado só fica vazio se as três vierem vazias.
- **`oferece_profissional`:** fica vazio onde o Censo não traz
  `in_profissionalizante`. São 1.765 escolas no Brasil e 312 na BA e no ES.
- **Na ordem do catálogo,** o bloco vem logo depois da identificação.

## O aviso de cobertura

- **No dicionário:** as 15 colunas do bloco IDEB dizem que o vazio é "não
  oferece a etapa" (com a coluna `oferece_*` correspondente) ou "não teve
  resultado publicado". Dizem também que a falta não é aleatória.
- **Na descrição do bloco:** a mesma ressalva.
- **Na tela:** com o IDEB marcado e sem as etapas, uma dica com o botão
  "Marcar também as etapas oferecidas".
- **Na ajuda:** a seção "Quem fica sem IDEB", com o exemplo medido e duas
  linhas de R para comparar quem tem IDEB entre os grupos antes de modelar.
- **Cuidado de formato:** nenhuma descrição nova leva `;`. O CSV sai certo
  entre aspas, mas um leitor ingênuo (como o parser dos testes) quebra a
  linha nesse caractere.

## Validação

- **Perl (`base_analise.t`):**
  - o catálogo em ordem;
  - uma escola de anos iniciais sem médio;
  - o médio só integrado contando como médio;
  - a educação profissional sem resposta saindo vazia;
  - o aviso no IDEB e nas notas.
- **Suíte Perl:** passou em 2 de 3 rodadas locais seguidas. A falha não se
  reproduziu e não foi identificada, provavelmente instabilidade de
  paralelismo. O CI passou.
- **vitest:** a dica e o botão. 153 arquivos, 1331 testes.
- **Dados reais:** só com as bases baixadas da BA e do ES, a medida da
  avaliação sai idêntica à do banco (417 com 12,7% e 9.273 com 44,3%). A
  dica foi conferida no navegador.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
