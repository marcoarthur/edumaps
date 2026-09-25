package EduMaps::Model::AppConfig;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

# Configuração global da plataforma (Painel de Configuração). Módulo isolado:
# expõe a árvore de configuração e a leitura/gravação de itens (segredos
# cifrados com pgcrypto + master key do ambiente). Usado pelo
# Plugin::API::Admin (rotas /api/admin/config) e pelo Task::Chat (injeção da
# config LLM global).

with 'EduMaps::Roles::Business::Config::AppConfig';

1;