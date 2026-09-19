package EduMaps::Model::Pesquisa;
use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

with 'EduMaps::Roles::Business::Pesquisa::Gestores';
with 'EduMaps::Roles::Business::Pesquisa::Surveys';
with 'EduMaps::Roles::Business::Pesquisa::Respostas';

1;