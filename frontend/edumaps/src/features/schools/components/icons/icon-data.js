/**
 * src/features/school/components/icons/icon-data.js
 * icon-data.js
 *
 * Conjunto de ícones do Painel Escolar. Cada ícone é desenhado uma única vez
 * em viewBox "0 0 24 24", com traço (stroke) uniforme — o componente Icon.svelte
 * decide o tamanho de saída (30 ou 50) e a cor conforme o estado (presente/ausente).
 *
 * category:
 *   'etapa'  -> etapas de ensino oferecidas pela escola (cor --ep-etapas)
 *   'infra'  -> itens de infraestrutura do censo (cor --ep-infra-on / --ep-infra-off)
 *
 * A ordem dentro de ETAPAS_ORDER / INFRA_ORDER é a ordem fixa de exibição —
 * o layout nunca reordena por presença/ausência (ver princípio 1 da estratégia:
 * inventário fixo, estado variável).
 */

export const ICONS = {
  // ---------------- ETAPAS DE ENSINO ----------------
  creche: {
    category: "etapa",
    label: "Creche",
    svg: `<path d="M9 2h6M10 2v3.2c0 .5-.2.9-.6 1.3L8 8v11a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2V8l-1.4-1.5a2 2 0 0 1-.6-1.3V2"/><path d="M8 12h8"/>`,
  },
  pre_escola: {
    category: "etapa",
    label: "Pré-escola",
    svg: `<rect x="3" y="13" width="7" height="7" rx="1"/><rect x="14" y="13" width="7" height="7" rx="1"/><rect x="8.5" y="4" width="7" height="7" rx="1"/>`,
  },
  fundamental_i: {
    category: "etapa",
    label: "Fundamental — Anos Iniciais",
    svg: `<path d="M4 20l1-5L16 4l4 4L9 19l-5 1z"/><path d="M13 6l4 4"/>`,
  },
  fundamental_ii: {
    category: "etapa",
    label: "Fundamental — Anos Finais",
    svg: `<path d="M3 5c3-1.5 6-1.5 9 0v14c-3-1.5-6-1.5-9 0V5z"/><path d="M21 5c-3-1.5-6-1.5-9 0v14c3-1.5 6-1.5 9 0V5z"/>`,
  },
  ensino_medio: {
    category: "etapa",
    label: "Ensino Médio",
    svg: `<path d="M2 9l10-5 10 5-10 5-10-5z"/><path d="M6 11.5V17c0 1.5 3 3 6 3s6-1.5 6-3v-5.5"/><path d="M22 9v6"/>`,
  },
  eja: {
    category: "etapa",
    label: "EJA — Educação de Jovens e Adultos",
    svg: `<path d="M15.5 4a6.5 6.5 0 1 0 4.9 10.8A8 8 0 0 1 15.5 4z"/><path d="M20 3v3M18.5 4.5h3"/>`,
  },
  profissionalizante: {
    category: "etapa",
    label: "Educação Profissionalizante",
    svg: `<path d="M14 6a4 4 0 1 0-5.3 5.3L4 16v4h4l4.7-4.7A4 4 0 0 0 14 6z"/>`,
  },

  // ---------------- INFRAESTRUTURA ----------------
  agua_potavel: {
    category: "infra",
    label: "Água potável",
    svg: `<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>`,
  },
  energia: {
    category: "infra",
    label: "Energia da rede pública",
    svg: `<path d="M13 2 4 14h6l-1 8 9-12h-6l1-8z"/>`,
  },
  esgoto: {
    category: "infra",
    label: "Esgoto (rede pública ou fossa séptica)",
    svg: `<path d="M3 9c1.5-2 3.5-2 5 0s3.5 2 5 0 3.5-2 5 0 3.5 2 5 0"/><path d="M3 15c1.5-2 3.5-2 5 0s3.5 2 5 0 3.5-2 5 0 3.5 2 5 0"/>`,
  },
  coleta_lixo: {
    category: "infra",
    label: "Coleta de lixo",
    svg: `<path d="M5 7h14"/><path d="M9 7V4h6v3"/><path d="M7 7l1 13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1l1-13"/>`,
  },
  internet: {
    category: "infra",
    label: "Internet",
    svg: `<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5.5 13a10 10 0 0 1 13 0"/><path d="M9 17a5 5 0 0 1 6 0"/><circle cx="12" cy="20" r="1" fill="currentColor" stroke="none"/>`,
  },
  biblioteca: {
    category: "infra",
    label: "Biblioteca / sala de leitura",
    svg: `<path d="M4 20V5a1 1 0 0 1 1-1h3v16H5a1 1 0 0 1-1-1z"/><path d="M10 4h4v16h-4z"/><path d="M16 5.3l3-.7 2 15-3 .7z"/>`,
  },
  laboratorio_ciencias: {
    category: "infra",
    label: "Laboratório de ciências",
    svg: `<path d="M9 2h6"/><path d="M10 2v6.5L4.5 19a1.5 1.5 0 0 0 1.3 2.2h12.4a1.5 1.5 0 0 0 1.3-2.2L14 8.5V2"/><path d="M7.5 15h9"/>`,
  },
  laboratorio_informatica: {
    category: "infra",
    label: "Laboratório de informática",
    svg: `<rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/>`,
  },
  quadra_esportes: {
    category: "infra",
    label: "Quadra de esportes",
    svg: `<circle cx="12" cy="12" r="9"/><path d="M12 3v18M3 12h18M6 6c3 3 9 3 12 0M6 18c3-3 9-3 12 0"/>`,
  },
  acessibilidade: {
    category: "infra",
    label: "Acessibilidade (rampas, sinalização, banheiro PNE)",
    svg: `<circle cx="17" cy="6" r="1.6" fill="currentColor" stroke="none"/><path d="M17 9v4l4 3"/><path d="M13 13a4 4 0 1 0 4 4"/><path d="M11 9h6l-2 4h-4z"/>`,
  },
  alimentacao: {
    category: "infra",
    label: "Alimentação escolar",
    svg: `<path d="M6 2v8a2 2 0 0 0 4 0V2"/><path d="M8 10v12"/><path d="M16 2c-1.6 0-2.5 2-2.5 4.5S14.4 11 16 11s2.5-2 2.5-4.5S17.6 2 16 2z"/><path d="M16 11v11"/>`,
  },

  // ---------------- PORTE (usado sozinho, com número ao lado) ----------------
  matriculas: {
    category: "porte",
    label: "Matrículas",
    svg: `<circle cx="9" cy="8" r="3"/><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6"/><circle cx="17" cy="9" r="2.3"/><path d="M15.5 20c.2-2.7 1.8-5 4.5-5"/>`,
  },
  // ---------- MARCA EDUMAPS (usado como ícone) ----------
  edumaps: {
    category: "brand",
    label: "EduMaps",
    svg: `
    <defs>
      <!-- Gradiente do Corpo do Pin -->
      <linearGradient id="pinGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#38bdf8"/>
        <stop offset="100%" stop-color="#1d4ed8"/>
      </linearGradient>
      <!-- Gradiente do Capelo -->
      <linearGradient id="capGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#fbbf24"/>
        <stop offset="100%" stop-color="#d97706"/>
      </linearGradient>
    </defs>

    <!-- Sombra Projetada no Chão (opcional) -->
    <ellipse cx="32" cy="68" rx="14" ry="3" fill="#000000" opacity="0.25"/>

    <!-- Corpo do Pin de Mapa -->
    <path d="M 32 14 C 18.7 14, 8 24.7, 8 38 C 8 52, 28 66, 32 68 C 36 66, 56 52, 56 38 C 56 24.7, 45.3 14, 32 14 Z" fill="url(#pinGrad)" stroke="#ffffff" stroke-width="2.5"/>

    <!-- Livro Aberto (Vazado/Branco dentro do Pin) -->
    <path d="M 32 35 L 20 29 C 20 29, 19 41, 27 45 C 30 46.5, 32 45.5, 32 45.5 Z" fill="#ffffff" opacity="0.95"/>
    <path d="M 32 35 L 44 29 C 44 29, 45 41, 37 45 C 34 46.5, 32 45.5, 32 45.5 Z" fill="#cbd5e1"/>
    <path d="M 32 35 L 32 45.5" stroke="#94a3b8" stroke-width="1"/>

    <!-- Capelo (Graduation Cap) no Topo do Pin -->
    <g transform="translate(0, 0)">
      <!-- Losango do Capelo -->
      <polygon points="32,2 48,10 32,18 16,10" fill="url(#capGrad)" stroke="#ffffff" stroke-width="1.5"/>
      <!-- Base do Capelo -->
      <path d="M 23 14.5 L 23 20 C 23 22, 41 22, 41 20 L 41 14.5 Z" fill="#b45309"/>
      <!-- Tassel / Pompom -->
      <path d="M 16 10 C 13 13, 12 16, 12 19" fill="none" stroke="#fbbf24" stroke-width="1.5"/>
      <circle cx="12" cy="19" r="1.5" fill="#fef08a"/>
    </g>
    `,
  },
};

export const ETAPAS_ORDER = [
  "creche",
  "pre_escola",
  "fundamental_i",
  "fundamental_ii",
  "ensino_medio",
  "eja",
  "profissionalizante",
];

export const INFRA_ORDER = [
  "agua_potavel",
  "energia",
  "esgoto",
  "coleta_lixo",
  "internet",
  "biblioteca",
  "laboratorio_ciencias",
  "laboratorio_informatica",
  "quadra_esportes",
  "acessibilidade",
  "alimentacao",
];

export const NETWORK_LABELS = {
  municipal: "Municipal",
  estadual: "Estadual",
  privada: "Privada",
};
