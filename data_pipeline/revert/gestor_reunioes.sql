-- Revert edumaps:gestor_reunioes from pg

BEGIN;

  DROP TABLE clean.reuniao_anexos;
  DROP TABLE clean.reunioes_participantes;
  DROP TABLE clean.reunioes;
  DROP TABLE clean.contatos;
  DROP TABLE clean.contato_grupos;

COMMIT;