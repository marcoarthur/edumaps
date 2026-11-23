-- Deploy edumaps:remuneracao_nomes_utf8 to pg
-- requires: raw_siope
--
-- #536 (QO-02 da P5): nomes da folha do SIOPE com o UTF-8 codificado duas
-- vezes na fonte (Cuiabá: "Ã" + U+0087 no lugar de "Ç"; o arquivo do FNDE
-- já vem assim, conferido nas planilhas de 2025 e 2026). A carga passou a
-- corrigir na leitura (EduMaps::Util::Mojibake); esta change repara o que
-- já está no banco, em três passos:
--   1. decodifica o que foi codificado duas vezes (volta a Latin-1 e lê
--      como UTF-8; o que não couber fica como está);
--   2. a letra que chegou perdida ("Ã¿", que vira "ÿ") é recuperada do
--      mesmo profissional (município e CPF mascarado iguais) em outra linha
--      com o nome certo e do mesmo formato, quando houver um só;
--   3. a que sobrar vira "?" (decisão B1).
-- Não tem revert de dado: o texto anterior era o defeito.

BEGIN;

CREATE TEMP TABLE _nomes ON COMMIT DROP AS
SELECT DISTINCT nome_profissional AS antigo, NULL::text AS novo
  FROM clean.remuneracao_municipal
 WHERE nome_profissional ~ E'[\\u00C2\\u00C3][\\u0080-\\u00BF]';

-- 1. decodificação dupla, nome a nome (um nome que não couber em Latin-1
--    ou não formar UTF-8 válido fica como está)
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT antigo FROM _nomes LOOP
    BEGIN
      UPDATE _nomes SET novo = convert_from(convert_to(r.antigo, 'LATIN1'), 'UTF8') WHERE antigo = r.antigo;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END LOOP;
END $$;

UPDATE clean.remuneracao_municipal m
   SET nome_profissional = n.novo
  FROM _nomes n
 WHERE m.nome_profissional = n.antigo AND n.novo IS NOT NULL;

-- 2. letra perdida: o nome do mesmo profissional em outra linha, com o mesmo
--    formato ("ÿ" vale uma letra qualquer), quando só houver um candidato
WITH perdidos AS (
  SELECT DISTINCT cod_municipio, cpf, nome_profissional AS nome,
         replace(replace(replace(replace(nome_profissional, E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_'), 'ÿ', '_') AS molde
    FROM clean.remuneracao_municipal
   WHERE nome_profissional LIKE '%ÿ%'
),
candidatos AS (
  SELECT p.cod_municipio, p.cpf, p.nome, b.nome_profissional AS certo
    FROM perdidos p
    JOIN clean.remuneracao_municipal b
      ON b.cod_municipio = p.cod_municipio AND b.cpf = p.cpf
     AND b.nome_profissional NOT LIKE '%ÿ%'
     AND b.nome_profissional LIKE p.molde
   GROUP BY 1, 2, 3, 4
),
unicos AS (
  SELECT cod_municipio, cpf, nome, min(certo) AS certo
    FROM candidatos GROUP BY 1, 2, 3 HAVING count(*) = 1
)
UPDATE clean.remuneracao_municipal m
   SET nome_profissional = u.certo
  FROM unicos u
 WHERE m.cod_municipio = u.cod_municipio AND m.cpf = u.cpf AND m.nome_profissional = u.nome;

-- 3. o que não voltou: "?"
UPDATE clean.remuneracao_municipal
   SET nome_profissional = replace(nome_profissional, 'ÿ', '?')
 WHERE nome_profissional LIKE '%ÿ%';

COMMIT;
