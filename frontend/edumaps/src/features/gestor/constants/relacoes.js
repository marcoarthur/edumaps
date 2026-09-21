// src/features/gestor/constants/relacoes.js
//
// Domínio das Relações Institucionais da escola. A taxonomia (grupos e
// finalidades) é editável no backend; aqui ficam apenas rótulos/cores e as
// sugestões iniciais usadas nos formulários.

export const RELACAO_STATUS = [
  { value: "aberta", label: "Aberta" },
  { value: "em_andamento", label: "Em andamento" },
  { value: "aguardando", label: "Aguardando" },
  { value: "concluida", label: "Concluída" },
  { value: "cancelada", label: "Cancelada" },
];

export const RELACAO_STATUS_LABELS = Object.fromEntries(
  RELACAO_STATUS.map((s) => [s.value, s.label]),
);

export const RELACAO_STATUS_BADGE = {
  aberta: "bg-blue-100 text-blue-700",
  em_andamento: "bg-amber-100 text-amber-700",
  aguardando: "bg-purple-100 text-purple-700",
  concluida: "bg-green-100 text-green-700",
  cancelada: "bg-gray-200 text-gray-600",
};

export const RELACAO_PRIORIDADES = [
  { value: "baixa", label: "Baixa" },
  { value: "media", label: "Média" },
  { value: "alta", label: "Alta" },
  { value: "urgente", label: "Urgente" },
];

export const RELACAO_PRIORIDADE_LABELS = Object.fromEntries(
  RELACAO_PRIORIDADES.map((p) => [p.value, p.label]),
);

export const RELACAO_PRIORIDADE_BADGE = {
  baixa: "bg-gray-100 text-gray-600",
  media: "bg-blue-100 text-blue-700",
  alta: "bg-amber-100 text-amber-700",
  urgente: "bg-red-100 text-red-700",
};

// Sugestões iniciais (o backend semeia a mesma lista, editável).
export const GRUPOS_SUGERIDOS = [
  "Órgãos públicos",
  "Outras escolas",
  "Fornecedores",
  "Famílias",
  "Comunidade",
  "Instituições parceiras",
  "Conselhos e representação",
];

export const FINALIDADES_SUGERIDAS = [
  "Obrigação/regulação",
  "Solicitação",
  "Prestação de contas",
  "Contratação",
  "Comunicação",
  "Parceria",
  "Participação",
  "Resolução de problema",
  "Projeto",
  "Acompanhamento",
];

export const RELACAO_LIMITS = {
  NOME_MAX: 120,
  ASSUNTO_MAX: 160,
  DESCRICAO_MAX: 2000,
};

export const INTERACAO_CANAIS = [
  "reunião",
  "e-mail",
  "telefone",
  "ofício",
  "whatsapp",
  "visita",
  "outro",
];

export const DOCUMENTO_TIPOS = [
  "ofício",
  "contrato",
  "nota fiscal",
  "ata",
  "foto",
  "outro",
];
