// src/features/ranking-recorte/mocks/fixtures.js
export const REDES_FIXTURE = {
  indicador: { id: "ideb_anos_iniciais", label: "IDEB – Anos Iniciais" },
  ano: 2023, ano_anterior: 2021, recorte: { uf: "ES" }, minimo_escolas: 3,
  total: 3, fora_por_poucas_escolas: 2,
  redes: [
    { codigo_ibge: "3202900", municipio: "Itarana", uf: "ES", escolas: 3, media: 7.8, variacao: null, inse: 5.2, quinto_inse: 5, media_quinto_inse: 6.6, posicao: 1, posicao_variacao: null },
    { codigo_ibge: "3203304", municipio: "Mantenópolis", uf: "ES", escolas: 5, media: 7.64, variacao: 0.84, inse: 4.87, quinto_inse: 2, media_quinto_inse: 6.1, posicao: 2, posicao_variacao: 1 },
    { codigo_ibge: "3205309", municipio: "Vitória", uf: "ES", escolas: 51, media: 6.2, variacao: -0.3, inse: 5.4, quinto_inse: 5, media_quinto_inse: 6.6, posicao: 3, posicao_variacao: 2 },
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
