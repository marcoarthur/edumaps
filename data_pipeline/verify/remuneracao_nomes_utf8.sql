-- Verify edumaps:remuneracao_nomes_utf8 on pg

DO $$
DECLARE
  n bigint;
BEGIN
  SELECT count(*) INTO n FROM clean.remuneracao_municipal
   WHERE nome_profissional ~ E'[\\u00C2\\u00C3][\\u0080-\\u00BF]' OR nome_profissional LIKE '%ÿ%';
  IF n > 0 THEN
    RAISE EXCEPTION '% nomes da folha ainda codificados duas vezes (#536)', n;
  END IF;
END $$;
