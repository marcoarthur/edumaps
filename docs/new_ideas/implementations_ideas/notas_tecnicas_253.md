# Nota técnica 253: nomes acentuados da folha do SIOPE (#536)

Achado QO-02 da segunda avaliação da P5
(`docs/personas/publicos/avaliacoes/2026-11-23-p5-auditoria-cuiaba.md`).
Issue aberta com a aprovação do developer. O plano foi aprovado com as
opções A1 e B1, e o download das planilhas também foi autorizado. Um PR:
#538 (merge `91cac01`).

## O problema

- **QO-02 (atrapalha).** Na folha de Cuiabá, todo nome com acento estava
  quebrado: cerca de 440 nomes, em 2.514 linhas de 2025 e 1.572 de 2026.
  O auditor confere os profissionais com o portal da transparência pelo
  nome, e esses não batiam.
- A carga convertia a planilha em CSV (`xlsxio`) e já corrigia à mão a
  categoria. A suspeita era a conversão.

## Diagnóstico

- **Download sem captcha:** as planilhas de Cuiabá de 2025 (11,0 MB) e
  2026 (7,7 MB) foram baixadas com o módulo da própria carga e o captcha
  vazio (o developer confirmou que o SIOPE aceita), sem gravar no banco.
- **Leitura do XML:** os nomes vêm como entidades numéricas. **O defeito
  é da fonte:**
  - **2026:** `&#195;&#135;` ("Ã" + U+0087) no lugar de "Ç", que é UTF-8
    codificado duas vezes;
  - **2025:** `&#195;&#191;` ("Ã¿", 2.841 vezes), com a letra já perdida.
- Recarregar não resolveria. A correção foi para a carga e o banco.

## Decisões

- **`EduMaps::Util::Mojibake`:**
  - "Ã" ou "Â" seguidos de um caractere da faixa U+0080 a U+00BF marcam o
    UTF-8 lido como Latin-1. O texto volta a bytes Latin-1 e é lido como
    UTF-8, com `FB_CROAK`;
  - se não couber em Latin-1 ou não formar UTF-8 válido, fica como veio;
  - "ÿ" (a letra perdida) vira "?" (B1). Nenhum nome brasileiro tem "ÿ".
- **A carga aplica a correção a todas as colunas.** A correção à mão da
  categoria ("magistério", "educação") continua valendo, também na forma
  U+FFFD que sai da decodificação.
- **Recarga sem duplicar:** a carga só inseria, e recarregar duplicava as
  linhas. Agora apaga a folha do município e do ano e insere a nova numa
  transação.
- **Change `remuneracao_nomes_utf8` (reparo do banco):**
  - decodifica nome a nome num bloco com exceção por nome;
  - recupera a letra perdida de outra linha do mesmo município e CPF
    mascarado (`xxx.999.999-xx`), com o nome no mesmo formato (`LIKE`, "ÿ"
    vira `_`) e um só candidato. A maior parte veio da folha de 2026;
  - o resto vira "?".
  - O revert não desfaz o dado, porque o texto anterior era o defeito.
- **Tela:** a folha da escola diz quando algum nome tem "?".

## Validação

- **Leitura corrigida nas planilhas:** nenhum nome continua quebrado. Em
  2025 voltam "Á" (213) e "Í" (111).
- **Banco local depois da change:**
  - 2026 ficou todo certo;
  - em 2025 sobram 93 linhas com "?", de 26 profissionais (219 tinham a
    letra perdida, e 193 voltaram pelo CPF);
  - a escola da avaliação mostra o sobrenome com "Ç".
- **Testes:**
  - Perl, 1.851 testes, com `mojibake.t`, `remuneracao_nomes.t` e
    `siope_recarga.t` (planilha simulada: a recarga dá 3 linhas, e não 5);
  - vitest, 1.393;
  - CI do PR verde (Perl, R, vitest e build).

## Pendências

- No LXC: `deploy_db_dev` (a change repara a folha de lá também),
  `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`.
- Os 26 profissionais com "?" só voltam se o FNDE corrigir a fonte.
