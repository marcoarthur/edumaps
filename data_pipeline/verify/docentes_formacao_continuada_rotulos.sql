-- Verify edumaps:docentes_formacao_continuada_rotulos on pg
--
-- Falha de verdade (DO + RAISE, #160): nenhum comentário das colunas
-- qt_doc_bas_espec_* (nem o de prop_sem_especializacao) fala em
-- "especialização", e o de qt_doc_bas_espec_nenhum diz formação continuada.

BEGIN;

DO $$
DECLARE
    n bigint;
BEGIN
    SELECT count(*) INTO n
      FROM pg_attribute a
     WHERE a.attrelid = 'clean.censo_docentes'::regclass
       AND a.attname LIKE 'qt\_doc\_bas\_espec\_%'
       AND NOT a.attisdropped
       AND col_description(a.attrelid, a.attnum) ILIKE '%especializa%';
    IF n > 0 THEN
        RAISE EXCEPTION 'censo_docentes: % colunas qt_doc_bas_espec_* ainda dizem especialização (#522)', n;
    END IF;
    IF col_description('clean.censo_docentes'::regclass,
         (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.censo_docentes'::regclass
             AND attname = 'qt_doc_bas_espec_nenhum')) NOT LIKE 'Docentes sem formação continuada%' THEN
        RAISE EXCEPTION 'qt_doc_bas_espec_nenhum sem o comentário de formação continuada (#522)';
    END IF;
    IF col_description('clean.school_indicators'::regclass,
         (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.school_indicators'::regclass
             AND attname = 'prop_sem_especializacao')) NOT LIKE '%sem formação continuada%' THEN
        RAISE EXCEPTION 'school_indicators.prop_sem_especializacao sem o comentário novo (#522)';
    END IF;
END $$;

ROLLBACK;
