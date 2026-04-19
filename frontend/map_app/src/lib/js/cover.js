export async function fetchCoverArea(codigo_inep, raio = 5) {
  try {
    const url = `/api/school/${codigo_inep}/cover?raio=${raio}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Erro ao buscar área de cobertura: ${response.status}`);
    }
    const geojson = await response.json();
    return geojson;
  } catch (error) {
    console.error('fetchCoverArea error:', error);
    throw error;
  }
}
