<script>
  import { onMount } from 'svelte';
  import BaseMap from '../AnalBaseMap.svelte';
  import MarkerCluster from '../Map/MarkerCluster.svelte';
  import SearchAutocomplete from '../ui/SearchAutocomplete.svelte';
  import CityDetailModal from './DetailModal.svelte';

  export let selectedCity = null;
  export let onCitySelect = (city) => {};

  let showModal = false;
  let selectedCityDetails = null;
  let markerCluster;
  let baseMapComponent = null;  // ← Referência ao componente BaseMap
  let mapInstance = null;       // ← Referência direta ao mapa

  // Configuração para os marcadores de municípios
  const getMarkerColor = (city) => {
    const ideb = city.analise.ideb_fund_ii;
    if (!ideb) return '#9ca3af';
    if (ideb >= 7) return '#059669';
    if (ideb >= 5) return '#22c55e';
    if (ideb >= 3) return '#f59e0b';
    return '#ef4444';
  };

  const getPopupContent = (city) => `
    <div style="font-family: sans-serif; min-width: 220px;">
      <strong style="font-size: 1rem;">${escapeHtml(city.nome_municipio)}</strong><br>
      <span style="color: #6b7280;">${city.sigla_estado} • ${city.nome_regiao || ''}</span>
      <hr style="margin: 8px 0;">
      <table style="width: 100%; font-size: 0.8rem;">
        <tr><td>📊 IDEB Fund. II:</td><td><b>${city.analise.ideb_fund_ii || 'N/A'}</b></td></tr>
        <tr><td>👥 População:</td><td><b>${(city.populacao_estimada || 0).toLocaleString()}</b></td></tr>
        <tr><td>🏫 Escolas:</td><td><b>${city.analise.total_escolas || 0}</b></td></tr>
        <tr><td>📚 Alunos:</td><td><b>${(city.analise.total_alunos || 0).toLocaleString()}</b></td></tr>
        <tr><td>💰 PIB per capita:</td><td><b>${(city.analise.pib_per_capita || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })}</b></td></tr>
      </table>
      <button 
        onclick="window.dispatchEvent(new CustomEvent('showCityDetails', { detail: { codigo_ibge: '${city.codigo_ibge}' } }))"
        style="margin-top: 8px; width: 100%; padding: 6px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer;">
        🔍 Ver detalhes
      </button>
    </div>
  `;

  const fetchCityMarkers = async (bbox, zoom) => {
    console.log('calling for markers');
    const response = await fetch(`/api/analytics/cities/markers?bbox=${encodeURIComponent(bbox)}&zoom=${zoom}&limit=150`);
    return response.json();
  };

  const handleMarkerClick = (city, marker) => {
    selectedCity = city;
    onCitySelect(city);
    markerCluster.highlightMarker(city.codigo_ibge);
  };

  const fetchCitySuggestions = async (query) => {
    const response = await fetch(`/api/analytics/cities/search?q=${encodeURIComponent(query)}&limit=10`);
    const cities = await response.json();
    return cities.map(city => ({
      label: `${city.nome_municipio} - ${city.sigla_estado}`,
      value: city.codigo_ibge,
      subtitle: `${city.populacao_estimada?.toLocaleString()} habitantes • IDEB: ${city.analise.ideb_fund_ii || 'N/A'}`,
      original: city
    }));
  };

  const handleCitySelect = (event) => {
    const city = event.detail.original.original;
    console.log(`cidade selecionada`, city);
    selectedCity = city;
    onCitySelect(city);
    
    console.log(`${city.latitude}  latitude, ${city.longitude} longitude`);
    mapInstance.setView([city.latitude, city.longitude], 12);
    markerCluster?.highlightMarker(city.codigo_ibge);
  };

  const handleMapReady = (evt) => {
    console.log('CitySelector: handleMapReady chamado"', evt);
    mapInstance = evt.detail.map;
    console.log(`Instancia do mapa`, mapInstance);
    markerCluster?.init(mapInstance);
  };

  const escapeHtml = (str) => {
    if (!str) return '';
    return str.replace(/[&<>]/g, function(m) {
      if (m === '&') return '&amp;';
      if (m === '<') return '&lt;';
      if (m === '>') return '&gt;';
      return m;
    });
  };

  onMount( () => {
    window.addEventListener('showCityDetails', async (event) => {
      const { codigo_ibge } = event.detail;

      const response = await fetch(`/api/analytics/city/${codigo_ibge}/details`);
      selectedCityDetails = await response.json();
      showModal = true;
    });

    return () => {
      window.removeEventListener('showCityDetails');
    };
  });

</script>

<div class="city-selector">
  <div class="search-header">
    <SearchAutocomplete
      placeholder="Buscar município (ex: Ubatuba, São Paulo, Rio de Janeiro)..."
      fetchSuggestions={fetchCitySuggestions}
      minChars={3}
      delay={300}
      on:select={handleCitySelect}
    />
  </div>

  <BaseMap
    center={[-15.5, -55.0]} 
    zoom={4} 
    style="height: 550px; width: 100%;"
    on:mapReady={handleMapReady}
  />

  <MarkerCluster
    bind:this={markerCluster}
    {getMarkerColor}
    {getPopupContent}
    fetchMarkers={fetchCityMarkers}
    onMarkerClick={handleMarkerClick}
    markerRadius={7}
    debounceDelay={300}
  />

  <CityDetailModal
    isOpen={showModal}
    cityData={selectedCityDetails}
    onClose={() => {
      showModal = false;
      selectedCityDetails = null;
    }}
  />
  <div class="map-legend">
    <div class="legend-title">🎨 IDEB dos municípios (Fund. II)</div>
    <div class="legend-items">
      <div class="legend-item"><div class="legend-color" style="background: #059669;"></div><span>≥ 7 (Excelente)</span></div>
      <div class="legend-item"><div class="legend-color" style="background: #22c55e;"></div><span>5-7 (Bom)</span></div>
      <div class="legend-item"><div class="legend-color" style="background: #f59e0b;"></div><span>3-5 (Regular)</span></div>
      <div class="legend-item"><div class="legend-color" style="background: #ef4444;"></div><span>&lt; 3 (Crítico)</span></div>
      <div class="legend-item"><div class="legend-color" style="background: #9ca3af;"></div><span>Sem dados</span></div>
    </div>
  </div>
</div>

<style>
  .city-selector {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .search-header {
    padding: 1rem;
    background: white;
    border-radius: 0.75rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    z-index: 10;
    position: relative;
  }

  .map-legend {
    position: absolute;
    bottom: 1rem;
    right: 1rem;
    background: white;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    font-size: 0.75rem;
    z-index: 1000;
    pointer-events: none;
  }

  .legend-title {
    font-weight: 600;
    margin-bottom: 0.5rem;
    font-size: 0.7rem;
    text-transform: uppercase;
    color: #6b7280;
  }

  .legend-items {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .legend-color {
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }
</style>
