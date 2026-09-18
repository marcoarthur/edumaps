package EduMaps::Model::Gestor;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

# Visão do gestor escolar: módulo isolado, própria API/Model/role.
# Reusa os ResultSets genéricos do Censo (CensoEscolas, CensoMatriculas,
# CensoDocentes) e a Model::Base — sem alterar módulos pré-existentes.

with 'EduMaps::Roles::Business::Gestor::Overview';

sub panel($self, $params = {}) {
  return $self->overview($params);
}

1;
