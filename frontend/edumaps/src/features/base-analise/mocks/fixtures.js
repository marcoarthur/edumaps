// src/features/base-analise/mocks/fixtures.js
const col = (coluna, descricao) => ({ coluna, descricao });

export const BASE_ANALISE_FIXTURE = {
  blocos: [
    { id: "identificacao", label: "Identificação", fixo: true, fonte: "censo",
      descricao: "INEP, nome, município, UF, rede e localização da escola (sempre incluído).",
      colunas: [col("inep", "Código INEP da escola"), col("escola", "Nome da escola")] },
    { id: "etapas", label: "Etapas oferecidas", fixo: false, fonte: "censo",
      descricao: "Se a escola oferece cada etapa.",
      colunas: [col("oferece_ai", "Oferece os anos iniciais"), col("oferece_af", "Oferece os anos finais")] },
    { id: "infraestrutura", label: "Infraestrutura", fixo: false, fonte: "censo",
      descricao: "Água, energia, esgoto, lixo, banheiro, biblioteca, laboratórios, quadra, internet e rampas.",
      colunas: [col("in_agua_potavel", "Tem água potável (1 = sim, 0 = não)"), col("in_internet", "Tem internet (1 = sim, 0 = não)")] },
    { id: "docencia", label: "Docência", fixo: false, fonte: "censo",
      descricao: "Número de docentes e proporções de formação.",
      colunas: [col("qt_docentes", "Docentes da educação básica (total)")] },
    { id: "desempenho", label: "IDEB e SAEB por etapa", fixo: false, fonte: "ideb",
      descricao: "IDEB, notas e aprovação nos anos iniciais (_ai), finais (_af) e no ensino médio (_em), na edição escolhida.",
      colunas: [col("ideb_ai", "IDEB observado, anos iniciais do fundamental"), col("ideb_af", "IDEB observado, anos finais do fundamental")] },
    { id: "inse", label: "Nível socioeconômico (INSE)", fixo: false, fonte: "inse",
      descricao: "INSE médio dos alunos e o nível.", colunas: [col("inse_media", "INSE médio dos alunos da escola")] },
    { id: "porte", label: "Porte do município", fixo: false, fonte: "ibge_populacao",
      descricao: "População estimada do município e a classe de tamanho do IBGE.",
      colunas: [col("populacao_municipio", "População estimada do município")] },
  ],
  redes: [
    { id: "publica", label: "Pública (federal, estadual e municipal)" },
    { id: "municipal", label: "Municipal" },
    { id: "estadual", label: "Estadual" },
    { id: "federal", label: "Federal" },
    { id: "privada", label: "Privada" },
  ],
  ufs: ["AC", "ES", "MG", "SP"],
  anos: { censo: 2025, inse: 2023, ideb: [2023, 2021, 2019], populacao: "2025" },
  total: null,
};
