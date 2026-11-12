// src/features/rede/mocks/redeFixtures.js — conta de rede (#394).
export const REDE_TOKEN = "77777777-8888-4aaa-8bbb-dddddddddddd";

// tokens de convite (43 caracteres base64url)
export const CONVITE_VALIDO = "A".repeat(43);
export const CONVITE_USADO = "B".repeat(43);
export const CONVITE_VENCIDO = "C".repeat(43);

export const CONVITES = {
  [CONVITE_VALIDO]: { situacao: "valido", nome: "Técnica da Rede", email: "tecnica@prefeitura.exemplo" },
  [CONVITE_USADO]: { situacao: "usado", nome: "Técnica da Rede", email: "tecnica@prefeitura.exemplo" },
  [CONVITE_VENCIDO]: { situacao: "vencido", nome: "Outro Técnico", email: "outro@prefeitura.exemplo" },
};

export const REDE_CONTA = {
  id: 501,
  nome: "Técnica da Rede",
  email: "tecnica@prefeitura.exemplo",
  cargo: "Técnica pedagógica",
  senha_definida: true,
  convite_pendente: null,
  vinculos: [
    { id: 9001, tp_dependencia: 3, dependencia: "Municipal", co_municipio: 1100015,
      municipio: "Alta Floresta D'Oeste", uf: "RO", concedido_em: "2026-11-12T10:00:00" },
  ],
  criada_em: "2026-11-12T09:00:00",
};

export const REDE_ESCOLAS = [
  { cod_inep: 11000040, nome: "EMEF Pioneiros", dependencia: "Municipal", co_municipio: 1100015, municipio: "Alta Floresta D'Oeste", uf: "RO" },
  { cod_inep: 11000058, nome: "EMEI Pequeno Príncipe", dependencia: "Municipal", co_municipio: 1100015, municipio: "Alta Floresta D'Oeste", uf: "RO" },
];

// contas vistas pelo admin
export const ADMIN_REDE_CONTAS = [
  REDE_CONTA,
  { id: 502, nome: "Secretário Adjunto", email: "adjunto@prefeitura.exemplo", cargo: null, senha_definida: false,
    convite_pendente: { expira_em: "2026-11-19T10:00:00" }, vinculos: [], criada_em: "2026-11-12T11:00:00" },
];

export const MUNICIPIOS = { 1100015: { municipio: "Alta Floresta D'Oeste", uf: "RO" }, 3550308: { municipio: "São Paulo", uf: "SP" } };

// Painel da rede (#396): uma escola com o plano dos mocks de planos (id 1),
// uma só com rascunho e uma com plano sem metas medidas.
export const REDE_PAINEL = {
  totais: { escolas: 3, com_plano_vigente: 2, sem_plano_vigente: 1, acoes_atrasadas: 1 },
  escolas: [
    { cod_inep: 11000040, nome: "EMEF Pioneiros", dependencia: "Municipal", co_municipio: 1100015,
      municipio: "Alta Floresta D'Oeste", uf: "RO", n_planos: 2,
      plano: { id: 1, tipo: "acao", titulo: "Plano de ação 2026", inicio: "2026-02-01", fim: "2026-12-15",
               progresso: { valor: 0.4, n_medidas: 1, n_metas: 2 }, n_acoes: 2, n_concluidas: 0,
               n_atrasadas: 1, n_vencem_7d: 1, n_evidencias: 3, atualizado_em: "2026-03-09T10:00:00", n_vigentes: 1 } },
    { cod_inep: 11000058, nome: "EMEI Pequeno Príncipe", dependencia: "Municipal", co_municipio: 1100015,
      municipio: "Alta Floresta D'Oeste", uf: "RO", n_planos: 1, plano: null },
    { cod_inep: 11000066, nome: "EMEF Rio Novo", dependencia: "Municipal", co_municipio: 1100015,
      municipio: "Alta Floresta D'Oeste", uf: "RO", n_planos: 1,
      plano: { id: 7, tipo: "gestao", titulo: "Plano de gestão 2026", inicio: null, fim: null,
               progresso: { valor: null, n_medidas: 0, n_metas: 3 }, n_acoes: 4, n_concluidas: 2,
               n_atrasadas: 0, n_vencem_7d: 0, n_evidencias: 0, atualizado_em: "2026-02-01T10:00:00", n_vigentes: 2 } },
  ],
};
