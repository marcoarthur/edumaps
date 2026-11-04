-- Deploy edumaps:leitor_sem_tabelas_sensiveis to pg
-- requires: edumaps_leitor_role
-- requires: sessoes_token_hash
--
-- O papel somente-leitura edumaps_leitor (motor R do Assistente do Censo)
-- recebeu SELECT em todo o schema clean. Ele só precisa dos dados públicos
-- (Censo, avaliações, IBGE, indicadores). Esta change tira o acesso às
-- tabelas internas e com dados pessoais: contas e sessões de gestores,
-- contatos e canais, conversas, módulos do gestor, filas e eventos.
--
-- Tabela nova com dado pessoal em clean.* precisa entrar nesta lista (via
-- change nova): o ALTER DEFAULT PRIVILEGES da edumaps_leitor_role concede
-- SELECT automaticamente a toda tabela criada no schema.

BEGIN;

  DO $$
  DECLARE t text;
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
      RETURN;
    END IF;
    FOREACH t IN ARRAY ARRAY[
      'gestores','sessoes','auth_falhas','senha_redefinicoes',
      'contatos','contato_grupos',
      'canal_confirmacao_refs','canal_confirmacoes','canal_envio_destinatarios',
      'canal_envio_suspensoes','canal_envios','canal_exclusoes','canal_inscricoes',
      'canal_lista_membros','canal_listas','canal_mensagens','canal_optouts',
      'canal_qr_acessos','canal_qrcodes','canal_segmentos','canal_telegram_estado',
      'chat_conversas','chat_mensagens',
      'gestor_pesquisas','gestor_pesquisas_perguntas','gestor_pesquisas_respostas',
      'gestor_pesquisas_respostas_itens',
      'relacoes','relacoes_categorias','relacoes_documentos','relacoes_entidades',
      'relacoes_interacoes','relacoes_tarefas',
      'reunioes','reuniao_anexos','reunioes_participantes',
      'inventario_anexos','inventario_categorias','inventario_fornecedores','inventario_itens',
      'escola_documentos','escola_documentos_auditoria','escola_documentos_versoes',
      'pastas_escolares','relatorios_salvos','consentimento_versoes',
      'event_store','session_tracking',
      'minion_jobs','minion_locks','minion_schedules','minion_workers','mojo_migrations'
    ] LOOP
      IF to_regclass('clean.' || t) IS NOT NULL THEN
        EXECUTE format('REVOKE ALL ON clean.%I FROM edumaps_leitor', t);
      END IF;
    END LOOP;
  END
  $$;

COMMIT;
