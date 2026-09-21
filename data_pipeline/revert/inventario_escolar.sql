-- Revert edumaps:inventario_escolar from pg

BEGIN;

  DROP TABLE clean.inventario_anexos;
  DROP TABLE clean.inventario_itens;
  DROP TABLE clean.inventario_fornecedores;
  DROP TABLE clean.inventario_categorias;

COMMIT;
