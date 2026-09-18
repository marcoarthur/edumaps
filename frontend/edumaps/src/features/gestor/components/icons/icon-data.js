// src/features/gestor/components/icons/icon-data.js
//
// Ícones do painel do gestor. Reusa o acervo já existente da feature de
// escolas (DRY) e acrescenta apenas o que falta (turno, modalidade, faixa
// etária, formação, vínculo, equipamentos, acessibilidade, etc.).
import { ICONS as SCHOOL_ICONS } from "@/features/schools/components/icons/icon-data.js";

const S = {
  sun: `<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>`,
  sunset: `<path d="M17 18a5 5 0 0 0-10 0"/><path d="M12 2v8M4.2 10.2l1.4 1.4M2 18h2M20 18h2M18.4 11.6l1.4-1.4"/><path d="M3 22h18"/>`,
  moon: `<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>`,
  clock: `<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>`,
  users: `<circle cx="9" cy="8" r="3"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.3"/><path d="M15.5 20c.2-2.7 1.8-5 4.5-5"/>`,
  monitor: `<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>`,
  heartPerson: `<circle cx="8" cy="8" r="2.8"/><path d="M2.5 20c0-3 2.5-5.5 5.5-5.5s5.5 2.5 5.5 5.5"/><path d="M17.5 9.4c1.1-1.5 3.3-1.1 3.8.6.4 1.4-.7 2.5-3.8 5.1-3.1-2.6-4.2-3.7-3.8-5.1.5-1.7 2.7-2.1 3.8-.6z"/>`,
  person: `<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-8 8-8s8 3.6 8 8"/>`,
  grid: `<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>`,
  board: `<rect x="3" y="4" width="18" height="14" rx="1.5"/><path d="M8 21h8M12 18v3"/>`,
  cap: `<path d="M2 9l10-5 10 5-10 5-10-5z"/><path d="M6 11.5V17c0 1.5 3 3 6 3s6-1.5 6-3v-5.5"/>`,
  book: `<path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2z"/><path d="M8 3v18"/>`,
  idCard: `<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6 16c0-1.7 1.3-3 3-3s3 1.3 3 3M15 10h4M15 14h4"/>`,
  building: `<path d="M3 21h18"/><path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h6v6H9z"/>`,
  toilet: `<path d="M8 3v7a3 3 0 0 0 3 3h3a3 3 0 0 1 3 3v5"/><path d="M6 3h4"/><path d="M15 3v4"/>`,
  kitchen: `<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 7h8M8 12h8M8 17h4"/>`,
  tray: `<path d="M4 11h16"/><path d="M6 11a6 6 0 0 1 12 0"/><path d="M3 15h18l-2 6H5z"/>`,
  bookOpen: `<path d="M3 5c3-1.5 6-1.5 9 0v14c-3-1.5-6-1.5-9 0V5z"/><path d="M21 5c-3-1.5-6-1.5-9 0v14c3-1.5 6-1.5 9 0V5z"/>`,
  tree: `<path d="M12 3l5 7h-3l4 6H6l4-6H7z"/><path d="M12 16v5"/>`,
  slide: `<path d="M6 4h6l6 16"/><path d="M4 20h4M18 20h2"/>`,
  ball: `<circle cx="12" cy="12" r="9"/><path d="M12 3v18M3 12h18M6 6c3 3 9 3 12 0M6 18c3-3 9-3 12 0"/>`,
  desktop: `<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>`,
  laptop: `<rect x="4" y="6" width="16" height="10" rx="1.5"/><path d="M3 19h18"/>`,
  tablet: `<rect x="6" y="3" width="12" height="18" rx="2"/><path d="M11 18h2"/>`,
  printer: `<path d="M6 9V3h12v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M6 17v4h12v-4"/>`,
  scanner: `<rect x="3" y="8" width="18" height="10" rx="2"/><path d="M7 8V4h10v4"/><path d="M7 18v2h10v-2"/>`,
  dvd: `<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/>`,
  speaker: `<path d="M4 9h3l5-4v14l-5-4H4z"/><path d="M16 9a4 4 0 0 1 0 6"/>`,
  tv: `<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8"/>`,
  projector: `<rect x="3" y="5" width="18" height="11" rx="1.5"/><path d="M12 9l4 2-4 2z"/><path d="M9 20h6"/>`,
  wifi: `<path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/>`,
  wheelchair: `<circle cx="17" cy="6" r="1.6" fill="currentColor" stroke="none"/><path d="M17 9v4l4 3"/><path d="M13 13a4 4 0 1 0 4 4"/><path d="M11 9h6l-2 4h-4z"/>`,
  ramp: `<path d="M3 19h6L21 6"/><path d="M3 19V8"/>`,
  handrail: `<path d="M4 5h16"/><path d="M6 5v14M18 5v14"/>`,
  elevator: `<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 10l2-2 2 2M15 14l-2 2-2-2"/>`,
  tactile: `<path d="M4 4h4v4H4zM10 4h4v4h-4zM16 4h4v4h-4zM4 10h4v4H4zM10 10h4v4h-4zM16 10h4v4h-4zM4 16h4v4H4zM10 16h4v4h-4zM16 16h4v4h-4z"/>`,
  hand: `<path d="M8 12V6a2 2 0 1 1 4 0v5M12 11V5a2 2 0 1 1 4 0v7"/><path d="M6 13a6 6 0 0 0 12 0"/>`,
  eye: `<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6z"/><circle cx="12" cy="12" r="2.5"/>`,
  sign: `<path d="M12 3v18"/><rect x="5" y="5" width="14" height="6" rx="1"/>`,
  inbox: `<path d="M4 13h4l2 3h4l2-3h4"/><path d="M5 5h14l2 8v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5z"/>`,
  star: `<path d="M12 3l2.6 5.6L21 9.3l-4.5 4.3 1.1 6.1L12 17l-5.6 3.7 1.1-6.1L3 9.3l6.4-.7z"/>`,
  handshake: `<path d="M3 9l4-4 5 4 5-4 4 4"/><path d="M7 13l3 3 2-2 2 2 3-3"/><path d="M3 9v5l4 4M21 9v5l-4 4"/>`,
  doc: `<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/>`,
};

