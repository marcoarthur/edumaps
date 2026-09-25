-- Deploy edumaps:gestor_access_role to pg
-- requires: gestor_respostas
--
-- Papel do gestor na plataforma: 'gestor' (padrão, administra a própria
-- escola) ou 'admin' (administração da instalação — Painel de Configuração).
-- A verificação é feita na aplicação (_require_admin), reutilizando o bearer.

BEGIN;

  ALTER TABLE clean.gestores
    ADD COLUMN access_role text NOT NULL DEFAULT 'gestor'
      CHECK (access_role IN ('gestor', 'admin'));

  COMMENT ON COLUMN clean.gestores.access_role IS
    'Papel na plataforma: gestor (administra a própria escola) ou admin (administra a instalação — accesso ao Painel de Configuração). Padrão: gestor.';

COMMIT;