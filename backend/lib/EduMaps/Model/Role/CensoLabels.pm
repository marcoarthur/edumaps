package EduMaps::Model::Role::CensoLabels;

use Mojo::Base -role, -signatures;
use EduMaps::Model::Domain::CensoLabels;

# Fornece o modelo de rótulos canônicos do Censo (`censo_labels`) a qualquer
# role de negócio que precise traduzir códigos do Censo (issue #228).
#
# Vive num role partilhado — e não num `has` repetido em cada role — porque os
# modelos compõem vários roles ao mesmo tempo (ex.: EduMaps::Model::SchoolNetwork
# = Profile + Analytic + Geo). Um `has censo_labels` em cada role colidiria na
# composição ("method name conflict between roles"). Compondo o mesmo role, o
# Role::Tiny resolve o diamante e a colisão desaparece.

requires qw(schema);

has censo_labels => sub ($self) {
  EduMaps::Model::Domain::CensoLabels->new(schema => $self->schema);
};

1;
