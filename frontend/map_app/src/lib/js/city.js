// Função para buscar dados reais (substituir depois)
const fetchCityData = async (codigoIbge) => {
  loading = true;
  error = null;
  try {
    // Substituir pela chamada real
    const response = await fetch(`/api/analytics/city/${codigoIbge}/details`);
    const data = await response.json();
    cityData = data;

    // Mock para demonstração
    console.log(`Buscando dados para ${codigoIbge}...`);
  } catch (err) {
    error = err.message;
  } finally {
    loading = false;
  }
};
