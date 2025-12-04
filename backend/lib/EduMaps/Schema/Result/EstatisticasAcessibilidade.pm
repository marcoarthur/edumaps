use utf8;
package EduMaps::Schema::Result::EstatisticasAcessibilidade;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::EstatisticasAcessibilidade

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<analytics.estatisticas_acessibilidade>

=cut

__PACKAGE__->table("analytics.estatisticas_acessibilidade");
__PACKAGE__->result_source_instance->view_definition(" SELECT count(*) AS total_municipios,\n    avg(percentual_cobertura) AS cobertura_media,\n    min(percentual_cobertura) AS cobertura_minima,\n    max(percentual_cobertura) AS cobertura_maxima,\n    avg(densidade_escolas_km2) AS densidade_media,\n    count(*) FILTER (WHERE (percentual_cobertura >= (75)::double precision)) AS municipios_alta_cobertura,\n    count(*) FILTER (WHERE (percentual_cobertura < (50)::double precision)) AS municipios_baixa_cobertura,\n    count(*) FILTER (WHERE (n_escolas = 0)) AS municipios_sem_escolas\n   FROM metricas_acessibilidade_municipios");

=head1 ACCESSORS

=head2 total_municipios

  data_type: 'bigint'
  is_nullable: 1

=head2 cobertura_media

  data_type: 'double precision'
  is_nullable: 1

=head2 cobertura_minima

  data_type: 'double precision'
  is_nullable: 1

=head2 cobertura_maxima

  data_type: 'double precision'
  is_nullable: 1

=head2 densidade_media

  data_type: 'double precision'
  is_nullable: 1

=head2 municipios_alta_cobertura

  data_type: 'bigint'
  is_nullable: 1

=head2 municipios_baixa_cobertura

  data_type: 'bigint'
  is_nullable: 1

=head2 municipios_sem_escolas

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "total_municipios",
  { data_type => "bigint", is_nullable => 1 },
  "cobertura_media",
  { data_type => "double precision", is_nullable => 1 },
  "cobertura_minima",
  { data_type => "double precision", is_nullable => 1 },
  "cobertura_maxima",
  { data_type => "double precision", is_nullable => 1 },
  "densidade_media",
  { data_type => "double precision", is_nullable => 1 },
  "municipios_alta_cobertura",
  { data_type => "bigint", is_nullable => 1 },
  "municipios_baixa_cobertura",
  { data_type => "bigint", is_nullable => 1 },
  "municipios_sem_escolas",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-03 21:38:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iW0K7obKjfLyvG1mZx2h2g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
