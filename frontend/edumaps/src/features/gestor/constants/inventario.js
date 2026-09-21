// src/features/gestor/constants/inventario.js
//
// Domínio do Painel de Inventário Escolar. As categorias são livres (o gestor
// nomeia), mas estes valores são sugestões para padronizar unidades, estado e
// periodicidade — todos aceitos como texto livre pelo backend.

export const INVENTARIO_TIPOS = [
  { value: "recurso", label: "Recurso (bem físico)" },
  { value: "servico", label: "Serviço (conta/contrato)" },
];

export const UNIDADES = [
  "un",
  "caixa",
  "pacote",
  "resma",
  "kg",
  "litro",
  "m²",
  "conta",
  "contrato",
];

export const ESTADOS = ["novo", "bom", "regular", "ruim", "danificado"];

export const PERIODICIDADES = [
  "mensal",
  "bimestral",
  "trimestral",
  "semestral",
  "anual",
];

export const INVENTARIO_LIMITS = {
  NOME_MAX: 120,
  DESCRICAO_MAX: 2000,
  CATEGORIA_NOME_MAX: 80,
  FORNECEDOR_NOME_MAX: 120,
  ANEXO_MAX_BYTES: 10 * 1024 * 1024,
  ANEXO_EXTS: ["pdf", "docx", "xlsx", "png", "jpg", "jpeg", "txt"],
};
