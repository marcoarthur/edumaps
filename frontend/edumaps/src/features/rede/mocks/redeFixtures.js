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
