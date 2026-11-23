# Nota técnica 258: vagas que faltam para a meta do PNE (#547)

Achado QK-01 da avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-23-p2-expansao-creche.md`).
Issue aberta com a aprovação do developer; plano aprovado com a opção A1.
Um PR: #548 (merge `5a80642`).

## O problema

- **QK-01 (atrapalha).** A taxa de atendimento (#533 e #535) só dava a
  porcentagem. O plano municipal, o orçamento e o pedido de recursos
  (Proinfância) são escritos em vagas.
- O secretário de Vitória de Santo Antão (PE) fazia a conta à mão (2.026
  vagas de creche e 494 de pré-escola), com o risco de usar a taxa da
  rede municipal no lugar da de todas as redes.

## Decisões

- **A conta:** meta × crianças, para cima (meio aluno não é vaga), menos
  as matrículas de todas as redes. Dá 0 quando a meta foi atingida. O
  `− 1e-9` antes do `ceil` evita que 0,5 × 6.550 = 3.275,0000001 vire
  3.276.
- **Todas as redes, não a municipal:** a meta do PNE é do município
  inteiro. A rede municipal e o teto com as conveniadas continuam como
  colunas da taxa, mas as vagas são da meta.
- **A1, fora da tabela do ranking:** por município, as vagas estão no CSV
  (`vagas_faltam_meta`) e na comparação de redes. A nota do ranking dá a
  soma do recorte (`meta.vagas_faltam`), que é a pergunta de quem olha um
  estado ou uma região.
- **Comparação de redes:** a coluna "Vagas que faltam para a meta" fica ao
  lado da meta, com "—" quando ela já foi atingida, e a nota explica a
  conta e o ano da população.

## Validação

- **Docker local:**
  - Vitória de Santo Antão: 2.026 vagas de creche e 494 de pré-escola;
  - Nordeste: 405.893 vagas de creche e 134.141 de pré-escola.
- **Testes:**
  - Perl, 1.852, com as vagas conferidas município a município, a soma e
    a meta atingida;
  - vitest, 1.410;
  - CI do PR verde (Perl, vitest e build).

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- "Onde abrir vagas" (a demanda por bairro ou setor) depende de carregar
  os setores do Censo 2022 (observação da avaliação da P2).
