# Nota técnica 208: avisos da base de análise (#444)

Achados BA-01, BA-03 e BA-04 da terceira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-16-p4-base-analise.md`). Um PR:
#446 (merge `f724249`). Só textos: o cálculo e o formato do arquivo não
mudam.

## BA-01: edição antiga do IDEB cruzada com o Censo mais recente

Só um Censo está carregado (2025). A base deixa escolher o IDEB de 2005 a
2023, e uma edição antiga é cruzada com a lista de escolas, a
infraestrutura e a docência de 2025. As escolas fechadas desde então saem:
no ES, das 1.209 escolas com IDEB 2019, 26 ficam fora.

- `EduMaps::BaseAnalise::descricao_ano_ideb($anos, $ano_ideb)`:
  - com a edição mais recente, a descrição fica "Edição do IDEB/SAEB";
  - com outra edição, diz o cruzamento com os dois anos.

  A descrição vai para a linha de `ano_ideb` do dicionário. O aviso viaja com
  o arquivo, não fica só na tela.
- Na página, `idebAntigo` (bloco marcado e edição diferente da primeira do
  catálogo) mostra o mesmo aviso abaixo da edição e em "Baixar". Um
  `{#snippet}` serve aos dois lugares.
- Não mudamos o comportamento (por exemplo, incluir as escolas fechadas com
  IDEB antigo). Isso pediria o Censo daquele ano, que é a série histórica,
  fora do escopo por decisão.

## BA-03: o link traz a carga mais recente

A URL guarda o recorte e os blocos, não os dados. A página e a ajuda dizem
isso e indicam o arquivo, com os anos no nome e nas colunas, como o que se
guarda para citar. Fixar a versão no link exigiria guardar cargas antigas,
o que também é série histórica e assinatura.

## BA-04: fórmula das proporções de docência

- `qt_docentes`: docentes da educação básica da escola. Quem dá aula em
  mais de uma escola conta em cada uma, que é a contagem por escola do
  Censo Escolar, a mesma ressalva das sinopses do INEP.
- Cada `prop_*`: "… ÷ docentes da escola (qt_docentes)". O denominador é
  montado de uma constante (`$DENOM`), para as cinco descrições não
  divergirem.
- A descrição do bloco Docência leva a ressalva para a tela.

## Validação

- `t/04-api/base_analise.t`: a ressalva de `ano_ideb` aparece só na edição
  antiga, e o denominador está nas cinco proporções. vitest: o aviso aparece
  só com edição antiga e some ao desmarcar o bloco; a frase do link aparece.
- Perl `-j4`: 193 arquivos, 1709 testes. vitest: 152 arquivos. CI verde.
- Stack local com as imagens reconstruídas: o dicionário real com
  `ano_ideb=2019` traz a ressalva, e no navegador o aviso aparece nos dois
  lugares.

## Deploy

Backend e frontend, sem migração. Entram no LXC pelo roteiro
`docs/admin/deploy-lxc-2026-11-16.md`.
