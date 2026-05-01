-- Deploy edumaps:badge_functions to pg
-- requires: scores_view

BEGIN;
  CREATE OR REPLACE FUNCTION clean.infra_badge_bag(p_co_entidade bigint)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
      row_record RECORD;
  BEGIN
      SELECT
          COALESCE(in_agua_potavel, 0) AS agua_potavel,
          COALESCE(in_agua_rede_publica, 0) AS agua_rede,
          GREATEST(COALESCE(in_esgoto_rede_publica,0), COALESCE(in_esgoto_fossa_septica,0)) AS esgoto_adequado,
          COALESCE(in_energia_rede_publica, 0) AS energia,
          COALESCE(in_lixo_servico_coleta, 0) AS lixo_coleta
      INTO row_record
      FROM clean.censo_escolas
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN '[]'::JSON;
      END IF;

      result_json := JSON_BUILD_ARRAY(
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.agua_potavel = 1 THEN '✅' ELSE '❌' END,
              'label', 'Água potável',
              'info', CASE WHEN row_record.agua_potavel = 1 THEN 'Disponível' ELSE 'Indisponível' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.agua_rede = 1 THEN '✅' ELSE '❌' END,
              'label', 'Água rede pública',
              'info', CASE WHEN row_record.agua_rede = 1 THEN 'Sim' ELSE 'Não' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.esgoto_adequado = 1 THEN '✅' ELSE '❌' END,
              'label', 'Esgoto sanitário',
              'info', CASE WHEN row_record.esgoto_adequado = 1 THEN 'Rede ou fossa séptica' ELSE 'Inexistente ou precário' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.energia = 1 THEN '✅' ELSE '❌' END,
              'label', 'Energia elétrica',
              'info', CASE WHEN row_record.energia = 1 THEN 'Rede pública' ELSE 'Sem energia' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.lixo_coleta = 1 THEN '✅' ELSE '❌' END,
              'label', 'Coleta de lixo',
              'info', CASE WHEN row_record.lixo_coleta = 1 THEN 'Serviço público' ELSE 'Outro destino' END
          )
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION clean.accessibility_badge_bag(p_co_entidade bigint)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
      row_record RECORD;
  BEGIN
      SELECT
          COALESCE(in_banheiro_pne, 0) AS banheiro_pne,
          COALESCE(in_acessibilidade_rampas, 0) AS rampas,
          COALESCE(in_acessibilidade_corrimao, 0) AS corrimao,
          COALESCE(in_acessibilidade_sinalizacao, 0) AS sinalizacao,
          COALESCE(in_acessibilidade_pisos_tateis, 0) AS pisos_tateis,
          COALESCE(in_sala_atendimento_especial, 0) AS sala_aee
      INTO row_record
      FROM clean.censo_escolas
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN '[]'::JSON;
      END IF;

      result_json := JSON_BUILD_ARRAY(
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.banheiro_pne = 1 THEN '♿' ELSE '🚫' END,
              'label', 'Banheiro acessível',
              'info', CASE WHEN row_record.banheiro_pne = 1 THEN 'Sim' ELSE 'Não' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.rampas = 1 THEN '♿' ELSE '🚫' END,
              'label', 'Rampas',
              'info', CASE WHEN row_record.rampas = 1 THEN 'Presentes' ELSE 'Ausentes' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.corrimao = 1 THEN '✅' ELSE '❌' END,
              'label', 'Corrimãos',
              'info', CASE WHEN row_record.corrimao = 1 THEN 'Disponíveis' ELSE 'Não disponíveis' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.sinalizacao = 1 THEN '🪧' ELSE '❌' END,
              'label', 'Sinalização',
              'info', CASE WHEN row_record.sinalizacao = 1 THEN 'Inclusiva' ELSE 'Inexistente' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.pisos_tateis = 1 THEN '🦯' ELSE '❌' END,
              'label', 'Pisos táteis',
              'info', CASE WHEN row_record.pisos_tateis = 1 THEN 'Sim' ELSE 'Não' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.sala_aee = 1 THEN '📚' ELSE '❌' END,
              'label', 'Sala de AEE',
              'info', CASE WHEN row_record.sala_aee = 1 THEN 'Atendimento Especializado' ELSE 'Ausente' END
          )
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION clean.internet_badge_bag(p_co_entidade bigint)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
      row_record RECORD;
  BEGIN
      SELECT
          COALESCE(in_internet, 0) AS internet,
          COALESCE(in_banda_larga, 0) AS banda_larga,
          COALESCE(in_computador, 0) AS computador,
          COALESCE(in_laboratorio_informatica, 0) AS lab_info,
          COALESCE(in_equip_multimidia, 0) AS multimidia
      INTO row_record
      FROM clean.censo_escolas
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN '[]'::JSON;
      END IF;

      result_json := JSON_BUILD_ARRAY(
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.internet = 1 THEN '🌐' ELSE '❌' END,
              'label', 'Acesso à internet',
              'info', CASE WHEN row_record.internet = 1 THEN 'Sim' ELSE 'Não' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.banda_larga = 1 THEN '⏩' ELSE '🐢' END,
              'label', 'Banda larga',
              'info', CASE WHEN row_record.banda_larga = 1 THEN 'Disponível' ELSE 'Não disponível' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.computador = 1 THEN '💻' ELSE '❌' END,
              'label', 'Computadores',
              'info', CASE WHEN row_record.computador = 1 THEN 'Existem' ELSE 'Nenhum' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.lab_info = 1 THEN '🖥️' ELSE '❌' END,
              'label', 'Laboratório de informática',
              'info', CASE WHEN row_record.lab_info = 1 THEN 'Presente' ELSE 'Ausente' END
          ),
          JSON_BUILD_OBJECT(
              'icone', CASE WHEN row_record.multimidia = 1 THEN '📽️' ELSE '❌' END,
              'label', 'Equipamento multimídia',
              'info', CASE WHEN row_record.multimidia = 1 THEN 'Disponível' ELSE 'Não disponível' END
          )
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION clean.typification_badge(p_co_entidade bigint)
  RETURNS JSON AS $$
  DECLARE
      result_json JSON;
      dep_text TEXT;
      loc_text TEXT;
      dep_icon TEXT;
      loc_icon TEXT;
      row_record RECORD;
  BEGIN
      SELECT
          tp_dependencia,
          tp_localizacao
      INTO row_record
      FROM clean.censo_escolas
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN '{}'::JSON;
      END IF;

      -- Mapeamento dependência (valores típicos do Censo Escolar)
      dep_text := CASE row_record.tp_dependencia
          WHEN 1 THEN 'Federal'
          WHEN 2 THEN 'Estadual'
          WHEN 3 THEN 'Municipal'
          WHEN 4 THEN 'Privada'
          ELSE 'Não informada'
      END;
      dep_icon := CASE row_record.tp_dependencia
          WHEN 1 THEN '🏛️'
          WHEN 2 THEN '🏢'
          WHEN 3 THEN '🏙️'
          WHEN 4 THEN '🏫'
          ELSE '❓'
      END;

      -- Localização: 1=urbana, 2=rural
      loc_text := CASE row_record.tp_localizacao
          WHEN 1 THEN 'Urbana'
          WHEN 2 THEN 'Rural'
          ELSE 'Não informada'
      END;
      loc_icon := CASE row_record.tp_localizacao
          WHEN 1 THEN '🏙️'
          WHEN 2 THEN '🌾'
          ELSE '❓'
      END;

      result_json := JSON_BUILD_OBJECT(
          'icone_principal', dep_icon,
          'label_principal', dep_text,
          'icone_localizacao', loc_icon,
          'label_localizacao', loc_text
      );

      RETURN result_json;
  END;
  $$ LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION clean.quick_score_avaliation(p_co_entidade bigint)
  RETURNS JSON AS $$
  DECLARE
      rec RECORD;
      s_infra NUMERIC;
      s_tec NUMERIC;
      s_espacos NUMERIC;
      s_acess NUMERIC;
      s_apoio NUMERIC;
      s_material NUMERIC;
      s_diversidade NUMERIC;
      s_gestao NUMERIC;
  BEGIN
      -- Busca todos os campos necessários para calcular os scores (mesma lógica da view)
      SELECT
          -- infra
          COALESCE(in_agua_potavel,0) + COALESCE(in_agua_rede_publica,0) +
          GREATEST(COALESCE(in_esgoto_rede_publica,0), COALESCE(in_esgoto_fossa_septica,0)) +
          COALESCE(in_energia_rede_publica,0) + COALESCE(in_lixo_servico_coleta,0) AS soma_infra,
          -- tecnologia
          COALESCE(in_computador,0) + COALESCE(in_internet,0) + COALESCE(in_banda_larga,0) +
          COALESCE(in_laboratorio_informatica,0) + COALESCE(in_equip_lousa_digital,0) +
          COALESCE(in_equip_multimidia,0) AS soma_tec,
          -- espaços
          COALESCE(in_biblioteca,0) + COALESCE(in_laboratorio_ciencias,0) +
          COALESCE(in_quadra_esportes,0) + COALESCE(in_patio_coberto,0) +
          COALESCE(in_cozinha,0) + COALESCE(in_refeitorio,0) +
          COALESCE(in_auditorio,0) + COALESCE(in_parque_infantil,0) AS soma_espacos,
          -- acessibilidade
          COALESCE(in_banheiro_pne,0) + COALESCE(in_acessibilidade_rampas,0) +
          COALESCE(in_acessibilidade_corrimao,0) + COALESCE(in_acessibilidade_sinalizacao,0) +
          COALESCE(in_acessibilidade_vao_livre,0) + COALESCE(in_acessibilidade_pisos_tateis,0) +
          COALESCE(in_sala_atendimento_especial,0) AS soma_acess,
          -- apoio
          (CASE WHEN COALESCE(qt_prof_psicologo,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_fonaudiologo,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_nutricionista,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_assist_social,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_trad_libras,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_bibliotecario,0)>0 THEN 1 ELSE 0 END) +
          (CASE WHEN COALESCE(qt_prof_seguranca,0)>0 THEN 1 ELSE 0 END) AS soma_apoio,
          -- material
          COALESCE(in_material_ped_multimidia,0) + COALESCE(in_material_ped_infantil,0) +
          COALESCE(in_material_ped_cientifico,0) + COALESCE(in_material_ped_jogos,0) +
          COALESCE(in_material_ped_artisticas,0) + COALESCE(in_material_ped_desportiva,0) +
          COALESCE(in_material_ped_edu_esp,0) AS soma_material,
          -- diversidade
          COALESCE(in_comum_creche,0) + COALESCE(in_comum_pre,0) +
          COALESCE(in_comum_fund_ai,0) + COALESCE(in_comum_fund_af,0) +
          COALESCE(in_comum_medio_medio,0) + COALESCE(in_comum_eja_fund,0) +
          COALESCE(in_comum_eja_medio,0) + COALESCE(in_profissionalizante,0) AS soma_diversidade,
          -- gestão
          COALESCE(in_orgao_conselho_escolar,0) + COALESCE(in_orgao_ass_pais,0) +
          COALESCE(in_orgao_gremio_estudantil,0) + COALESCE(in_redes_sociais,0) AS soma_gestao
      INTO rec
      FROM clean.censo_escolas
      WHERE co_entidade = p_co_entidade;

      IF NOT FOUND THEN
          RETURN '[]'::JSON;
      END IF;

      -- Converte somas em scores (0-10)
      s_infra := ROUND(rec.soma_infra / 5.0 * 10, 1);
      s_tec := ROUND(rec.soma_tec / 6.0 * 10, 1);
      s_espacos := ROUND(rec.soma_espacos / 8.0 * 10, 1);
      s_acess := ROUND(rec.soma_acess / 7.0 * 10, 1);
      s_apoio := ROUND(rec.soma_apoio / 7.0 * 10, 1);
      s_material := ROUND(rec.soma_material / 7.0 * 10, 1);
      s_diversidade := ROUND(rec.soma_diversidade / 8.0 * 10, 1);
      s_gestao := ROUND(rec.soma_gestao / 4.0 * 10, 1);

      -- Monta o JSON array com classificação qualitativa e ícones inline
      RETURN JSON_BUILD_ARRAY(
          JSON_BUILD_OBJECT(
              'dimensao', 'Infraestrutura básica',
              'icone', CASE WHEN s_infra >= 6 THEN '🏗️' ELSE '⚠️' END,
              'label', CASE WHEN s_infra < 2 THEN 'muito baixo'
                            WHEN s_infra < 4 THEN 'baixo'
                            WHEN s_infra < 6 THEN 'mediano'
                            WHEN s_infra < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_infra
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Tecnologia e conectividade',
              'icone', CASE WHEN s_tec >= 6 THEN '📡' ELSE '⚠️' END,
              'label', CASE WHEN s_tec < 2 THEN 'muito baixo'
                            WHEN s_tec < 4 THEN 'baixo'
                            WHEN s_tec < 6 THEN 'mediano'
                            WHEN s_tec < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_tec
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Espaços físicos',
              'icone', CASE WHEN s_espacos >= 6 THEN '🏟️' ELSE '⚠️' END,
              'label', CASE WHEN s_espacos < 2 THEN 'muito baixo'
                            WHEN s_espacos < 4 THEN 'baixo'
                            WHEN s_espacos < 6 THEN 'mediano'
                            WHEN s_espacos < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_espacos
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Acessibilidade',
              'icone', CASE WHEN s_acess >= 6 THEN '♿' ELSE '⚠️' END,
              'label', CASE WHEN s_acess < 2 THEN 'muito baixo'
                            WHEN s_acess < 4 THEN 'baixo'
                            WHEN s_acess < 6 THEN 'mediano'
                            WHEN s_acess < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_acess
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Apoio multiprofissional',
              'icone', CASE WHEN s_apoio >= 6 THEN '👥' ELSE '⚠️' END,
              'label', CASE WHEN s_apoio < 2 THEN 'muito baixo'
                            WHEN s_apoio < 4 THEN 'baixo'
                            WHEN s_apoio < 6 THEN 'mediano'
                            WHEN s_apoio < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_apoio
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Material pedagógico',
              'icone', CASE WHEN s_material >= 6 THEN '📦' ELSE '⚠️' END,
              'label', CASE WHEN s_material < 2 THEN 'muito baixo'
                            WHEN s_material < 4 THEN 'baixo'
                            WHEN s_material < 6 THEN 'mediano'
                            WHEN s_material < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_material
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Diversidade de oferta',
              'icone', CASE WHEN s_diversidade >= 6 THEN '📚' ELSE '⚠️' END,
              'label', CASE WHEN s_diversidade < 2 THEN 'muito baixo'
                            WHEN s_diversidade < 4 THEN 'baixo'
                            WHEN s_diversidade < 6 THEN 'mediano'
                            WHEN s_diversidade < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_diversidade
          ),
          JSON_BUILD_OBJECT(
              'dimensao', 'Gestão e participação',
              'icone', CASE WHEN s_gestao >= 6 THEN '🗳️' ELSE '⚠️' END,
              'label', CASE WHEN s_gestao < 2 THEN 'muito baixo'
                            WHEN s_gestao < 4 THEN 'baixo'
                            WHEN s_gestao < 6 THEN 'mediano'
                            WHEN s_gestao < 8 THEN 'alto'
                            ELSE 'muito alto' END,
              'valor', s_gestao
          )
      );
  END;
  $$ LANGUAGE plpgsql;

COMMIT;
