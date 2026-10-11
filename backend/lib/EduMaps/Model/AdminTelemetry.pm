package EduMaps::Model::AdminTelemetry;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

# Telemetria de sessão do Painel de Administração (/api/admin/telemetry).
# Módulo isolado que agrega os KPIs do fluxo de acesso a partir do
# event_store/session_tracking. Só agregados — nunca dado pessoal.

with 'EduMaps::Roles::Business::Admin::Telemetry';

1;
