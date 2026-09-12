package EduMaps::Model::SchoolNetwork;

use Mojo::Base "EduMaps::Model::Base", -signatures;
use Role::Tiny::With;
use utf8;

our @BUSINESS_ROLES = map {
  "EduMaps::Roles::Business::SchoolNetwork::$_"
} qw/Profile Analytic Geo/;

with @BUSINESS_ROLES;

has rs => 'RedeEscolas';

sub default_columns($self) {
  state $DEFAULT_COLS = [
    qw(
      co_municipio no_municipio sg_uf no_regiao rede codigo_rede
      total_escolas total_etapas media_etapas total_matriculas total_docentes
      ideb_fund_i ideb_fund_ii ideb_medio ano_ideb
    ),
  ];
};

1;

__END__

=pod

=head1 NAME

EduMaps::Model::SchoolNetwork - Modelo da rede de escolas por município

=head1 DESCRIPTION

O Modelo representa a rede de escolas de um município, classificada por tipo
de administração (federal, estadual, municipal, privada), com informações
de matrículas e professores (Censo Escolar) e agregados de desempenho em
exames (IDEB/SAEB).

=head1 AUTHOR

EduMaps Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2026 EduMaps. All rights reserved.

This software is part of the EduMaps educational mapping platform.

=cut