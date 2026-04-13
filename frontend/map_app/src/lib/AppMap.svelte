<script>
  import { fade } from 'svelte/transition';
  import { onDestroy } from 'svelte';
  import CityDetail from './CityDetail.svelte';
  import ProgressBar from './ProgressBar.svelte';
  import MapControls from './MapControls.svelte';
  import BaseMap from './BaseMap.svelte';
  import OSMBaseLayer from './OSMBaseLayer.svelte';
  import OsmWays from './OsmWays.svelte';
  import CityLayer from './CityLayer.svelte';
  import SchoolLayer from './SchoolLayer.svelte';
  import SchoolClusterLayer from './School/ClusterLayer.svelte';
  import { osmDisabled } from './osmStore.js';
  import '../styles/cluster-popup.css';
  import SchoolTable from './SchoolTable.svelte';
  import { schools, selectedSchool, hoveredSchool } from './js/schoolStore.js';

  let baseMap;
  let cityLayer;
  let schoolLayer;
  let osmWaysLayer;
  let sse = null;
  let cityName = '';
  let statusMessage = '';
  let currentDetails = null;
  let progress = null;
  let cityData = null;
  let osmData = null;
  let schoolData = null;
  let schoolClusterData = null;
  
  // Controles de cluster
  let showClusters = false;
  let selectedClusters = [1, 2, 3, 4, 5, 6];
  let currentCityForCluster = null; // Armazena a cidade atual para clusters
  let clusterKey = 0;

  $: if (schoolData?.features?.length) {
    schools.set(schoolData.features);
  } else {
    schools.set([]);
  }

  onDestroy(() => {
    sse?.close();
  });

  // Função para obter o mapa do BaseMap
  function getBaseMap() {
    if (baseMap && typeof baseMap.getMap === 'function') {
      return baseMap.getMap();
    }
    return null;
  }
  async function loadCityGeoJSON(name) {
    statusMessage = `Buscando por ${name}...`;
    currentDetails = null;
    cityData = null;
    schoolData = null;
    schoolClusterData = null;
    currentCityForCluster = null;

    try {
      const response = await fetch(`/api/geojson?city=${encodeURIComponent(name)}`);
      const data = await response.json();

      if (!data.features?.length) {
        statusMessage = `Nenhuma cidade parecida com ${name}`;
        return;
      }

      cityData = data;
      statusMessage = `Found ${data.features.length} features for ${name}`;
    } catch (err) {
      statusMessage = `Error: ${err.message}`;
      console.error(err);
    }
  }

  async function loadRelatedPoints(city) {
    schoolData = null;

    try {
      const res = await fetch(`/api/schools?city=${encodeURIComponent(city)}`);
      const data = await res.json();

      if (!data.features?.length) {
        statusMessage = `No schools found for ${city}`;
        return;
      }

      schoolData = data;
      statusMessage = `Loaded ${data.features.length} schools for ${city}`;
    } catch (err) {
      statusMessage = `Error loading schools: ${err.message}`;
    }
  }

  async function handleClusterFilterChange(event) {
    selectedClusters = event.detail.selectedClusters;
    
    // Recarregar dados com novo filtro
    if (showClusters && currentCityForCluster) {
      await loadClusteredSchools(currentCityForCluster.city, currentCityForCluster.codigoIbge);
    }
  }
  // Nova função específica para carregar clusters de uma cidade
  async function loadClusteredSchools(city, codigoIbge = null) {
    schoolClusterData = null;
    currentCityForCluster = { city, codigoIbge };
    
    try {
      let url = `/api/school/cluster`;
      if (codigoIbge) {
        url += `?ibge=${codigoIbge}`;
      }
      
      const res = await fetch(url);
      const data = await res.json();

      console.log('Dados de cluster recebidos:', data);
      
      if (!Array.isArray(data) || data.length === 0) {
        statusMessage = `Nenhuma escola clusterizada encontrada para ${city}`;
        schoolClusterData = null;
        return;
      }

      // Aplicar filtros
      let filteredData = data;
      if (selectedClusters && selectedClusters.length > 0 && selectedClusters.length < 6) {
        filteredData = data.filter(cluster => selectedClusters.includes(cluster.cluster_id));
      }
      
      if (filteredData.length === 0) {
        statusMessage = `Nenhuma escola encontrada para os clusters selecionados`;
        schoolClusterData = null;
        return;
      }

      schoolClusterData = filteredData;
      
      // Forçar recriação do componente cluster layer
      clusterKey++;
      
      const totalEscolas = filteredData.reduce((sum, cluster) => sum + (cluster.escolas?.length || 0), 0);
      statusMessage = `Carregadas ${totalEscolas} escolas clusterizadas para ${city}`;
      
      if (!showClusters && totalEscolas > 0) {
        showClusters = true;
      }
    } catch (err) {
      statusMessage = `Erro ao carregar escolas clusterizadas: ${err.message}`;
      console.error(err);
      schoolClusterData = null;
    }
  }

  // Handler para o evento de cluster vindo do CityLayer
  function handleClusterEvent(event) {
    const { city, codigo_ibge, uf, fid } = event.detail;
    statusMessage = `Carregando análise de clusters para ${city}...`;
    
    // Carregar os dados clusterizados para esta cidade específica
    loadClusteredSchools(city, codigo_ibge);
  }

  function handleToggleClusters(event) {
    showClusters = event.detail.showClusters;
    
    // Se ativou clusters e temos uma cidade carregada, carrega os dados
    if (showClusters && cityData && cityData.features && cityData.features[0]) {
      const firstCity = cityData.features[0].properties;
      if (!schoolClusterData || currentCityForCluster?.city !== firstCity.name) {
        loadClusteredSchools(firstCity.name, firstCity.codigo_ibge);
      }
    } else if (!showClusters) {
      // Se desativou, limpa os dados de cluster
      schoolClusterData = null;
      statusMessage = 'Visualização de clusters desativada';
    }
  }

  function handleSchoolSelect(schoolId) {
    statusMessage = `Escola selecionada: ${schoolId}`;
    // Aqui você pode implementar a abertura de um modal com detalhes da escola
    console.log('School selected:', schoolId);
  }

  async function loadOSMGeoJSON(fid) {
    statusMessage = `Loading OSM data...`;
    currentDetails = null;
    osmData = null;

    try {
      const response = await fetch(`/api/query-osm?fid=${fid}`);
      const data = await response.json();

      if( !data.features?.length) {
        statusMessage = `No features found for ${fid}`;
        return;
      }
      osmData = data;
      statusMessage = `Found ${data.features.length} OSM features`;
    } catch(err) {
      statusMessage = `Error: ${err.message}`;
      console.error(err);
    }
  }

  async function loadDetails(fid) {
    try {
      const res = await fetch(`/api/details?fid=${fid}`);
      currentDetails = await res.json();
      statusMessage = `Loaded details for FID: ${fid}`;
    } catch (err) {
      statusMessage = `Error loading details: ${err.message}`;
    }
  }

  function setSSE(job_id) {
    osmDisabled.set(true);
    sse = new EventSource(`/api/query-osm/progress/${job_id}`);
    
    sse.addEventListener('progress', (event) => {
      try {
        const edata = JSON.parse(event.data);
        progress = edata;
        
        if (edata.progress.state === 'finished' || edata.progress.state === 'failed') {
          sse.close();
          sse = null;
          progress = null;
          osmDisabled.set(false);
        }
      } catch (err) {
        console.error('SSE parse error', err);
        osmDisabled.set(false);
      }
    });
  }

  async function loadOSMData(fid) {
    try {
      const res = await fetch(`/api/query-osm?fid=${fid}`);
      const data = await res.json();
      currentDetails = { type: 'osm', data };
      statusMessage = `Loaded OSM data for FID: ${fid}`;
      
      if (data.job_id) { 
        setSSE(data.job_id);
        return;
      } else {
        osmData = data;
      }
    } catch (err) {
      statusMessage = `Error loading OSM data: ${err.message}`;
    }
  }

  function clearMap() {
    cityData = null;
    schoolData = null;
    schoolClusterData = null;
    currentDetails = null;
    osmData = null;
    sse?.close();
    sse = null;
    progress = null;
    statusMessage = 'Map cleared';
    osmDisabled.set(false);
    showClusters = false;
    currentCityForCluster = null;
    schools.set([]);
    selectedSchool.set(null);
    hoveredSchool.set(null);
  }
