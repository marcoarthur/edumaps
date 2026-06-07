package EduMaps::Schema::Result::View::ClusterEscola;
use Mojo::Base "DBIx::Class::Core", -signatures;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('metricas');

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "no_entidade",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "vetor_normalizado",
  { data_type => "array", is_nullable => 0 },
  "cluster_id",
  { data_type => "integer", is_nullable => 0 },
  "geometry",
  { data_type => "geometry", is_nullable => 1, size => [18, 16896] },
);

__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
  WITH base AS (
      SELECT 
          e.co_entidade,
          e.no_entidade,
          e.geometry,
          s.score_capacidade_atendimento,
          s.score_infraestrutura,
          s.score_capacitacao_docente,
          s.score_diversidade_discente,
          s.score_capacidade_gestora,
          s.score_sustentabilidade
      FROM censo_escolas e
      JOIN mv_escolas_scores s ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
      WHERE e.co_municipio = ?
        AND e.tp_situacao_funcionamento = 1
        AND e.nu_ano_censo = 2025
  ),
  estatisticas AS (
      SELECT
          AVG(score_capacidade_atendimento) AS mean_cap,
          STDDEV(score_capacidade_atendimento) AS std_cap,
          AVG(score_infraestrutura) AS mean_infra,
          STDDEV(score_infraestrutura) AS std_infra,
          AVG(score_capacitacao_docente) AS mean_doc,
          STDDEV(score_capacitacao_docente) AS std_doc,
          AVG(score_diversidade_discente) AS mean_div,
          STDDEV(score_diversidade_discente) AS std_div,
          AVG(score_capacidade_gestora) AS mean_gest,
          STDDEV(score_capacidade_gestora) AS std_gest,
          AVG(score_sustentabilidade) AS mean_sus,
          STDDEV(score_sustentabilidade) AS std_sus
      FROM base
  ),
  normalized AS (
      SELECT
          b.co_entidade,
          b.no_entidade,
          b.geometry,
          (b.score_capacidade_atendimento - s.mean_cap) / NULLIF(s.std_cap, 0) AS z_capacidade,
          (b.score_infraestrutura - s.mean_infra) / NULLIF(s.std_infra, 0) AS z_infra,
          (b.score_capacitacao_docente - s.mean_doc) / NULLIF(s.std_doc, 0) AS z_docente,
          (b.score_diversidade_discente - s.mean_div) / NULLIF(s.std_div, 0) AS z_diversidade,
          (b.score_capacidade_gestora - s.mean_gest) / NULLIF(s.std_gest, 0) AS z_gestao,
          (b.score_sustentabilidade - s.mean_sus) / NULLIF(s.std_sus, 0) AS z_sustentabilidade
      FROM base b
      CROSS JOIN estatisticas s
  )
  SELECT
      co_entidade,
      no_entidade,
      ARRAY[z_capacidade, z_infra, z_docente, z_diversidade, z_gestao, z_sustentabilidade] AS vetor_normalizado,
      kmeans(ARRAY[z_capacidade, z_infra, z_docente, z_diversidade, z_gestao, z_sustentabilidade]::float8[], ?) OVER () + 1 AS cluster_id,
      geometry
  FROM normalized
  ORDER BY cluster_id, co_entidade
]);

sub numeric_features($self) {
  return [
    map { $self->$_ } qw(
      score_capacidade_atendimento score_capacidade_gestora score_capacitacao_docente
      score_diversidade_discente score_infraestrutura score_sustentabilidade
    )
  ];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME


=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 TABLE: <+table+>

=head1 ACCESSORS

=head1 VIEW DEFINITION

=head1 PARAMETERS


=head1 SEE ALSO

L<EduMaps::Schema::Result::MunicipiosSp>
L<EduMaps::Schema::Result::Escolas>

=head1 AUTHOR

EduMaps Team

=head1 LICENSE

Este software é código aberto sob a licença Perl

=cut
