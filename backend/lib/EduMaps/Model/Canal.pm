package EduMaps::Model::Canal;

use Mojo::Base 'EduMaps::Model::Base', -signatures;
use utf8;
use Role::Tiny::With;

# Módulo isolado dos canais de comunicação: lista nomeada com QR para
# autoinscrição (issue #208, Fase 0). Compõe a regra de negócio das listas e a
# config global (AppConfig) usada para `canais.inscricao.*`.
#
# Confirmação de posse do telefone nas listas (issue #212, Fase 1): compõe
# `Canal::Confirmacao` DEPOIS de Listas e AppConfig — ela requer os helpers
# SQL de Listas e a disponibilidade de canais do AppConfig.

with 'EduMaps::Roles::Business::Canal::Listas';
with 'EduMaps::Roles::Business::Config::AppConfig';
with 'EduMaps::Roles::Business::Canal::Confirmacao';

# E-mail e LGPD nas listas (issue #214, Fase 2): consentimento versionado
# (clean.consentimento_versoes), usado pela inscrição pública e pelo admin.
with 'EduMaps::Roles::Business::Canal::Consentimento';

1;