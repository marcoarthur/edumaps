# Nota técnica 241: folha da base de análise por UF e educação infantil (#512)

Achados QZ-01 a QZ-03 da vigésima nona avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-21-p4-remuneracao-base.md`).
Um PR: #513 (merge `dbd9edc`).

## O problema

- **QZ-01 (atrapalha).** O "Ano da folha (SIOPE)" da base de análise era um
  só para o Brasil: o último ano com 12 meses em algum município (2025, por
  causa de Cuiabá).
  - Ubatuba/SP só tem 2026 e Alta Floresta d'Oeste/RO só tem 2024, então as
    bases de SP e de RO saíam com a remuneração vazia no padrão, sem aviso.
  - A tela não dizia que municípios tinham folha.
  - A ajuda mandava ver a lista em `/fontes`, que não a tinha.
- **QZ-02 (detalhe).** Em Cuiabá, 53 das 167 escolas com folha são só de
  educação infantil e não têm ninguém no magistério do SIOPE: quem trabalha
  com as crianças está como "Auxiliar/Assistente Educacional".
  `prof_magisterio` vinha 0 e o salário vazio, sem o motivo.
- **QZ-03 (detalhe).** `prof_magisterio` conta as pessoas pagas no ano, uma
  mediana de 1,59 vez os docentes do Censo, e a ajuda não dizia.

## Decisões

- **O padrão da folha pela UF:**
  - `siope_padrao_uf` escolhe o último ano com 12 meses num município da UF
    que tenha escolas; sem ano completo, o mais recente da UF; sem folha na
    UF, nenhum ano, e aí vale o padrão do Brasil;
  - um município só com o total da Secretaria não conta;
  - o CSV e o dicionário sem `ano_siope` usam o mesmo padrão, para o arquivo
    bater com a tela.
- **A cobertura numa função só** (`BaseAnalise::cobertura_siope`), usada
  pelo catálogo da base (com a UF) e pelo cartão do SIOPE em `/fontes`:
  - município, UF e código IBGE vêm do Censo (`left(co_municipio, 6)` =
    `cod_municipio`);
  - por ano, os meses e as escolas;
  - **os meses são os das escolas.** Em Cuiabá 2026, julho e agosto só têm o
    total da Secretaria; contá-los dava 8 meses no lugar de 6. O município
    só com a Secretaria fica com os meses dela e 0 escolas, e a tela diz "só
    o total da Secretaria".
- **As escolas do recorte com folha, por ano** (`contar_folha`), no catálogo:
  a tela diz "N escolas deste recorte têm folha em {ano}", ou avisa que sai
  vazio e diz os anos que têm. O ano segue o padrão da UF até a pessoa
  escolher outro no seletor.
- **Colunas novas na folha**, calculadas por pessoa e mês como as outras:
  - `prof_magisterio_mes` = pessoas-mês do magistério ÷ meses com folha da
    escola;
  - `aux_educacional`, `aux_educacional_mes` e
    `salario_medio_aux_educacional`, pela categoria "Auxiliar/Assistente
    Educacional", que é padrão do SIOPE e aparece em Cuiabá, Ubatuba e
    Taubaté. O salário segue a regra do magistério: sem dezembro, com os
    vínculos da pessoa no mês somados.
- **Textos:**
  - o dicionário diz que `prof_magisterio` não é o número de docentes e dá
    o quarto motivo do salário vazio (0 no magistério, creche só com
    auxiliares);
  - a descrição do bloco cita os auxiliares;
  - a ajuda da base e a de fontes foram atualizadas.

## Validação

- **Docker local:**
  - SP sai com 2026 (Ubatuba: 47 escolas municipais em funcionamento com
    folha; Taubaté só com a Secretaria);
  - MT sai com 2025;
  - RO sai com 2024;
  - CEIC Altos da Glória: 0 no magistério, 37 auxiliares (29,1 por mês,
    R$ 3.748);
  - EMEB Ranulpho: 89 no ano, 74,8 por mês, 37 docentes no Censo;
  - validação visual do developer.
- **Correção da avaliação:** ela dizia que Cuiabá tinha 2026 de janeiro a
  junho. Julho e agosto também estão carregados, mas só com o total da
  Secretaria. Os achados não mudam.
- **Testes:**
  - Perl: `base_analise.t` (colunas novas, escola sem magistério,
    cobertura, mês só da Secretaria fora, padrão da UF, CSV sem
    `ano_siope`) e `fontes.t`; 202 arquivos e 1.771 testes;
  - vitest: 1.373 testes;
  - CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev` e `deploy_frontend_dev`, sem change de banco.
- O quadro "Como ler os números" de `/fontes` ainda dá `indices-v2` como
  exemplo de versão dos índices (a atual é a `indices-v6`). É um texto antigo,
  fora do escopo, e `t/02-models/indices_versao.t` não o confere.
