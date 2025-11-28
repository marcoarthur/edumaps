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
  import { osmDisabled } from './osmStore.js';

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

  onDestroy(() => {
    sse?.close();
  });

  async function loadCityGeoJSON(name) {
    statusMessage = `Buscando por ${name}...`;
    currentDetails = null;
    cityData = null;
    schoolData = null;

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
    currentDetails = null;
    osmData = null;
    sse?.close();
    sse = null;
    progress = null;
    statusMessage = 'Map cleared';
    osmDisabled.set(false);
  }
</script>

<div class="container">
  <h1>🗺️ EduMaps</h1>
  <h2>Mapas da Educação</h2>
  
  <div class="layout">
    <div class="map-wrapper">
      <MapControls
        bind:cityName
        {statusMessage}
        on:search={() => loadCityGeoJSON(cityName)}
        on:clear={clearMap}
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
          />

          <OsmWays
            bind:this={osmWaysLayer}
            {osmData}
          />
          
          <SchoolLayer 
            bind:this={schoolLayer}
            {schoolData}
          />
        </BaseMap>
      </div>
    </div>

    <div class="info-panel">
      {#if currentDetails && currentDetails.type !== 'osm'}
        {#key currentDetails.codigo_ibge}
          <div class="details-wrapper" transition:fade>
            <CityDetail data={currentDetails} />
          </div>
        {/key}
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

  .layout {
    display: flex;
    gap: 1rem;
  }

  .map-wrapper {
    flex: 1; /* ocupa o resto */
  }

  .info-panel {
    width: 350px;
    display: block;
    position: relative;
  }
</style>
