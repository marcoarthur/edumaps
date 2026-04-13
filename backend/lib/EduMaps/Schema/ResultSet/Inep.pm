package EduMaps::Schema::ResultSet::Inep;

use Mojo::Base "EduMaps::Schema::ResultSet::Base", -signatures;

sub full_grade($self, $cod_inep) {
  my $QUERY =<<~'EOQ';
  SELECT 
      jsonb_build_object(
          'escola', jsonb_build_object(
              'id', id_escola,
              'nome', no_escola,
              'municipio', no_municipio,
              'uf', sg_uf,
              'codigo_ibge', codigo_ibge,
              'rede', rede
          ),
          'notas_por_serie', jsonb_build_object(
              'serie_1_4_anos', jsonb_build_object(
                  'matematica', jsonb_build_object(
                      '2005', ROUND((vl_nota_matematica_2005 / 500.0) * 10, 2),
                      '2007', ROUND((vl_nota_matematica_2007 / 500.0) * 10, 2),
                      '2009', ROUND((vl_nota_matematica_2009 / 500.0) * 10, 2),
                      '2011', ROUND((vl_nota_matematica_2011 / 500.0) * 10, 2),
                      '2013', ROUND((vl_nota_matematica_2013 / 500.0) * 10, 2),
                      '2015', ROUND((vl_nota_matematica_2015 / 500.0) * 10, 2),
                      '2017', ROUND((vl_nota_matematica_2017 / 500.0) * 10, 2),
                      '2019', ROUND((vl_nota_matematica_2019 / 500.0) * 10, 2),
                      '2021', ROUND((vl_nota_matematica_2021 / 500.0) * 10, 2),
                      '2023', ROUND((vl_nota_matematica_2023 / 500.0) * 10, 2)
                  ),
                  'portugues', jsonb_build_object(
                      '2005', ROUND((vl_nota_portugues_2005 / 500.0) * 10, 2),
                      '2007', ROUND((vl_nota_portugues_2007 / 500.0) * 10, 2),
                      '2009', ROUND((vl_nota_portugues_2009 / 500.0) * 10, 2),
                      '2011', ROUND((vl_nota_portugues_2011 / 500.0) * 10, 2),
                      '2013', ROUND((vl_nota_portugues_2013 / 500.0) * 10, 2),
                      '2015', ROUND((vl_nota_portugues_2015 / 500.0) * 10, 2),
                      '2017', ROUND((vl_nota_portugues_2017 / 500.0) * 10, 2),
                      '2019', ROUND((vl_nota_portugues_2019 / 500.0) * 10, 2),
                      '2021', ROUND((vl_nota_portugues_2021 / 500.0) * 10, 2),
                      '2023', ROUND((vl_nota_portugues_2023 / 500.0) * 10, 2)
                  ),
                  'media', jsonb_build_object(
                      '2005', ROUND(vl_nota_media_2005,2),
                      '2007', ROUND(vl_nota_media_2007,2),
                      '2009', ROUND(vl_nota_media_2009,2),
                      '2011', ROUND(vl_nota_media_2011,2),
                      '2013', ROUND(vl_nota_media_2013,2),
                      '2015', ROUND(vl_nota_media_2015,2),
                      '2017', ROUND(vl_nota_media_2017,2),
                      '2019', ROUND(vl_nota_media_2019,2),
                      '2021', ROUND(vl_nota_media_2021,2),
                      '2023', ROUND(vl_nota_media_2023,2)
                  )
              ),
              'serie_iniciais_1_4', jsonb_build_object(
                  'matematica', jsonb_build_object(
                      '2005', ROUND((vl_nota_matematica_2005 / 500.0) * 10, 2),
                      '2007', ROUND((vl_nota_matematica_2007 / 500.0) * 10, 2),
                      '2009', ROUND((vl_nota_matematica_2009 / 500.0) * 10, 2),
                      '2011', ROUND((vl_nota_matematica_2011 / 500.0) * 10, 2),
                      '2013', ROUND((vl_nota_matematica_2013 / 500.0) * 10, 2),
                      '2015', ROUND((vl_nota_matematica_2015 / 500.0) * 10, 2),
                      '2017', ROUND((vl_nota_matematica_2017 / 500.0) * 10, 2),
                      '2019', ROUND((vl_nota_matematica_2019 / 500.0) * 10, 2),
                      '2021', ROUND((vl_nota_matematica_2021 / 500.0) * 10, 2),
                      '2023', ROUND((vl_nota_matematica_2023 / 500.0) * 10, 2)
                  ),
                  'portugues', jsonb_build_object(
                      '2005', ROUND((vl_nota_portugues_2005 / 500.0) * 10, 2),
                      '2007', ROUND((vl_nota_portugues_2007 / 500.0) * 10, 2),
                      '2009', ROUND((vl_nota_portugues_2009 / 500.0) * 10, 2),
                      '2011', ROUND((vl_nota_portugues_2011 / 500.0) * 10, 2),
                      '2013', ROUND((vl_nota_portugues_2013 / 500.0) * 10, 2),
                      '2015', ROUND((vl_nota_portugues_2015 / 500.0) * 10, 2),
                      '2017', ROUND((vl_nota_portugues_2017 / 500.0) * 10, 2),
                      '2019', ROUND((vl_nota_portugues_2019 / 500.0) * 10, 2),
                      '2021', ROUND((vl_nota_portugues_2021 / 500.0) * 10, 2),
                      '2023', ROUND((vl_nota_portugues_2023 / 500.0) * 10, 2)
                  ),
                  'media', jsonb_build_object(
                      '2005', vl_nota_media_2005,
                      '2007', vl_nota_media_2007,
                      '2009', vl_nota_media_2009,
                      '2011', vl_nota_media_2011,
                      '2013', vl_nota_media_2013,
                      '2015', vl_nota_media_2015,
                      '2017', vl_nota_media_2017,
                      '2019', vl_nota_media_2019,
                      '2021', vl_nota_media_2021,
                      '2023', vl_nota_media_2023
                  )
              )
          ),
          'valores_observados_e_projecoes', jsonb_build_object(
              '2005', jsonb_build_object('observado', vl_observado_2005),
              '2007', jsonb_build_object(
                  'observado', vl_observado_2007,
                  'projecao', vl_projecao_2007
              ),
              '2009', jsonb_build_object(
                  'observado', vl_observado_2009,
                  'projecao', vl_projecao_2009
              ),
              '2011', jsonb_build_object(
                  'observado', vl_observado_2011,
                  'projecao', vl_projecao_2011
              ),
              '2013', jsonb_build_object(
                  'observado', vl_observado_2013,
                  'projecao', vl_projecao_2013
              ),
              '2015', jsonb_build_object(
                  'observado', vl_observado_2015,
                  'projecao', vl_projecao_2015
              ),
              '2017', jsonb_build_object(
                  'observado', vl_observado_2017,
                  'projecao', vl_projecao_2017
              ),
              '2019', jsonb_build_object(
                  'observado', vl_observado_2019,
                  'projecao', vl_projecao_2019
              ),
              '2021', jsonb_build_object(
                  'observado', vl_observado_2021,
                  'projecao', vl_projecao_2021
              ),
              '2023', jsonb_build_object(
                  'observado', vl_observado_2023
              )
          ),
          'taxas_aprovacao', jsonb_build_object(
              'serie_1_4_anos', jsonb_build_object(
                  '2005', vl_aprovacao_2005_1,
                  '2007', vl_aprovacao_2007_1,
                  '2009', vl_aprovacao_2009_1,
                  '2011', vl_aprovacao_2011_1,
                  '2013', vl_aprovacao_2013_1,
                  '2015', vl_aprovacao_2015_1,
                  '2017', vl_aprovacao_2017_1,
                  '2019', vl_aprovacao_2019_1,
                  '2021', vl_aprovacao_2021_1,
                  '2023', vl_aprovacao_2023_1
              ),
              'serie_5_8_anos', jsonb_build_object(
                  '2005', vl_aprovacao_2005_2,
                  '2007', vl_aprovacao_2007_2,
                  '2009', vl_aprovacao_2009_2,
                  '2011', vl_aprovacao_2011_2,
                  '2013', vl_aprovacao_2013_2,
                  '2015', vl_aprovacao_2015_2,
                  '2017', vl_aprovacao_2017_2,
                  '2019', vl_aprovacao_2019_2,
                  '2021', vl_aprovacao_2021_2,
                  '2023', vl_aprovacao_2023_2
              ),
              'ensino_medio', jsonb_build_object(
                  '2005', vl_aprovacao_2005_3,
                  '2007', vl_aprovacao_2007_3,
                  '2009', vl_aprovacao_2009_3,
                  '2011', vl_aprovacao_2011_3,
                  '2013', vl_aprovacao_2013_3,
                  '2015', vl_aprovacao_2015_3,
                  '2017', vl_aprovacao_2017_3,
                  '2019', vl_aprovacao_2019_3,
                  '2021', vl_aprovacao_2021_3,
                  '2023', vl_aprovacao_2023_3
              ),
              'serie_4', jsonb_build_object(
                  '2005', vl_aprovacao_2005_4,
                  '2007', vl_aprovacao_2007_4,
                  '2009', vl_aprovacao_2009_4,
                  '2011', vl_aprovacao_2011_4,
                  '2013', vl_aprovacao_2013_4,
                  '2015', vl_aprovacao_2015_4,
                  '2017', vl_aprovacao_2017_4,
                  '2019', vl_aprovacao_2019_4,
                  '2021', vl_aprovacao_2021_4,
                  '2023', vl_aprovacao_2023_4
              )
          ),
          'indicador_rendimento', jsonb_build_object(
              '2005', ROUND(vl_indicador_rend_2005,2),
              '2007', ROUND(vl_indicador_rend_2007,2),
              '2009', ROUND(vl_indicador_rend_2009,2),
              '2011', ROUND(vl_indicador_rend_2011,2),
              '2013', ROUND(vl_indicador_rend_2013,2),
              '2015', ROUND(vl_indicador_rend_2015,2),
              '2017', ROUND(vl_indicador_rend_2017,2),
              '2019', ROUND(vl_indicador_rend_2019,2),
              '2021', ROUND(vl_indicador_rend_2021,2),
              '2023', ROUND(vl_indicador_rend_2023,2)
          ),
          'dados_extras', jsonb_build_object(
              'linha_original', linha_original,
              'metadados', jsonb_build_object(
                  'escala_notas', '0-10',
                  'escala_taxas_aprovacao', 'Percentual (%)',
                  'escala_indicador_rendimento', '0-1'
              )
          )
      ) AS dados_escola_json
  FROM clean.inep
  WHERE id_escola = ?
  EOQ

  my $data = $self->custom_query($QUERY, ['dados_escola_json'], [$cod_inep] )->as_hash->first;
  return 'null' unless $data;
  return $data->{dados_escola_json};
}

1;
