-- Deploy edumaps:indicadores_gestao_docente to pg
-- requires: censo_gestor
-- requires: censo_docentes

BEGIN;
  -- ============================================================
  -- 1. Indicadores do Gestor Escolar
  -- ============================================================

  CREATE OR REPLACE FUNCTION clean.gestor_indicators(p_co_entidade BIGINT)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
      gestor RECORD;
  BEGIN
      SELECT 
          COALESCE(qt_gest_bas, 0) AS total_gestores,
          COALESCE(qt_gest_bas_esco_sup_grad, 0) AS tem_superior,
          COALESCE(qt_gest_bas_esco_sup_grad_licen, 0) AS tem_licenciatura,
          COALESCE(qt_gest_bas_esco_sup_pos_espec, 0) AS tem_especializacao,
          COALESCE(qt_gest_bas_esco_sup_pos_mestra, 0) AS tem_mestrado,
          COALESCE(qt_gest_bas_esco_sup_pos_douto, 0) AS tem_doutorado,
          COALESCE(qt_gest_bas_vinculo_concur, 0) AS concursados,
          COALESCE(qt_gest_bas_vinculo_contra, 0) AS contratados,
          COALESCE(qt_gest_bas_acesso_cargo_eleic, 0) AS acesso_eleicao,
          COALESCE(qt_gest_bas_acesso_cargo_conca, 0) AS acesso_concurso,
          COALESCE(qt_gest_bas_acesso_cargo_indic, 0) AS acesso_indicacao,
          COALESCE(qt_gest_bas_fem, 0) AS gestoras_feminino,
          COALESCE(qt_gest_bas_masc, 0) AS gestores_masculino,
          COALESCE(qt_gest_bas_pcd, 0) AS gestores_pcd,
          COALESCE(qt_gest_bas_espec_gestao, 0) AS form_gestao,
          COALESCE(qt_gest_bas_espec_ed_especial, 0) AS form_ed_especial,
          COALESCE(qt_gest_bas_diretor, 0) AS diretores,
          COALESCE(qt_gest_bas_outro, 0) AS outros_cargos
      INTO gestor
      FROM clean.censo_gestor
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN JSON_BUILD_OBJECT('erro', 'Gestor não encontrado para esta escola');
      END IF;

      result_json := JSON_BUILD_OBJECT(
          'total_gestores', gestor.total_gestores,
          'perfil_formacao', JSON_BUILD_OBJECT(
              'superior', gestor.tem_superior,
              'licenciatura', gestor.tem_licenciatura,
              'especializacao', gestor.tem_especializacao,
              'mestrado', gestor.tem_mestrado,
              'doutorado', gestor.tem_doutorado,
              'pontuacao_qualificacao', ROUND(
                  (gestor.tem_superior * 2 +
                   gestor.tem_licenciatura * 3 +
                   gestor.tem_especializacao * 4 +
                   gestor.tem_mestrado * 5 +
                   gestor.tem_doutorado * 6)::NUMERIC / 
                  NULLIF(gestor.total_gestores, 0), 1
              )
          ),
          'vinculo', JSON_BUILD_OBJECT(
              'concursados', gestor.concursados,
              'contratados', gestor.contratados,
              'percentual_estavel', ROUND(gestor.concursados::NUMERIC / NULLIF(gestor.total_gestores, 0) * 100, 1)
          ),
          'acesso_cargo', JSON_BUILD_OBJECT(
              'eleicao', gestor.acesso_eleicao,
              'concurso', gestor.acesso_concurso,
              'indicacao', gestor.acesso_indicacao,
              'pontuacao_democratico', ROUND(
                  (gestor.acesso_eleicao * 10 + gestor.acesso_concurso * 8)::NUMERIC / 
                  NULLIF(gestor.total_gestores, 0), 1
              )
          ),
          'diversidade', JSON_BUILD_OBJECT(
              'percentual_feminino', ROUND(gestor.gestoras_feminino::NUMERIC / NULLIF(gestor.total_gestores, 0) * 100, 1),
              'percentual_masculino', ROUND(gestor.gestores_masculino::NUMERIC / NULLIF(gestor.total_gestores, 0) * 100, 1),
              'percentual_pcd', ROUND(gestor.gestores_pcd::NUMERIC / NULLIF(gestor.total_gestores, 0) * 100, 1)
          ),
          'formacao_continuada', JSON_BUILD_OBJECT(
              'gestao_escolar', gestor.form_gestao,
              'educacao_especial', gestor.form_ed_especial,
              'possui_especializacao', gestor.form_gestao > 0 OR gestor.form_ed_especial > 0
          ),
          'cargos', JSON_BUILD_OBJECT(
              'diretores', gestor.diretores,
              'outros_cargos', gestor.outros_cargos
          )
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  -- ============================================================
  -- 2. Indicadores do Corpo Docente
  -- ============================================================

  CREATE OR REPLACE FUNCTION clean.docente_indicators(p_co_entidade BIGINT)
  RETURNS JSON AS $$
  DECLARE
      docente RECORD;
      matriculas BIGINT;
      result_json JSON;
  BEGIN
      -- Busca dados dos docentes
      SELECT 
          COALESCE(qt_doc_bas, 0) AS total_docentes,
          COALESCE(qt_doc_bas_esco_sup_grad, 0) AS ensino_superior,
          COALESCE(qt_doc_bas_esco_sup_grad_licen, 0) AS licenciatura,
          COALESCE(qt_doc_bas_esco_sup_pos_espec, 0) AS especializacao,
          COALESCE(qt_doc_bas_esco_sup_pos_mestra, 0) AS mestrado,
          COALESCE(qt_doc_bas_esco_sup_pos_douto, 0) AS doutorado,
          COALESCE(qt_doc_bas_vinculo_concur, 0) AS concursados,
          COALESCE(qt_doc_bas_vinculo_contra, 0) AS contratados,
          COALESCE(qt_doc_bas_vinculo_clt, 0) AS clt,
          COALESCE(qt_doc_bas_instrutor_ep, 0) AS instrutores_ep,
          COALESCE(qt_doc_bas_apoio_pcd, 0) AS apoio_pcd,
          COALESCE(qt_doc_bas_libras, 0) AS proficiencia_libras,
          COALESCE(qt_doc_bas_guia_interprete, 0) AS interprete_libras,
          COALESCE(qt_doc_bas_fem, 0) AS docentes_feminino,
          COALESCE(qt_doc_bas_masc, 0) AS docentes_masculino,
          COALESCE(qt_doc_bas_pcd, 0) AS docentes_pcd,
          COALESCE(qt_doc_bas_0_24, 0) AS idade_ate_24,
          COALESCE(qt_doc_bas_25_29, 0) AS idade_25_29,
          COALESCE(qt_doc_bas_30_39, 0) AS idade_30_39,
          COALESCE(qt_doc_bas_40_49, 0) AS idade_40_49,
          COALESCE(qt_doc_bas_50_54, 0) AS idade_50_54,
          COALESCE(qt_doc_bas_55_59, 0) AS idade_55_59,
          COALESCE(qt_doc_bas_60_mais, 0) AS idade_60_mais,
          COALESCE(qt_doc_bas_docente, 0) AS regencia_classe,
          COALESCE(qt_doc_bas_auxiliar, 0) AS auxiliares
      INTO docente
      FROM clean.censo_docentes
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN JSON_BUILD_OBJECT('erro', 'Docentes não encontrados para esta escola');
      END IF;

      -- Busca total de alunos para relação aluno-docente
      SELECT COALESCE(qt_mat_bas, 0) INTO matriculas
      FROM clean.censo_matriculas
      WHERE co_entidade = p_co_entidade;

      -- Constroi JSON
      result_json := JSON_BUILD_OBJECT(
          'total_docentes', docente.total_docentes,
          'qualificacao_academica', JSON_BUILD_OBJECT(
              'ensino_superior', docente.ensino_superior,
              'licenciatura', docente.licenciatura,
              'especializacao', docente.especializacao,
              'mestrado', docente.mestrado,
              'doutorado', docente.doutorado,
              'pontuacao_qualificacao', ROUND(
                  (docente.ensino_superior * 1 +
                   docente.licenciatura * 2 +
                   docente.especializacao * 3 +
                   docente.mestrado * 4 +
                   docente.doutorado * 5)::NUMERIC / 
                  NULLIF(docente.total_docentes, 0), 1
              ),
              'percentual_especializacao', ROUND(docente.especializacao::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              'percentual_pos_stricto', ROUND((docente.mestrado + docente.doutorado)::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1)
          ),
          'vinculo_empregaticio', JSON_BUILD_OBJECT(
              'concursados', docente.concursados,
              'contratados', docente.contratados,
              'clt', docente.clt,
              'percentual_estavel', ROUND(docente.concursados::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1)
          ),
          'distribuicao_etaria', JSON_BUILD_OBJECT(
              'ate_24', ROUND(docente.idade_ate_24::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              '25_29', ROUND(docente.idade_25_29::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              '30_39', ROUND(docente.idade_30_39::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              '40_49', ROUND(docente.idade_40_49::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              '50_59', ROUND((docente.idade_50_54 + docente.idade_55_59)::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              '60_mais', ROUND(docente.idade_60_mais::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              'pontuacao_experiencia', ROUND(
                  (docente.idade_30_39 * 5 + docente.idade_40_49 * 4 + 
                   (docente.idade_50_54 + docente.idade_55_59) * 3)::NUMERIC / 
                  NULLIF(docente.total_docentes, 0), 1
              )
          ),
          'diversidade_inclusao', JSON_BUILD_OBJECT(
              'percentual_feminino', ROUND(docente.docentes_feminino::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              'percentual_masculino', ROUND(docente.docentes_masculino::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              'percentual_pcd', ROUND(docente.docentes_pcd::NUMERIC / NULLIF(docente.total_docentes, 0) * 100, 1),
              'apoio_educacao_especial', docente.apoio_pcd,
              'proficiencia_libras', docente.proficiencia_libras,
              'interpretes_libras', docente.interprete_libras
          ),
          'atuacao_educacao_profissional', JSON_BUILD_OBJECT(
              'instrutores_ep', docente.instrutores_ep,
              'regencia_classe', docente.regencia_classe,
              'auxiliares', docente.auxiliares
          ),
          'relacao_aluno_docente', JSON_BUILD_OBJECT(
              'total_alunos', matriculas,
              'alunos_por_docente', ROUND(matriculas::NUMERIC / NULLIF(docente.total_docentes, 0), 1)
          )
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  -- ============================================================
  -- 3. Indicadores Consolidados da Escola (Gestão + Docente)
  -- ============================================================

  CREATE OR REPLACE FUNCTION clean.school_indicators(p_co_entidade BIGINT)
  RETURNS JSON AS $$
  DECLARE
      gestor_json JSON;
      docente_json JSON;
  BEGIN
      gestor_json := clean.gestor_indicators(p_co_entidade);
      docente_json := clean.docente_indicators(p_co_entidade);
      
      RETURN JSON_BUILD_OBJECT(
          'co_entidade', p_co_entidade,
          'gestor', gestor_json,
          'docente', docente_json,
          'score_gestao', 
              (COALESCE((gestor_json->'perfil_formacao'->>'pontuacao_qualificacao')::NUMERIC, 0) * 0.3 +
               COALESCE((gestor_json->'vinculo'->>'percentual_estavel')::NUMERIC, 0) * 0.2 / 100 +
               COALESCE((gestor_json->'acesso_cargo'->>'pontuacao_democratico')::NUMERIC, 0) * 0.3 +
               COALESCE((gestor_json->'diversidade'->>'percentual_feminino')::NUMERIC, 0) * 0.1 / 100 +
               COALESCE((gestor_json->'formacao_continuada'->>'gestao_escolar')::NUMERIC, 0) * 0.1)::NUMERIC(5,2),
          'score_docente',
              (COALESCE((docente_json->'qualificacao_academica'->>'pontuacao_qualificacao')::NUMERIC, 0) * 0.35 +
               COALESCE((docente_json->'vinculo_empregaticio'->>'percentual_estavel')::NUMERIC, 0) * 0.25 / 100 +
               COALESCE((docente_json->'distribuicao_etaria'->>'pontuacao_experiencia')::NUMERIC, 0) * 0.25 +
               COALESCE((docente_json->'diversidade_inclusao'->>'percentual_feminino')::NUMERIC, 0) * 0.05 / 100 +
               COALESCE((docente_json->'diversidade_inclusao'->>'apoio_educacao_especial')::NUMERIC, 0) * 0.10)::NUMERIC(5,2)
      );
  END;
  $$ LANGUAGE plpgsql;
COMMIT;
