# Nota técnica 257: rede distrital e conveniadas do DF (#545)

Achado QL-01 da trigésima sétima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-23-p4-atendimento-infantil.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #546 (merge `6529213`).

## O problema

- **QL-01 (atrapalha).** O Distrito Federal não tem prefeitura:
  - a rede pública é a distrital (`tp_dependencia = 2`, "estadual" no
    Censo);
  - as privadas conveniadas têm parceria com o governo distrital (esfera
    estadual, `tp_poder_publico_parceria = 2`).
- A taxa de atendimento (#533 e #535) contava como "rede municipal" só a
  dependência 3, e como conveniadas só as de parceria municipal. O DF
  aparecia com 0,0% na rede municipal e sem teto, embora 24.570
  matrículas em creche estejam em conveniadas com o governo distrital.

## Decisões

- **A1, na MV:** a change `rede_escolas_df` recria a
  `analytics.mv_rede_escolas` com a regra de `rede_escolas_conveniadas`
  ampliada. No DF (5300108), a parceria com a esfera estadual também é
  "conveniada". A comparação de redes, o ranking e qualquer outro leitor
  da MV ficam certos de uma vez.
  - O verify compara as conveniadas do DF na MV com o Censo. Sem o DF no
    banco (fixtures do CI), não há o que comparar.
  - O revert volta à definição anterior.
- **A rede local fica na leitura:** a MV continua com a rede distrital em
  `codigo_rede = 2`. O ranking soma `codigo_rede = 3` ou, no DF,
  `codigo_rede = 2`, e devolve `rede_local` (`municipal` ou `distrital`).
- **B1, rótulos:**
  - a tabela do ranking diz "Rede do município" e marca o DF com
    "distrital";
  - a comparação de redes do DF diz "Rede do DF (distrital)", e a nota
    das conveniadas diz "com o governo do DF".
- **CSV:** as colunas da rede local passaram a `matriculas_rede_local`,
  `taxa_rede_local` e `taxa_rede_local_mais_conveniadas_teto`, mais
  `rede_local`. A troca de nomes veio no mesmo dia em que o CSV nasceu
  (#535), antes de alguém depender dele.

## Validação

- **Docker local, depois do merge:**
  - DF, creche: 32,7% em todas as redes, 0,1% na rede distrital e 19,0%
    de teto;
  - MT sem mudança: 116 de 141 municípios abaixo da meta, Cuiabá em
    101º.
- **Testes:**
  - Perl, 1.852;
  - vitest, 1.410 (o quadro do DF e a tabela com a marca);
  - change no banco do CI: deploy, verify, revert e redeploy;
  - CI do PR verde (Perl, R, vitest e build).
- **A primeira reconstrução do backend falhou:** um tempo esgotado da rede
  derrubou o `carton install`, e os contêineres subiram com a imagem
  antiga. Só o md5 acusou. A segunda passou, agora com a recriação
  condicionada ao build.

## Pendências

- No LXC: `deploy_db_dev` (change `rede_escolas_df`, que recria a MV; no
  Docker local precisou do `PGOPTIONS`), `deploy_backend_dev` e
  `deploy_frontend_dev`.
- Infraestrutura (sem issue): cada build do backend reinstala as
  dependências Perl (de 10 a 50 minutos), sinal de que o cache das
  dependências não sobrevive à cópia do código.
