<script>
  import { mount } from 'svelte';
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';
  import CityPopup from './CityPopup.svelte';
  import SchoolPopup from './SchoolPopup.svelte';
  import CityDetail from './CityDetail.svelte';
  import ProgressBar from './ProgressBar.svelte';
  import MapControls from './MapControls.svelte';
  import { osmDisabled } from './osmStore.js';

  const dispatch = createEventDispatcher();

  let mapContainer;
  let map;
  let geoJsonLayer;
  let pointsLayer;
  let sse = null;

  let cityName = '';
  let statusMessage = '';
  let currentDetails = null;
  let progress = null;

  onMount(() => {
    map = L.map(mapContainer).setView([-23.56, -45.15], 15);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(map);

    geoJsonLayer = L.layerGroup().addTo(map);
    pointsLayer = L.layerGroup().addTo(map);
  });

  onDestroy(() => map?.remove());

  async function loadCityGeoJSON(name) {
    statusMessage = `Searching for ${name}...`;
    currentDetails = null;
    geoJsonLayer.clearLayers();
    pointsLayer.clearLayers();

    try {
      const response = await fetch(`/api/geojson?city=${encodeURIComponent(name)}`);
      const data = await response.json();

      if (!data.features?.length) {
        statusMessage = `No features found for ${name}`;
        return;
      }

      geoJsonLayer = L.geoJSON(data, {
        style: {
          color: '#3388ff',
          weight: 2,
          fillColor: '#3388ff',
          fillOpacity: 0.2
        },
        onEachFeature: (feature, layer) => {
          const popup = L.popup();
          const popupContainer = document.createElement('div');

          // Mount the Svelte popup component inside Leaflet popup
          mount( CityPopup, {
            target: popupContainer,
            props: {
              feature: feature.properties,
              onDetails: (fid) => loadDetails(fid),
              onSchools: (city) => loadRelatedPoints(city),
              onOSM: (fid) => loadOSMData(fid),
            }}
          );

          popup.setContent(popupContainer);
          layer.bindPopup(popup);
        }
      }).addTo(map);

      map.fitBounds(geoJsonLayer.getBounds());
      statusMessage = `Found ${data.features.length} features for ${name}`;
    } catch (err) {
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
    pointsLayer.clearLayers();
    try {
      const res = await fetch(`/api/schools?city=${encodeURIComponent(city)}`);
      const data = await res.json();

      if (!data.features?.length) {
        statusMessage = `No schools found for ${city}`;
        return;
      }

      L.geoJSON(data, {
        pointToLayer: (_, latlng) =>
          L.circleMarker(latlng, {
            radius: 6,
            fillColor: "#ff7800",
            color: "#000",
            weight: 1,
            fillOpacity: 0.8
          }),
        onEachFeature: (feature, layer) => {
          const popupContainer = document.createElement('div');
          mount(SchoolPopup, { target: popupContainer, props: { school: feature.properties } } );
          layer.bindPopup(popupContainer);
        }
      }).addTo(pointsLayer);

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
      if ( data.job_id ) setSSE(data.job_id);
    } catch (err) {
      statusMessage = `Error loading OSM data: ${err.message}`;
    }
  }

  function clearMap() {
    geoJsonLayer.clearLayers();
    pointsLayer.clearLayers();
    currentDetails = null;
    sse = null;
    statusMessage = 'Map cleared';
    osmDisabled.set(false);
  }
</script>

<div class="container">
  <h1>🗺️ Municipalidades de São Paulo</h1>

  <MapControls
    bind:cityName
    {statusMessage}
    on:search={() => loadCityGeoJSON(cityName)}
    on:clear={clearMap}
  />
  <!-- Map container with progress bar integrated at the top -->
  <div class="map-with-progress">
    {#if sse && progress}
      <div class="progress-overlay">
        <ProgressBar {progress} />
      </div>
    {/if}
    <div id="map" bind:this={mapContainer}></div>
  </div>

  <div class="info-panel">
    <h3>Database-Generated GeoJSON</h3>
    {#if currentDetails && currentDetails.type !== 'osm'}
      <CityDetail data={currentDetails} />
    {:else if currentDetails && currentDetails.type === 'osm'}
      <div class="details-container">
        <h3>OSM Data</h3>
        <pre>{JSON.stringify(currentDetails.data, null, 2)}</pre>
      </div>
    {/if}

  </div>
</div>

<style>
  .map-with-progress {
    position: relative;
    width: 100%;
  }
  
  .progress-overlay {
    position: absolute;
    top: 0;
    left: 50%;
    z-index: 1000; /* Ensure it appears above the map */
    transform: translateX(-50%); /* Center horizontally */
    padding: 10px;
    background: rgba(255, 255, 255, 0.9); /* Semi-transparent background */
    border-radius: 8px 8px 0 0; /* Match map's border radius on top */
    width: 100%;
    display: flex;
    justify-content: center;
    align-items: center;
  }
  
  #map { 
    height: 600px; 
    width: 100%; 
    border: 2px solid #ccc; 
    border-radius: 8px; 
  }
  
</style>
