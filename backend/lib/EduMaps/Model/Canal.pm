package EduMaps::Model::Canal;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

# Módulo isolado dos canais de comunicação: lista nomeada com QR para
# autoinscrição (issue #208, Fase 0). Compõe a regra de negócio das listas e a
# config global (AppConfig) usada para `canais.inscricao.*`.

with 'EduMaps::Roles::Business::Canal::Listas';
with 'EduMaps::Roles::Business::Config::AppConfig';

1;