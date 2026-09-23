// src/features/gestor/mocks/documentosFixtures.js
// Fixtures do módulo Documentos e Planos Escolares (árvore, versões, tags).

export const INEP_DOCUMENTOS = "11000040";

export const DOCUMENTOS_ARVORE_INICIAL = {
  pastas: [
    { id: 1, nome: "Planejamento", pasta_pai_id: null, gestor_id: 7, created_at: "2026-09-02T10:00:00", updated_at: "2026-09-02T10:00:00" },
    { id: 2, nome: "2026", pasta_pai_id: 1, gestor_id: 7, created_at: "2026-09-02T10:05:00", updated_at: "2026-09-02T10:05:00" },
    { id: 3, nome: "Conselho de Classe", pasta_pai_id: null, gestor_id: 7, created_at: "2026-09-03T09:00:00", updated_at: "2026-09-03T09:00:00" },
  ],
  documentos: [
    {
      id: 10,
      pasta_id: null,
      gestor_id: 7,
      nome: "PPP da escola.pdf",
      tags: ["PPP", "identidade"],
      criado_em: "2026-09-01T08:00:00",
      atualizado_em: "2026-09-12T09:00:00",
      versao_atual: 2,
      tamanho: 512000,
      mime: "application/pdf",
      atualizado_por: "Marina Souza",
    },
    {
      id: 11,
      pasta_id: 2,
      gestor_id: 7,
      nome: "Regimento interno.docx",
      tags: [],
      criado_em: "2026-09-05T14:00:00",
      atualizado_em: "2026-09-05T14:00:00",
      versao_atual: 1,
      tamanho: 10240,
      mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      atualizado_por: "Marina Souza",
    },
    {
      id: 12,
      pasta_id: 3,
      gestor_id: 7,
      nome: "Ata do conselho.txt",
      tags: ["conselho", "ata"],
      criado_em: "2026-09-08T16:00:00",
      atualizado_em: "2026-09-20T11:00:00",
      versao_atual: 1,
      tamanho: 2048,
      mime: "text/plain",
      atualizado_por: "Marina Souza",
    },
  ],
  tags: ["PPP", "identidade", "conselho", "ata"],
};

export const DOCUMENTOS_AUDITORIA_INICIAL = [
  { id: 5, entidade: "documento", entidade_id: 12, acao: "tags", nome: "Ata do conselho.txt", gestor: "Marina Souza", criado_em: "2026-09-20T11:05:00", detalhes: { adicionadas: ["conselho", "ata"] } },
  { id: 4, entidade: "documento", entidade_id: 12, acao: "sobrescrito", nome: "Ata do conselho.txt", gestor: "Marina Souza", criado_em: "2026-09-20T11:00:00", detalhes: { versao: 2, tamanho: 2048 } },
  { id: 3, entidade: "pasta", entidade_id: 3, acao: "criado", nome: "Conselho de Classe", gestor: "Marina Souza", criado_em: "2026-09-03T09:00:00", detalhes: { nome: "Conselho de Classe" } },
  { id: 2, entidade: "documento", entidade_id: 10, acao: "sobrescrito", nome: "PPP da escola.pdf", gestor: "Marina Souza", criado_em: "2026-09-12T09:00:00", detalhes: { versao: 2, tamanho: 512000 } },
  { id: 1, entidade: "documento", entidade_id: 10, acao: "criado", nome: "PPP da escola.pdf", gestor: "Marina Souza", criado_em: "2026-09-01T08:00:00", detalhes: { versao: 1, tamanho: 500000 } },
];

export const DOCUMENTOS_VERSAOES_EXEMPLO = [
  { versao: 2, nome_original: "PPP da escola.pdf", mime: "application/pdf", tamanho: 512000, gestor: "Marina Souza", criado_em: "2026-09-12T09:00:00" },
  { versao: 1, nome_original: "PPP da escola.pdf", mime: "application/pdf", tamanho: 500000, gestor: "Marina Souza", criado_em: "2026-09-01T08:00:00" },
];