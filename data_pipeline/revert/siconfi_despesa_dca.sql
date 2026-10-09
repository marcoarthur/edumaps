-- Revert edumaps:siconfi_despesa_dca from pg

BEGIN;

-- Restaura o schema original (fonte "tesouror" presumida, coluna-chave
-- textual). NOT NULL com DEFAULT só para permitir o revert com dados.
ALTER TABLE clean.siconfi_despesa DROP CONSTRAINT pk_siconfi_despesa;

ALTER TABLE clean.siconfi_despesa
  ADD COLUMN coluna_despesa TEXT NOT NULL DEFAULT '';

ALTER TABLE clean.siconfi_despesa
  ADD CONSTRAINT pk_siconfi_despesa
    PRIMARY KEY (codigo_ibge, exercicio, funcao, subfuncao, coluna_despesa, classificacao, dt_snapshot);

COMMENT ON TABLE clean.siconfi_despesa IS 'Despesas municipais SICONFI/Tesouro Nacional. Chave: codigo_ibge + exercicio + funcao + subfuncao + coluna_despesa + classificacao + dt_snapshot. FUNÇÃO 12 = Educação. SUBFUNÇÃO 361 = Ensino Fundamental, 362 = Ensino Médio, 363 = Educação Infantil, 364 = Educação de Jovens e Adultos, 365 = Educação Especial. SEMPRE filtrar classificacao=realizada.';
COMMENT ON COLUMN clean.siconfi_despesa.coluna_despesa IS 'Código da coluna SICONFI';

COMMIT;