function def(key, category, label, svg) {
  return { category, label, svg };
}

const GESTOR_ICONS = {
  // Etapas (aliases das chaves já usadas pela API do gestor)
  fundamental_ai: { ...SCHOOL_ICONS.fundamental_i, label: "Fundamental — Anos Iniciais" },
  fundamental_af: { ...SCHOOL_ICONS.fundamental_ii, label: "Fundamental — Anos Finais" },

  // Matrículas / porte
  matricula: def("matricula", "matricula", "Matrículas", S.users),
  sala: def("sala", "matricula", "Salas de aula", S.grid),
  alunos_por_sala: def("alunos_por_sala", "matricula", "Alunos por sala", S.users),
  inclusao: def("inclusao", "matricula", "Inclusão", S.heartPerson),

  // Turno
  matutino: def("matutino", "turno", "Matutino", S.sun),
  vespertino: def("vespertino", "turno", "Vespertino", S.sunset),
  noturno: def("noturno", "turno", "Noturno", S.moon),
  integral: def("integral", "turno", "Tempo integral", S.clock),

  // Modalidade
  regular: def("regular", "modalidade", "Ensino regular", S.users),
  ead: def("ead", "modalidade", "Ensino a distância", S.monitor),
  educacao_especial: def("educacao_especial", "modalidade", "Educação especial", S.heartPerson),
  especial: def("especial", "modalidade", "Educação especial", S.heartPerson),
  eja: { ...SCHOOL_ICONS.eja, category: "modalidade" },
  profissionalizante: { ...SCHOOL_ICONS.profissionalizante, category: "modalidade" },

  // Faixa etária
  "0-3": def("0-3", "idade", "0 a 3 anos", S.person),
  "4-5": def("4-5", "idade", "4 a 5 anos", S.person),
  "6-10": def("6-10", "idade", "6 a 10 anos", S.person),
  "11-14": def("11-14", "idade", "11 a 14 anos", S.person),
  "15-17": def("15-17", "idade", "15 a 17 anos", S.person),
  "18+": def("18+", "idade", "18 anos ou mais", S.person),

  // Docentes
  docente: { ...SCHOOL_ICONS.docente, category: "docente", label: "Docentes" },
  formacao: def("formacao", "docente", "Formação", S.cap),
  disciplina: def("disciplina", "docente", "Disciplina", S.book),
  vinculo: def("vinculo", "docente", "Vínculo", S.idCard),
  fundamental: def("fundamental", "docente", "Ensino Fundamental", S.book),
  medio: def("medio", "docente", "Ensino Médio", S.book),
  superior: def("superior", "docente", "Superior", S.cap),
  superior_licenciatura: def("superior_licenciatura", "docente", "Superior — Licenciatura", S.cap),
  superior_sem_licenciatura: def("superior_sem_licenciatura", "docente", "Superior — Sem licenciatura", S.cap),
  especializacao: def("especializacao", "docente", "Especialização", S.cap),
  mestrado: def("mestrado", "docente", "Mestrado", S.cap),
  doutorado: def("doutorado", "docente", "Doutorado", S.cap),
  concurso: def("concurso", "docente", "Concurso público", S.star),
  clt: def("clt", "docente", "CLT", S.idCard),
  contrato: def("contrato", "docente", "Contrato temporário", S.doc),
  terceirizado: def("terceirizado", "docente", "Terceirizado", S.handshake),

  // Infraestrutura — básica
  banheiro: def("banheiro", "infra", "Banheiro", S.toilet),
  cozinha: def("cozinha", "infra", "Cozinha", S.kitchen),
  refeitorio: def("refeitorio", "infra", "Refeitório", S.tray),
  fossa_septica: { ...SCHOOL_ICONS.esgoto, label: "Fossa séptica" },

  // Infraestrutura — espaços
  sala_leitura: { ...SCHOOL_ICONS.biblioteca, label: "Sala de leitura" },
  patio_coberto: def("patio_coberto", "infra", "Pátio coberto", S.grid),
  patio_descoberto: def("patio_descoberto", "infra", "Pátio descoberto", S.grid),
  parque_infantil: def("parque_infantil", "infra", "Parque infantil", S.slide),
  auditorio: def("auditorio", "infra", "Auditório", S.board),
  sala_professor: def("sala_professor", "infra", "Sala dos professores", S.building),
  sala_diretoria: def("sala_diretoria", "infra", "Sala da direção", S.building),
  secretaria: def("secretaria", "infra", "Secretaria", S.building),
  area_verde: def("area_verde", "infra", "Área verde", S.tree),
  espaco: def("espaco", "infra", "Espaço", S.grid),
  predio: def("predio", "infra", "Prédio", S.building),

  // Equipamentos
  computador: def("computador", "equip", "Computador", S.desktop),
  parabolica: def("parabolica", "equip", "Antena parabólica", S.wifi),
  copiadora: def("copiadora", "equip", "Copiadora", S.printer),
  impressora: def("impressora", "equip", "Impressora", S.printer),
  impressora_mult: def("impressora_mult", "equip", "Impressora multifuncional", S.printer),
  scanner: def("scanner", "equip", "Scanner", S.scanner),
  dvd: def("dvd", "equip", "Aparelho de DVD", S.dvd),
  som: def("som", "equip", "Aparelho de som", S.speaker),
  tv: def("tv", "equip", "Televisão", S.tv),
  lousa_digital: def("lousa_digital", "equip", "Lousa digital", S.board),
  multimidia: def("multimidia", "equip", "Projetor multimídia", S.projector),
  desktop_aluno: def("desktop_aluno", "equip", "Computadores (aluno)", S.desktop),
  notebook_aluno: def("notebook_aluno", "equip", "Notebooks (aluno)", S.laptop),
  tablet_aluno: def("tablet_aluno", "equip", "Tablets (aluno)", S.tablet),

  // Conectividade
  internet_alunos: { ...SCHOOL_ICONS.internet, category: "equip", label: "Internet para alunos" },
  internet_administrativo: { ...SCHOOL_ICONS.internet, category: "equip", label: "Internet administrativa" },
  internet_aprendizagem: { ...SCHOOL_ICONS.internet, category: "equip", label: "Internet de aprendizagem" },
  internet_comunidade: { ...SCHOOL_ICONS.internet, category: "equip", label: "Internet para a comunidade" },
  banda_larga: def("banda_larga", "equip", "Banda larga", S.wifi),
  acesso_computador: def("acesso_computador", "equip", "Acesso por computador", S.desktop),
  dispositivos_pessoais: def("dispositivos_pessoais", "equip", "Dispositivos pessoais", S.tablet),

  // Acessibilidade
  rampas: def("rampas", "acess", "Rampas", S.ramp),
  corrimao: def("corrimao", "acess", "Corrimão", S.handrail),
  elevador: def("elevador", "acess", "Elevador", S.elevator),
  pisos_tateis: def("pisos_tateis", "acess", "Pisos táteis", S.tactile),
  vao_livre: def("vao_livre", "acess", "Vão livre", S.wheelchair),
  sinal_sonoro: def("sinal_sonoro", "acess", "Sinalização sonora", S.speaker),
  sinal_tatil: def("sinal_tatil", "acess", "Sinalização tátil", S.hand),
  sinal_visual: def("sinal_visual", "acess", "Sinalização visual", S.eye),
  sinalizacao: def("sinalizacao", "acess", "Sinalização", S.sign),
  banheiro_pne: def("banheiro_pne", "acess", "Banheiro acessível", S.wheelchair),
};

export const ICONS = { ...SCHOOL_ICONS, ...GESTOR_ICONS };
