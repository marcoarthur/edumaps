// src/shared/ui/components/charts/localeCarbon.js
//
// Textos do Carbon Charts em PT-BR (#431, AN-07). O Carbon vem em inglês
// ("Export to CSV", "Show as table"); os quatro wrappers passam as options
// por `comLocale`, então todo gráfico do app sai traduzido sem cada tela
// lembrar disso. Uma tradução passada pela tela tem precedência.

export const TRADUCOES_CARBON = Object.freeze({
  group: "Grupo",
  total: "Total",
  tabularRep: {
    title: "Tabela de dados",
    downloadAsCSV: "Baixar CSV",
  },
  toolbar: {
    exportAsCSV: "Exportar CSV",
    exportAsJPG: "Exportar JPG",
    exportAsPNG: "Exportar PNG",
    zoomIn: "Aproximar",
    zoomOut: "Afastar",
    resetZoom: "Restaurar zoom",
    moreOptions: "Mais opções",
    makeFullScreen: "Tela cheia",
    exitFullScreen: "Sair da tela cheia",
    showAsTable: "Ver como tabela",
  },
});

/**
 * Devolve as options com o `locale.translations` em PT-BR, preservando o
 * que a tela já tiver definido.
 * @param {object} [options]
 * @returns {object}
 */
export function comLocale(options = {}) {
  const locale = options.locale ?? {};
  const proprias = locale.translations ?? {};
  return {
    ...options,
    locale: {
      ...locale,
      translations: {
        ...TRADUCOES_CARBON,
        ...proprias,
        tabularRep: { ...TRADUCOES_CARBON.tabularRep, ...(proprias.tabularRep ?? {}) },
        toolbar: { ...TRADUCOES_CARBON.toolbar, ...(proprias.toolbar ?? {}) },
      },
    },
  };
}
