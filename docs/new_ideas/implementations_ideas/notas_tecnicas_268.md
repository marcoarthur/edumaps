# Nota técnica 268: os docentes do Censo ao lado da folha (#567)

Achado P1-FL-01 da segunda avaliação da P1
(`docs/personas/publicos/avaliacoes/2026-11-24-p1-folha-da-escola.md`, a
folha da própria escola). Issue aberta com a aprovação do developer; plano
aprovado com as opções A1 e B1. Um PR: #569 (merge `7983c6c`).

## O problema

- **P1-FL-01 (atrapalha).** O painel financeiro da EM Tancredo Neves
  (Ubatuba) mostrava "Docentes 36" na folha de 2026; o Censo 2025 dá 62
  docentes. Nada dizia por que, e a diretora lia "metade dos professores"
  diante da secretaria.
- Em Ubatuba, 658 dos 1.374 profissionais do magistério de 2026 aparecem só
  no código da Secretaria, sem nenhuma escola.

## Decisões

- **Dois números da folha:** as pessoas pagas no ano (o número de antes) e
  a média por mês, que é a mais perto do Censo (a fotografia de um dia de
  maio). O Censo: `qt_doc_bas` do ano mais recente, como o `qt_docentes`
  da base.
- **A1, no cartão das categorias,** logo depois da lista, com a frase de
  por que podem diferir: professor pago no total da Secretaria, por outra
  rede ou por outra fonte; quem esteve na escola só parte do ano; quem está
  nela sem dar aula.
- **B1, o aviso com 10% ou mais só na Secretaria:** Ubatuba e Cuiabá 2026
  (48%) e Alta Floresta 2024 (14%) avisam; Cuiabá 2025 (1,7%), não. O
  painel não diz quais professores desta escola estão lá: o SIOPE não
  liga a pessoa da Secretaria a uma escola.
- **Só no painel da escola:** o da Secretaria já é o total.
- **O outro lado também aparece:** na EMEB Zeferino (Cuiabá 2025), a folha
  tem 66 pessoas no ano (52,3 por mês) contra 50 docentes no Censo. A
  frase cobre os dois sentidos.

## Validação

- **Docker local:** EM Tancredo Neves (2026): "Docentes na folha: 36 em
  2026 (26,5 por mês, em média). No Censo Escolar 2025: 62.", com o aviso
  de 658 dos 1.374; EMEB Zeferino 2025 sem aviso, 2026 com.
- **Testes:** Perl, 211 arquivos (novo `t/04-api/school/finance_docentes.t`);
  vitest, 1.438. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`.
- #568 (meses em vez de competências; a soma das categorias) segue aberta.
