// src/features/ranking-recorte/mocks/fixtures.js
export const REDES_FIXTURE = {
  indicador: { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais" },
  ano: 2023, ano_anterior: 2021, recorte: { uf: "ES" }, minimo_escolas: 3, variacao_regra: "mesmas_escolas",
  populacao_fonte: { ano: "2025", descricao: "Estimativa da população do IBGE" },
  total: 3, fora_por_poucas_escolas: 2, ano_censo: 2025, escolas_fora: 7,
  atipico: { desvios: 2, media_variacao: 0.27, desvio_variacao: 0.3, limite_inferior: -0.33, limite_superior: 0.8, marcadas: 1 },
  redes: [
    { codigo_ibge: "3202900", municipio: "Itarana", uf: "ES", escolas: 3, escolas_fora: 0, escolas_variacao: 1, media: 7.8, variacao: null, atipico: false, inse: 5.2, quinto_inse: 5, media_quinto_inse: 6.6, posicao: 1, posicao_variacao: null, populacao: 11500, porte: "10_20mil" },
    { codigo_ibge: "3203304", municipio: "Mantenópolis", uf: "ES", escolas: 5, escolas_fora: 0, escolas_variacao: 5, media: 7.64, variacao: 0.84, atipico: true, inse: 4.87, quinto_inse: 2, media_quinto_inse: 6.1, posicao: 2, posicao_variacao: 1, populacao: 11800, porte: "10_20mil" },
    { codigo_ibge: "3205309", municipio: "Vitória", uf: "ES", escolas: 51, escolas_fora: 7, escolas_variacao: 40, media: 6.2, variacao: -0.3, atipico: false, inse: 5.4, quinto_inse: 5, media_quinto_inse: 6.6, posicao: 3, posicao_variacao: 2, populacao: 368000, porte: "100_500mil" },
  ],
};

export const ESCOLAS_FIXTURE = {
  indicador: { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais", fonte: "ideb" },
  ano: 2023, municipio: { codigo_ibge: "3205309", nome: "Vitória", uf: "ES" }, rede: "municipal", total: 2,
  escolas: [
    { co_entidade: "32095406", no_entidade: "EMEF MARIA MADALENA", rede: "Municipal", valor: 7.9, posicao: 1, inse: 5.94 },
    { co_entidade: "32040164", no_entidade: "EMEF EXEMPLO; TESTE", rede: "Municipal", valor: 6.1, posicao: 2, inse: null },
  ],
};

// #535 (QO-01 da P5): taxa de atendimento da creche por município.
export const ATENDIMENTO_FIXTURE = {
  tipo: "atendimento",
  indicador: { id: "atendimento_creche", label: "Atendimento em creche (0 a 3 anos)", etapa: "creche", idade: "0 a 3 anos" },
  ano: 2022,
  ano_censo: 2025,
  meta: { valor: 0.5, abaixo: 2, vagas_faltam: 1794 },
  ordem: "menor_primeiro",
  recorte: { uf: "MT" },
  portes: [],
  regioes: [],
  populacao_fonte: { ano: "2025", descricao: "Estimativa da população do IBGE" },
  populacao_idade_fonte: { ano: 2022, descricao: "Censo Demográfico do IBGE" },
  total: 3,
  redes: [
    { codigo_ibge: "5101209", municipio: "Araguainha", uf: "MT", posicao: 1, media: 0, taxa: 0, taxa_municipal: 0, teto: null,
      abaixo_meta: true, vagas_faltam_meta: 18, criancas: 36, matriculas: 0, matriculas_municipal: 0, matriculas_conveniadas: 0, populacao: 997, porte: "ate_5mil" },
    { codigo_ibge: "5103403", municipio: "Cuiabá", uf: "MT", posicao: 2, media: 0.4487, taxa: 0.4487, taxa_municipal: 0.3433, teto: 0.3806,
      abaixo_meta: true, vagas_faltam_meta: 1763, criancas: 34367, matriculas: 15421, matriculas_municipal: 11797, matriculas_conveniadas: 1284, populacao: 691875, porte: "mais_500mil" },
    { codigo_ibge: "5108402", municipio: "Várzea Grande", uf: "MT", posicao: 3, media: 0.61, taxa: 0.61, taxa_municipal: 0.4, teto: null,
      abaixo_meta: false, vagas_faltam_meta: 0, criancas: 15000, matriculas: 9150, matriculas_municipal: 6000, matriculas_conveniadas: 0, populacao: 300000, porte: "100_500mil" },
  ],
};
