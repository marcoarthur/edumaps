// src/features/gestor/mocks/inventarioFixtures.js
// Fixtures do Painel de Inventário Escolar (compatíveis com o backend).

export const INEP_INVENTARIO = "11000040";

// Baseline do Censo (somente leitura) — grupos com itens presentes.
export const CENSO_INVENTARIO = {
  ano: 2025,
  escola: {
    id_escola: 11000040,
    nome: "EE Prof. Marina Souza",
    municipio: "Porto Velho",
    uf: "RO",
  },
  grupos: [
    {
      key: "dispositivos",
      label: "Dispositivos",
      itens: [
        { key: "desktop_aluno", label: "Computadores (aluno)", presente: 1, qtd: 20, categoria: "Computadores" },
        { key: "tablet_aluno", label: "Tablets (aluno)", presente: 1, qtd: 8, categoria: "Tablets" },
      ],
    },
    {
      key: "equipamentos",
      label: "Equipamentos",
      itens: [
        { key: "impressora", label: "Impressora", presente: 1, qtd: 1, categoria: "Impressoras e periféricos" },
        { key: "tv", label: "Televisão", presente: 1, qtd: 3, categoria: "Equipamentos audiovisuais" },
      ],
    },
    {
      key: "servicos_basicos",
      label: "Infraestrutura e serviços básicos",
      itens: [
        { key: "agua_potavel", label: "Água potável", presente: 1, qtd: 1, categoria: "Infraestrutura e serviços básicos" },
        { key: "energia", label: "Energia da rede pública", presente: 1, qtd: 1, categoria: "Infraestrutura e serviços básicos" },
      ],
    },
  ],
};

export const CATEGORIAS_INVENTARIO = [
  { id: 1, tipo: "recurso", nome: "Computadores", origem: "censo", n_itens: 1 },
  { id: 2, tipo: "recurso", nome: "Tablets", origem: "censo", n_itens: 0 },
  { id: 3, tipo: "recurso", nome: "Impressoras e periféricos", origem: "censo", n_itens: 0 },
  { id: 4, tipo: "recurso", nome: "Equipamentos audiovisuais", origem: "censo", n_itens: 0 },
  { id: 5, tipo: "recurso", nome: "Materiais pedagógicos", origem: "censo", n_itens: 1 },
  { id: 6, tipo: "recurso", nome: "Espaços e salas", origem: "censo", n_itens: 0 },
  { id: 7, tipo: "servico", nome: "Infraestrutura e serviços básicos", origem: "censo", n_itens: 1 },
  { id: 8, tipo: "servico", nome: "Conectividade", origem: "censo", n_itens: 0 },
];

export const FORNECEDORES_INVENTARIO = [
  {
    id: 1,
    nome: "Águas de Porto Velho",
    tipo_servico: "água",
    email: "contato@aguas.test",
    telefone: "6933330000",
    site: null,
    documento: null,
    observacoes: null,
    atributos: { conta: "123-4" },
    n_itens: 1,
    updated_at: "2026-09-20T10:00:00",
  },
];

export const ITENS_INVENTARIO = [
  {
    id: 10,
    nome: "Computadores (aluno)",
    descricao: null,
    quantidade: 20,
    unidade: "un",
    estado: "bom",
    identificador: null,
    periodicidade: null,
    valor: null,
    data_aquisicao: null,
    censo_ref: "desktop_aluno",
    atributos: { origem: "censo" },
    categoria_id: 1,
    categoria_nome: "Computadores",
    categoria_tipo: "recurso",
    fornecedor_id: null,
    fornecedor_nome: null,
    n_anexos: 0,
    updated_at: "2026-09-20T10:00:00",
  },
  {
    id: 11,
    nome: "Giz de cera",
    descricao: "Caixas de giz colorido",
    quantidade: 15,
    unidade: "caixa",
    estado: "novo",
    identificador: null,
    periodicidade: null,
    valor: 12.5,
    data_aquisicao: "2026-02-10",
    censo_ref: null,
    atributos: { cor: "colorido" },
    categoria_id: 5,
    categoria_nome: "Materiais pedagógicos",
    categoria_tipo: "recurso",
    fornecedor_id: null,
    fornecedor_nome: null,
    n_anexos: 1,
    updated_at: "2026-09-20T10:00:00",
  },
  {
    id: 12,
    nome: "Conta de água",
    descricao: null,
    quantidade: 1,
    unidade: "conta",
    estado: null,
    identificador: "HID-001",
    periodicidade: "mensal",
    valor: 187.45,
    data_aquisicao: null,
    censo_ref: null,
    atributos: { vencimento: 10 },
    categoria_id: 7,
    categoria_nome: "Infraestrutura e serviços básicos",
    categoria_tipo: "servico",
    fornecedor_id: 1,
    fornecedor_nome: "Águas de Porto Velho",
    n_anexos: 0,
    updated_at: "2026-09-20T10:00:00",
  },
];

export const ANEXO_FIXTURE = {
  id: 1,
  nome_original: "nota-giz.pdf",
  mime: "application/pdf",
  tamanho: 1234,
  created_at: "2026-09-20T10:00:00",
};
