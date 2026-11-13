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

// Metas comparáveis (#397)
export const REDE_INDICADORES = {
  n_escolas: 3,
  n_com_plano_vigente: 2,
  manuais: { n_metas: 2, n_escolas: 1 },
  indicadores: [
    { codigo: "ideb_ai", rotulo: "IDEB — anos iniciais", unidade: "pontos (0 a 10)", fonte: "INEP — IDEB",
      n_escolas: 2, n_metas: 2, n_medidas: 1, andamento_medio: 0.4, n_base_ajustada: 1,
      escolas: [
        { cod_inep: 11000040, nome: "EMEF Pioneiros", municipio: "Alta Floresta D'Oeste", uf: "RO", plano_id: 1, plano_titulo: "Plano de ação 2026",
          meta: { id: 100, descricao: "Subir o IDEB dos anos iniciais", sentido: "aumentar", linha_base: 5.0, linha_base_oficial: 5.2,
                  base_ajustada: true, alvo: 6.0, atual: { valor: 5.4, ano_ref: 2023, data_ref: "2023-12-31" }, progresso: 0.4, estado: "medida" } },
        { cod_inep: 11000066, nome: "EMEF Rio Novo", municipio: "Alta Floresta D'Oeste", uf: "RO", plano_id: 7, plano_titulo: "Plano de gestão 2026",
          meta: { id: 700, descricao: "IDEB 6,0", sentido: "aumentar", linha_base: 4.8, linha_base_oficial: 4.8,
                  base_ajustada: false, alvo: 6.0, atual: null, progresso: null, estado: "sem_dado" } },
      ] },
    { codigo: "infra_quadra", rotulo: "Tem quadra de esportes", unidade: "sim/não", fonte: "INEP — Censo Escolar",
      n_escolas: 1, n_metas: 1, n_medidas: 0, andamento_medio: null, n_base_ajustada: 0,
      escolas: [
        { cod_inep: 11000066, nome: "EMEF Rio Novo", municipio: "Alta Floresta D'Oeste", uf: "RO", plano_id: 7, plano_titulo: "Plano de gestão 2026",
          meta: { id: 701, descricao: "Construir a quadra", sentido: "aumentar", linha_base: 0, linha_base_oficial: 0,
                  base_ajustada: false, alvo: 1, atual: null, progresso: null, estado: "sem_dado" } },
      ] },
  ],
};

// Custo por fonte na rede (#398). EMEF Pioneiros com os mesmos números do
// relatório do plano 1 dos mocks de planos; Rio Novo sem valor executado
// (null, nunca R$ 0); um plano encerrado à parte.
export const REDE_CUSTOS = {
  n_escolas: 3,
  n_com_plano_vigente: 2,
  consolidado: {
    por_fonte: [
      { fonte: "pdde", total: 1500, n_acoes: 1, executado: 900, n_executadas: 1 },
      { fonte: "fundeb", total: 3200, n_acoes: 2, executado: null, n_executadas: 0 },
    ],
    total: 4700, total_executado: 900, n_acoes_sem_custo: 2, n_acoes_sem_executado: 3, n_escolas_com_custo: 2,
  },
  encerrados: {
    por_fonte: [{ fonte: "proprio", total: 800, n_acoes: 1, executado: 750, n_executadas: 1 }],
    total: 800, total_executado: 750, n_acoes_sem_custo: 0, n_acoes_sem_executado: 0, n_planos: 1, n_escolas: 1,
  },
  escolas: [
    { cod_inep: 11000040, nome: "EMEF Pioneiros", municipio: "Alta Floresta D'Oeste", uf: "RO", plano_id: 1,
      plano_titulo: "Plano de ação 2026",
      custos: { por_fonte: [{ fonte: "pdde", total: 1500, n_acoes: 1, executado: 900, n_executadas: 1 }],
                total: 1500, total_executado: 900, n_acoes_sem_custo: 1, n_acoes_sem_executado: 1 } },
    { cod_inep: 11000066, nome: "EMEF Rio Novo", municipio: "Alta Floresta D'Oeste", uf: "RO", plano_id: 7,
      plano_titulo: "Plano de gestão 2026",
      custos: { por_fonte: [{ fonte: "fundeb", total: 3200, n_acoes: 2, executado: null, n_executadas: 0 }],
                total: 3200, total_executado: null, n_acoes_sem_custo: 1, n_acoes_sem_executado: 2 } },
  ],
};