</script>

<div class="container">
  <h1>🗺️ EduMaps</h1>
  <h2>Mapas da Educação - Análise por Clusters</h2>
  
  <div class="layout">
    <div class="map-wrapper">
      <MapControls
        bind:cityName
        {statusMessage}
        bind:showClusters
        bind:selectedClusters
        on:search={() => loadCityGeoJSON(cityName)}
        on:clear={clearMap}
        on:toggleClusters={handleToggleClusters}
      />

      <div class="map-with-progress">
        {#if sse && progress}
          <div class="progress-overlay">
            <ProgressBar {progress} />
          </div>
        {/if}
        
        <BaseMap bind:this={baseMap} center={[-23.56, -45.75]} zoom={15}>
          <OSMBaseLayer />
          
          <CityLayer 
            bind:this={cityLayer}
            {cityData}
            on:details={(e) => loadDetails(e.detail.fid)}
            on:schools={(e) => loadRelatedPoints(e.detail.city)}
            on:osm={(e) => loadOSMData(e.detail.fid)}
            on:cluster={handleClusterEvent}
          />

          <OsmWays
            bind:this={osmWaysLayer}
            {osmData}
          />
          
          <!-- SchoolLayer original - sempre visível -->
          <SchoolLayer 
            bind:this={schoolLayer}
            {schoolData}
          />
          <!-- No template do AppMap.svelte -->
          {#key clusterKey}
            {#if showClusters && schoolClusterData && schoolClusterData.length > 0}
              <SchoolClusterLayer 
                map={baseMap?.getMap() || null}
                clusterData={schoolClusterData}
                visible={showClusters}
                onSchoolSelect={handleSchoolSelect}
              />
            {/if}
          {/key}
        </BaseMap>
      </div>
    </div>

    <div class="info-panel">
      <SchoolTable />
      {#if currentDetails && currentDetails.type !== 'osm'}
        {#key currentDetails.codigo_ibge}
          <div class="details-wrapper" transition:fade>
            <CityDetail data={currentDetails} />
          </div>
        {/key}
      {/if}
      
      <!-- Informações adicionais sobre clusters ativos -->
      {#if showClusters && schoolClusterData && currentCityForCluster}
        <div class="cluster-info-panel">
          <h4>📊 Análise de Clusters Ativa</h4>
          <p><strong>Cidade:</strong> {currentCityForCluster.city}</p>
          <p><strong>Filtros ativos:</strong> {selectedClusters.length} clusters</p>
          <button 
            class="btn-refresh" 
            on:click={() => loadClusteredSchools(currentCityForCluster.city, currentCityForCluster.codigoIbge)}>
            🔄 Recarregar Análise
          </button>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  .map-with-progress {
    position: relative;
    width: 100%;
  }

  .map-wrapper {
    width: 100%;
    display: flex;
    flex-direction: column;
    gap: .5rem;
  }
  
  .progress-overlay {
    position: absolute;
    top: 0;
    left: 50%;
    z-index: 1000;
    transform: translateX(-50%);
    padding: 10px;
    background: rgba(255, 255, 255, 0.9);
    border-radius: 8px 8px 0 0;
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .cluster-info-panel {
    margin-top: 16px;
    padding: 12px;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-radius: 8px;
  }
  
  .cluster-info-panel h4 {
    margin: 0 0 8px 0;
    font-size: 14px;
  }
  
  .cluster-info-panel p {
    margin: 4px 0;
    font-size: 12px;
  }
  
  .btn-refresh {
    width: 100%;
    margin-top: 8px;
    padding: 6px;
    background: rgba(255,255,255,0.2);
    border: 1px solid rgba(255,255,255,0.3);
    color: white;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    transition: all 0.2s;
  }
  
  .btn-refresh:hover {
    background: rgba(255,255,255,0.3);
  }

  .layout {
    display: flex;
    gap: 1rem;
    align-items: flex-start;
  }

  .map-wrapper {
    flex: 2;
    min-width: 0;
  }

  .info-panel {
    flex: 1;
    width: auto;
    max-width: 400px;
    max-height: 80vh;
    overflow-y: auto;
    position: sticky;
    top: 1rem;
  }

  @media (max-width: 768px) {
    .layout {
      flex-direction: column;
    }
    
    .info-panel {
      max-width: none;
      width: 100%;
      max-height: none;
      position: static;
      margin-top: 1rem;
    }
  }
</style>
