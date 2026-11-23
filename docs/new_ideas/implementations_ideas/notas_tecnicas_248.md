# Nota técnica 248: rótulos curtos no agrupamento e a privada sem comparação de concursados (#526, #527)

Sobras do ciclo da #524 (nota técnica 247, "Pendências"). As issues foram
abertas e implementadas sozinho, a pedido do developer (ausente). Um PR:
#528 (merge `ed5e5c0`), com a permissão de merge dada depois.

## O problema

- **#526.** Na tela do agrupamento, os indicadores escolhidos (chips) e as
  opções da busca mostravam o comentário inteiro do banco, com a fórmula
  entre parênteses. O resumo dos grupos e a caixa Universo já usavam o
  rótulo curto, e a mesma tela falava de dois jeitos do mesmo indicador.
- **#527.** Desde a #524, a escola privada tem os concursados vazios. No
  perfil dela, porém, o município e o Brasil continuavam com valores
  (32,5% e 52,4% em Franca), que são médias só das públicas, sem nenhuma
  explicação.

## Decisões

- **Uma função de rótulo** (`rotuloCurto`, em `constants/cluster.js`). Ela
  serve aos chips, à busca, ao resumo e à Universo. O comentário inteiro
  fica no `title`, e a busca continua usando o comentário e o nome da
  coluna.
- **No motor R, a regra "só na pública"** (`PROFILE_SO_PUBLICA`):
  - na escola privada (`tp_dependencia` 4, que agora vai no metadata), a
    linha fica sem escola, município, rede, Brasil, grupo, quartil e
    sinal, e ganha a `nota` com o motivo;
  - o frontend mostra a nota sob o rótulo;
  - na escola pública, nada muda;
  - a versão do cache do perfil foi de 8 para 9;
  - se outro indicador passar a ter a mesma regra, basta incluí-lo em
    `PROFILE_SO_PUBLICA`.

## Validação

- **Docker local:** no perfil da 35004827, a linha de concursados aparece
  com "–" em tudo e o motivo; no agrupamento de SP, os chips trazem
  "Proporção de docentes concursados" e "Docentes sem formação
  continuada".
- **Testes:**
  - Perl: 1.821 testes;
  - R: perfil da privada e da pública;
  - vitest: 1.380 testes (`FeatureSelect` e `ProfileComparison`);
  - CI do PR verde nos três workflows.

## Pendências

- No LXC: `deploy_backend_dev`, `deploy_minion_dev`, `deploy_analytics_dev`
  e `deploy_frontend_dev`.
