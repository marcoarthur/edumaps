# Nota técnica 236: versão citável dos índices coerente nos textos (#501)

Achados RE-01 e RE-02 da vigésima quarta avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-19-p4-citar-indices.md`).
Um PR: #502 (merge `b2fd8f3`).

## O problema

- **RE-01 (atrapalha).** A versão citável dos índices é `indices-v6`
  (`$INDICES_VERSAO`, `/fontes`, CSV), mas a ajuda de rankings dizia "A atual
  é a `indices-v5`" e a §2.2 de `docs/analises/ivet.md`, aberta pelo link
  "Fórmula completa" do cartão de `/fontes`, dizia `indices-v2`. O teste
  `indices_versao.t` conferia só o código e o COMMENT da MV; as mudanças
  #471, #473 e #475 atualizaram uns textos e não outros.
- **RE-02 (detalhe).** A ajuda de fontes mandava conferir o SHA-256 em
  "Arquivos da última carga", e nenhuma das seis bases públicas tem
  manifesto registrado em `clean.import_metadata`.

## Decisões

- **Os textos com a versão atual entram no teste.** Um subtest em
  `indices_versao.t` lê, a partir da raiz do repositório (como o
  `ivet_versao.t`), a frase "A atual é a **`indices-vN`**" e o exemplo do
  nome do arquivo em `rankings.md`, o cabeçalho "Versão citável dos seis
  scores (#462): **`indices-vN`**" da §2.2 e os exemplos "ex.:
  `indices-vN`" das ajudas de fontes e da base de análise, contra
  `$INDICES_VERSAO`. Antes da correção, o teste falhou com `indices-v5` e
  sem a frase da §2.2.
  - **Por que não gerar os textos do registro:** as ajudas são markdown
    estático publicado também no GitHub Pages; um teste que trava a
    divergência resolve sem mudar a publicação.
- **A §2.2 traz o histórico v1…v6**, e a inclusão da diversidade passa a
  ser datada pela `indices-v2` (no IVET, `ivet-v1.4`).
- **A regra do `AGENTS.md`** ganha o passo 3 com a lista dos textos.
- **RE-02 só na ajuda:** o passo 3 diz que os arquivos aparecem quando a
  carga os registra, e que hoje nenhuma base pública tem. Registrar os
  manifestos exige recarregar as bases.

## Validação

- Perl: 199 arquivos e 1.760 testes, todos passando; CI do PR verde.
- Sem mudança de API nem de tela.

## Pendências

- Registrar o manifesto (URL e SHA-256 dos arquivos) nas próximas cargas do
  Censo, IDEB, INSE, malha e população.
