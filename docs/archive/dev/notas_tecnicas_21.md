# Plano para reescrita do frontend

Estado Atual do frontend no código, árvore

```text
[01;34m.[0m
├── [01;34mpublic[0m
│   └── [01;35mvite.svg[0m
├── [01;34msrc[0m
│   ├── [01;34massets[0m
│   │   └── [01;35msvelte.svg[0m
│   ├── [01;34mlib[0m
│   │   ├── [01;34mCity[0m
│   │   │   ├── Briefing.svelte
│   │   │   ├── CitySelector.svelte
│   │   │   ├── DetailModal.svelte
│   │   │   └── MunicipiosMapa.svelte
│   │   ├── [01;34mjs[0m
│   │   │   ├── city.js
│   │   │   ├── cover.js
│   │   │   ├── schoolStore.js
│   │   │   └── siope.js
│   │   ├── [01;34mMap[0m
│   │   │   └── MarkerCluster.svelte
│   │   ├── [01;34mSchool[0m
│   │   │   ├── ClusterLayer.svelte
│   │   │   ├── ClusterLegend.svelte
│   │   │   ├── CoverArea.svelte
│   │   │   ├── GradesModal.svelte
│   │   │   ├── PayrollModal.svelte
│   │   │   ├── SchList.svelte
│   │   │   ├── SchoolScores.svelte
│   │   │   ├── ScoresModal.svelte
│   │   │   ├── SearchForm.svelte
│   │   │   └── SearchSchoolPage.svelte
│   │   ├── [01;34mservice[0m
│   │   │   ├── api.js
│   │   │   ├── schoolClusterService.js
│   │   │   └── school.js
│   │   ├── [01;34mSiope[0m
│   │   │   ├── JobProgress.svelte
│   │   │   └── Payroll.svelte
│   │   ├── [01;34mstores[0m
│   │   │   └── activeCoverStore.js
│   │   ├── [01;34mui[0m
│   │   │   ├── LoadingSpinner.svelte
│   │   │   ├── SearchAutocomplete.svelte
│   │   │   ├── SearchInputSimple.svelte
│   │   │   └── SearchInput.svelte
│   │   ├── AnalBaseMap.svelte
│   │   ├── AppMap.svelte
│   │   ├── BaseMap.svelte
│   │   ├── CityDetail.svelte
│   │   ├── CityLayer.svelte
│   │   ├── CityPopup.svelte
│   │   ├── JobProgress.svelte
│   │   ├── MapControls.svelte
│   │   ├── Map.svelte
│   │   ├── OSMBaseLayer.svelte
│   │   ├── OsmPopup.svelte
│   │   ├── osmStore.js
│   │   ├── OsmWays.svelte
│   │   ├── ProgressBar.svelte
│   │   ├── SchoolLayer.svelte
│   │   ├── SchoolPopup.svelte
│   │   └── SchoolTable.svelte
│   ├── [01;34mstyles[0m
│   │   └── cluster-popup.css
│   ├── [01;34mtests[0m
│   │   ├── ScoresModal.test.js
│   │   └── ScoresModalWithIntegration.test.js
│   ├── app.css
│   ├── App.svelte
│   ├── main.js
│   └── vitest-setup.js
├── gitignore
├── index.html
├── jsconfig.json
├── package.json
├── package-lock.json
├── svelte.config.js
├── vite.config.js
└── vite.config.js.timestamp-1776078848866-63f5ad066456d8.mjs

15 directories, 63 files
```

## Principais arquivos atuais e desenhos adhocs

O principal problema foram as decisões rápidas, adhoc, para:

- Rotas: Feitas no módulo principal:

```svelte
// App.svelte
<script>
  import { onMount } from 'svelte';
  import BuscaEscolasPage from './lib/School/SearchSchoolPage.svelte';
  import MunicipiosMapa from './lib/City/MunicipiosMapa.svelte';
  
  // Você pode adicionar outros componentes aqui quando necessário
  // import Map from './lib/Siope/Map.svelte';
  
  import Map from './lib/AppMap.svelte';
  let currentView = 'busca';
  
  // Simples roteamento baseado na URL
  onMount(() => {
    const path = window.location.pathname;
    if (path === '/mapa') {
      currentView = 'mapa';
    } else if (path === '/busca') {
      currentView = 'busca';
    } else if (path === '/analytic') {
      currentView = 'analytic';
    }
  });
</script>

<main>
  <nav class="main-nav">
    <div class="nav-container">
      <div class="nav-brand">
        <span class="brand-icon">🏫</span>
        <span class="brand-name">Sistema Escolar</span>
      </div>
      <div class="nav-links">
        <a href="/busca" class="nav-link" class:active={currentView === 'busca'}>
          🔍 Buscar Escolas
        </a>
        <a href="/analytic" class="nav-link" class:active={currentView === 'analytic'}>
          🔍 Análises Municípios 
        </a>
        <a href="/mapa" class="nav-link" class:active={currentView === 'mapa'}>
          🗺️ Mapa
        </a>
      </div>
    </div>
  </nav>
  
  <div class="content">
    {#if currentView === 'busca'}
      <BuscaEscolasPage />
    {:else if currentView === 'mapa'}
      <Map />
    {:else if currentView === 'analytic'}
      <MunicipiosMapa />
    {/if}
  </div>
</main>

<style>
  .main-nav {
    background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
    color: white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .nav-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .nav-brand {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.25rem;
    font-weight: bold;
  }

  .brand-icon {
    font-size: 1.5rem;
  }

  .nav-links {
    display: flex;
    gap: 2rem;
  }

  .nav-link {
    color: white;
    text-decoration: none;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    transition: background-color 0.2s;
  }

  .nav-link:hover {
    background-color: rgba(255, 255, 255, 0.1);
  }

  .nav-link.active {
    background-color: rgba(255, 255, 255, 0.2);
    font-weight: 500;
  }

  .content {
    min-height: calc(100vh - 64px);
    background-color: #f9fafb;
  }

  .coming-soon {
    text-align: center;
    padding: 4rem;
    font-size: 1.25rem;
    color: #6b7280;
  }
</style>
```

O estilo não centralizado (dependente e inserido em cada componente). Pouca responsividade
para clientes sem js habilitado. Componentes feitos de maneira adhoc, sem reuso sério,
(apenas alguns foram pensados e mantidos em src/lib/ui).

Segue abaixo a listagem geral para total entendimento dos arquivos importantes ao projeto de frontend

# Conteúdo dos arquivos do frontend (map_app)

Gerado a partir da estrutura atual.

## 📂 Raiz

### `.gitignore`

```text
# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
lerna-debug.log*

node_modules
dist
dist-ssr
*.local

# Editor directories and files
.vscode/*
!.vscode/extensions.json
.idea
.DS_Store
*.suo
*.ntvs*
*.njsproj
*.sln
*.sw?
```

### `index.html`

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>EduMaps</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
```

### `jsconfig.json`

```json
{
  "compilerOptions": {
    "moduleResolution": "bundler",
    "target": "ESNext",
    "module": "ESNext",
    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "resolveJsonModule": true,
    "sourceMap": true,
    "esModuleInterop": true,
    "types": ["vite/client"],
    "skipLibCheck": true,
    
    // Manter check ativo mas reduzir rigor
    "checkJs": false,
    "strict": false,  // ← Desabilita modo estrito
    "noImplicitAny": false,  // ← Permite 'any' implícito
    "noUnusedLocals": false,  // ← Não avisa sobre variáveis não usadas
    "noUnusedParameters": false,  // ← Não avisa sobre parâmetros não usados
    "noImplicitReturns": false,
    "noFallthroughCasesInSwitch": false,
    
    // Ignorar erros de tipos de bibliotecas
    "skipDefaultLibCheck": true
  },
  "include": ["src/**/*.d.ts", "src/**/*.js", "src/**/*.svelte"],
  "exclude": ["node_modules", "dist", "build"]
}
```

### `package.json`

```json
{
  "name": "map_app",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:run": "vitest run",
    "test:ui": "vitest --ui"
  },
  "dependencies": {
    "@carbon/charts-svelte": "^1.22.18",
    "@carbon/styles": "^1.103.0",
    "leaflet": "^1.9.4",
    "svelte": "^4.0.0"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^3.1.2",
    "@testing-library/jest-dom": "^6.9.1",
    "@testing-library/svelte": "^5.2.9",
    "@testing-library/user-event": "^14.6.1",
    "jsdom": "^27.2.0",
    "leaflet.markercluster": "^1.5.3",
    "vite": "^5.0.0",
    "vitest": "^4.0.14"
  }
}
```


---

## 📁 public

### `public/vite.svg`

```text
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFEA83"></stop><stop offset="8.333%" stop-color="#FFDD35"></stop><stop offset="100%" stop-color="#FFA800"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
```


---

## 📁 src

### `src/App.svelte`

```svelte
<script>
  import { onMount } from 'svelte';
  import BuscaEscolasPage from './lib/School/SearchSchoolPage.svelte';
  import MunicipiosMapa from './lib/City/MunicipiosMapa.svelte';
  
  // Você pode adicionar outros componentes aqui quando necessário
  // import Map from './lib/Siope/Map.svelte';
  
  import Map from './lib/AppMap.svelte';
  let currentView = 'busca';
  
  // Simples roteamento baseado na URL
  onMount(() => {
    const path = window.location.pathname;
    if (path === '/mapa') {
      currentView = 'mapa';
    } else if (path === '/busca') {
      currentView = 'busca';
    } else if (path === '/analytic') {
      currentView = 'analytic';
    }
  });
</script>

<main>
  <nav class="main-nav">
    <div class="nav-container">
      <div class="nav-brand">
        <span class="brand-icon">🏫</span>
        <span class="brand-name">Sistema Escolar</span>
      </div>
      <div class="nav-links">
        <a href="/busca" class="nav-link" class:active={currentView === 'busca'}>
          🔍 Buscar Escolas
        </a>
        <a href="/analytic" class="nav-link" class:active={currentView === 'analytic'}>
          🔍 Análises Municípios 
        </a>
        <a href="/mapa" class="nav-link" class:active={currentView === 'mapa'}>
          🗺️ Mapa
        </a>
      </div>
    </div>
  </nav>
  
  <div class="content">
    {#if currentView === 'busca'}
      <BuscaEscolasPage />
    {:else if currentView === 'mapa'}
      <Map />
    {:else if currentView === 'analytic'}
      <MunicipiosMapa />
    {/if}
  </div>
</main>

<style>
  .main-nav {
    background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
    color: white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .nav-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .nav-brand {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.25rem;
    font-weight: bold;
  }

  .brand-icon {
    font-size: 1.5rem;
  }

  .nav-links {
    display: flex;
    gap: 2rem;
  }

  .nav-link {
    color: white;
    text-decoration: none;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    transition: background-color 0.2s;
  }

  .nav-link:hover {
    background-color: rgba(255, 255, 255, 0.1);
  }

  .nav-link.active {
    background-color: rgba(255, 255, 255, 0.2);
    font-weight: 500;
  }

  .content {
    min-height: calc(100vh - 64px);
    background-color: #f9fafb;
  }

  .coming-soon {
    text-align: center;
    padding: 4rem;
    font-size: 1.25rem;
    color: #6b7280;
  }
</style>
```

### `src/app.css`

```css
:root {
  font-family: system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;

  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

a {
  font-weight: 500;
  color: #646cff;
  text-decoration: inherit;
}
a:hover {
  color: #535bf2;
}

body {
  margin: 0;
  display: flex;
  place-items: center;
  min-width: 320px;
  min-height: 100vh;
}

h1 {
  font-size: 3.2em;
  line-height: 1.1;
}

.card {
  padding: 2em;
}

#app {
  margin: 0 auto;
  width: 100%;
  padding: 2rem;
  text-align: center;
}

button {
  border-radius: 8px;
  border: 1px solid transparent;
  padding: 0.6em 1.2em;
  font-size: 1em;
  font-weight: 500;
  font-family: inherit;
  background-color: #1a1a1a;
  cursor: pointer;
  transition: border-color 0.25s;
}
button:hover {
  border-color: #646cff;
}
button:focus,
button:focus-visible {
  outline: 4px auto -webkit-focus-ring-color;
}

@media (prefers-color-scheme: light) {
  :root {
    color: #213547;
    background-color: #ffffff;
  }
  a:hover {
    color: #747bff;
  }
  button {
    background-color: #f9f9f9;
  }
}
```


---

## 📁 src/assets

### `src/assets/svelte.svg`

```text
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="26.6" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 308"><path fill="#FF3E00" d="M239.682 40.707C211.113-.182 154.69-12.301 113.895 13.69L42.247 59.356a82.198 82.198 0 0 0-37.135 55.056a86.566 86.566 0 0 0 8.536 55.576a82.425 82.425 0 0 0-12.296 30.719a87.596 87.596 0 0 0 14.964 66.244c28.574 40.893 84.997 53.007 125.787 27.016l71.648-45.664a82.182 82.182 0 0 0 37.135-55.057a86.601 86.601 0 0 0-8.53-55.577a82.409 82.409 0 0 0 12.29-30.718a87.573 87.573 0 0 0-14.963-66.244"></path><path fill="#FFF" d="M106.889 270.841c-23.102 6.007-47.497-3.036-61.103-22.648a52.685 52.685 0 0 1-9.003-39.85a49.978 49.978 0 0 1 1.713-6.693l1.35-4.115l3.671 2.697a92.447 92.447 0 0 0 28.036 14.007l2.663.808l-.245 2.659a16.067 16.067 0 0 0 2.89 10.656a17.143 17.143 0 0 0 18.397 6.828a15.786 15.786 0 0 0 4.403-1.935l71.67-45.672a14.922 14.922 0 0 0 6.734-9.977a15.923 15.923 0 0 0-2.713-12.011a17.156 17.156 0 0 0-18.404-6.832a15.78 15.78 0 0 0-4.396 1.933l-27.35 17.434a52.298 52.298 0 0 1-14.553 6.391c-23.101 6.007-47.497-3.036-61.101-22.649a52.681 52.681 0 0 1-9.004-39.849a49.428 49.428 0 0 1 22.34-33.114l71.664-45.677a52.218 52.218 0 0 1 14.563-6.398c23.101-6.007 47.497 3.036 61.101 22.648a52.685 52.685 0 0 1 9.004 39.85a50.559 50.559 0 0 1-1.713 6.692l-1.35 4.116l-3.67-2.693a92.373 92.373 0 0 0-28.037-14.013l-2.664-.809l.246-2.658a16.099 16.099 0 0 0-2.89-10.656a17.143 17.143 0 0 0-18.398-6.828a15.786 15.786 0 0 0-4.402 1.935l-71.67 45.674a14.898 14.898 0 0 0-6.73 9.975a15.9 15.9 0 0 0 2.709 12.012a17.156 17.156 0 0 0 18.404 6.832a15.841 15.841 0 0 0 4.402-1.935l27.345-17.427a52.147 52.147 0 0 1 14.552-6.397c23.101-6.006 47.497 3.037 61.102 22.65a52.681 52.681 0 0 1 9.003 39.848a49.453 49.453 0 0 1-22.34 33.12l-71.664 45.673a52.218 52.218 0 0 1-14.563 6.398"></path></svg>
```


---

## 📁 src/lib

### `src/lib/AnalBaseMap.svelte`

```svelte
<script>
  import { onMount, onDestroy, setContext, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  export let center = [-15.5, -55.0];  // Centro do Brasil
  export let zoom = 4;
  export let style = {};
  export let tileLayer = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  export let tileLayerOptions = {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/">CartoDB</a>',
    subdomains: 'abcd',
    maxZoom: 19,
    minZoom: 3
  };

  let mapContainer;
  let mapReady = false;
  let map;
  const dispatch = createEventDispatcher();

  // Expor instância do mapa para componentes filhos via context
  setContext('leaflet-map', {
    getMap: () => map,
    isReady: () => mapReady
  });

  onMount(() => {
    // Inicializar o mapa
    map = L.map(mapContainer).setView(center, zoom);
    
    // Adicionar tile layer padrão (obrigatório para ver o mapa!)
    L.tileLayer(tileLayer, tileLayerOptions).addTo(map);
    
    mapReady = true;
    
    // Disparar evento personalizado para components que escutam
    dispatch('mapReady', { map });
  });

  onDestroy(() => {
    if (map) {
      map.remove();
    }
  });

  // Métodos públicos
  export function fitBounds(bounds) {
    map?.fitBounds(bounds);
  }

  export function getMap() {
    return map;
  }
  
  export function setView(lat, lng, newZoom) {
    map?.setView([lat, lng], newZoom);
  }
</script>

<div bind:this={mapContainer} class="map-container" style={style}>
  {#if mapReady}
    <slot />
  {/if}
</div>

<style>
  .map-container {
    height: 500px;
    width: 100%;
    border-radius: 8px;
    overflow: hidden;
    position: relative;
    z-index: 1;  /* Adicionar z-index baixo */
  }
  
  /* Estilos padrão para tiles Leaflet */
  :global(.leaflet-container) {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  
  :global(.leaflet-popup-content-wrapper) {
    border-radius: 8px;
  }

  /* Forçar todos os elementos do Leaflet terem z-index menor */
  :global(.leaflet-pane),
  :global(.leaflet-top),
  :global(.leaflet-bottom),
  :global(.leaflet-control-container),
  :global(.leaflet-popup) {
    z-index: 1000 !important;
  }
</style>
```

### `src/lib/AppMap.svelte`

```svelte
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
```

### `src/lib/BaseMap.svelte`

```svelte
<script>
  import { onMount, onDestroy, setContext } from 'svelte';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  export let center = [-23.56, -45.15];
  export let zoom = 15;
  export let style = {};

  let mapContainer;
  let map;
  let mapReady = false;

  // Expose map instance to child components via context
  setContext('leaflet-map', {
    getMap: () => map,
    isReady: () => mapReady
  });

  onMount(() => {
    // Aguardar o próximo tick para garantir que o DOM está pronto
    setTimeout(() => {
      map = L.map(mapContainer).setView(center, zoom);
      mapReady = true;
    }, 0);
  });

  onDestroy(() => {
    map?.remove();
  });

  // Public methods
  export function fitBounds(bounds) {
    map?.fitBounds(bounds);
  }

  export function getMap() {
    return map;
  }
</script>

<div class="map-container" bind:this={mapContainer} style={style}>
  {#if mapReady}
    <slot />
  {/if}
</div>

<style>
  .map-container {
    height: 600px;
    width: 100%;
    border: 2px solid #ccc;
    border-radius: 8px;
  }
</style>
```


---

## 📁 src/lib/City

### `src/lib/City/Briefing.svelte`

```svelte
<script>
  // Dados mockados (substituir pela chamada API real)
  let cityData = {
    "agro_percent": "0.42407487334352667",
    "alunos_eja": 108,
    "alunos_fundamental": 2938,
    "alunos_infantil": 859,
    "alunos_medio": 1019,
    "alunos_por_1000_hab": "216.09",
    "alunos_por_docente": "11.6",
    "alunos_por_escola": "154",
    "ano_ideb": 2023,
    "ano_pib": 2021,
    "co_municipio": "1100015",
    "escolas_privadas": 1,
    "escolas_publicas": 31,
    "escolas_rurais": 20,
    "escolas_urbanas": 12,
    "governo_percent": "0.23571106666466976",
    "ideb_fund_i": "6.9",
    "ideb_fund_ii": "5.4",
    "ideb_medio": "5.5",
    "industria_percent": "0.037911846277640791",
    "no_municipio": "Alta Floresta D'Oeste",
    "no_regiao": "Norte",
    "perc_docentes_concursados": "64.55",
    "perc_docentes_superior": "94.13",
    "pib_per_capita": "32231.84",
    "pib_total": "734467",
    "pop_0_a_14": 4627,
    "pop_15_a_24": 3198,
    "pop_25_a_59": 8968,
    "pop_60_mais": 3079,
    "populacao_estimada": 22787,
    "score_acessibilidade_medio": "3.08",
    "score_gestao_medio": "3.59",
    "score_infra_medio": "5.31",
    "score_tecnologia_medio": "3.85",
    "servicos_percent": "0.30230221371416277",
    "sg_uf": "RO",
    "total_alunos": 4924,
    "total_docentes": 426,
    "total_escolas": 32
  };

  let loading = false;
  let error = null;
  let activeTab = 'resumo';

  // Formatação de números
  const formatNumber = (value, decimals = 0) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toLocaleString('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
  };

  const formatPercent = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return (num * 100).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
  };

  const formatCurrency = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return 'R$ ' + num.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  const formatScore = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toFixed(1);
  };

  // Cores baseadas em scores
  const getScoreColor = (score) => {
    const s = parseFloat(score);
    if (s >= 8) return 'green';
    if (s >= 6) return 'lightgreen';
    if (s >= 4) return 'orange';
    return 'red';
  };

  const getIdebColor = (ideb) => {
    const i = parseFloat(ideb);
    if (i >= 7) return 'green';
    if (i >= 5) return 'lightgreen';
    if (i >= 4) return 'orange';
    return 'red';
  };

  // Função para gerar segmentos do pie chart
  const generatePieSegments = () => {
    const values = [
      { label: 'Agro', value: parseFloat(cityData.agro_percent) || 0, color: '#22c55e' },
      { label: 'Indústria', value: parseFloat(cityData.industria_percent) || 0, color: '#3b82f6' },
      { label: 'Serviços', value: parseFloat(cityData.servicos_percent) || 0, color: '#f59e0b' },
      { label: 'Governo', value: parseFloat(cityData.governo_percent) || 0, color: '#ef4444' }
    ];
    
    // Filtrar valores zero
    const nonZero = values.filter(v => v.value > 0);
    
    // Calcular total e proporções
    const total = nonZero.reduce((sum, v) => sum + v.value, 0);
    let currentAngle = 0;
    
    return nonZero.map(v => {
      const angle = (v.value / total) * 360;
      const startAngle = currentAngle;
      const endAngle = currentAngle + angle;
      currentAngle = endAngle;
      
      // Calcular coordenadas para SVG arc
      const startRad = (startAngle - 90) * Math.PI / 180;
      const endRad = (endAngle - 90) * Math.PI / 180;
      
      const radius = 80;
      const centerX = 100;
      const centerY = 100;
      
      const x1 = centerX + radius * Math.cos(startRad);
      const y1 = centerY + radius * Math.sin(startRad);
      const x2 = centerX + radius * Math.cos(endRad);
      const y2 = centerY + radius * Math.sin(endRad);
      
      const largeArc = angle > 180 ? 1 : 0;
      
      return {
        label: v.label,
        value: (v.value * 100).toFixed(1),
        color: v.color,
        path: `M ${centerX} ${centerY} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z`
      };
    });
  };
</script>

<main>
  <div class="container">
    <!-- Cabeçalho -->
    <div class="header">
      <h1>
        {cityData.no_municipio}
        <span class="uf-badge">{cityData.sg_uf}</span>
      </h1>
      <p class="subtitle">Região {cityData.no_regiao} • Código IBGE {cityData.co_municipio}</p>
    </div>

    <!-- Tabs -->
    <div class="tabs">
      <button class="tab" class:active={activeTab === 'resumo'} on:click={() => activeTab = 'resumo'}>
        📊 Resumo
      </button>
      <button class="tab" class:active={activeTab === 'infra'} on:click={() => activeTab = 'infra'}>
        🏗️ Infraestrutura
      </button>
      <button class="tab" class:active={activeTab === 'economia'} on:click={() => activeTab = 'economia'}>
        💰 Economia
      </button>
      <button class="tab" class:active={activeTab === 'demografia'} on:click={() => activeTab = 'demografia'}>
        👥 Demografia
      </button>
    </div>

    {#if activeTab === 'resumo'}
      <!-- Aba Resumo -->
      <div class="summary-grid">
        <div class="card">
          <div class="card-title">📚 População Escolar</div>
          <div class="stat-large">{formatNumber(cityData.total_alunos)}</div>
          <div class="stat-detail">
            <span>👶 Infantil: {formatNumber(cityData.alunos_infantil)}</span>
            <span>📘 Fundamental: {formatNumber(cityData.alunos_fundamental)}</span>
            <span>🎓 Médio: {formatNumber(cityData.alunos_medio)}</span>
            <span>📖 EJA: {formatNumber(cityData.alunos_eja)}</span>
          </div>
        </div>

        <div class="card">
          <div class="card-title">🎯 Qualidade do Ensino (IDEB)</div>
          <div class="ideb-grid">
            <div class="ideb-item">
              <span class="ideb-label">Fund. I</span>
              <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_i)}">
                {formatNumber(cityData.ideb_fund_i, 1)}
              </span>
            </div>
            <div class="ideb-item">
              <span class="ideb-label">Fund. II</span>
              <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_ii)}">
                {formatNumber(cityData.ideb_fund_ii, 1)}
              </span>
            </div>
            <div class="ideb-item">
              <span class="ideb-label">Médio</span>
              <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_medio)}">
                {formatNumber(cityData.ideb_medio, 1)}
              </span>
            </div>
          </div>
          <div class="card-footnote">Ano referência: {cityData.ano_ideb}</div>
        </div>

        <div class="card">
          <div class="card-title">👩‍🏫 Corpo Docente</div>
          <div class="stat-large">{formatNumber(cityData.total_docentes)}</div>
          <div class="stat-detail">
            <span>🎓 Superior: {formatPercent(cityData.perc_docentes_superior)}</span>
            <span>⚖️ Concursados: {formatPercent(cityData.perc_docentes_concursados)}</span>
            <span>👨‍👩‍👧 Aluno/Docente: {cityData.alunos_por_docente}</span>
          </div>
        </div>

        <div class="card">
          <div class="card-title">🏫 Rede Escolar</div>
          <div class="stat-large">{formatNumber(cityData.total_escolas)} escolas</div>
          <div class="stat-detail">
            <span>🏛️ Pública: {cityData.escolas_publicas}</span>
            <span>🏨 Privada: {cityData.escolas_privadas}</span>
            <span>🌆 Urbana: {cityData.escolas_urbanas}</span>
            <span>🌾 Rural: {cityData.escolas_rurais}</span>
          </div>
        </div>
      </div>

      <div class="cards-row">
        <div class="card half">
          <div class="card-title">📈 Infraestrutura (Score 0-10)</div>
          <div class="scores-grid">
            <div class="score-item">
              <span>🏗️ Básica</span>
              <div class="score-bar">
                <div class="score-fill" style="width: {parseFloat(cityData.score_infra_medio) * 10}%"></div>
              </div>
              <span class="score-value">{formatScore(cityData.score_infra_medio)}</span>
            </div>
            <div class="score-item">
              <span>💻 Tecnologia</span>
              <div class="score-bar">
                <div class="score-fill" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%"></div>
              </div>
              <span class="score-value">{formatScore(cityData.score_tecnologia_medio)}</span>
            </div>
            <div class="score-item">
              <span>♿ Acessibilidade</span>
              <div class="score-bar">
                <div class="score-fill" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%"></div>
              </div>
              <span class="score-value">{formatScore(cityData.score_acessibilidade_medio)}</span>
            </div>
            <div class="score-item">
              <span>🗳️ Gestão</span>
              <div class="score-bar">
                <div class="score-fill" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%"></div>
              </div>
              <span class="score-value">{formatScore(cityData.score_gestao_medio)}</span>
            </div>
          </div>
        </div>

        <div class="card half">
          <div class="card-title">👥 Atendimento Educacional</div>
          <div class="stats-compact">
            <div class="stat-row">
              <span>📊 Alunos por 1.000 hab:</span>
              <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)}</strong>
            </div>
            <div class="stat-row">
              <span>📚 Alunos por escola:</span>
              <strong>{formatNumber(cityData.alunos_por_escola)}</strong>
            </div>
            <div class="stat-row">
              <span>👩‍🏫 Alunos por docente:</span>
              <strong>{cityData.alunos_por_docente}</strong>
            </div>
          </div>
        </div>
      </div>
    {/if}

    {#if activeTab === 'infra'}
      <div class="full-card">
        <div class="card-title">🏗️ Indicadores de Infraestrutura Escolar</div>
        <div class="scores-detailed">
          <div class="score-detailed-item">
            <div class="score-label">Infraestrutura Básica (água, esgoto, energia, lixo)</div>
            <div class="score-bar-large">
              <div class="score-fill-large" style="width: {parseFloat(cityData.score_infra_medio) * 10}%; background: #2563eb;"></div>
            </div>
            <div class="score-number">{formatScore(cityData.score_infra_medio)}/10</div>
          </div>
          <div class="score-detailed-item">
            <div class="score-label">Tecnologia e Conectividade</div>
            <div class="score-bar-large">
              <div class="score-fill-large" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%; background: #059669;"></div>
            </div>
            <div class="score-number">{formatScore(cityData.score_tecnologia_medio)}/10</div>
          </div>
          <div class="score-detailed-item">
            <div class="score-label">Acessibilidade e Inclusão</div>
            <div class="score-bar-large">
              <div class="score-fill-large" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%; background: #d97706;"></div>
            </div>
            <div class="score-number">{formatScore(cityData.score_acessibilidade_medio)}/10</div>
          </div>
          <div class="score-detailed-item">
            <div class="score-label">Gestão e Participação</div>
            <div class="score-bar-large">
              <div class="score-fill-large" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%; background: #7c3aed;"></div>
            </div>
            <div class="score-number">{formatScore(cityData.score_gestao_medio)}/10</div>
          </div>
        </div>
      </div>
    {/if}
    {#if activeTab === 'economia'}
      <div class="grid-2cols">
        <div class="card">
          <div class="card-title">💰 Produto Interno Bruto</div>
          <div class="stat-large">{formatCurrency(cityData.pib_total)}</div>
          <div class="stat-detail">PIB per capita</div>
          <div class="stat-large" style="font-size: 1.5rem;">{formatCurrency(cityData.pib_per_capita)}</div>
          <div class="stat-detail">PIB total (milhares de R$)</div>
          <div class="card-footnote">Ano referência: {cityData.ano_pib}</div>
        </div>

        <div class="card">
          <div class="card-title">🏭 Composição Setorial do PIB</div>
          
          {#if parseFloat(cityData.agro_percent) || parseFloat(cityData.industria_percent) || parseFloat(cityData.servicos_percent) || parseFloat(cityData.governo_percent)}
            <div class="pie-container">
              <div class="pie-chart">
                <svg viewBox="0 0 200 200" width="160" height="160">
                  {#each generatePieSegments() as segment}
                    <path d={segment.path} fill={segment.color} stroke="white" stroke-width="2" />
                  {/each}
                  <circle cx="100" cy="100" r="45" fill="white" />
                  <text x="100" y="95" text-anchor="middle" font-size="11" font-weight="bold" fill="#333">
                    Total
                  </text>
                  <text x="100" y="110" text-anchor="middle" font-size="9" fill="#666">
                    100%
                  </text>
                </svg>
              </div>
              
              <div class="pie-legend">
                {#each generatePieSegments() as segment}
                  <div class="legend-item">
                    <span class="legend-color" style="background: {segment.color}"></span>
                    <span class="legend-label">{segment.label}</span>
                    <span class="legend-value">{segment.value}%</span>
                  </div>
                {/each}
              </div>
            </div>
            
            <div class="card-footnote" style="margin-top: 1rem;">
              Dados do IBGE - Censo {cityData.ano_pib}
            </div>
          {:else}
            <div class="no-data-message">
              <p>📭 Dados de composição setorial não disponíveis</p>
              <p class="no-data-sub">Município sem dados detalhados do PIB para {cityData.ano_pib}</p>
            </div>
          {/if}
        </div>
      </div>
    {/if}

    {#if activeTab === 'demografia'}
      <div class="grid-2cols">
        <div class="card">
          <div class="card-title">👥 População</div>
          <div class="stat-large">{formatNumber(cityData.populacao_estimada)}</div>
          <div class="stat-detail">habitantes estimados</div>
          <div class="pyramid-container">
            <div class="age-group">
              <span>0-14 anos</span>
              <div class="age-bar">
                <div class="age-bar-fill" style="width: {(cityData.pop_0_a_14 / cityData.populacao_estimada) * 100}%;"></div>
              </div>
              <span>{formatPercent(cityData.pop_0_a_14 / cityData.populacao_estimada)}</span>
            </div>
            <div class="age-group">
              <span>15-24 anos</span>
              <div class="age-bar">
                <div class="age-bar-fill" style="width: {(cityData.pop_15_a_24 / cityData.populacao_estimada) * 100}%;"></div>
              </div>
              <span>{formatPercent(cityData.pop_15_a_24 / cityData.populacao_estimada)}</span>
            </div>
            <div class="age-group">
              <span>25-59 anos</span>
              <div class="age-bar">
                <div class="age-bar-fill" style="width: {(cityData.pop_25_a_59 / cityData.populacao_estimada) * 100}%;"></div>
              </div>
              <span>{formatPercent(cityData.pop_25_a_59 / cityData.populacao_estimada)}</span>
            </div>
            <div class="age-group">
              <span>60+ anos</span>
              <div class="age-bar">
                <div class="age-bar-fill" style="width: {(cityData.pop_60_mais / cityData.populacao_estimada) * 100}%;"></div>
              </div>
              <span>{formatPercent(cityData.pop_60_mais / cityData.populacao_estimada)}</span>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-title">📊 Indicadores de Cobertura</div>
          <div class="stats-compact">
            <div class="stat-row">
              <span>📚 Cobertura escolar (alunos/1.000 hab):</span>
              <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)}</strong>
            </div>
            <div class="stat-row">
              <span>🏫 Densidade de escolas (escolas/1.000 hab):</span>
              <strong>{(cityData.total_escolas / cityData.populacao_estimada * 1000).toFixed(2)}</strong>
            </div>
            <div class="stat-row">
              <span>👩‍🎓 Percentual da população na escola:</span>
              <strong>{formatPercent(cityData.total_alunos / cityData.populacao_estimada)}</strong>
            </div>
          </div>
          <div class="card-footnote" style="margin-top: 1rem;">
            Dados populacionais: Censo IBGE 2022
          </div>
        </div>
      </div>
    {/if}
  </div>
</main>

<style>
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f3f4f6;
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 1.5rem;
  }

  .header {
    margin-bottom: 1.5rem;
    padding-bottom: 1rem;
    border-bottom: 2px solid #e5e7eb;
  }

  h1 {
    font-size: 1.875rem;
    font-weight: 700;
    color: #111827;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.5rem;
  }

  .uf-badge {
    background: #2563eb;
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .subtitle {
    color: #6b7280;
    font-size: 0.875rem;
  }

  .tabs {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }

  .tab {
    padding: 0.75rem 1.5rem;
    background: none;
    border: none;
    font-size: 0.875rem;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.2s;
  }

  .tab:hover {
    color: #2563eb;
  }

  .tab.active {
    color: #2563eb;
    border-bottom: 2px solid #2563eb;
  }

  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.25rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .half {
    flex: 1;
  }

  .card-title {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #6b7280;
    margin-bottom: 1rem;
  }

  .stat-large {
    font-size: 2rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .stat-detail {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    font-size: 0.75rem;
    color: #6b7280;
    border-top: 1px solid #e5e7eb;
    padding-top: 0.75rem;
    margin-top: 0.5rem;
  }

  .ideb-grid {
    display: flex;
    justify-content: space-around;
    text-align: center;
  }

  .ideb-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .ideb-label {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .ideb-value {
    font-size: 1.5rem;
    font-weight: 700;
  }

  .scores-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .score-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .score-bar {
    flex: 1;
    height: 6px;
    background: #e5e7eb;
    border-radius: 3px;
    overflow: hidden;
  }

  .score-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 3px;
  }

  .score-value {
    min-width: 2rem;
    text-align: right;
    font-weight: 500;
  }

  .cards-row {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .stats-compact {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .stat-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
  }

  .grid-2cols {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 1rem;
  }

  .full-card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .scores-detailed {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .score-detailed-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .score-label {
    width: 180px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .score-bar-large {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .score-fill-large {
    height: 100%;
    border-radius: 4px;
  }

  .score-number {
    min-width: 3rem;
    text-align: right;
    font-weight: 600;
  }

  .pie-chart-placeholder {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .pie-bar {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .pie-segment {
    padding: 0.5rem;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 500;
    text-align: center;
    color: white;
  }

  .pyramid-container {
    margin-top: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .age-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.875rem;
  }

  .age-bar {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .age-bar-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 4px;
  }

  .card-footnote {
    margin-top: 0.75rem;
    font-size: 0.7rem;
    color: #9ca3af;
    text-align: right;
  }

  .pie-container {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 2rem;
    flex-wrap: wrap;
  }

  .pie-chart {
    flex-shrink: 0;
  }

  .pie-legend {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .legend-label {
    min-width: 70px;
    color: #374151;
  }

  .legend-value {
    font-weight: 600;
    color: #111827;
    margin-left: auto;
  }

  .no-data-message {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    color: #6b7280;
  }

  .no-data-sub {
    font-size: 0.75rem;
    margin-top: 0.5rem;
  }
</style>
```

### `src/lib/City/CitySelector.svelte`

```svelte
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
```

### `src/lib/City/DetailModal.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';

  export let isOpen = false;
  export let cityData = null;
  export let onClose = () => {};

  let activeTab = 'resumo';
  let loading = false;
  let error = null;

  const dispatch = createEventDispatcher();

  const closeModal = () => {
    isOpen = false;
    onClose();
    dispatch('close');
  };

  // Formatação de números
  const formatNumber = (value, decimals = 0) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toLocaleString('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
  };

  const formatPercent = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    if ( num < 1 ) {
      return (num * 100).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
    } else {
      return (num).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
    }
  };

  const formatCurrency = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return 'R$ ' + num.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  const formatScore = (value) => {
    if (!value && value !== 0) return 'N/A';
    const num = typeof value === 'string' ? parseFloat(value) : value;
    return num.toFixed(1);
  };

  const getIdebColor = (ideb) => {
    const i = parseFloat(ideb);
    if (i >= 7) return '#059669';
    if (i >= 5) return '#22c55e';
    if (i >= 3) return '#f59e0b';
    return '#ef4444';
  };

  // Função para gerar segmentos do pie chart
  const generatePieSegments = () => {
    if (!cityData) return [];
    
    const values = [
      { label: 'Agro', value: parseFloat(cityData.agro_percent) || 0, color: '#22c55e' },
      { label: 'Indústria', value: parseFloat(cityData.industria_percent) || 0, color: '#3b82f6' },
      { label: 'Serviços', value: parseFloat(cityData.servicos_percent) || 0, color: '#f59e0b' },
      { label: 'Governo', value: parseFloat(cityData.governo_percent) || 0, color: '#ef4444' }
    ];
    
    const nonZero = values.filter(v => v.value > 0);
    const total = nonZero.reduce((sum, v) => sum + v.value, 0);
    let currentAngle = 0;
    
    return nonZero.map(v => {
      const angle = (v.value / total) * 360;
      const startAngle = currentAngle;
      const endAngle = currentAngle + angle;
      currentAngle = endAngle;
      
      const startRad = (startAngle - 90) * Math.PI / 180;
      const endRad = (endAngle - 90) * Math.PI / 180;
      const radius = 80;
      const centerX = 100;
      const centerY = 100;
      const x1 = centerX + radius * Math.cos(startRad);
      const y1 = centerY + radius * Math.sin(startRad);
      const x2 = centerX + radius * Math.cos(endRad);
      const y2 = centerY + radius * Math.sin(endRad);
      const largeArc = angle > 180 ? 1 : 0;
      
      return {
        label: v.label,
        value: (v.value * 100).toFixed(1),
        color: v.color,
        path: `M ${centerX} ${centerY} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2} Z`
      };
    });
  };
</script>

{#if isOpen && cityData}
  <div class="modal-overlay" on:click={closeModal} 
  on:keydown={(e) => e.key === 'Escape' && closeModal()}
  role="button"
  tabindex=0
  >
    <div class="modal-container" on:click|stopPropagation>
      <div class="modal-header">
        <div class="modal-title">
          <h2>
            {cityData.no_municipio || cityData.nome_municipio}
            <span class="uf-badge">{cityData.sg_uf || cityData.sigla_estado}</span>
          </h2>
          <p class="modal-subtitle">
            Região {cityData.no_regiao || ''} • Código IBGE {cityData.co_municipio || cityData.codigo_ibge}
          </p>
        </div>
        <button class="close-btn" on:click={closeModal}>✕</button>
      </div>

      <div class="modal-tabs">
        <button class="tab" class:active={activeTab === 'resumo'} on:click={() => activeTab = 'resumo'}>
          📊 Resumo
        </button>
        <button class="tab" class:active={activeTab === 'infra'} on:click={() => activeTab = 'infra'}>
          🏗️ Infraestrutura
        </button>
        <button class="tab" class:active={activeTab === 'economia'} on:click={() => activeTab = 'economia'}>
          💰 Economia
        </button>
        <button class="tab" class:active={activeTab === 'demografia'} on:click={() => activeTab = 'demografia'}>
          👥 Demografia
        </button>
      </div>

      <div class="modal-body">
        {#if activeTab === 'resumo'}
          <div class="summary-grid">
            <div class="card">
              <div class="card-title">📚 População Escolar</div>
              <div class="stat-large">{formatNumber(cityData.total_alunos)}</div>
              <div class="stat-detail">
                <span>👶 Infantil: {formatNumber(cityData.alunos_infantil)}</span>
                <span>📘 Fundamental: {formatNumber(cityData.alunos_fundamental)}</span>
                <span>🎓 Médio: {formatNumber(cityData.alunos_medio)}</span>
                <span>📖 EJA: {formatNumber(cityData.alunos_eja)}</span>
              </div>
            </div>

            <div class="card">
              <div class="card-title">🎯 Qualidade do Ensino (IDEB)</div>
              <div class="ideb-grid">
                <div class="ideb-item">
                  <span class="ideb-label">Fund. I</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_i)}">
                    {formatNumber(cityData.ideb_fund_i, 1)}
                  </span>
                </div>
                <div class="ideb-item">
                  <span class="ideb-label">Fund. II</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_fund_ii)}">
                    {formatNumber(cityData.ideb_fund_ii, 1)}
                  </span>
                </div>
                <div class="ideb-item">
                  <span class="ideb-label">Médio</span>
                  <span class="ideb-value" style="color: {getIdebColor(cityData.ideb_medio)}">
                    {formatNumber(cityData.ideb_medio, 1)}
                  </span>
                </div>
              </div>
              <div class="card-footnote">Ano referência: {cityData.ano_ideb || 2023}</div>
            </div>

            <div class="card">
              <div class="card-title">👩‍🏫 Corpo Docente</div>
              <div class="stat-large">{formatNumber(cityData.total_docentes)}</div>
              <div class="stat-detail">
                <span>🎓 Superior: {formatPercent(cityData.perc_docentes_superior)}</span>
                <span>⚖️ Concursados: {formatPercent(cityData.perc_docentes_concursados)}</span>
                <span>👨‍👩‍👧 Aluno/Docente: {cityData.alunos_por_docente}</span>
              </div>
            </div>

            <div class="card">
              <div class="card-title">🏫 Rede Escolar</div>
              <div class="stat-large">{formatNumber(cityData.total_escolas)} escolas</div>
              <div class="stat-detail">
                <span>🏛️ Pública: {cityData.escolas_publicas}</span>
                <span>🏨 Privada: {cityData.escolas_privadas}</span>
                <span>🌆 Urbana: {cityData.escolas_urbanas}</span>
                <span>🌾 Rural: {cityData.escolas_rurais}</span>
              </div>
            </div>
          </div>

          <div class="cards-row">
            <div class="card half">
              <div class="card-title">📈 Infraestrutura (Score 0-10)</div>
              <div class="scores-grid">
                <div class="score-item">
                  <span>🏗️ Básica</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_infra_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_infra_medio)}</span>
                </div>
                <div class="score-item">
                  <span>💻 Tecnologia</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_tecnologia_medio)}</span>
                </div>
                <div class="score-item">
                  <span>♿ Acessibilidade</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_acessibilidade_medio)}</span>
                </div>
                <div class="score-item">
                  <span>🗳️ Gestão</span>
                  <div class="score-bar">
                    <div class="score-fill" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%"></div>
                  </div>
                  <span class="score-value">{formatScore(cityData.score_gestao_medio)}</span>
                </div>
              </div>
            </div>

            <div class="card half">
              <div class="card-title">👥 Atendimento Educacional</div>
              <div class="stats-compact">
                <div class="stat-row">
                  <span>📊 Alunos por 1.000 hab:</span>
                  <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)}</strong>
                </div>
                <div class="stat-row">
                  <span>📚 Alunos por escola:</span>
                  <strong>{formatNumber(cityData.alunos_por_escola)}</strong>
                </div>
                <div class="stat-row">
                  <span>👩‍🏫 Alunos por docente:</span>
                  <strong>{cityData.alunos_por_docente}</strong>
                </div>
              </div>
            </div>
          </div>
        {/if}

        {#if activeTab === 'infra'}
          <div class="full-card">
            <div class="card-title">🏗️ Indicadores de Infraestrutura Escolar</div>
            <div class="scores-detailed">
              <div class="score-detailed-item">
                <div class="score-label">Infraestrutura Básica</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_infra_medio) * 10}%; background: #2563eb;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_infra_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Tecnologia e Conectividade</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_tecnologia_medio) * 10}%; background: #059669;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_tecnologia_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Acessibilidade e Inclusão</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_acessibilidade_medio) * 10}%; background: #d97706;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_acessibilidade_medio)}/10</div>
              </div>
              <div class="score-detailed-item">
                <div class="score-label">Gestão e Participação</div>
                <div class="score-bar-large">
                  <div class="score-fill-large" style="width: {parseFloat(cityData.score_gestao_medio) * 10}%; background: #7c3aed;"></div>
                </div>
                <div class="score-number">{formatScore(cityData.score_gestao_medio)}/10</div>
              </div>
            </div>
          </div>
        {/if}

        {#if activeTab === 'economia'}
          <div class="grid-2cols">
            <div class="card">
              <div class="card-title">💰 Produto Interno Bruto</div>
              <div class="stat-large">{formatCurrency(cityData.pib_total)}</div>
              <div class="stat-detail">PIB total (R$ milhares)</div>
              <div class="stat-large" style="font-size: 1.5rem;">{formatCurrency(cityData.pib_per_capita)}</div>
              <div class="stat-detail">PIB per capita</div>
              <div class="card-footnote">Ano referência: {cityData.ano_pib || 2021}</div>
            </div>

            <div class="card">
              <div class="card-title">🏭 Composição Setorial do PIB</div>
              {#if parseFloat(cityData.agro_percent) || parseFloat(cityData.industria_percent) || parseFloat(cityData.servicos_percent) || parseFloat(cityData.governo_percent)}
                <div class="pie-container">
                  <div class="pie-chart">
                    <svg viewBox="0 0 200 200" width="160" height="160">
                      {#each generatePieSegments() as segment}
                        <path d={segment.path} fill={segment.color} stroke="white" stroke-width="2" />
                      {/each}
                      <circle cx="100" cy="100" r="45" fill="white" />
                      <text x="100" y="95" text-anchor="middle" font-size="11" font-weight="bold" fill="#333">Total</text>
                      <text x="100" y="110" text-anchor="middle" font-size="9" fill="#666">100%</text>
                    </svg>
                  </div>
                  <div class="pie-legend">
                    {#each generatePieSegments() as segment}
                      <div class="legend-item">
                        <span class="legend-color" style="background: {segment.color}"></span>
                        <span class="legend-label">{segment.label}</span>
                        <span class="legend-value">{segment.value}%</span>
                      </div>
                    {/each}
                  </div>
                </div>
              {:else}
                <div class="no-data-message">
                  <p>📭 Dados de composição setorial não disponíveis</p>
                </div>
              {/if}
            </div>
          </div>
        {/if}

        {#if activeTab === 'demografia'}
          <div class="grid-2cols">
            <div class="card">
              <div class="card-title">👥 População</div>
              <div class="stat-large">{formatNumber(cityData.populacao_estimada)}</div>
              <div class="stat-detail">habitantes estimados</div>
              <div class="pyramid-container">
                <div class="age-group">
                  <span>0-14 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_0_a_14 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_0_a_14 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>15-24 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_15_a_24 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_15_a_24 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>25-59 anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_25_a_59 / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_25_a_59 / cityData.populacao_estimada)}</span>
                </div>
                <div class="age-group">
                  <span>60+ anos</span>
                  <div class="age-bar">
                    <div class="age-bar-fill" style="width: {(cityData.pop_60_mais / cityData.populacao_estimada) * 100}%;"></div>
                  </div>
                  <span>{formatPercent(cityData.pop_60_mais / cityData.populacao_estimada)}</span>
                </div>
              </div>
            </div>

            <div class="card">
              <div class="card-title">📊 Indicadores de Cobertura</div>
              <div class="stats-compact">
                <div class="stat-row">
                  <span>📚 Cobertura escolar:</span>
                  <strong>{formatNumber(cityData.alunos_por_1000_hab, 2)} alunos/1.000 hab</strong>
                </div>
                <div class="stat-row">
                  <span>🏫 Densidade de escolas:</span>
                  <strong>{(cityData.total_escolas / cityData.populacao_estimada * 1000).toFixed(2)} escolas/1.000 hab</strong>
                </div>
                <div class="stat-row">
                  <span>👩‍🎓 % população na escola:</span>
                  <strong>{formatPercent(cityData.total_alunos / cityData.populacao_estimada)}</strong>
                </div>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 99999;
  }

  .modal-container {
    background: #f3f4f6;
    border-radius: 1rem;
    width: 90vw;
    max-width: 1200px;
    height: 85vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 25px 50px rgba(0,0,0,0.3);
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    padding: 1.25rem 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .modal-title h2 {
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.25rem;
  }

  .uf-badge {
    background: #2563eb;
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .modal-subtitle {
    color: #6b7280;
    font-size: 0.875rem;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #6b7280;
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
  }

  .close-btn:hover {
    background: #f3f4f6;
    color: #111827;
  }

  .modal-tabs {
    display: flex;
    gap: 0.5rem;
    padding: 0 1.5rem;
    background: white;
    border-bottom: 1px solid #e5e7eb;
  }

  .tab {
    padding: 0.75rem 1.5rem;
    background: none;
    border: none;
    font-size: 0.875rem;
    font-weight: 500;
    color: #6b7280;
    cursor: pointer;
    transition: all 0.2s;
  }

  .tab:hover {
    color: #2563eb;
  }

  .tab.active {
    color: #2563eb;
    border-bottom: 2px solid #2563eb;
  }

  .modal-body {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }

  /* Reutilizando os estilos já existentes */
  .summary-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.25rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .half {
    flex: 1;
  }

  .card-title {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #6b7280;
    margin-bottom: 1rem;
  }

  .stat-large {
    font-size: 2rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .stat-detail {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    font-size: 0.75rem;
    color: #6b7280;
    border-top: 1px solid #e5e7eb;
    padding-top: 0.75rem;
    margin-top: 0.5rem;
  }

  .ideb-grid {
    display: flex;
    justify-content: space-around;
    text-align: center;
  }

  .ideb-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.25rem;
  }

  .ideb-label {
    font-size: 0.75rem;
    color: #6b7280;
  }

  .ideb-value {
    font-size: 1.5rem;
    font-weight: 700;
  }

  .scores-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .score-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .score-bar {
    flex: 1;
    height: 6px;
    background: #e5e7eb;
    border-radius: 3px;
    overflow: hidden;
  }

  .score-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 3px;
  }

  .score-value {
    min-width: 2rem;
    text-align: right;
    font-weight: 500;
  }

  .cards-row {
    display: flex;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .stats-compact {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .stat-row {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
  }

  .grid-2cols {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
    gap: 1rem;
  }

  .full-card {
    background: white;
    border-radius: 0.75rem;
    padding: 1.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
  }

  .scores-detailed {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .score-detailed-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .score-label {
    width: 180px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  .score-bar-large {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .score-fill-large {
    height: 100%;
    border-radius: 4px;
  }

  .score-number {
    min-width: 3rem;
    text-align: right;
    font-weight: 600;
  }

  .pyramid-container {
    margin-top: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .age-group {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.875rem;
  }

  .age-bar {
    flex: 1;
    height: 8px;
    background: #e5e7eb;
    border-radius: 4px;
    overflow: hidden;
  }

  .age-bar-fill {
    height: 100%;
    background: #2563eb;
    border-radius: 4px;
  }

  .card-footnote {
    margin-top: 0.75rem;
    font-size: 0.7rem;
    color: #9ca3af;
    text-align: right;
  }

  .pie-container {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 2rem;
    flex-wrap: wrap;
  }

  .pie-chart {
    flex-shrink: 0;
  }

  .pie-legend {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .legend-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 4px;
    flex-shrink: 0;
  }

  .legend-label {
    min-width: 70px;
    color: #374151;
  }

  .legend-value {
    font-weight: 600;
    color: #111827;
    margin-left: auto;
  }

  .no-data-message {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    color: #6b7280;
  }
</style>
```

### `src/lib/City/MunicipiosMapa.svelte`

```svelte
<script>
  import CitySelector from './CitySelector.svelte';
  
  let currentCity = null;
  
  const handleCitySelect = (city) => {
    console.log(`MunicipiosMapa: cidade selecionada`, city);
    currentCity = city.original;
    // Opcional: salvar no localStorage ou store global
    localStorage.setItem('lastSelectedCity', JSON.stringify(city));
  };
</script>

<div class="page">
  <h1 class="page-title">📊 Análise Municipal - Educação no Brasil</h1>
  <p class="page-subtitle">
    Explore indicadores educacionais, econômicos e demográficos de todos os municípios brasileiros
  </p>
  
  <CitySelector onCitySelect={handleCitySelect} />
  
  {#if currentCity}
    <div class="selected-indicator">
      ✅ Município selecionado: <strong>{currentCity.nome_municipio} - {currentCity.sigla_estado}</strong>
      <span class="selected-id">(IBGE: {currentCity.codigo_ibge})</span>
    </div>
  {/if}
</div>

<style>
  .page {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem;
  }

  .page-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .page-subtitle {
    color: #6b7280;
    margin-bottom: 1.5rem;
    font-size: 0.875rem;
  }

  .selected-indicator {
    margin-top: 1rem;
    padding: 0.5rem 1rem;
    background: #e0f2fe;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    color: #0369a1;
  }

  .selected-id {
    font-size: 0.7rem;
    color: #0284c7;
  }
</style>
```


---

## 📁 src/lib

### `src/lib/CityDetail.svelte`

```svelte
<script>
  import { getSiopePayroll } from './js/siope.js';
  import Payroll     from './Siope/Payroll.svelte';
  import JobProgress from './Siope/JobProgress.svelte';
  export let data = null;
  export let year = new Date().getFullYear() - 1; //  Last year
  
  const fieldLabels = {
    'id': 'ID',
    'area': 'Área (km²)',
    'codigo_municipio': 'Código do Município',
    'nome_municipio': 'Município',
    'codigo_unidade_federativa': 'Código UF',
    'nome_unidade_federativa': 'Estado',
    'sigla_unidade_federativa': 'UF',
    'codigo_regiao': 'Código Região',
    'nome_regiao_intermediaria': 'Região Intermediária',
    'nome_regiao_interna': 'Região Imediata',
    'sigla_regiao': 'Sigla Região',
    'codigo_concurso': 'Código Concurso',
    'nome_concurso': 'Nome Concurso',
    'total_escolas': 'Total de Escolas'
  };

  function formatValue(key, value) {
    if (value === null) return 'N/A';
    
    switch (key) {
      case 'area':
        return Number(value).toLocaleString('pt-BR', {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        });
      case 'codigo_municipio':
      case 'codigo_unidade_federativa':
        return `"${value}"`;
      default:
        return String(value);
    }
  }

  // Variáveis de estado para o SIOPE
  let siopePayroll = null; // Armazena os dados finais (Componente 1)
  let siopeJobId = null;  // Armazena o ID do Job (Componente 2)
  let isFetching = false; // Estado de carregamento inicial
  let hasAttempted = false; // Para não mostrar o botão de primeira
  let fetchError = null;

  async function handleFetchSiope() {
      if (!data || !data.codigo_ibge) {
          console.error("Código do município não disponível.");
          return;
      }

      const cityId = String(data.codigo_ibge).slice(0,-1);
      isFetching = true;
      hasAttempted = true;
      siopeJobId = null;
      siopePayroll = null;
      fetchError = null;

      try {
          // Chamada da função principal (GET -> POST, se necessário)
          const result = await getSiopePayroll(cityId, year);
          
          // O getSiopePayroll resolve com o job ID ou com os dados.
          if (typeof result === 'number') {
              // Caso 202 Accepted, result é o Job ID
              siopeJobId = result;
              // O monitorJobProgress do JobProgress.svelte continuará o fluxo
          } else {
              // Caso 200 OK, result são os dados do payroll
              siopePayroll = result;
          }

      } catch (e) {
          fetchError = e.message;
          console.error("Erro no fluxo SIOPE:", e);
      } finally {
          isFetching = false;
      }
  }

  // Callback chamado pelo JobProgress.svelte quando o job Minion termina
  function handleJobComplete(data) {
      siopeJobId = null;
      siopePayroll = data;
      console.log("Fluxo SIOPE concluído e dados recebidos!");
  }
</script>

{#if data}
  <div class="details-container">
    <h3 class="details-header">Detalhes {data.nome_municipio || ''}</h3>
    <p class="details-subheader">Dados malha IBGE, municípios paulista</p>
    
    <table class="geojson-details">
      <tbody>
        {#each Object.entries(data) as [key, value]}
          {#if key !== 'type' && key !== 'geometry'}
            <tr>
              <th>{fieldLabels[key] || key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}</th>
              <td class:null-value={value === null}>
                {formatValue(key, value)}
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>

    <hr/>
    
    <div class="siope-section">
        {#if siopePayroll}
            <Payroll payrollData={siopePayroll} />

        {:else if siopeJobId}
            <JobProgress 
                jobId={siopeJobId} 
                onJobComplete={handleJobComplete} 
                jobName={`Cálculo SIOPE para ${year}`}
            />

        {:else if fetchError}
            <div class="error-message">⚠️ Erro ao buscar dados SIOPE: {fetchError}</div>
            <button on:click={handleFetchSiope} class="fetch-button">Tentar novamente</button>

        {:else}
            <button 
                on:click={handleFetchSiope} 
                disabled={isFetching}
                class="fetch-button primary"
            >
                {#if isFetching}
                    Carregando...
                {:else}
                    Buscar Detalhes SIOPE {year}
                {/if}
            </button>
            <p class="fetch-note">A primeira busca pode iniciar um processo demorado.</p>
        {/if}
    </div>

  </div>

{/if}

<style>
  .details-container {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.5);
    margin: 1rem 0;
  }

  .details-header {
    color: #2c3e50;
    margin-bottom: 0.5rem;
    font-size: 1.2rem;
    font-weight: 600;
  }

  .details-subheader {
    color: #6c757d;
    margin-bottom: 1rem;
    font-size: 0.9rem;
  }

  .geojson-details {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 0.9rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.5);
    border-radius: 8px;
    overflow: hidden;
  }

  .geojson-details th {
    background-color: #f8f9fa;
    padding: 12px 16px;
    text-align: left;
    font-weight: 600;
    color: #2c3e50;
    border-bottom: 2px solid #e9ecef;
    width: 30%;
  }

  .geojson-details td {
    padding: 12px 16px;
    border-bottom: 1px solid #e9ecef;
    background-color: white;
    word-break: break-word;
  }

  .geojson-details tr:last-child td {
    border-bottom: none;
  }

  .geojson-details tr:hover td {
    background-color: #f8f9fa;
  }

  .null-value {
    color: #6c757d;
    font-style: italic;
  }

  @media (max-width: 768px) {
    .geojson-details {
      font-size: 0.8rem;
    }
    
    .geojson-details th,
    .geojson-details td {
      padding: 8px 12px;
    }
    
    .details-container {
      padding: 1rem;
    }
  }
</style>
```

### `src/lib/CityLayer.svelte`

```svelte
<script>
  import { onMount, getContext, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import CityPopup from './CityPopup.svelte';

  export let cityData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  const dispatch = createEventDispatcher();
  
  let geoJsonLayer;
  let mapReady = false;

  $: if (cityData && mapReady) {
    updateLayer(cityData);
  }

  onMount(() => {
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          geoJsonLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      geoJsonLayer?.clearLayers();
      geoJsonLayer?.remove();
    };
  });

  function updateLayer(data) {
    if (!geoJsonLayer || !data) return;

    geoJsonLayer.clearLayers();

    const layer = L.geoJSON(data, {
      style: {
        color: '#3388ff',
        weight: 2,
        fillColor: '#3388ff',
        fillOpacity: 0.2
      },
      onEachFeature: (feature, layer) => {
        const popup = L.popup();
        const popupContainer = document.createElement('div');

        new CityPopup({
          target: popupContainer,
          props: {
            feature: feature.properties,
            onDetails: (fid) => dispatch('details', { fid }),
            onSchools: (city) => dispatch('schools', { city }),
            onOSM: (fid) => dispatch('osm', { fid }),
            onCluster: (clusterData) => dispatch('cluster', clusterData)
          }
        });

        popup.setContent(popupContainer);
        layer.bindPopup(popup);
      }
    });

    layer.addTo(geoJsonLayer);

    // Fit bounds to the new data
    const map = getMap();
    if (map && layer.getBounds().isValid()) {
      map.fitBounds(layer.getBounds());
    }
  }

  export function clear() {
    geoJsonLayer?.clearLayers();
  }
</script>
```

### `src/lib/CityPopup.svelte`

```svelte
<script>
  import { osmDisabled } from './osmStore.js';
  export let feature;
  export let onDetails;
  export let onSchools;
  export let onOSM;
  export let onCluster;  // Novo evento
  
  function handleCluster() {
    // Emite o evento com o código IBGE e nome da cidade
    onCluster({ 
      codigo_ibge: feature.fid,
      city: feature.name
    });
  }
</script>

<div class="popup">
  <strong>{feature.name}</strong><br />
  <button on:click={() => onDetails(feature.fid)}>Detalhes</button><br />
  <button on:click={() => onSchools(feature.fid)}>Escolas</button><br />
  <button on:click={() => onOSM(feature.fid)} disabled={$osmDisabled}>
  OSM {$osmDisabled ? '⏳' : ''} </button><br />
  <button on:click={handleCluster} class='cluster-btn'>Cluster</button>
</div>

<style>
  button {
    all: unset;
    color: #007bff;
    cursor: pointer;
    margin-top: 4px;
    display: inline-block;
  }
  button:hover {
    text-decoration: underline;
  }

  .cluster-btn {
    background-color: #8b5cf6;
    color: white;
  }
</style>
```

### `src/lib/JobProgress.svelte`

```svelte
<script>
  import { onDestroy } from 'svelte';
  
  let jobId = null;
  let progress = 0;
  let jobStatus = 'idle';
  let finalResult = null;
  let errorMessage = '';
  let eventSource = null;

  async function startQuery() {
    jobStatus = 'loading';
    errorMessage = '';
    finalResult = null;
    progress = 0;

    try {
      // Start the job
      const response = await fetch('/api/query-osm?fid=example_fid');
      const data = await response.json();
      jobId = data.job_id;
      jobStatus = 'active';
      
      // Connect to SSE stream
      setupEventSource();
    } catch (error) {
      jobStatus = 'error';
      errorMessage = 'Failed to start the job';
    }
  }

  function setupEventSource() {
    if (eventSource) {
      eventSource.close();
    }

    eventSource = new EventSource(`/api/job-events/${jobId}`);
    
    eventSource.onopen = () => {
      console.log('SSE connection opened');
    };

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        progress = data.progress || 0;
        jobStatus = data.status;
        
        if (data.result) {
          finalResult = data.result;
        }
        
        if (data.status === 'finished' || data.status === 'failed') {
          eventSource.close();
          if (data.status === 'failed') {
            errorMessage = 'Job processing failed';
          }
        }
      } catch (error) {
        console.error('Error parsing SSE data:', error);
      }
    };

    eventSource.onerror = (error) => {
      console.error('SSE error:', error);
      jobStatus = 'error';
      errorMessage = 'Connection error';
      eventSource.close();
    };
  }

  function cancelJob() {
    if (eventSource) {
      eventSource.close();
      eventSource = null;
    }
    jobStatus = 'idle';
    progress = 0;
  }

  onDestroy(() => {
    if (eventSource) {
      eventSource.close();
    }
  });
</script>

<div class="w-full max-w-md mx-auto p-4">
  {#if jobStatus === 'idle'}
    <button on:click={startQuery} class="btn btn-primary">
      Start OSM Query
    </button>
  
  {:else if jobStatus === 'loading'}
    <div class="flex items-center gap-2">
      <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-900"></div>
      <p>Starting job...</p>
    </div>
  
  {:else if jobStatus === 'active'}
    <div>
      <div class="flex justify-between mb-1">
        <span class="font-medium">Processing OSM Data</span>
        <span>{progress}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div 
          class="bg-blue-600 h-2 rounded-full transition-all duration-300" 
          style="width: {progress}%"
        ></div>
      </div>
      <button on:click={cancelJob} class="mt-2 text-sm text-gray-600 hover:text-gray-800">
        Cancel
      </button>
    </div>
  
  {:else if jobStatus === 'finished'}
    <div class="p-4 bg-green-50 border border-green-200 rounded-lg">
      <div class="flex items-center gap-2 text-green-800 mb-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span class="font-medium">Job Complete!</span>
      </div>
      {#if finalResult}
        <p class="text-green-700">Result: {finalResult}</p>
      {/if}
      <button on:click={() => jobStatus = 'idle'} class="mt-3 btn btn-outline">
        Start New Query
      </button>
    </div>
  
  {:else if jobStatus === 'error'}
    <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
      <div class="flex items-center gap-2 text-red-800 mb-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
        </svg>
        <span class="font-medium">Error</span>
      </div>
      <p class="text-red-700">{errorMessage}</p>
      <button on:click={() => jobStatus = 'idle'} class="mt-3 btn btn-outline">
        Try Again
      </button>
    </div>
  {/if}
</div>

<style>
  .btn {
    @apply px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors;
  }
  .btn-outline {
    @apply bg-transparent border border-current text-current hover:bg-gray-100;
  }
  .btn-primary {
    @apply bg-blue-600 hover:bg-blue-700;
  }
</style>
```

### `src/lib/Map.svelte`

```svelte
<script>
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
          new CityPopup({
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
          new SchoolPopup( { target: popupContainer, props: { school: feature.properties } } );
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
```


---

## 📁 src/lib/Map

### `src/lib/Map/MarkerCluster.svelte`

```svelte
<script>
  import { onDestroy } from 'svelte';
  import L from 'leaflet';
  import 'leaflet.markercluster/dist/leaflet.markercluster';
  import 'leaflet.markercluster/dist/MarkerCluster.css';
  import 'leaflet.markercluster/dist/MarkerCluster.Default.css';

  export let getMarkerColor = null;        // função que retorna cor baseada nos dados
  export let getPopupContent = null;       // função que retorna HTML do popup
  export let fetchMarkers = null;          // função async para buscar marcadores (bbox, zoom) => dados
  export let onMarkerClick = null;         // callback quando marcador é clicado
  export let clusterSize = {
    small: { radius: 30, threshold: 10 },
    medium: { radius: 35, threshold: 50 },
    large: { radius: 40, threshold: Infinity }
  };
  export let markerRadius = 7;
  export let clusterSpiderfy = true;
  export let debounceDelay = 300;

  let mapInstance = null;
  let markerClusterGroup = null;
  let loading = false;
  let loadedMarkers = new Set();
  let debounceTimer;

  // Configuração padrão de cores
  const defaultGetMarkerColor = (data) => data.color || '#3b82f6';
  
  // Popup padrão
  const defaultGetPopupContent = (data) => `
    <div style="font-family: sans-serif;">
      <strong>${data.name || 'Sem nome'}</strong><br>
      <button onclick="window.location.href='${data.link || '#'}'">Ver detalhes</button>
    </div>
  `;

  const finalGetMarkerColor = getMarkerColor || defaultGetMarkerColor;
  const finalGetPopupContent = getPopupContent || defaultGetPopupContent;

  // Criar ícone de cluster customizado
  const createClusterIcon = (cluster) => {
    const childCount = cluster.getChildCount();
    let size = 'small';
    
    if (childCount > clusterSize.medium.threshold) {
      size = 'large';
    } else if (childCount > clusterSize.small.threshold) {
      size = 'medium';
    }
    
    const radius = clusterSize[size].radius;
    const fontSize = radius * 0.4;
    
    return L.divIcon({
      html: `<div class="cluster-${size}" style="width: ${radius}px; height: ${radius}px; font-size: ${fontSize}px;">${childCount}</div>`,
      className: 'marker-cluster-custom',
      iconSize: [radius, radius]
    });
  };

  // Adicionar marcadores ao mapa
  const addMarkers = (markersData) => {
    if (!mapInstance || !markersData || markersData.length === 0) return;
    
    if (!markerClusterGroup) {
      markerClusterGroup = L.markerClusterGroup({
        maxClusterRadius: 40,
        spiderfyOnMaxZoom: clusterSpiderfy,
        iconCreateFunction: createClusterIcon
      });
      mapInstance.addLayer(markerClusterGroup);
    }
    
    markersData.forEach(item => {
      if (!item.latitude || !item.longitude) return;
      
      const markerId = item.id || `${item.latitude},${item.longitude}`;
      if (loadedMarkers.has(markerId)) return;
      
      const marker = L.circleMarker([item.latitude, item.longitude], {
        radius: markerRadius,
        fillColor: finalGetMarkerColor(item),
        color: 'white',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.85
      });
      
      marker.options.data = item;
      
      marker.bindPopup(finalGetPopupContent(item));
      
      if (onMarkerClick) {
        marker.on('click', () => onMarkerClick(item, marker));
      }
      
      markerClusterGroup.addLayer(marker);
      loadedMarkers.add(markerId);
    });
  };

  // Carregar marcadores visíveis no viewport
  const loadVisibleMarkers = async () => {
    if (!mapInstance || !fetchMarkers) return;
    
    loading = true;
    
    const bounds = mapInstance.getBounds();
    const zoom = mapInstance.getZoom();
    const bbox = `${bounds.getWest()},${bounds.getSouth()},${bounds.getEast()},${bounds.getNorth()}`;
    
    try {
      const data = await fetchMarkers(bbox, zoom);
      addMarkers(data);
    } catch (err) {
      console.error('Erro ao carregar marcadores:', err);
    } finally {
      loading = false;
    }
  };

  // Handler para eventos do mapa
  const handleMapMoveEnd = () => {
    if (!fetchMarkers) return;
    
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      loadVisibleMarkers();
    }, debounceDelay);
  };

  // Destacar um marcador específico
  export function highlightMarker(id, highlightColor = '#f59e0b', duration = 2000) {
    if (!markerClusterGroup) return;
    
    markerClusterGroup.eachLayer(layer => {
      if (layer.options.data?.id === id || layer.options.data?.co_municipio === id) {
        const originalColor = finalGetMarkerColor(layer.options.data);
        layer.setStyle({ fillColor: highlightColor, radius: markerRadius + 3 });
        
        if (duration > 0) {
          setTimeout(() => {
            if (layer.setStyle) {
              layer.setStyle({ fillColor: originalColor, radius: markerRadius });
            }
          }, duration);
        }
        
        layer.openPopup();
      }
    });
  }

  // Limpar todos os marcadores
  export function clearMarkers() {
    if (markerClusterGroup) {
      markerClusterGroup.clearLayers();
      loadedMarkers.clear();
    }
  }

  // Forçar recarregamento
  export function reload() {
    clearMarkers();
    loadVisibleMarkers();
  }

  // Inicialização do mapa
  export function init(map) {
    mapInstance = map;
    mapInstance.on('moveend', handleMapMoveEnd);
    mapInstance.on('zoomend', handleMapMoveEnd);
    loadVisibleMarkers();
  }

  // Limpeza
  onDestroy(() => {
    if (mapInstance) {
      mapInstance.off('moveend', handleMapMoveEnd);
      mapInstance.off('zoomend', handleMapMoveEnd);
    }
    if (markerClusterGroup) {
      markerClusterGroup.clearLayers();
    }
  });
</script>

<!-- Este componente não renderiza nada visual diretamente -->
<!-- Toda a lógica é gerenciada via JavaScript e Leaflet -->

<style>
  /* Estilos dos clusters */
  :global(.cluster-small) {
    background: #3b82f6;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }

  :global(.cluster-medium) {
    background: #2563eb;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }

  :global(.cluster-large) {
    background: #1d4ed8;
    color: white;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }
</style>
```


---

## 📁 src/lib

### `src/lib/MapControls.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  export let cityName = '';
  export let statusMessage = '';
  export let showClusters = false;  // Novo prop
  export let selectedClusters = [1, 2, 3, 4, 5, 6]; // Novos clusters padrão

  function handleKeyPress(e) {
    if (e.key === 'Enter') dispatch('search');
  }

  function toggleClusters() {
    showClusters = !showClusters;
    dispatch('toggleClusters', { showClusters });
  }

  function updateClusterFilter(clusterId, checked) {
    if (checked) {
      selectedClusters = [...selectedClusters, clusterId];
    } else {
      selectedClusters = selectedClusters.filter(id => id !== clusterId);
    }
    dispatch('clusterFilterChange', { selectedClusters });
  }
</script>

<div class="controls">
  <div class="controls-row">
    <button on:click={() => dispatch('search')}>🔍 Search City</button>
    <button on:click={() => dispatch('clear')}>🗑️ Clear Map</button>
    <input
      bind:value={cityName}
      on:keypress={handleKeyPress}
      type="text"
      placeholder="Enter city name"
      class="form-control"
    />
    <span id="status">{statusMessage}</span>
  </div>
  
  <!-- Controle de Clusterização -->
  <div class="cluster-controls">
    <label class="cluster-toggle">
      <input 
        type="checkbox" 
        bind:checked={showClusters} 
        on:change={toggleClusters}
      />
      <span>📊 Ativar Análise por Clusters</span>
    </label>
    
    {#if showClusters}
      <div class="cluster-filters">
        <span class="filter-label">Filtrar por cluster:</span>
        <label class="filter-chip cluster-1">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(1)}
            on:change={(e) => updateClusterFilter(1, e.target.checked)}
          />
          <span>🏆 Excelência</span>
        </label>
        <label class="filter-chip cluster-2">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(2)}
            on:change={(e) => updateClusterFilter(2, e.target.checked)}
          />
          <span>⭐ Alto</span>
        </label>
        <label class="filter-chip cluster-3">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(3)}
            on:change={(e) => updateClusterFilter(3, e.target.checked)}
          />
          <span>📊 Médio</span>
        </label>
        <label class="filter-chip cluster-4">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(4)}
            on:change={(e) => updateClusterFilter(4, e.target.checked)}
          />
          <span>⚠️ Baixo</span>
        </label>
        <label class="filter-chip cluster-5">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(5)}
            on:change={(e) => updateClusterFilter(5, e.target.checked)}
          />
          <span>📉 Declínio</span>
        </label>
        <label class="filter-chip cluster-6">
          <input 
            type="checkbox" 
            checked={selectedClusters.includes(6)}
            on:change={(e) => updateClusterFilter(6, e.target.checked)}
          />
          <span>📈 Ascensão</span>
        </label>
      </div>
    {/if}
  </div>
</div>

<style>
  .controls {
    margin-bottom: 15px;
    padding: 14px;
    background: #f5f5f5;
    border-radius: 5px;
  }
  
  .controls-row {
    display: flex;
    gap: 10px;
    align-items: center;
    flex-wrap: wrap;
  }
  
  .form-control {
    display: inline-block;
    width: 200px;
    padding: 6px 12px;
    font-size: 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
  }
  
  .cluster-controls {
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid #ddd;
  }
  
  .cluster-toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
    font-weight: 500;
    margin-bottom: 10px;
  }
  
  .cluster-toggle input {
    width: 18px;
    height: 18px;
    cursor: pointer;
  }
  
  .cluster-filters {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-left: 24px;
  }
  
  .filter-label {
    font-size: 12px;
    color: #666;
    margin-right: 4px;
  }
  
  .filter-chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 8px;
    background: white;
    border-radius: 16px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s;
    border: 1px solid #ddd;
  }
  
  .filter-chip:hover {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }
  
  .filter-chip input {
    margin: 0;
    cursor: pointer;
  }
  
  .cluster-1 { border-left: 3px solid #10b981; }
  .cluster-2 { border-left: 3px solid #3b82f6; }
  .cluster-3 { border-left: 3px solid #f59e0b; }
  .cluster-4 { border-left: 3px solid #ef4444; }
  .cluster-5 { border-left: 3px solid #8b5cf6; }
  .cluster-6 { border-left: 3px solid #06b6d4; }
</style>
```

### `src/lib/OSMBaseLayer.svelte`

```svelte
<script>
  import { onMount, getContext } from 'svelte';
  import L from 'leaflet';

  export let attribution = '© OpenStreetMap contributors';
  export let url = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  const { getMap, isReady } = getContext('leaflet-map');
  let tileLayer;

  onMount(() => {
    // Aguardar o mapa estar pronto
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          tileLayer = L.tileLayer(url, { attribution }).addTo(map);
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      tileLayer?.remove();
    };
  });
</script>
```

### `src/lib/OsmPopup.svelte`

```svelte
<script>
  export let feature;
  // const log_feat = () => console.log(feature);
  const open_osm = () => {
    const id = feature?.properties?.id;
    const type = feature?.properties?.type || 'way'; // fallback

    const url = `https://www.openstreetmap.org/${type}/${id}`;
    window.open(url, '_blank');
  };

  let land = feature.properties?.landuse || 'Uso desconhecido';
  let name = feature.properties?.name || 'Sem Nome';
</script>
<div class="popup">
  <strong>{name}</strong><br />
  <strong>{land}</strong><br />
  <button on:click={open_osm}>Check</button><br />
</div>

<style>
</style>
```

### `src/lib/OsmWays.svelte`

```svelte
<script>
  import { onMount, getContext, createEventDispatcher } from 'svelte';
  import L from 'leaflet';
  import OsmPopup from './OsmPopup.svelte';

  export let osmData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  const dispatch = createEventDispatcher();
  
  let geoJsonLayer;
  let mapReady = false;

  $: if (osmData && mapReady) {
    updateLayer(osmData);
  }

  onMount(() => {
    const checkMap = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          geoJsonLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(checkMap);
        }
      }
    }, 50);

    return () => {
      clearInterval(checkMap);
      geoJsonLayer?.clearLayers();
      geoJsonLayer?.remove();
    };
  });


  function updateLayer(data) {
    if (!geoJsonLayer || !data) return;

    geoJsonLayer.clearLayers();

    const layer = L.geoJSON(data, {
      style: {
        color: '#1377ef',
        weight: 2,
        fillColor: '#1377ef',
        fillOpacity: 0.2
      },
      onEachFeature: (feature, layer) => {
        const popup = L.popup();
        const popupContainer = document.createElement('div');

        new OsmPopup({
          target: popupContainer,
          props: {
            feature: feature.properties,
          }
        });

        popup.setContent(popupContainer);
        layer.bindPopup(popup);
      }
    });

    layer.addTo(geoJsonLayer);

    // Fit bounds to the new data
    const map = getMap();
    if (map && layer.getBounds().isValid()) {
      map.fitBounds(layer.getBounds());
    }
  }
</script>
```

### `src/lib/ProgressBar.svelte`

```svelte
<script>
  export let progress = null;
  
  // Calculate progress percentage safely
  $: percentage = progress?.progress?.total > 0 
    ? Math.round((progress.progress.processed / progress.progress.total) * 100)
    : 0;
  
  // Determine if we're in progress
  $: isActive = progress?.progress?.state === 'active';
  $: isFinished = progress?.progress?.state === 'finished';
  $: isUnknown = progress?.progress?.state === 'unknown';
  
  // Get current phase
  $: currentPhase = progress?.progress?.phase || 'waiting';
</script>

<div class="progress-panel">
  {#if progress}
    <div class="progress-info">
      <div class="phase">Phase: <strong>{currentPhase}</strong></div>
      <div class="status">Status: <strong>{progress.progress.state}</strong></div>
      
      {#if isActive || isUnknown}
        <div class="progress-details">
          <span class="count">
            {progress.progress.processed} / {progress.progress.total}
          </span>
          {#if percentage > 0}
            <span class="percentage">({percentage}%)</span>
          {/if}
        </div>
      {/if}
    </div>

    {#if isActive && progress.progress.total > 0}
      <div class="progress-bar-container">
        <div 
          class="progress-bar" 
          style="width: {percentage}%"
          role="progressbar"
          aria-valuenow={percentage}
          aria-valuemin="0"
          aria-valuemax="100"
        >
          <span class="progress-text">{percentage}%</span>
        </div>
      </div>
    {:else if isUnknown}
      <div class="progress-bar-container">
        <div class="progress-bar indeterminate" role="progressbar">
          <span class="progress-text">Initializing...</span>
        </div>
      </div>
    {:else if isFinished}
      <div class="completion-message">
        ✅ Operation completed successfully!
      </div>
    {/if}
  {:else}
    <div class="waiting-message">
      Waiting for operation to start...
    </div>
  {/if}
</div>

<style>
  .progress-panel {
    border: 1px solid #e0e0e0;
    border-radius: 8px;
    padding: 1rem;
    background: #f9f9f9;
    max-width: 400px;
    margin: 1rem 0;
  }

  .progress-info {
    margin-bottom: 0.75rem;
  }

  .phase, .status {
    margin-bottom: 0.25rem;
    font-size: 0.9rem;
  }

  .progress-details {
    margin-top: 0.5rem;
    font-size: 0.85rem;
    color: #666;
  }

  .count, .percentage {
    margin-right: 0.5rem;
  }

  .progress-bar-container {
    width: 100%;
    height: 24px;
    background: #e0e0e0;
    border-radius: 12px;
    overflow: hidden;
    position: relative;
  }

  .progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #4CAF50, #45a049);
    border-radius: 12px;
    transition: width 0.3s ease;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 40px; /* Ensure text is visible even at low percentages */
  }

  .progress-bar.indeterminate {
    background: linear-gradient(90deg, #2196F3, #21b0f3);
    animation: indeterminate 1.5s infinite linear;
    width: 60% !important; /* Override the style attribute */
  }

  .progress-text {
    color: white;
    font-size: 0.75rem;
    font-weight: bold;
    text-shadow: 1px 1px 1px rgba(0,0,0,0.3);
  }

  .completion-message {
    color: #2E7D32;
    font-weight: bold;
    text-align: center;
    padding: 0.5rem;
    background: #E8F5E9;
    border-radius: 4px;
  }

  .waiting-message {
    color: #666;
    font-style: italic;
    text-align: center;
    padding: 0.5rem;
  }

  @keyframes indeterminate {
    0% {
      transform: translateX(-100%);
    }
    100% {
      transform: translateX(200%);
    }
  }
</style>
```


---

## 📁 src/lib/School

### `src/lib/School/ClusterLayer.svelte`

```svelte
<script>
  import { onDestroy } from 'svelte';
  
  export let map = null;
  export let clusterData = null;
  export let visible = false;
  export let onSchoolSelect = null;
  
  let layerGroup = null;
  let initializationAttempts = 0;
  let retryInterval = null;
  
  const clusterColors = {
    1: { bg: '#10b981', name: 'Excelência', icon: '🏆' },
    2: { bg: '#3b82f6', name: 'Alto Desempenho', icon: '⭐' },
    3: { bg: '#f59e0b', name: 'Médio Desempenho', icon: '📊' },
    4: { bg: '#ef4444', name: 'Baixo Desempenho', icon: '⚠️' },
    5: { bg: '#8b5cf6', name: 'Em Declínio', icon: '📉' },
    6: { bg: '#06b6d4', name: 'Em Ascensão', icon: '📈' }
  };
  
  function getClusterIcon(clusterId, size = 32) {
    const cluster = clusterColors[clusterId] || { bg: '#6b7280', name: 'Outro', icon: '📍' };
    
    return L.divIcon({
      className: 'cluster-marker',
      html: `
        <div style="
          background-color: ${cluster.bg};
          width: ${size}px;
          height: ${size}px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: ${size * 0.5}px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.3);
          border: 2px solid white;
          cursor: pointer;
          transition: transform 0.2s;
        "
        onmouseover="this.style.transform='scale(1.1)'"
        onmouseout="this.style.transform='scale(1)'">
          ${cluster.icon}
        </div>
      `,
      iconSize: [size, size],
      popupAnchor: [0, -size/2]
    });
  }
  
  function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
  
  function createPopupContent(school, clusterInfo) {
    const cluster = clusterColors[clusterInfo.cluster_id] || clusterColors[3];
    
    return `
      <div class="cluster-popup">
        <div class="popup-header" style="border-left-color: ${cluster.bg}">
          <h4>${escapeHtml(school.escola || 'Escola sem nome')}</h4>
          <span class="cluster-badge" style="background: ${cluster.bg}">
            ${cluster.icon} ${cluster.name}
          </span>
        </div>
        <div class="popup-body">
          <p><strong>📍 Local:</strong> ${escapeHtml(school.municipio)}/${school.uf}</p>
          <p><strong>🏫 Rede:</strong> ${school.rede || 'N/A'}</p>
          <hr/>
          <p><strong>⭐ IDEB 2023:</strong> <span class="value">${school.ideb?.toFixed(2) || 'N/A'}</span></p>
          <p><strong>📈 Nota Média:</strong> <span class="value">${school.nota?.toFixed(2) || 'N/A'}</span></p>
          <p><strong>✅ Aprovação:</strong> <span class="value">${school.aprovacao?.toFixed(1) || 'N/A'}%</span></p>
          <p><strong>📉 Tendência:</strong> <span class="value ${school.tendencia >= 0 ? 'positive' : 'negative'}">
            ${school.tendencia >= 0 ? '📈 +' : '📉 '}${school.tendencia?.toFixed(2) || '0'}
          </span></p>
        </div>
        <div class="popup-footer">
          <button class="btn-details" data-id="${school.id_escola}">
            Ver Detalhes
          </button>
        </div>
      </div>
    `;
  }
  
  function handleDetailClick(e) {
    const schoolId = parseInt(e.target.dataset.id);
    if (onSchoolSelect) onSchoolSelect(schoolId);
  }
  
  function bindPopupEvents() {
    setTimeout(() => {
      document.querySelectorAll('.btn-details').forEach(btn => {
        btn.removeEventListener('click', handleDetailClick);
        btn.addEventListener('click', handleDetailClick);
      });
    }, 100);
  }
  
  function isValidMap(mapInstance) {
    return mapInstance && 
           typeof mapInstance === 'object' && 
           typeof mapInstance.hasLayer === 'function' &&
           typeof mapInstance.addLayer === 'function';
  }
  
  function clearMarkers() {
    if (layerGroup) {
      layerGroup.clearLayers();
      if (map && isValidMap(map) && map.hasLayer(layerGroup)) {
        map.removeLayer(layerGroup);
      }
      layerGroup = null;
    }
  }
  
  function updateMarkers() {
    // Limpar markers existentes primeiro
    clearMarkers();
    
    // Verificar se o mapa é válido
    if (!isValidMap(map)) {
      console.log('ClusterLayer: Aguardando mapa ficar disponível...', { mapExists: !!map, hasLayer: map?.hasLayer });
      // Tentar novamente em 500ms se o mapa ainda não estiver pronto
      if (retryInterval) clearTimeout(retryInterval);
      retryInterval = setTimeout(() => {
        if (isValidMap(map)) {
          updateMarkers();
        }
      }, 500);
      return;
    }
    
    // Verificar condições para mostrar markers
    if (!visible || !clusterData || !Array.isArray(clusterData) || clusterData.length === 0) {
      console.log('ClusterLayer: Sem dados para mostrar', { visible, hasData: !!clusterData });
      return;
    }
    
    console.log('ClusterLayer: Atualizando markers', { 
      clusters: clusterData.length, 
      mapIsValid: true 
    });
    
    // Criar novo layer group
    layerGroup = L.layerGroup();
    
    // Adicionar novos markers
    let totalMarkers = 0;
    clusterData.forEach(cluster => {
      const clusterId = cluster.cluster_id;
      
      if (cluster.escolas && Array.isArray(cluster.escolas)) {
        cluster.escolas.forEach(school => {
          if (school.latitude && school.longitude) {
            const marker = L.marker([school.latitude, school.longitude], {
              icon: getClusterIcon(clusterId)
            });
            
            marker.bindPopup(createPopupContent(school, cluster), {
              maxWidth: 300,
              minWidth: 250,
              className: 'cluster-popup-wrapper'
            });
            
            marker.on('popupopen', bindPopupEvents);
            marker.addTo(layerGroup);
            totalMarkers++;
          }
        });
      }
    });
    
    console.log(`ClusterLayer: Adicionados ${totalMarkers} markers ao mapa`);
    
    // Adicionar ao mapa se tiver markers
    if (totalMarkers > 0) {
      layerGroup.addTo(map);
      
      // Ajustar zoom para mostrar todos os marcadores
      try {
        const bounds = L.latLngBounds(
          layerGroup.getLayers().map(layer => layer.getLatLng())
        );
        map.fitBounds(bounds, { padding: [50, 50] });
      } catch (e) {
        console.warn('Erro ao ajustar bounds:', e);
      }
    }
  }
  
  // Reagir a mudanças nas props
  $: {
    if (map && clusterData && visible) {
      // Pequeno delay para garantir que o mapa está completamente inicializado
      setTimeout(() => {
        updateMarkers();
      }, 100);
    } else if (!visible) {
      clearMarkers();
    }
  }
  
  // Limpeza no destroy
  onDestroy(() => {
    if (retryInterval) clearTimeout(retryInterval);
    clearMarkers();
  });
</script>
```

### `src/lib/School/ClusterLegend.svelte`

```svelte
<!-- ClusterLegend.svelte -->
<script>
  export let clusters = [];
  export let position = 'bottomright';
  
  const clusterInfo = {
    1: { name: 'Excelência', color: '#10b981', description: 'IDEB > 8.0, crescimento forte' },
    2: { name: 'Alto Desempenho', color: '#3b82f6', description: 'IDEB 6.0-8.0, consistente' },
    3: { name: 'Médio Desempenho', color: '#f59e0b', description: 'IDEB 4.5-6.0, estável' },
    4: { name: 'Baixo Desempenho', color: '#ef4444', description: 'IDEB < 4.5, atenção' },
    5: { name: 'Em Declínio', color: '#8b5cf6', description: 'Tendência negativa' },
    6: { name: 'Em Ascensão', color: '#06b6d4', description: 'Crescimento acelerado' }
  };
</script>

<div class="legend" class:bottomright={position === 'bottomright'} class:topright={position === 'topright'}>
  <div class="legend-title">📊 Clusters de Escolas</div>
  {#each Object.entries(clusterInfo) as [id, info]}
    <div class="legend-item">
      <div class="legend-color" style="background-color: {info.color}"></div>
      <div class="legend-info">
        <span class="legend-name">Cluster {id}: {info.name}</span>
        <span class="legend-desc">{info.description}</span>
      </div>
    </div>
  {/each}
</div>

<style>
  .legend {
    position: absolute;
    background: white;
    padding: 12px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    z-index: 1000;
    font-size: 12px;
    min-width: 200px;
    max-width: 250px;
  }
  
  .bottomright {
    bottom: 20px;
    right: 20px;
  }
  
  .topright {
    top: 20px;
    right: 20px;
  }
  
  .legend-title {
    font-weight: 600;
    margin-bottom: 8px;
    padding-bottom: 4px;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }
  
  .legend-color {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  
  .legend-info {
    flex: 1;
  }
  
  .legend-name {
    font-weight: 500;
    display: block;
  }
  
  .legend-desc {
    font-size: 10px;
    color: #6b7280;
  }
</style>
```

### `src/lib/School/CoverArea.svelte`

```svelte
<!-- lib/School/CoverArea.svelte -->
<script>
  import { onMount, onDestroy } from 'svelte';
  import { getContext } from 'svelte';
  import { activeCoverSchool } from '../stores/activeCoverStore.js';
  import { fetchCoverArea } from '../js/cover.js';
  import L from 'leaflet';

  const { getMap, isReady } = getContext('leaflet-map');
  let coverLayer = null;
  let unsubscribe;
  let currentSchoolId = null; // evita carregar a mesma escola concorrentemente

  onMount(() => {
    unsubscribe = activeCoverSchool.subscribe(async (school) => {
      // Remove camada anterior se existir
      if (coverLayer) {
        coverLayer.remove();
        coverLayer = null;
      }

      if (!school) {
        currentSchoolId = null;
        return;
      }

      const schoolId = school.properties.codigo_inep;
      // Evita buscar a mesma escola duas vezes seguidas (ex: cliques repetidos)
      if (currentSchoolId === schoolId) return;
      currentSchoolId = schoolId;

      // Aguarda o mapa estar pronto antes de tentar buscar/adicionar
      await waitForMap();

      const map = getMap();
      if (!map) return;

      try {
        const geojson = await fetchCoverArea(schoolId, 3);
        if (geojson && geojson.features?.length) {
          coverLayer = L.geoJSON(geojson, {
            style: {
              color: '#2c7da0',
              weight: 3,
              fillColor: '#61a5c2',
              fillOpacity: 0.3
            }
          }).addTo(map);
          // Ajusta o zoom para englobar o polígono (opcional)
          map.fitBounds(coverLayer.getBounds());
        } else {
          console.warn('Nenhum polígono retornado para escola', schoolId);
        }
      } catch (err) {
        console.error('Erro ao carregar área de cobertura', err);
      }
    });
  });

  // Função que retorna uma Promise resolvida quando o mapa estiver pronto
  async function waitForMap() {
    while (!isReady()) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    return true;
  }

  onDestroy(() => {
    if (unsubscribe) unsubscribe();
    if (coverLayer) coverLayer.remove();
  });
</script>
```

### `src/lib/School/GradesModal.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  import { LineChart } from '@carbon/charts-svelte';
  import '@carbon/styles/css/styles.css';
  import '@carbon/charts-svelte/styles.css';
  
  export let school = null;
  export let isOpen = false;
  
  const dispatch = createEventDispatcher();
  
  let schoolData = null;
  let isLoading = false;
  let error = null;
  let selectedSince = 2005;
  let selectedUntil = 2023;
  let selectedSerie = 'fundamental_i';
  
  let chartData = [];
  let chartOptions = {};
  
  const seriesOptions = {
    'fundamental_i': '1º ao 4º Ano (Fundamental I)',
    'fundamental_ii': '5º ao 9º Ano (Fundamental II)',
    'ensino_medio': 'Ensino Médio'
  };
  
  let availableYears = []; // será preenchido dinamicamente baseado nos dados reais
  
  let hasNotasData = false; // indica se a API forneceu notas_por_serie
  
  function closeModal() {
    isOpen = false;
    dispatch('close');
  }
  
  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) closeModal();
  }
  
  async function fetchSchoolData() {
    const id = school?.codigo_inep;
    if (!id) {
      error = 'Identificador da escola não encontrado.';
      return;
    }
    
    isLoading = true;
    error = null;
    schoolData = null;
    
    try {
      const url = `/api/school/${id}/full_grades`;
      const response = await fetch(url);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      schoolData = data;
      
      // Verifica se existem dados de notas (matemática/português)
      hasNotasData = !!(schoolData?.notas_por_serie && Object.keys(schoolData.notas_por_serie).length > 0);
      
      // Determina os anos disponíveis com base nos dados que existem
      updateAvailableYears();
      
      // Prepara gráfico apenas se houver dados de notas
      if (hasNotasData) prepareChartData();
    } catch (err) {
      console.error(err);
      error = err.message || 'Erro ao carregar os dados da escola.';
    } finally {
      isLoading = false;
    }
  }
  
  function updateAvailableYears() {
    let anosSet = new Set();
    
    // Tenta extrair anos das notas, se existirem
    if (hasNotasData && schoolData?.notas_por_serie?.[selectedSerie]?.matematica) {
      Object.keys(schoolData.notas_por_serie[selectedSerie].matematica).forEach(ano => anosSet.add(Number(ano)));
    }
    
    // Se não houver notas, ou para complementar, busca anos do indicador_rendimento para a série selecionada
    const indicadorSeries = schoolData?.indicador_rendimento?.[selectedSerie];
    if (indicadorSeries && typeof indicadorSeries === 'object') {
      Object.keys(indicadorSeries).forEach(ano => anosSet.add(Number(ano)));
    }
    
    let anos = Array.from(anosSet).filter(ano => !isNaN(ano)).sort((a,b) => a-b);
    if (anos.length === 0) {
      // Fallback: anos comuns das avaliações
      anos = [2005,2007,2009,2011,2013,2015,2017,2019,2021,2023];
    }
    availableYears = anos;
    
    // Ajusta os seletores de ano
    if (selectedSince < Math.min(...anos)) selectedSince = Math.min(...anos);
    if (selectedUntil > Math.max(...anos)) selectedUntil = Math.max(...anos);
  }
  
  function prepareChartData() {
    if (!hasNotasData || !schoolData?.notas_por_serie?.[selectedSerie]) {
      chartData = [];
      return;
    }
    
    const serieData = schoolData.notas_por_serie[selectedSerie];
    const newChartData = [];
    const anos = availableYears.filter(ano => ano >= selectedSince && ano <= selectedUntil).sort();
    
    anos.forEach(ano => {
      const anoStr = ano.toString();
      const matematica = serieData.matematica?.[anoStr];
      const portugues = serieData.portugues?.[anoStr];
      if (matematica != null) {
        newChartData.push({ group: 'Matemática', year: anoStr, value: parseFloat(matematica) });
      }
      if (portugues != null) {
        newChartData.push({ group: 'Português', year: anoStr, value: parseFloat(portugues) });
      }
    });
    
    chartData = newChartData;
    
    chartOptions = {
      title: `Evolução das Notas - ${seriesOptions[selectedSerie]}`,
      axes: {
        bottom: { title: 'Ano', mapsTo: 'year', scaleType: 'labels' },
        left: { title: 'Nota (0-10)', mapsTo: 'value', domain: [0, 10], ticks: { formatter: (tick) => tick.toFixed(1) } }
      },
      curve: 'curveLinear',
      points: { enabled: true, radius: 4 },
      line: { strokeWidth: 2 },
      legend: { position: 'top' },
      tooltip: {
        enabled: true,
        customHTML: (data) => {
          const { group, year, value } = data[0];
          const formattedValue = (value != null && !isNaN(value)) ? value.toFixed(2) : 'N/A';
          return `<div style="padding:8px;background:white;border-radius:4px;box-shadow:0 2px 8px rgba(0,0,0,0.15);">
            <strong>${group}</strong><br/>Ano: ${year}<br/>Nota: ${formattedValue}
          </div>`;
        }
      },
      grid: { x: { numberOfTicks: Math.min(10, anos.length) }, y: { numberOfTicks: 10 } },
      color: { scale: { 'Matemática': '#2563eb', 'Português': '#7c3aed' } },
      height: '400px',
      resizable: true
    };
  }
  
  function handleSinceChange(e) {
    selectedSince = parseInt(e.target.value);
    if (selectedSince > selectedUntil) selectedUntil = selectedSince;
    if (hasNotasData) prepareChartData();
  }
  
  function handleUntilChange(e) {
    selectedUntil = parseInt(e.target.value);
    if (selectedUntil < selectedSince) selectedSince = selectedUntil;
    if (hasNotasData) prepareChartData();
  }
  
  function handleSerieChange(e) {
    selectedSerie = e.target.value;
    updateAvailableYears();
    if (hasNotasData) prepareChartData();
  }
  
  function formatValue(value, decimals = 2) {
    if (value === null || value === undefined) return 'N/A';
    const num = parseFloat(value);
    return isNaN(num) ? 'N/A' : num.toFixed(decimals);
  }
  
  // Extrai o valor do indicador de rendimento (pode estar em 'total_serie' ou 'media')
  function getIndicadorValue(anoData) {
    if (!anoData) return null;
    // Prioriza total_serie (usado nos dados reais), depois media
    if (anoData.total_serie !== undefined && anoData.total_serie !== null) return anoData.total_serie;
    if (anoData.media !== undefined && anoData.media !== null) return anoData.media;
    return null;
  }
  
  // Reatividade
  $: if (school && isOpen) fetchSchoolData();
  $: if (schoolData && hasNotasData) prepareChartData();
</script>

{#if isOpen}
  <div class="modal-backdrop" on:click={handleBackdropClick}
    on:keydown={(e) => e.key === 'Escape' && closeModal()}
    role="button"
    tabindex="0"
  >
    <div class="modal">
      <div class="modal-header">
        <h2>Dados Completos da Escola</h2>
        <button class="close-btn" on:click={closeModal}>×</button>
      </div>
      
      <div class="modal-content">
        {#if schoolData}
          <div class="school-info">
            <h3>{school.escola || 'Nome não informado'}</h3>
            <div class="school-details">
              <span class="detail">Código INEP: {school.codigo_inep || '—'}</span>
              <span class="detail">Município: {school.municipio || '—'}</span>
              <span class="detail">Rede: {school.tipo || '—'}</span>
            </div>
          </div>
          
          <div class="filters">
            <div class="filter-group">
              <label for="serie">Série Escolar:</label>
              <select id="serie" bind:value={selectedSerie} on:change={handleSerieChange}>
                {#each Object.entries(seriesOptions) as [value, label]}
                  <option value={value}>{label}</option>
                {/each}
              </select>
            </div>
            <div class="filter-group">
              <label for="since">Ano Inicial:</label>
              <select id="since" bind:value={selectedSince} on:change={handleSinceChange}>
                {#each availableYears.filter(y => y <= selectedUntil) as year}
                  <option value={year}>{year}</option>
                {/each}
              </select>
            </div>
            <div class="filter-group">
              <label for="until">Ano Final:</label>
              <select id="until" bind:value={selectedUntil} on:change={handleUntilChange}>
                {#each availableYears.filter(y => y >= selectedSince) as year}
                  <option value={year}>{year}</option>
                {/each}
              </select>
            </div>
          </div>
          
          {#if isLoading}
            <div class="loading"><div class="spinner"></div><p>Carregando dados...</p></div>
          {:else if error}
            <div class="error"><p>❌ {error}</p></div>
          {:else}
            <!-- Seção de gráfico e tabela de notas – só aparece se houver dados de notas -->
            {#if hasNotasData}
              {#if chartData.length > 0}
                <div class="chart-container"><LineChart data={chartData} options={chartOptions} /></div>
              {:else}
                <div class="no-data"><p>📊 Nenhum dado de nota disponível para o período selecionado.</p></div>
              {/if}
              
              <!-- Tabela de Notas (matemática/português) -->
              {#if schoolData.notas_por_serie?.[selectedSerie]}
                <div class="data-section">
                  <h4>Notas por Ano - {seriesOptions[selectedSerie]}</h4>
                  <div class="grades-table-container">
                    <table class="grades-table">
                      <thead><tr><th>Ano</th><th>Matemática</th><th>Português</th><th>Média</th></tr></thead>
                      <tbody>
                        {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                          {@const anoStr = ano.toString()}
                          {@const mat = schoolData.notas_por_serie[selectedSerie].matematica?.[anoStr]}
                          {@const port = schoolData.notas_por_serie[selectedSerie].portugues?.[anoStr]}
                          {@const med = schoolData.notas_por_serie[selectedSerie].media?.[anoStr]}
                          <tr>
                            <td class="year-cell">{ano}</td>
                            <td class="grade-cell math-grade">{formatValue(mat)}</td>
                            <td class="grade-cell portuguese-grade">{formatValue(port)}</td>
                            <td class="grade-cell average-grade">{formatValue(med)}</td>
                          </tr>
                        {/each}
                      </tbody>
                    </table>
                  </div>
                </div>
              {/if}
            {:else}
              <div class="info">
                <p>ℹ️ Esta escola não possui dados de notas (Matemática/Português) disponíveis. Os indicadores de rendimento são apresentados abaixo.</p>
              </div>
            {/if}
            
            <!-- Indicador de Rendimento (agora lê total_serie ou media) -->
            {#if schoolData.indicador_rendimento?.[selectedSerie]}
              <div class="data-section">
                <h4>Indicador de Rendimento (Taxa de aprovação média)</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead><tr><th>Ano</th><th>Indicador (%)</th></tr></thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const anoData = schoolData.indicador_rendimento[selectedSerie][anoStr]}
                        {@const indicador = getIndicadorValue(anoData)}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatValue(indicador, 1)}%</td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
            
            <!-- IDEB Observado vs Projeção (apenas se for um objeto válido) -->
            {#if schoolData.valores_observados_e_projecoes && typeof schoolData.valores_observados_e_projecoes === 'object' && !Array.isArray(schoolData.valores_observados_e_projecoes)}
              <div class="data-section">
                <h4>IDEB - Observado vs Projeção</h4>
                <div class="grades-table-container">
                  <table class="grades-table">
                    <thead><tr><th>Ano</th><th>Observado</th><th>Projeção</th><th>Meta Atingida?</th></tr></thead>
                    <tbody>
                      {#each availableYears.filter(y => y >= selectedSince && y <= selectedUntil) as ano}
                        {@const anoStr = ano.toString()}
                        {@const dados = schoolData.valores_observados_e_projecoes[anoStr]}
                        {@const observado = dados?.observado}
                        {@const projecao = dados?.projecao}
                        {@const metaAtingida = observado != null && projecao != null && parseFloat(observado) >= parseFloat(projecao)}
                        <tr>
                          <td class="year-cell">{ano}</td>
                          <td class="grade-cell">{formatValue(observado)}</td>
                          <td class="grade-cell">{formatValue(projecao)}</td>
                          <td class="grade-cell {metaAtingida ? 'success' : observado != null ? 'warning' : ''}">
                            {#if observado != null && projecao != null}
                              {metaAtingida ? '✓ Sim' : '✗ Não'}
                            {:else if observado != null}Sem projeção{:else}Sem dados{/if}
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
              </div>
            {/if}
          {/if}
        {:else if !isLoading}
          <div class="error"><p>⚠️ Dados da escola não disponíveis</p></div>
        {/if}
      </div>
      
      <div class="modal-footer">
        <button class="btn btn-secondary" on:click={closeModal}>Fechar</button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* Mantenha os estilos exatamente como estavam (já fornecidos anteriormente) */
  .modal-backdrop { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background-color: rgba(0,0,0,0.5); display: flex; justify-content: center; align-items: center; z-index: 1000; }
  .modal { background: white; border-radius: 8px; width: 95%; max-width: 1200px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
  .modal-header { display: flex; justify-content: space-between; align-items: center; padding: 1rem 1.5rem; border-bottom: 1px solid #e5e7eb; }
  .modal-header h2 { margin: 0; font-size: 1.25rem; color: #111827; }
  .close-btn { background: none; border: none; font-size: 1.5rem; cursor: pointer; color: #6b7280; padding: 0; width: 2rem; height: 2rem; display: flex; align-items: center; justify-content: center; border-radius: 4px; }
  .close-btn:hover { background-color: #f3f4f6; color: #111827; }
  .modal-content { flex: 1; overflow-y: auto; padding: 1.5rem; }
  .school-info { margin-bottom: 1.5rem; padding-bottom: 1rem; border-bottom: 1px solid #e5e7eb; }
  .school-info h3 { margin: 0 0 0.5rem 0; font-size: 1.1rem; color: #111827; }
  .school-details { display: flex; flex-wrap: wrap; gap: 1rem; font-size: 0.875rem; color: #6b7280; }
  .detail { background-color: #f3f4f6; padding: 0.25rem 0.5rem; border-radius: 4px; }
  .filters { display: flex; gap: 1rem; margin-bottom: 1.5rem; padding: 1rem; background-color: #f9fafb; border-radius: 6px; flex-wrap: wrap; }
  .filter-group { display: flex; flex-direction: column; gap: 0.5rem; }
  .filter-group label { font-size: 0.875rem; font-weight: 500; color: #374151; }
  .filter-group select { padding: 0.5rem; border: 1px solid #d1d5db; border-radius: 4px; font-size: 0.875rem; background-color: white; cursor: pointer; min-width: 180px; }
  .chart-container { margin-bottom: 2rem; padding: 1rem; background-color: #ffffff; border: 1px solid #e5e7eb; border-radius: 8px; }
  .data-section { margin-bottom: 2rem; }
  .data-section h4 { margin: 0 0 1rem 0; font-size: 1rem; color: #374151; }
  .loading, .error, .no-data, .info { text-align: center; padding: 2rem; color: #6b7280; }
  .loading { display: flex; flex-direction: column; align-items: center; gap: 1rem; }
  .spinner { width: 40px; height: 40px; border: 3px solid #f3f3f3; border-top: 3px solid #10b981; border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  .error { color: #dc2626; background-color: #fef2f2; border-radius: 6px; }
  .info { color: #2563eb; background-color: #eff6ff; border-radius: 6px; }
  .grades-table-container { overflow-x: auto; }
  .grades-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
  .grades-table th, .grades-table td { padding: 0.75rem; text-align: left; border-bottom: 1px solid #e5e7eb; }
  .grades-table th { background-color: #f9fafb; font-weight: 600; color: #374151; position: sticky; top: 0; }
  .grades-table tbody tr:hover { background-color: #f9fafb; }
  .year-cell { font-weight: 500; color: #111827; }
  .grade-cell { font-family: monospace; font-size: 0.875rem; }
  .math-grade { color: #2563eb; font-weight: 500; }
  .portuguese-grade { color: #7c3aed; font-weight: 500; }
  .average-grade { color: #059669; font-weight: 600; }
  .success { color: #059669; font-weight: 600; }
  .warning { color: #d97706; font-weight: 600; }
  .modal-footer { padding: 1rem 1.5rem; border-top: 1px solid #e5e7eb; display: flex; justify-content: flex-end; }
  .btn { padding: 0.5rem 1rem; border-radius: 4px; font-size: 0.875rem; font-weight: 500; cursor: pointer; border: none; }
  .btn-secondary { background-color: #f3f4f6; color: #374151; }
  .btn-secondary:hover { background-color: #e5e7eb; }
</style>
```

### `src/lib/School/PayrollModal.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  
  export let show = false;
  export let escola = null;
  
  let payroll = null;
  let loading = false;
  let error = null;
  let selectedYear = new Date().getFullYear();
  let selectedMonth = new Date().getMonth() + 1;
  
  const dispatch = createEventDispatcher();
  
  const months = [
    { value: 1, name: 'Janeiro' },
    { value: 2, name: 'Fevereiro' },
    { value: 3, name: 'Março' },
    { value: 4, name: 'Abril' },
    { value: 5, name: 'Maio' },
    { value: 6, name: 'Junho' },
    { value: 7, name: 'Julho' },
    { value: 8, name: 'Agosto' },
    { value: 9, name: 'Setembro' },
    { value: 10, name: 'Outubro' },
    { value: 11, name: 'Novembro' },
    { value: 12, name: 'Dezembro' }
  ];
  
  const years = [2021, 2022, 2023, 2024, 2025];
  
  async function loadPayroll() {
    if (!escola) return;
    
    loading = true;
    error = null;
    payroll = null;
    
    try {
      const url = `/api/school/${escola.codigo_inep}/payroll?year=${selectedYear}&month=${selectedMonth}`;
      console.log('Carregando payroll:', url);
      
      const response = await fetch(url);
      
      if (!response.ok) {
        throw new Error(`Erro ao carregar payroll: ${response.status}`);
      }
      
      const data = await response.json();
      console.log('Payroll carregado:', data);
      
      // Garantir que profissionais seja sempre um array
      payroll = {
        ...data,
        profissionais: data.profissionais || [],
        resumo_categoria: data.resumo_categoria || {},
        resumo_segmento: data.resumo_segmento || {}
      };
    } catch (err) {
      error = err.message;
      console.error('Erro ao carregar payroll:', err);
    } finally {
      loading = false;
    }
  }
  
  function formatCurrency(value) {
    if (!value && value !== 0) return 'R$ 0,00';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(value);
  }
  
  function formatCPF(cpf) {
    if (!cpf) return '';
    // Remove caracteres não numéricos
    const clean = cpf.replace(/\D/g, '');
    if (clean.length === 11) {
      return clean.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
    }
    return cpf;
  }
  
  function closeModal() {
    show = false;
    payroll = null;
    dispatch('close');
  }
  
  function handleOverlayClick(e) {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  }
  
  $: if (show && escola) {
    loadPayroll();
  }
</script>

{#if show}
  <div class="modal-overlay" on:click={handleOverlayClick}
    on:keydown={(e) => e.key === 'Escape' && closeModal()}
    role="button"
    tabindex="0"
  >
    <div class="modal-container">
      <div class="modal-header">
        <div>
          <h2>💰 Folha de Pagamento</h2>
          <p class="school-name">{escola?.escola}</p>
          <p class="school-info">INEP: {escola?.codigo_inep} | {escola?.municipio} - {escola?.uf}</p>
        </div>
        <button class="close-btn" on:click={closeModal}>✕</button>
      </div>
      
      <div class="modal-controls">
        <div class="controls-group">
          <label for="year">Ano:</label>
          <select id="year" bind:value={selectedYear} on:change={loadPayroll} disabled={loading}>
            {#each years as year}
              <option value={year}>{year}</option>
            {/each}
          </select>
        </div>
        
        <div class="controls-group">
          <label for="month">Mês:</label>
          <select id="month" bind:value={selectedMonth} on:change={loadPayroll} disabled={loading}>
            {#each months as month}
              <option value={month.value}>{month.name}</option>
            {/each}
          </select>
        </div>
        
        <button class="refresh-btn" on:click={loadPayroll} disabled={loading}>
          {#if loading}
            <span class="spinner-small"></span>
          {:else}
            🔄
          {/if}
          Atualizar
        </button>
      </div>
      
      <div class="modal-content">
        {#if loading}
          <div class="loading-state">
            <div class="spinner"></div>
            <p>Carregando dados da folha de pagamento...</p>
          </div>
        {:else if error}
          <div class="error-state">
            <p class="error-icon">⚠️</p>
            <p class="error-message">{error}</p>
            <p class="error-hint">Verifique se os dados estão disponíveis para o período selecionado.</p>
          </div>
        {:else if payroll && payroll.escola}
          <div class="payroll-info">
            <div class="info-card">
              <h3>📊 Resumo da Escola</h3>
              <div class="info-grid">
                <div class="info-item">
                  <span class="info-label">Escola:</span>
                  <span class="info-value">{payroll.escola.escola}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Dependência:</span>
                  <span class="info-value">{payroll.escola.dependencia_administrativa}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Período:</span>
                  <span class="info-value">{payroll.escola.mes || months[selectedMonth-1]?.name}/{payroll.escola.ano || selectedYear}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Total Profissionais:</span>
                  <span class="info-value">{payroll.profissionais?.length || 0}</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Total Salários:</span>
                  <span class="info-value total-salario">
                    {formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_total || 0), 0))}
                  </span>
                </div>
              </div>
            </div>
            
            <div class="profissionais-section">
              <h3>👥 Profissionais ({payroll.profissionais?.length || 0})</h3>
              
              {#if payroll.profissionais && payroll.profissionais.length > 0}
                <div class="profissionais-table-container">
                  <table class="profissionais-table">
                    <thead>
                      <tr>
                        <th>Nome</th>
                        <th>CPF</th>
                        <th>Categoria</th>
                        <th>Situação</th>
                        <th>Carga Horária</th>
                        <th>Salário Base</th>
                        <th>Salário Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each payroll.profissionais as profissional, index (index)}
                        <tr>
                          <td class="nome-cell">{profissional.nome}</td>
                          <td class="cpf-cell">{formatCPF(profissional.cpf)}</td>
                          <td class="categoria-cell">{profissional.categoria}</td>
                          <td>
                            <span class={`situacao-badge ${profissional.situacao === 'Efetivo' ? 'situacao-efetivo' : 'situacao-outro'}`}>
                              {profissional.situacao}
                            </span>
                          </td>
                          <td>{profissional.carga_horaria}h</td>
                          <td class="valor-cell">{formatCurrency(profissional.salario_base)}</td>
                          <td class="valor-cell destaque">{formatCurrency(profissional.salario_total)}</td>
                        </tr>
                      {/each}
                    </tbody>
                    <tfoot>
                      <tr class="total-row">
                        <td colspan="5"><strong>Total Geral</strong></td>
                        <td class="valor-cell">
                          <strong>{formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_base || 0), 0))}</strong>
                        </td>
                        <td class="valor-cell destaque">
                          <strong>{formatCurrency(payroll.profissionais?.reduce((sum, p) => sum + (p.salario_total || 0), 0))}</strong>
                        </td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              {:else}
                <div class="empty-profissionais">
                  <p>📭 Nenhum profissional encontrado para o período selecionado.</p>
                  <p class="empty-hint">Tente selecionar outro ano ou mês.</p>
                </div>
              {/if}
            </div>
          </div>
        {:else}
          <div class="error-state">
            <p class="error-icon">📭</p>
            <p class="error-message">Nenhum dado disponível</p>
            <p class="error-hint">Não foi possível carregar os dados para este período.</p>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
    animation: fadeIn 0.2s ease;
  }
  
  .modal-container {
    background: white;
    border-radius: 0.75rem;
    width: 90%;
    max-width: 1300px;
    max-height: 90vh;
    display: flex;
    flex-direction: column;
    animation: slideUp 0.3s ease;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  }
  
  .modal-header {
    padding: 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border-radius: 0.75rem 0.75rem 0 0;
  }
  
  .modal-header h2 {
    font-size: 1.5rem;
    font-weight: bold;
    margin-bottom: 0.25rem;
  }
  
  .school-name {
    font-size: 1rem;
    font-weight: 500;
    opacity: 0.9;
    margin-bottom: 0.25rem;
  }
  
  .school-info {
    font-size: 0.875rem;
    opacity: 0.8;
  }
  
  .close-btn {
    background: rgba(255, 255, 255, 0.2);
    border: none;
    color: white;
    font-size: 1.5rem;
    cursor: pointer;
    width: 2rem;
    height: 2rem;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: background-color 0.2s;
  }
  
  .close-btn:hover {
    background: rgba(255, 255, 255, 0.3);
  }
  
  .modal-controls {
    padding: 1rem 1.5rem;
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;
    display: flex;
    gap: 1rem;
    align-items: flex-end;
  }
  
  .controls-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  
  .controls-group label {
    font-size: 0.75rem;
    font-weight: 500;
    color: #6b7280;
  }
  
  .controls-group select {
    padding: 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    background: white;
  }
  
  .refresh-btn {
    padding: 0.5rem 1rem;
    background-color: #3b82f6;
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    transition: background-color 0.2s;
  }
  
  .refresh-btn:hover:not(:disabled) {
    background-color: #2563eb;
  }
  
  .refresh-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .modal-content {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
  }
  
  .loading-state, .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 3rem;
    text-align: center;
  }
  
  .spinner {
    width: 3rem;
    height: 3rem;
    border: 3px solid #e5e7eb;
    border-top-color: #3b82f6;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-bottom: 1rem;
  }
  
  .spinner-small {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }
  
  .error-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }
  
  .error-message {
    font-size: 1.125rem;
    font-weight: 500;
    color: #dc2626;
    margin-bottom: 0.5rem;
  }
  
  .error-hint {
    font-size: 0.875rem;
    color: #6b7280;
  }
  
  .payroll-info {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }
  
  .info-card {
    background: #f9fafb;
    border-radius: 0.5rem;
    padding: 1.25rem;
    border: 1px solid #e5e7eb;
  }
  
  .info-card h3 {
    font-size: 1rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 1rem;
  }
  
  .info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
  }
  
  .info-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  
  .info-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: #6b7280;
    text-transform: uppercase;
  }
  
  .info-value {
    font-size: 1rem;
    font-weight: 600;
    color: #1f2937;
  }
  
  .total-salario {
    color: #059669;
    font-size: 1.125rem;
  }
  
  .profissionais-section h3 {
    font-size: 1rem;
    font-weight: 600;
    color: #374151;
    margin-bottom: 1rem;
  }
  
  .profissionais-table-container {
    overflow-x: auto;
  }
  
  .profissionais-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.875rem;
  }
  
  .profissionais-table thead {
    background: #f3f4f6;
  }
  
  .profissionais-table th {
    padding: 0.75rem;
    text-align: left;
    font-weight: 600;
    color: #374151;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .profissionais-table td {
    padding: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
    color: #6b7280;
  }
  
  .profissionais-table tr:hover {
    background: #f9fafb;
  }
  
  .nome-cell {
    font-weight: 500;
    color: #1f2937;
  }
  
  .cpf-cell {
    font-family: monospace;
    font-size: 0.75rem;
  }
  
  .categoria-cell {
    max-width: 200px;
    white-space: normal;
    word-break: break-word;
  }
  
  .valor-cell {
    text-align: right;
    font-family: monospace;
  }
  
  .destaque {
    font-weight: 600;
    color: #059669;
  }
  
  .situacao-badge {
    display: inline-block;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    font-size: 0.75rem;
    font-weight: 500;
  }
  
  .situacao-efetivo {
    background-color: #dcfce7;
    color: #166534;
  }
  
  .situacao-outro {
    background-color: #f3f4f6;
    color: #374151;
  }
  
  .total-row {
    background: #f9fafb;
    font-weight: 600;
  }
  
  .total-row td {
    border-top: 2px solid #e5e7eb;
    padding-top: 0.75rem;
  }
  
  .empty-profissionais {
    text-align: center;
    padding: 2rem;
    background: #f9fafb;
    border-radius: 0.5rem;
    border: 1px solid #e5e7eb;
  }
  
  .empty-profissionais p {
    color: #6b7280;
    margin-bottom: 0.5rem;
  }
  
  .empty-hint {
    font-size: 0.75rem;
    color: #9ca3af;
  }
  
  @keyframes fadeIn {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
  
  @keyframes slideUp {
    from {
      transform: translateY(20px);
      opacity: 0;
    }
    to {
      transform: translateY(0);
      opacity: 1;
    }
  }
  
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
  
  @media (max-width: 768px) {
    .modal-container {
      width: 95%;
      max-height: 95vh;
    }
    
    .modal-header h2 {
      font-size: 1.25rem;
    }
    
    .info-grid {
      grid-template-columns: 1fr;
    }
    
    .profissionais-table th,
    .profissionais-table td {
      padding: 0.5rem;
      font-size: 0.75rem;
    }
  }
</style>
```

### `src/lib/School/SchList.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  
  export let escolas = [];
  export let loading = false;
  export let error = null;
  
  // Paginação
  export let pageSize = 20;        // itens por página
  export let currentPage = 1;      // página atual (1-indexed)

  const dispatch = createEventDispatcher();

  // Total de páginas
  $: totalPages = Math.ceil(escolas.length / pageSize);
  
  // Garantir que currentPage esteja dentro dos limites
  $: {
    if (currentPage > totalPages && totalPages > 0) {
      currentPage = totalPages;
    }
    if (currentPage < 1 && escolas.length > 0) {
      currentPage = 1;
    }
  }
  
  // Escolas da página atual (fatia do array)
  $: paginatedEscolas = escolas.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  
  // Funções de navegação
  function goToPage(page) {
    if (page >= 1 && page <= totalPages) {
      currentPage = page;
      // Disparar evento para que o componente pai possa, se quiser, fazer server-side pagination
      dispatch('pageChange', { page, pageSize });
    }
  }
  
  function nextPage() {
    if (currentPage < totalPages) {
      goToPage(currentPage + 1);
    }
  }
  
  function prevPage() {
    if (currentPage > 1) {
      goToPage(currentPage - 1);
    }
  }
  
  function handlePageSizeChange(event) {
    pageSize = parseInt(event.target.value, 10);
    currentPage = 1; // reset para primeira página
    dispatch('pageSizeChange', { pageSize });
  }
  
  // Resto das funções originais (getHeaderColor, getModalidadeIcon, etc.)
  const getHeaderColor = (tipo) => {
    if (!tipo) return 'header-default';
    const tipoLower = tipo.toLowerCase();
    if (tipoLower === 'municipal') return 'header-municipal';
    if (tipoLower === 'estadual') return 'header-estadual';
    if (tipoLower === 'privada') return 'header-privada';
    if (tipoLower === 'federal') return 'header-federal';
    return 'header-default';
  };

  const getModalidadeIcon = (modalidade) => {
    const icones = {
      'Educação Infantil': '🏫',
      'Ensino Fundamental': '📚',
      'Ensino Médio': '🎓',
      'Educação de Jovens Adultos': '👥',
      'Educação Profissional': '🔧'
    };
    return icones[modalidade] || '📖';
  };

  const formatTelefone = (telefone) => {
    if (!telefone) return null;
    const numeros = telefone.replace(/\D/g, '');
    if (numeros.length === 10) {
      return numeros.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3');
    } else if (numeros.length === 11) {
      return numeros.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
    }
    return telefone;
  };

  function handleViewPayroll(escola) {
    console.log('Disparando evento viewPayroll para:', escola);
    dispatch('viewPayroll', { escola });
  }

  // Corrigindo a função handleViewGrades
  function handleViewGrades(escola) {
    console.log('Disparando evento viewGrades para:', escola);
    dispatch('viewGrades', { escola });
  }

  function handleViewScores(escola) {
    console.log('Disparando evento viewScores para:', escola);
    dispatch('viewScores', { escola } );
  }
</script>

{#if loading}
  <div class="loading-container">
    <div class="spinner-large"></div>
    <p>Carregando escolas...</p>
  </div>
{:else if error}
  <div class="error-container">
    <p class="error-message">⚠️ {error}</p>
  </div>
{:else if escolas.length === 0}
  <div class="empty-container">
    <div class="empty-icon">🏫</div>
    <p class="empty-title">Nenhuma escola encontrada</p>
    <p class="empty-description">Tente buscar por outro nome ou cidade</p>
  </div>
{:else}
  <div class="schools-grid">
    {#each paginatedEscolas as escola (escola.codigo_inep)}
      <div class="school-card">
        <!-- Header com cor baseada no tipo -->
        <div class={`card-header ${getHeaderColor(escola.tipo)}`}>
          <div class="card-header-content">
            <h3 class="school-name">{escola.escola}</h3>
            <p class="school-inep">INEP: {escola.codigo_inep}</p>
          </div>
          <span class="tipo-badge">
            {escola.tipo || 'Não informado'}
          </span>
        </div>

        <div class="card-content">
          <div class="info-row">
            <span class="info-icon">📍</span>
            <div class="info-text">
              <p>{escola.endereco}</p>
              <p class="city-text">{escola.municipio} - {escola.uf}</p>
            </div>
          </div>

          {#if escola.modalidades && escola.modalidades.length}
            <div class="modalidades">
              {#each escola.modalidades as modalidade}
                <span class="modalidade-badge">
                  <span class="modalidade-icon">{getModalidadeIcon(modalidade)}</span>
                  {modalidade}
                </span>
              {/each}
            </div>
          {/if}

          {#if escola.porte_escola}
            <div class="info-row">
              <span class="info-icon">🏛️</span>
              <span class="info-text">{escola.porte_escola}</span>
            </div>
          {/if}

          {#if escola.telefone}
            <div class="info-row">
              <span class="info-icon">📞</span>
              <a href="tel:{escola.telefone}" class="phone-link">
                {formatTelefone(escola.telefone)}
              </a>
              {#if escola.whatsapp}
                <a href={escola.whatsapp} target="_blank" rel="noopener noreferrer" class="whatsapp-link">
                  💬 WhatsApp
                </a>
              {/if}
            </div>
          {/if}

          <!-- Botões de ação -->
          <div class="buttons-container">
            <button
              class="scores-btn"
              on:click={() => handleViewScores(escola)}>
              📊 Pontuação
            </button>

            <button
              class="grades-btn"
              on:click={() => handleViewGrades(escola)}>
              📝 Notas INEP
            </button>

            <button 
              class="payroll-btn"
              on:click={() => handleViewPayroll(escola)}>
              💰 Folha de Pagamento
            </button>

          </div>

          <div class="map-links">
            <a href={escola.osm} target="_blank" rel="noopener noreferrer" class="map-link">
              🗺️ OpenStreetMap
            </a>
            <button 
              class="map-link"
              on:click={() => {
                const url = `https://www.google.com/maps?q=${escola.latitude},${escola.longitude}`;
                window.open(url, '_blank');
              }}>
              🗺️ Google Maps
            </button>
          </div>

          <div class="coordinates">
            Lat: {escola.latitude} | Lon: {escola.longitude}
          </div>
        </div>
      </div>
    {/each}
  </div>
  
  <!-- Controles de Paginação -->
  <div class="pagination-container">
    <div class="pagination-controls">
      <button 
        class="pagination-btn" 
        on:click={prevPage} 
        disabled={currentPage === 1}>
        ← Anterior
      </button>
      
      <div class="page-info">
        Página <strong>{currentPage}</strong> de <strong>{totalPages}</strong>
      </div>
      
      <button 
        class="pagination-btn" 
        on:click={nextPage} 
        disabled={currentPage === totalPages}>
        Próxima →
      </button>
    </div>
    
    <div class="page-size-selector">
      <label for="pageSize">Itens por página:</label>
      <select id="pageSize" bind:value={pageSize} on:change={handlePageSizeChange}>
        <option value="10">10</option>
        <option value="20">20</option>
        <option value="50">50</option>
        <option value="100">100</option>
      </select>
    </div>
  </div>
  
  <div class="stats">
    <p>Mostrando {escolas.length} escola{escolas.length !== 1 ? 's' : ''}</p>
  </div>
{/if}

<style>
  .schools-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(380px, 1fr));
    gap: 1.5rem;
  }

  .school-card {
    background: white;
    border-radius: 0.5rem;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: all 0.3s;
    border: 1px solid #e5e7eb;
  }

  .school-card:hover {
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);
  }

  /* Estilos base do header */
  .card-header {
    padding: 1rem 1.25rem;
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 0.75rem;
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  }

  /* Cores do header baseadas no tipo */
  .header-municipal {
    background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
    color: #166534;
  }

  .header-estadual {
    background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
    color: #1e40af;
  }

  .header-privada {
    background: linear-gradient(135deg, #f3e8ff 0%, #e9d5ff 100%);
    color: #6b21a5;
  }

  .header-federal {
    background: linear-gradient(135deg, #fef9c3 0%, #fde047 100%);
    color: #854d0e;
  }

  .header-default {
    background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
    color: #374151;
  }

  .card-header-content {
    flex: 1;
  }

  .school-name {
    font-size: 1rem;
    font-weight: 700;
    margin-bottom: 0.25rem;
    line-height: 1.4;
    color: inherit;
  }

  .school-inep {
    font-size: 0.75rem;
    opacity: 0.7;
    color: inherit;
  }

  .tipo-badge {
    padding: 0.25rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.75rem;
    font-weight: 600;
    white-space: nowrap;
    background-color: rgba(255, 255, 255, 0.9);
    color: inherit;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  }

  .card-content {
    padding: 1rem 1.25rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .info-row {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.875rem;
  }

  .info-icon {
    font-size: 1rem;
    flex-shrink: 0;
  }

  .info-text {
    flex: 1;
    color: #374151;
  }

  .city-text {
    font-size: 0.75rem;
    color: #6b7280;
    margin-top: 0.125rem;
  }

  .modalidades {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .modalidade-badge {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.25rem 0.5rem;
    background-color: #f3f4f6;
    border-radius: 0.375rem;
    font-size: 0.75rem;
    font-weight: 500;
    color: #374151;
  }

  .modalidade-icon {
    font-size: 0.75rem;
  }

  .phone-link, .whatsapp-link {
    color: #2563eb;
    text-decoration: none;
    font-size: 0.875rem;
  }

  .phone-link:hover, .whatsapp-link:hover {
    text-decoration: underline;
  }

  .buttons-container {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }
  
  .payroll-btn, .grades-btn, .scores-btn {
    width: 100%;
    padding: 0.5rem;
    color: white;
    border: none;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }
  
  .payroll-btn {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  }
  
  .payroll-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }
  
  .grades-btn {
    background-color: #10b981;
  }
  
  .grades-btn:hover {
    background-color: #059669;
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }

  .scores-btn {
    background-color: #13b081;
  }
  
  .scores-btn:hover {
    background-color: #099869;
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  }

  .map-links {
    display: flex;
    gap: 1rem;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e7eb;
  }

  .map-link {
    color: #2563eb;
    font-size: 0.75rem;
    text-decoration: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
  }

  .map-link:hover {
    text-decoration: underline;
  }

  .coordinates {
    font-size: 0.7rem;
    color: #9ca3af;
    padding-top: 0.5rem;
  }

  .loading-container, .error-container, .empty-container {
    text-align: center;
    padding: 3rem;
    background: white;
    border-radius: 0.5rem;
  }

  .spinner-large {
    display: inline-block;
    width: 2rem;
    height: 2rem;
    border: 3px solid #e5e7eb;
    border-radius: 50%;
    border-top-color: #2563eb;
    animation: spin 0.6s linear infinite;
    margin-bottom: 1rem;
  }

  .error-message {
    color: #dc2626;
  }

  .empty-icon {
    font-size: 3rem;
    margin-bottom: 1rem;
  }

  .empty-title {
    font-size: 1.125rem;
    font-weight: 500;
    color: #374151;
    margin-bottom: 0.5rem;
  }

  .empty-description {
    font-size: 0.875rem;
    color: #6b7280;
  }

  .stats {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
    text-align: center;
    font-size: 0.875rem;
    color: #6b7280;
  }

  .pagination-container {
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid #e5e7eb;
  }
  
  .pagination-controls {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  
  .pagination-btn {
    padding: 0.5rem 1rem;
    background-color: #f3f4f6;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all 0.2s;
  }
  
  .pagination-btn:hover:not(:disabled) {
    background-color: #e5e7eb;
    border-color: #9ca3af;
  }
  
  .pagination-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  
  .page-info {
    font-size: 0.875rem;
    color: #374151;
  }
  
  .page-size-selector {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.875rem;
  }
  
  .page-size-selector select {
    padding: 0.25rem 0.5rem;
    border-radius: 0.375rem;
    border: 1px solid #d1d5db;
    background-color: white;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  @media (max-width: 640px) {
    .schools-grid {
      grid-template-columns: 1fr;
    }
    
    .tipo-badge {
      font-size: 0.7rem;
      padding: 0.2rem 0.6rem;
    }
    
    .buttons-container {
      grid-template-columns: 1fr;
    }
    .pagination-controls {
      justify-content: center;
    }
    .page-size-selector {
      justify-content: center;
    }
  }
</style>
```

### `src/lib/School/SchoolScores.svelte`

```svelte
<script>
  export let schoolData;
  export let averages = null;

  const scoreKeys = [
    { key: 'score_capacidade_atendimento', label: 'Capacidade de Atendimento' },
    { key: 'score_infraestrutura', label: 'Infraestrutura' },
    { key: 'score_capacitacao_docente', label: 'Capacitação Docente' },
    { key: 'score_diversidade_discente', label: 'Diversidade Discente' },
    { key: 'score_capacidade_gestora', label: 'Capacidade Gestora' },
    { key: 'score_sustentabilidade', label: 'Sustentabilidade' }
  ];

  function formatScore(value) {
    const num = parseFloat(value);
    return isNaN(num) ? '—' : num.toFixed(1);
  }

  function getBarColor(score) {
    const num = parseFloat(score);
    if (isNaN(num)) return '#d1d5db'; // cinza claro
    if (num < 3) return '#ef4444';    // vermelho
    if (num < 6) return '#eab308';    // amarelo
    if (num < 8) return '#3b82f6';    // azul
    return '#22c55e';                 // verde
  }
</script>

<div class="score-card">
  <div class="score-header">
    <h2>{schoolData.escola}</h2>
    <p class="address">Endereço: {schoolData.endereco}</p>
    <p>Código: {schoolData.co_entidade} | Ano: {schoolData.nu_ano_censo}</p>
    <p class="update-date">Atualizado em: {new Date(schoolData.data_atualizacao).toLocaleString()}</p>
  </div>

  <div class="score-list">
    {#each scoreKeys as item (item.key)}
      {@const scoreValue = schoolData[item.key]}
      {@const scoreNum = parseFloat(scoreValue)}
      {@const hasAverage = averages && averages[item.key]}
      <div class="score-item">
        <div class="score-row">
          <div class="score-label">{item.label}</div>
          <div class="score-number">{formatScore(scoreValue)} / 10</div>
        </div>
        <div class="bar-bg">
          <div
            class="bar-fill"
            style="width: {Math.min(100, Math.max(0, scoreNum * 10))}%; background-color: {getBarColor(scoreValue)};"
          ></div>
        </div>
        {#if hasAverage}
          <div class="averages">
            {#if averages[item.key].municipal !== undefined}
              <span>Municipal: {averages[item.key].municipal.toFixed(1)}</span>
            {/if}
            {#if averages[item.key].estadual !== undefined}
              <span>Estadual: {averages[item.key].estadual.toFixed(1)}</span>
            {/if}
            {#if averages[item.key].nacional !== undefined}
              <span>Nacional: {averages[item.key].nacional.toFixed(1)}</span>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  .score-card {
    max-width: 700px;
    margin: 2rem auto;
    background: white;
    border-radius: 0.75rem;
    box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.02);
    border: 1px solid #e5e7eb;
    overflow: hidden;
    font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
  }
  .score-header {
    background: linear-gradient(135deg, #1e3a8a, #1e40af);
    padding: 1.25rem 1.5rem;
    color: white;
  }
  .score-header h2 {
    font-size: 1.25rem;
    font-weight: 700;
    margin: 0 0 0.25rem 0;
  }
  .score-header p {
    margin: 0.25rem 0;
    font-size: 0.875rem;
    opacity: 0.9;
  }
  .update-date {
    font-size: 0.75rem;
    opacity: 0.75;
  }
  .address {
    font-size: 0.80rem;
    opacity: 0.50;
  }
  .score-list {
    padding: 0;
  }
  .score-item {
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
  }
  .score-item:last-child {
    border-bottom: none;
  }
  .score-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    flex-wrap: wrap;
    margin-bottom: 0.5rem;
  }
  .score-label {
    font-weight: 600;
    color: #1f2937;
  }
  .score-number {
    font-weight: 700;
    font-size: 1.125rem;
    color: #111827;
  }
  .bar-bg {
    background-color: #e5e7eb;
    border-radius: 9999px;
    height: 0.75rem;
    overflow: hidden;
  }
  .bar-fill {
    height: 0.75rem;
    border-radius: 9999px;
    transition: width 0.3s ease;
  }
  .averages {
    margin-top: 0.75rem;
    padding-top: 0.5rem;
    border-top: 1px solid #f3f4f6;
    font-size: 0.7rem;
    color: #6b7280;
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
  }
  .averages span {
    background: #f9fafb;
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
  }
</style>
```

### `src/lib/School/ScoresModal.svelte`

```svelte
<script>
  import { onMount } from 'svelte';
  import SchoolScores from './SchoolScores.svelte';
  import { fetchSchoolScores } from '../service/school.js'; // ajuste o caminho conforme necessário

  export let escola = null;
  export let isOpen = false;

  let schoolData = null;
  let loading = false;
  let error = null;

  // Observa a abertura do modal ou mudança de escola para carregar os dados
  $: if (isOpen && escola && escola.codigo_inep) {
    loadScores();
  }

  async function loadScores() {
    loading = true;
    error = null;
    schoolData = null;

    try {
      const data = await fetchSchoolScores(escola.codigo_inep);
      schoolData = data;
    } catch (err) {
      error = err.message;
      console.error('Erro ao carregar scores:', err);
    } finally {
      loading = false;
    }
  }

  function handleClose() {
    isOpen = false;
    schoolData = null;
    error = null;
    // Disparar evento para o pai
    dispatch('close');
  }

  // Impede scroll do body quando modal aberto
  onMount(() => {
    if (typeof window !== 'undefined') {
      const originalOverflow = window.getComputedStyle(document.body).overflow;
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  });

  $: if (isOpen) {
    document.body.style.overflow = 'hidden';
  } else {
    document.body.style.overflow = '';
  }

  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();
</script>

{#if isOpen}
  <div class="modal-overlay" on:click={handleClose}
    on:keydown={(e) => e.key === 'Escape' && handleClose()}
    role="button"
    tabindex="0"
  >
    <div class="modal-container" on:click|stopPropagation>
      <div class="modal-header">
        <h2>Scores da Escola</h2>
        <button class="close-btn" on:click={handleClose}>✕</button>
      </div>
      <div class="modal-body">
        {#if loading}
          <div class="loading">Carregando scores...</div>
        {:else if error}
          <div class="error">
            <p>Erro ao carregar os scores: {error}</p>
            <button on:click={loadScores}>Tentar novamente</button>
          </div>
        {:else if schoolData}
          <SchoolScores schoolData={{...schoolData, ...escola}} averages={null} />
        {:else}
          <div class="empty">Nenhum dado disponível</div>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    backdrop-filter: blur(3px);
    animation: fadeIn 0.2s ease-out;
  }
  .modal-container {
    background: white;
    border-radius: 1rem;
    width: 90%;
    max-width: 850px;
    max-height: 90vh;
    overflow-y: auto;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    animation: slideUp 0.3s ease-out;
  }
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1rem 1.5rem;
    border-bottom: 1px solid #e5e7eb;
    background: linear-gradient(135deg, #1e3a8a, #1e40af);
    border-radius: 1rem 1rem 0 0;
    color: white;
  }
  .modal-header h2 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
  }
  .close-btn {
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: white;
    opacity: 0.8;
    transition: opacity 0.2s;
    line-height: 1;
    padding: 0;
  }
  .close-btn:hover {
    opacity: 1;
  }
  .modal-body {
    padding: 1.5rem;
  }
  .loading, .error, .empty {
    text-align: center;
    padding: 2rem;
    font-size: 1rem;
  }
  .error {
    color: #dc2626;
  }
  .error button {
    margin-top: 0.75rem;
    padding: 0.5rem 1rem;
    background-color: #3b82f6;
    color: white;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
  }
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  @keyframes slideUp {
    from { transform: translateY(30px); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
</style>
```

### `src/lib/School/SearchForm.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  
  export let loading = false;
  
  const dispatch = createEventDispatcher();
  
  let nomeEscola = '';
  let cidade = '';

  function buscarEscolas() {
    if (!nomeEscola.trim() && !cidade.trim()) {
      dispatch('error', { message: 'Informe pelo menos o nome da escola ou a cidade' });
      return;
    }
    
    dispatch('search', { nome: nomeEscola, cidade });
  }

  function limparFiltros() {
    nomeEscola = '';
    cidade = '';
    dispatch('clear');
  }
</script>

<div class="search-form">
  <form on:submit|preventDefault={buscarEscolas} class="form-container">
    <div class="form-grid">
      <div class="form-field">
        <label for="nome-escola">
          🏫 Nome da Escola
        </label>
        <input
          id="nome-escola"
          type="text"
          bind:value={nomeEscola}
          placeholder="Digite o nome da escola..."
          disabled={loading}
        />
        <small>Exemplo: "Maria", "São José", "Profª Helena"</small>
      </div>

      <div class="form-field">
        <label for="cidade">
          🌆 Cidade
        </label>
        <input
          id="cidade"
          type="text"
          bind:value={cidade}
          placeholder="Digite o nome da cidade..."
          disabled={loading}
        />
        <small>Exemplo: "Ubatuba", "São Paulo", "Campinas"</small>
      </div>
    </div>

    <div class="form-actions">
      <button
        type="submit"
        disabled={loading || (!nomeEscola.trim() && !cidade.trim())}
        class="btn-primary"
      >
        {#if loading}
          <span class="spinner"></span>
          Buscando...
        {:else}
          🔍 Buscar Escolas
        {/if}
      </button>

      <button
        type="button"
        on:click={limparFiltros}
        disabled={loading}
        class="btn-secondary"
      >
        Limpar
      </button>
    </div>

    <div class="form-hint">
      💡 Dica: Você pode buscar por nome da escola, por cidade, ou combinar ambos para resultados mais precisos.
    </div>
  </form>
</div>

<style>
  .search-form {
    background: white;
    border-radius: 0.5rem;
    box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
    padding: 1.5rem;
  }

  .form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    margin-bottom: 1.5rem;
  }

  .form-field {
    display: flex;
    flex-direction: column;
  }

  .form-field label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #374151;
    margin-bottom: 0.5rem;
  }

  .form-field input {
    padding: 0.5rem 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    font-size: 0.875rem;
    transition: all 0.2s;
  }

  .form-field input:focus {
    outline: none;
    border-color: #3b82f6;
    ring: 2px solid #3b82f6;
  }

  .form-field input:disabled {
    background-color: #f3f4f6;
    cursor: not-allowed;
  }

  .form-field small {
    margin-top: 0.25rem;
    font-size: 0.75rem;
    color: #6b7280;
  }

  .form-actions {
    display: flex;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }

  .btn-primary {
    flex: 1;
    background-color: #2563eb;
    color: white;
    font-weight: 500;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: #1d4ed8;
  }

  .btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .btn-secondary {
    padding: 0.5rem 1rem;
    border: 1px solid #d1d5db;
    border-radius: 0.375rem;
    color: #374151;
    background: white;
    transition: all 0.2s;
  }

  .btn-secondary:hover:not(:disabled) {
    background-color: #f3f4f6;
  }

  .btn-secondary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .spinner {
    display: inline-block;
    width: 1rem;
    height: 1rem;
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-radius: 50%;
    border-top-color: white;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .form-hint {
    font-size: 0.75rem;
    color: #6b7280;
    background-color: #f9fafb;
    padding: 0.75rem;
    border-radius: 0.375rem;
  }

  @media (max-width: 768px) {
    .form-grid {
      grid-template-columns: 1fr;
      gap: 1rem;
    }
  }
</style>
```

### `src/lib/School/SearchSchoolPage.svelte`

```svelte
<script>
  import SearchForm from './SearchForm.svelte';
  import SchList from './SchList.svelte';
  import PayrollModal from './PayrollModal.svelte';
  import GradesModal from './GradesModal.svelte';
  import ScoresModal from './ScoresModal.svelte';
  
  let escolas = [];           // resultados originais da API
  let loading = false;
  let error = null;
  let buscaRealizada = false;
  let showPayrollModal = false;
  let showGradesModal = false;
  let showScoreModal = false;
  let selectedEscola = null;

  // --- Filtros ---
  let filtroTipo = 'todos';           // 'todos' ou um valor específico (ex: 'Municipal')
  let filtroCidade = 'todas';         // 'todas' ou um valor específico (ex: 'São Paulo - SP')
  let filtroModalidade = 'todas';     // 'todas' ou uma modalidade específica (ex: 'Ensino Fundamental')
  
  let opcoesTipos = [];               // ex: ['Municipal', 'Estadual', 'Privada', 'Federal']
  let opcoesCidades = [];             // ex: ['São Paulo - SP', 'Rio de Janeiro - RJ']
  let opcoesModalidades = [];         // ex: ['Ensino Fundamental', 'Ensino Médio', 'EJA']

  // --- Lista filtrada (reativa) ---
  $: listaFiltrada = aplicarFiltros(escolas, filtroTipo, filtroCidade, filtroModalidade);

  // Função que aplica os filtros sobre a lista original
  function aplicarFiltros(lista, tipo, cidade, modalidade) {
    if (!lista || lista.length === 0) return [];
    
    return lista.filter(escola => {
      // Filtro por tipo 
      if (tipo !== 'todos' && escola.tipo !== tipo) {
        return false;
      }
      
      // Filtro por cidade/estado (combinação "municipio - UF")
      if (cidade !== 'todas') {
        const cidadeEstado = `${escola.municipio} - ${escola.uf}`;
        if (cidadeEstado !== cidade) {
          return false;
        }
      }

      // Filtro por modalidade (escola.modalidades é um array)
      if (modalidade !== 'todas') {
        // Verifica se o array existe e contém a modalidade selecionada
        if (!escola.modalidades || !escola.modalidades.includes(modalidade)) {
          return false;
        }
      }
      
      return true;
    });
  }

  // Extrai os valores únicos de tipo, cidade/estado e modalidades a partir dos resultados da busca
  function atualizarOpcoesFiltro(resultados) {
    if (!resultados || resultados.length === 0) {
      opcoesTipos = [];
      opcoesCidades = [];
      opcoesModalidades = [];
      return;
    }
    
    // Tipos únicos
    const tiposSet = new Set();
    resultados.forEach(escola => {
      if (escola.tipo) {
        tiposSet.add(escola.tipo);
      }
    });
    opcoesTipos = Array.from(tiposSet).sort();
    
    // Cidades/Estados únicos (formato "municipio - UF")
    const cidadesSet = new Set();
    resultados.forEach(escola => {
      if (escola.municipio && escola.uf) {
        cidadesSet.add(`${escola.municipio} - ${escola.uf}`);
      }
    });
    opcoesCidades = Array.from(cidadesSet).sort();

    // Modalidades únicas (extraídas dos arrays)
    const modalidadesSet = new Set();
    resultados.forEach(escola => {
      if (escola.modalidades && Array.isArray(escola.modalidades)) {
        escola.modalidades.forEach(mod => {
          if (mod) modalidadesSet.add(mod);
        });
      }
    });
    opcoesModalidades = Array.from(modalidadesSet).sort();
  }

  // Reseta os filtros para "todos"/"todas"
  function resetarFiltros() {
    filtroTipo = 'todos';
    filtroCidade = 'todas';
    filtroModalidade = 'todas';
  }

  // Limpa a busca atual e reseta os filtros
  function handleClear() {
    escolas = [];
    error = null;
    buscaRealizada = false;
    resetarFiltros();
    opcoesTipos = [];
    opcoesCidades = [];
    opcoesModalidades = [];
  }

  // Busca de escolas (já existente)
  async function handleSearch(event) {
    const { nome, cidade } = event.detail;
    
    loading = true;
    error = null;
    escolas = [];
    buscaRealizada = true;
    resetarFiltros();  // toda nova busca reinicia os filtros

    try {
      let url = '/api/school/search';
      if (nome && nome.trim()) {
        url += `/${encodeURIComponent(nome)}`;
      }
      if (cidade && cidade.trim()) {
        const cidadeParam = encodeURIComponent(cidade.trim());
        url += (url.includes('?') ? `&cidade=${cidadeParam}` : `?cidade=${cidadeParam}`);
      }
      
      const response = await fetch(url);
      if (!response.ok) throw new Error(`Erro na busca: ${response.status}`);
      
      const data = await response.json();
      escolas = data;
      
      // Após obter os resultados, atualiza as opções dos filtros
      atualizarOpcoesFiltro(escolas);
      
      if (escolas.length === 0) {
        error = 'Nenhuma escola encontrada com os critérios informados';
      }
    } catch (err) {
      error = err.message;
      console.error('Erro ao buscar escolas:', err);
    } finally {
      loading = false;
    }
  }

  function handleError(event) {
    error = event.detail.message;
  }

  function openGradesModal(school) {
    selectedEscola = school;
    showGradesModal = true;
  }

  function closeGradesModal() {
    showGradesModal = false;
    selectedEscola = null;
  }

  function openScoreModal(school) {
    selectedEscola = school;
    showScoreModal = true;
  }

  function closeScoreModal() {
    showScoreModal = false;
    selectedEscola = null;
  }

  function handleViewPayroll(event) {
    selectedEscola = event.detail.escola;
    showPayrollModal = true;
  }

  function handleViewGrades(event) {
    selectedEscola = event.detail.escola;
    showGradesModal = true;
  }

  function handleViewScores(event) {
    selectedEscola = event.detail.escola;
    showScoreModal = true;
  }
</script>

<div class="busca-escolas-page">
  <div class="page-header">
    <h1>🔍 Busca de Escolas</h1>
    <p>Encontre escolas pelo nome ou cidade</p>
  </div>

  <SearchForm 
    on:search={handleSearch}
    on:error={handleError}
    on:clear={handleClear}
    {loading}
  />

  {#if buscaRealizada}
    <!-- Barra de filtros (exibida somente se houver resultados) -->
    {#if escolas.length > 0}
      <div class="filtros-bar">
        <div class="filtro-group">
          <label for="filtro-tipo">🏫 Tipo de escola:</label>
          <select id="filtro-tipo" bind:value={filtroTipo}>
            <option value="todos">Todos</option>
            {#each opcoesTipos as tipo}
              <option value={tipo}>{tipo}</option>
            {/each}
          </select>
        </div>

        <div class="filtro-group">
          <label for="filtro-cidade">📍 Cidade / Estado:</label>
          <select id="filtro-cidade" bind:value={filtroCidade}>
            <option value="todas">Todas</option>
            {#each opcoesCidades as cidade}
              <option value={cidade}>{cidade}</option>
            {/each}
          </select>
        </div>

        <!-- Novo filtro de Modalidade -->
        <div class="filtro-group">
          <label for="filtro-modalidade">📚 Modalidade:</label>
          <select id="filtro-modalidade" bind:value={filtroModalidade}>
            <option value="todas">Todas</option>
            {#each opcoesModalidades as modalidade}
              <option value={modalidade}>{modalidade}</option>
            {/each}
          </select>
        </div>

        <!-- Exibe contagem de resultados filtrados -->
        <div class="contagem">
          Exibindo <strong>{listaFiltrada.length}</strong> de {escolas.length} escola(s)
        </div>
      </div>
    {/if}

    <div class="results-section">
      <SchList 
        escolas={listaFiltrada}
        loading={loading}
        error={error}
        on:viewPayroll={handleViewPayroll}
        on:viewGrades={handleViewGrades}
        on:viewScores={handleViewScores}
      />
    </div>
  {/if}
</div>

<!-- Modais -->
<PayrollModal 
  bind:show={showPayrollModal}
  escola={selectedEscola}
  on:close={() => {
    showPayrollModal = false;
    selectedEscola = null;
  }}
/>

<GradesModal
  school={selectedEscola}
  bind:isOpen={showGradesModal}
  on:close={closeGradesModal}
/>

<ScoresModal
  escola={selectedEscola}
  bind:isOpen={showScoreModal}
  on:close={closeScoreModal}
/>

<style>
  .busca-escolas-page {
    max-width: 1400px;
    margin: 0 auto;
    padding: 2rem;
  }
  .page-header {
    text-align: center;
    margin-bottom: 2rem;
  }
  .page-header h1 {
    font-size: 2rem;
    font-weight: bold;
    color: #1f2937;
    margin-bottom: 0.5rem;
  }
  .page-header p {
    color: #6b7280;
  }
  .results-section {
    margin-top: 2rem;
  }
  
  /* Estilos dos filtros */
  .filtros-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 1.5rem;
    align-items: flex-end;
    background: #f9fafb;
    padding: 1rem 1.5rem;
    border-radius: 12px;
    margin-top: 1rem;
    margin-bottom: 1rem;
    border: 1px solid #e5e7eb;
  }
  .filtro-group {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }
  .filtro-group label {
    font-size: 0.875rem;
    font-weight: 500;
    color: #4b5563;
  }
  .filtro-group select {
    padding: 0.5rem 2rem 0.5rem 0.75rem;
    border-radius: 8px;
    border: 1px solid #d1d5db;
    background-color: white;
    font-size: 0.875rem;
    cursor: pointer;
  }
  .contagem {
    margin-left: auto;
    font-size: 0.875rem;
    color: #6b7280;
    background: white;
    padding: 0.25rem 0.75rem;
    border-radius: 20px;
    border: 1px solid #e5e7eb;
  }
</style>
```


---

## 📁 src/lib

### `src/lib/SchoolLayer.svelte`

```svelte
<script>
  import { onMount, getContext } from 'svelte';
  import L from 'leaflet';
  import SchoolPopup from './SchoolPopup.svelte';
  import { selectedSchool, hoveredSchool } from './js/schoolStore.js';
  import CoverArea from './School/CoverArea.svelte';
  import { activeCoverSchool } from './stores/activeCoverStore.js';

  export let schoolData = null;

  const { getMap, isReady } = getContext('leaflet-map');
  let pointsLayer;
  let mapReady = false;
  let markersMap = new Map(); // codigo_inep → marker

  // Estilos
  const styleDefault  = { radius: 6,  fillColor: '#ff7800', color: '#000', weight: 1, fillOpacity: 0.8 };
  const styleSelected = { radius: 10, fillColor: '#e63946', color: '#fff', weight: 2, fillOpacity: 1   };
  const styleHovered  = { radius: 8,  fillColor: '#ffd166', color: '#333', weight: 1.5, fillOpacity: 1 };

  $: if (schoolData && mapReady) updateLayer(schoolData);

  // Reage a selectedSchool vindo da tabela → destaca no mapa e dá pan
  $: if (mapReady && $selectedSchool) {
    highlightMarker($selectedSchool, styleSelected);
    const map = getMap();
    const coords = $selectedSchool.geometry.coordinates;
    map?.panTo([coords[1], coords[0]], { animate: true });
  }

  // Reage a hoveredSchool vindo da tabela → destaca sem pan
  $: if (mapReady) {
    markersMap.forEach((marker, id) => {
      const isSelected = $selectedSchool?.properties.codigo_inep === id;
      const isHovered  = $hoveredSchool?.properties.codigo_inep  === id;
      marker.setStyle(isSelected ? styleSelected : isHovered ? styleHovered : styleDefault);
      if (isHovered || isSelected) marker.bringToFront();
    });
  }

  onMount(() => {
    const check = setInterval(() => {
      if (isReady()) {
        const map = getMap();
        if (map) {
          pointsLayer = L.layerGroup().addTo(map);
          mapReady = true;
          clearInterval(check);
        }
      }
    }, 50);
    return () => {
      clearInterval(check);
      pointsLayer?.clearLayers();
      pointsLayer?.remove();
    };
  });

  function updateLayer(data) {
    if (!pointsLayer) return;
    pointsLayer.clearLayers();
    markersMap.clear();

    L.geoJSON(data, {
      pointToLayer: (feature, latlng) => {
        const marker = L.circleMarker(latlng, { ...styleDefault });
        const id = feature.properties.codigo_inep;
        markersMap.set(id, marker);

        marker.on('click', () => selectedSchool.set(feature));
        marker.on('mouseover', () => hoveredSchool.set(feature));
        marker.on('mouseout',  () => hoveredSchool.set(null));

        const popup = document.createElement('div');
        new SchoolPopup({ target: popup, props: { school: feature.properties } });
        marker.bindPopup(popup);
        return marker;
      }
    }).addTo(pointsLayer);
  }

  function highlightMarker(feature, style) {
    markersMap.forEach((m, id) => {
      m.setStyle(id === feature.properties.codigo_inep ? style : styleDefault);
    });
  }
</script>

<CoverArea />
```

### `src/lib/SchoolPopup.svelte`

```svelte
<script>
  import { activeCoverSchool } from './stores/activeCoverStore.js';
  export let school;
</script>

<div>
  <strong>{school.escola || 'Escola - Sem Nome'}</strong><br>
  {#if school.categoria_administrativa}
    Tipo: {school.categoria_administrativa}<br>
  {/if}
  {school.telefone}
  <br>
  <button on:click={() => activeCoverSchool.set({ properties: school })}>
    🗺️ Área de cobertura (5 km)
  </button>
</div>

<style>
  button {
    margin-top: 0.5rem;
    padding: 0.25rem 0.5rem;
    background: #2c7da0;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
  }
  button:hover {
    background: #1f5e7a;
  }
</style>
```

### `src/lib/SchoolTable.svelte`

```svelte
<script>
  import { selectedSchool, hoveredSchool, sortedSchools } from './js/schoolStore.js';
</script>

<div class="school-table-wrapper">
  {#if $sortedSchools.length === 0}
    <p class="empty">Nenhuma escola carregada.</p>
  {:else}
    <table>
      <thead>
        <tr>
          <th>Código INEP</th>
          <th>Escola</th>
          <th>Telefone</th>
        </tr>
      </thead>
      <tbody>
        {#each $sortedSchools as school (school.properties.codigo_inep)}
          {@const p = school.properties}
          {@const isSelected = $selectedSchool?.properties.codigo_inep === p.codigo_inep}
          {@const isHovered  = $hoveredSchool?.properties.codigo_inep  === p.codigo_inep}
          <tr
            class:selected={isSelected}
            class:hovered={isHovered}
            on:click={() => selectedSchool.set(school)}
            on:mouseenter={() => hoveredSchool.set(school)}
            on:mouseleave={() => hoveredSchool.set(null)}
          >
            <td>{p.codigo_inep ?? '—'}</td>
            <td>{p.escola      ?? '—'}</td>
            <td>{p.telefone ?? '—'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .school-table-wrapper {
    max-height: 400px;
    overflow-y: auto;
    border: 1px solid rgba(0,0,0,.12);
    border-radius: 8px;
    font-size: 13px;
  }
  table { width: 100%; border-collapse: collapse; }
  thead th {
    position: sticky; top: 0;
    background: var(--color-background-secondary, #f5f5f5);
    padding: 8px 10px;
    text-align: left;
    font-weight: 500;
    border-bottom: 1px solid rgba(0,0,0,.1);
  }
  tbody tr {
    cursor: pointer;
    transition: background .15s;
  }
  tbody tr:hover, tr.hovered   { background: rgba(255, 209, 102, .25); }
  tr.selected                  { background: rgba(230,  57,  70, .12); font-weight: 500; }
  td { padding: 7px 10px; border-bottom: 1px solid rgba(0,0,0,.06); }
  .empty { padding: 16px; color: var(--color-text-secondary); text-align: center; }
</style>
```


---

## 📁 src/lib/Siope

### `src/lib/Siope/JobProgress.svelte`

```svelte
<script>
  import { onMount, onDestroy } from 'svelte';
  import { monitorJobProgress } from '../js/siope.js';

  export let jobId;
  export let jobName = "Processamento SIOPE";
  export let onJobComplete; // Callback para quando o job terminar (passa os dados)

  let progressPercentage = 0;
  let jobStatus = 'Iniciando...';
  let errorMessage = null;

  let cleanup = () => {}; // Função para fechar a conexão SSE

  onMount(() => {
    // Assume que a URL de progresso é /api/job/progress/:id
    const progressUrl = `/api/job/progress/${jobId}`;

    console.log(`JobProgress: Monitorando Job ID ${jobId} via SSE em ${progressUrl}`);

    // monitorJobProgress retorna uma função de limpeza (cleanup)
    cleanup = monitorJobProgress(
      progressUrl,
      (data) => {
        console.log(data);
        // Função de atualização (do SSE onmessage)
        jobStatus = data.progress.state;
        if (data.progress.total && data.progress.total > 0) {
          progressPercentage = (data.progress.processed / data.progress.total)*100.0;
        }

        if (data.progress.state === 'finished' && data.result) {
          cleanup(); // Fecha a conexão
          // Chama o callback para o componente pai renderizar os dados
          onJobComplete(data.result);
        }

        if (data.progress.state === 'failed') {
          errorMessage = data.error || 'Erro desconhecido durante o processamento.';
          cleanup();
        }
      },
      (error) => {
        // Função de erro
        jobStatus = 'Erro de Conexão';
        errorMessage = error.message;
        cleanup();
      }
    );
  });

  onDestroy(() => {
    cleanup(); // Garante que a conexão SSE seja fechada ao destruir o componente
  });
</script>

<div class="progress-card">
  <h5 class="progress-title">⏳ {jobName} em Processamento...</h5>

  {#if errorMessage}
    <div class="error-message">❌ {jobStatus}: {errorMessage}</div>
  {:else}
    <div class="progress-status">{jobStatus} ({Math.round(progressPercentage)}%)</div>
    <div class="progress-bar-container">
      <div 
        class="progress-bar" 
        style="width: {progressPercentage}%"
        aria-valuenow={progressPercentage}
        aria-valuemin="0"
        aria-valuemax="100"
      ></div>
    </div>
    <p class="job-note">ID do Job: {jobId}. Os dados serão carregados automaticamente ao finalizar.</p>
  {/if}
</div>

<style>
.progress-card {
  background-color: #fff3cd; /* Cor de aviso */
  border: 1px solid #ffeeba;
  padding: 1rem;
  border-radius: 8px;
  margin-top: 1rem;
}
.progress-title {
  color: #856404;
  margin-top: 0;
  margin-bottom: 0.5rem;
  font-size: 1rem;
  font-weight: 600;
}
.progress-status {
  font-size: 0.9rem;
  color: #383d41;
  margin-bottom: 0.5rem;
}
.progress-bar-container {
  height: 10px;
  background-color: #e9ecef;
  border-radius: 5px;
  overflow: hidden;
  margin-bottom: 0.5rem;
}
.progress-bar {
  height: 100%;
  background-color: #007bff; /* Cor azul primária */
  transition: width 0.4s ease;
}
.job-note {
  font-size: 0.75rem;
  color: #6c757d;
  margin-bottom: 0;
}
.error-message {
  color: #721c24;
  background-color: #f8d7da;
  border: 1px solid #f5c6cb;
  padding: 0.5rem;
  border-radius: 4px;
}
</style>
```

### `src/lib/Siope/Payroll.svelte`

```svelte
<script>
import { formatValue } from '../js/siope.js';

// O array de dados do payroll do SIOPE (e.g., RemuneracaoMunicipal)
export let payrollData = [];

// Mapeamento de rótulos específicos para o payroll
const payrollLabels = {
  'tipo': 'Tipo',
  'ano': 'Ano de Referência',
  'mes': 'Mês',
  'nome_profissional': 'Nome do Profissional',
  'cod_municipio': 'Código IBGE do município',
  'cod_inep': 'Código INEP da escola',
  'escola': 'Nome da Escola',
  'carga_horaria': 'Carga Horária Semanal',
  'cpf': 'CPF do profissional',
  'situacao': 'Situação / Tipo contrato',
  'segmento_ensino': 'Segmento de ensino em que atua',
  'rede': 'Rede da escola',
  'salario_base': 'Salário Base',
  'salario_fundeb_max': 'Salário com até 70% parcela FUNDEB',
  'salario_fundeb_min': 'Salário com até 30% parcela FUNDEB',
  'salario_outros': 'Outras fontes',
  'salario_total': 'Total salário'
};

function formatPayrollValue(key, value) {
  if (key === 'salario_total' || key === 'total_salarios') {
    return Number(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  }
  return formatValue(key, value); // Reutiliza a função de formatação geral
}
</script>

<div class="siope-data-container">
  <h4>💸 Detalhes do Payroll SIOPE ({payrollData.length} registros)</h4>

  {#if payrollData.length > 0}
    <table class="payroll-details">
      <thead>
        <tr>
          {#each Object.keys(payrollData[0] || {}) as key}
            <th>{payrollLabels[key] || key.toUpperCase()}</th>
          {/each}
        </tr>
      </thead>
      <tbody>
        {#each payrollData.slice(0, 10) as item} <tr>
          {#each Object.entries(item) as [key, value]}
            <td>{formatPayrollValue(key, value)}</td>
          {/each}
        </tr>
        {/each}
      </tbody>
    </table>
    {#if payrollData.length > 10}
      <p class="note">... e mais {payrollData.length - 10} registros. (Total: {payrollData.length})</p>
    {/if}
  {:else}
    <p>Nenhum registro de folha de pagamento do SIOPE encontrado para este ano.</p>
  {/if}
</div>

<style>
.siope-data-container {
  margin-top: 1.5rem;
  padding-top: 1rem;
  border-top: 1px solid #ddd;
}
.payroll-details {
  width: 100%;
  border-collapse: collapse;
}
.payroll-details th, .payroll-details td {
  border: 1px solid #eee;
  padding: 8px;
  text-align: left;
  font-size: 0.85rem;
}
.payroll-details th {
  background-color: #f1f1f1;
}
.note {
  font-size: 0.8rem;
  color: #6c757d;
  margin-top: 0.5rem;
}
</style>
```


---

## 📁 src/lib/js

### `src/lib/js/cover.js`

```javascript
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
```

### `src/lib/js/schoolStore.js`

```javascript
import { writable, derived } from "svelte/store";

export const schools = writable([]);
export const selectedSchool = writable(null);
export const hoveredSchool = writable(null);

// Lista ordenada: escola selecionada sempre no topo
export const sortedSchools = derived(
  [schools, selectedSchool],
  ([$schools, $selected]) => {
    if (!$selected) return $schools;
    return [
      $selected,
      ...$schools.filter(
        (s) => s.properties.codigo_inep !== $selected.properties.codigo_inep,
      ),
    ];
  },
);
```

### `src/lib/js/siope.js`

```javascript
export async function getSiopePayroll(cityId, year) {
  const queryUrl = `/api/query/siope?city=${cityId}&year=${year}`;

  // --- 1. TENTATIVA DE LEITURA (GET) ---
  console.log(`1. Tentando GET: ${queryUrl}`);
  let response = await fetch(queryUrl);

  if (response.status == 200) {
    // Status 200 OK: Dados encontrados no cache/DB
    console.log("✅ Dados prontos (Status 200 OK).");
    return await response.json();
  } else if (response.status === 204 || response.status === 404) {
    // Status 204 No Content / 404 Not Found: Os dados não existem (ainda).
    console.log(
      `2. Dados não encontrados (Status ${response.status}). Iniciando job...`,
    );

    // --- 2. INICIAÇÃO DO JOB (POST) ---
    return await startSiopeJob(cityId, year);
  } else {
    // Tratar outros erros (500, etc.)
    throw new Error(
      `Erro ao buscar dados: ${response.status} ${response.statusText}`,
    );
  }
}

export async function startSiopeJob(cityId, year) {
  const jobUrl = `/api/jobs/siope`;

  console.log(`3. Enviando POST para iniciar job: ${jobUrl}`);

  // O POST envia os mesmos parâmetros para que o backend crie o job
  let postResponse = await fetch(jobUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ city: cityId, year: year }),
  });

  if (postResponse.status === 202) {
    // Status 202 Accepted: Job iniciado com sucesso
    const jobInfo = await postResponse.json();
    const jobId = jobInfo.job_id;

    console.log(`4. Job aceito (Status 202). Job ID: ${jobId}`);
    return jobId;
  } else {
    throw new Error(
      `Erro ao iniciar o job: ${postResponse.status} ${postResponse.statusText}`,
    );
  }
}

export function monitorJobProgress(progressUrl, updateCallback, errorCallback) {
  const eventSource = new EventSource(progressUrl);

  eventSource.addEventListener('progress', (event) => {
    try {
      const data = JSON.parse(event.data);
      updateCallback(data);
    } catch (e) {
      console.error("Erro ao parsear mensagem SSE:", e);
    }
  });

  eventSource.onerror = (err) => {
    errorCallback(new Error("Falha na conexão de monitoramento SSE."));
    eventSource.close();
  };

  // Retorna a função de limpeza
  return () => eventSource.close();
}

export function formatValue(key, value) {
  if (value === null) return "N/A";

  switch (key) {
    case "area":
      return Number(value).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
    case "codigo_municipio":
    case "codigo_unidade_federativa":
      return `"${value}"`;
    default:
      return String(value);
  }
}
```


---

## 📁 src/lib

### `src/lib/osmStore.js`

```javascript
import { writable } from "svelte/store";

export const osmDisabled = writable(false);
```


---

## 📁 src/lib/service

### `src/lib/service/api.js`

```javascript
```

### `src/lib/service/school.js`

```javascript
/**
 * school.js
 * Módulo para buscar dados de scores de escolas via API
 * Endpoint: /api/school/scores?id=<co_entidade>
 */

/**
 * Busca os scores de uma escola pelo seu código INEP (co_entidade)
 * @param {number|string} id - Código da escola (co_entidade)
 * @returns {Promise<Object>} Objeto com os dados da escola e scores
 * @throws {Error} Lança erro se a requisição falhar ou se a resposta não for ok
 */
export async function fetchSchoolScores(id) {
  if (!id) {
    throw new Error("ID da escola não fornecido");
  }

  const url = `/api/school/scores?id=${encodeURIComponent(id)}`;

  try {
    const response = await fetch(url);

    if (!response.ok) {
      // Tenta extrair mensagem de erro do corpo da resposta, se disponível
      let errorMessage = `Erro ${response.status}: ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.message) {
          errorMessage = errorData.message;
        }
      } catch {
        // Se não for JSON, mantém a mensagem padrão
      }
      throw new Error(errorMessage);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    // Relançar o erro para que o chamador possa tratá-lo
    throw new Error(`Falha ao buscar scores da escola ${id}: ${error.message}`);
  }
}

/**
 * Exemplo de uso:
 *
 * import { fetchSchoolScores } from './school.js';
 *
 * try {
 *   const scores = await fetchSchoolScores(35245264);
 *   console.log(scores);
 * } catch (err) {
 *   console.error(err.message);
 * }
 */
```

### `src/lib/service/schoolClusterService.js`

```javascript
// services/schoolClusterService.js
export async function fetchClusteredSchools(city, clusterIds = null) {
  const params = new URLSearchParams({
    city: encodeURIComponent(city)
  });
  
  if (clusterIds && clusterIds.length) {
    params.append('clusters', clusterIds.join(','));
  }
  
  const response = await fetch(`/api/schools/clustered?${params}`);
  
  if (!response.ok) {
    throw new Error(`Failed to fetch clustered schools: ${response.status}`);
  }
  
  return await response.json();
}

export async function fetchSchoolComparison(schoolIds) {
  const response = await fetch('/api/schools/compare', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ school_ids: schoolIds })
  });
  
  return await response.json();
}
```


---

## 📁 src/lib/stores

### `src/lib/stores/activeCoverStore.js`

```javascript
import { writable } from "svelte/store";

export const activeCoverSchool = writable(null);
```


---

## 📁 src/lib/ui

### `src/lib/ui/LoadingSpinner.svelte`

```svelte
<script>
  export let size = '20px';
  export let color = '#2563eb';
</script>

<div class="spinner" style="width: {size}; height: {size}; border-top-color: {color};"></div>

<style>
  .spinner {
    border: 2px solid #e5e7eb;
    border-top-color: #2563eb;
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
```

### `src/lib/ui/SearchAutocomplete.svelte`

```svelte
<script>
  import { createEventDispatcher } from 'svelte';
  import SearchInput from './SearchInput.svelte';
  import LoadingSpinner from './LoadingSpinner.svelte';

  export let value = '';
  export let placeholder = 'Buscar...';
  export let fetchSuggestions = async (query) => [];  // função que retorna array
  export let minChars = 3;
  export let delay = 300;
  export let renderSuggestion = (item) => item.label || item;
  export let getSuggestionValue = (item) => item.value || item;
  export let disabled = false;

  let suggestions = [];
  let loading = false;
  let showDropdown = false;
  let searchValue = value;
  
  const dispatch = createEventDispatcher();

  const handleSearch = async (query) => {
    if (query.length < minChars) {
      suggestions = [];
      showDropdown = false;
      return;
    }

    loading = true;
    try {
      suggestions = await fetchSuggestions(query);
      showDropdown = suggestions.length > 0;
    } catch (err) {
      console.error('Erro ao buscar sugestões:', err);
      suggestions = [];
    } finally {
      loading = false;
    }
  };

  const selectSuggestion = (item) => {
    const selectedValue = getSuggestionValue(item);
    searchValue = renderSuggestion(item);
    value = selectedValue;
    suggestions = [];
    showDropdown = false;
    dispatch('select', { original: item, value: selectedValue });
  };

  // Expor métodos
  export function clear() {
    searchValue = '';
    value = '';
    suggestions = [];
    showDropdown = false;
  }
</script>

<div class="autocomplete-container">
  <SearchInput
    bind:value={searchValue}
    {placeholder}
    {disabled}
    {loading}
    {delay}
    onSearch={handleSearch}
  />

  {#if showDropdown}
    <div class="suggestions-dropdown">
      {#each suggestions as suggestion}
        <div class="suggestion-item" on:click={() => selectSuggestion(suggestion)}>
          {@html renderSuggestion(suggestion)}
          {#if suggestion.subtitle}
            <div class="suggestion-subtitle">{suggestion.subtitle}</div>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .autocomplete-container {
    position: relative;
    width: 100%;
    z-index: 10000;  /* Adicionar z-index no container */
  }

  .suggestions-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
    margin-top: 0.25rem;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    z-index: 100;
    max-height: 400px;
    overflow-y: auto;
  }

  .suggestion-item {
    padding: 0.75rem 1rem;
    cursor: pointer;
    border-bottom: 1px solid #f3f4f6;
    transition: background 0.2s;
  }

  .suggestion-item:hover {
    background: #f3f4f6;
  }

  .suggestion-subtitle {
    font-size: 0.7rem;
    color: #6b7280;
    margin-top: 0.25rem;
  }
</style>
```

### `src/lib/ui/SearchInput.svelte`

```svelte
<script>
  import LoadingSpinner from './LoadingSpinner.svelte';

  export let value = '';
  export let placeholder = 'Buscar...';
  export let disabled = false;
  export let loading = false;
  export let delay = 0;  // ms de debounce
  export let onSearch = (value) => {};

  let debounceTimer;
  let internalValue = value;

  $: internalValue = value;

  const handleInput = (e) => {
    internalValue = e.target.value;
    
    if (delay > 0) {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        onSearch(internalValue);
      }, delay);
    } else {
      onSearch(internalValue);
    }
  };
</script>

<div class="search-input-container">
  <span class="search-icon">🔍</span>
  <input
    type="text"
    bind:value={internalValue}
    on:input={handleInput}
    {placeholder}
    {disabled}
    class="search-input"
  />
  {#if loading}
    <div class="spinner-wrapper">
      <LoadingSpinner size="16px" />
    </div>
  {/if}
</div>

<style>
  .search-input-container {
    position: relative;
    display: flex;
    align-items: center;
    width: 100%;
  }

  .search-icon {
    position: absolute;
    left: 12px;
    font-size: 1rem;
    color: #9ca3af;
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    padding: 0.75rem 1rem 0.75rem 2.5rem;
    font-size: 1rem;
    border: 2px solid #e5e7eb;
    border-radius: 0.5rem;
    transition: all 0.2s;
  }

  .search-input:focus {
    outline: none;
    border-color: #2563eb;
    box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
  }

  .search-input:disabled {
    background-color: #f3f4f6;
    cursor: not-allowed;
  }

  .spinner-wrapper {
    position: absolute;
    right: 12px;
  }
</style>
```

### `src/lib/ui/SearchInputSimple.svelte`

```svelte
<script>
  export let value = '';
  export let placeholder = 'Buscar...';
  export let disabled = false;
  export let onSearch = (value) => {};
</script>

<div class="search-simple">
  <input
    type="text"
    bind:value
    on:input={() => onSearch(value)}
    {placeholder}
    {disabled}
    class="simple-input"
  />
  <span class="simple-icon">🔍</span>
</div>

<style>
  .search-simple {
    position: relative;
    width: 100%;
  }

  .simple-input {
    width: 100%;
    padding: 0.5rem 1rem 0.5rem 2rem;
    font-size: 0.875rem;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
  }

  .simple-input:focus {
    outline: none;
    border-color: #2563eb;
  }

  .simple-icon {
    position: absolute;
    left: 8px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.875rem;
    color: #9ca3af;
  }
</style>
```


---

## 📁 src

### `src/main.js`

```javascript
import "./app.css";
import App from "./App.svelte";

const app = new App({
  target: document.getElementById("app"),
});

export default app;
```


---

## 📁 src/styles

### `src/styles/cluster-popup.css`

```css
/* cluster-popup.css - Estilos para os popups dos clusters */

.cluster-popup-wrapper .leaflet-popup-content-wrapper {
  border-radius: 12px;
  padding: 0;
  overflow: hidden;
}

.cluster-popup {
  min-width: 260px;
}

.popup-header {
  padding: 12px;
  background: #f8f9fa;
  border-left: 4px solid;
  border-bottom: 1px solid #e5e7eb;
}

.popup-header h4 {
  margin: 0 0 6px 0;
  font-size: 14px;
  font-weight: 600;
  color: #1f2937;
}

.cluster-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 500;
  color: white;
}

.popup-body {
  padding: 12px;
  font-size: 12px;
}

.popup-body p {
  margin: 6px 0;
}

.popup-body hr {
  margin: 8px 0;
  border: none;
  border-top: 1px solid #e5e7eb;
}

.value {
  font-weight: 600;
  color: #1f2937;
}

.positive {
  color: #10b981;
}

.negative {
  color: #ef4444;
}

.popup-footer {
  padding: 10px 12px;
  background: #f8f9fa;
  border-top: 1px solid #e5e7eb;
}

.btn-details {
  width: 100%;
  padding: 6px;
  background: #3b82f6;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-details:hover {
  background: #2563eb;
}

/* Estilos para os marcadores de cluster */
.cluster-marker div {
  transition: transform 0.2s;
}

.cluster-marker div:hover {
  transform: scale(1.1);
}
```


---

## 📁 src/tests

### `src/tests/ScoresModal.test.js`

```javascript
import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import SchoolScores from '../lib/School/SchoolScores.svelte';

describe('SchoolScores Component', () => {
  const baseSchoolData = {
    escola: 'Colégio Estadual do Futuro',
    endereco: 'Av Central, 500',
    co_entidade: '998877',
    nu_ano_censo: '2026',
    data_atualizacao: '2026-01-01T12:00:00Z',
    score_capacidade_atendimento: '2.5', // < 3 -> Vermelho (#ef4444)
    score_infraestrutura: '5.5',         // < 6 -> Amarelo (#eab308)
    score_capacitacao_docente: '7.5',    // < 8 -> Azul (#3b82f6)
    score_diversidade_discente: '9.0',   // >= 8 -> Verde (#22c55e)
  };

  it('deve renderizar os cabeçalhos e metadados da escola corretamente', () => {
    render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    expect(screen.getByText('Colégio Estadual do Futuro')).toBeInTheDocument();
    expect(screen.getByText(/Código: 998877/)).toBeInTheDocument();
    expect(screen.getByText(/Ano: 2026/)).toBeInTheDocument();
  });

  it('deve aplicar as cores corretas nas barras baseado nos ranges das notas', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });

    // Seleciona todas as divs de preenchimento de barra (.bar-fill)
    const bars = container.querySelectorAll('.bar-fill');

    // Nota 2.5 (Vermelho)
    expect(bars[0].style.backgroundColor).toBe('rgb(239, 68, 68)'); // #ef4444 em RGB

    // Nota 5.5 (Amarelo)
    expect(bars[1].style.backgroundColor).toBe('rgb(234, 179, 8)');  // #eab308 em RGB

    // Nota 7.5 (Azul)
    expect(bars[2].style.backgroundColor).toBe('rgb(59, 130, 246)'); // #3b82f6 em RGB

    // Nota 9.0 (Verde)
    expect(bars[3].style.backgroundColor).toBe('rgb(34, 197, 94)');  // #22c55e em RGB
  });

  it('não deve renderizar a seção de médias se o objeto averages for nulo', () => {
    const { container } = render(SchoolScores, { schoolData: baseSchoolData, averages: null });
    const averagesDiv = container.querySelector('.averages');
    expect(averagesDiv).toBeNull();
  });

  it('deve renderizar as médias regionalizadas quando fornecidas', () => {
    const mockAverages = {
      score_capacidade_atendimento: { municipal: 4.2, estadual: 5.1, nacional: 6.0 }
    };

    render(SchoolScores, { schoolData: baseSchoolData, averages: mockAverages });

    expect(screen.getByText('Municipal: 4.2')).toBeInTheDocument();
    expect(screen.getByText('Estadual: 5.1')).toBeInTheDocument();
    expect(screen.getByText('Nacional: 6.0')).toBeInTheDocument();
  });
});
```

### `src/tests/ScoresModalWithIntegration.test.js`

```javascript
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import SearchSchoolPage from "../lib/School/SearchSchoolPage.svelte";
import { fetchSchoolScores } from "../lib/service/school.js";

// 1. Mock do serviço que o ScoresModal vai chamar internamente
vi.mock("../lib/service/school.js", () => ({
  fetchSchoolScores: vi.fn(),
}));

describe("SearchSchoolPage Integration - Fluxo de Scores", () => {
  // Dados simulados da busca de escolas
  const mockEscolasBusca = [
    {
      codigo_inep: "112233",
      escola: "Escola Municipal Paulo Freire",
      municipio: "Ubatuba",
      uf: "SP",
      tipo: "Municipal",
      modalidades: ["Ensino Fundamental"],
    },
  ];

  // Dados simulados do detalhe dos scores
  const mockScoresData = {
    co_entidade: "112233",
    nu_ano_censo: "2026",
    data_atualizacao: "2026-06-07T12:00:00Z",
    score_infraestrutura: "9.0",
  };

  beforeEach(() => {
    vi.clearAllMocks();

    // 2. Mock do fetch global para a busca de escolas da página
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue(mockEscolasBusca),
    });
  });

  it("deve buscar escolas, listar o resultado e abrir o modal de scores ao clicar no botão correspondente", async () => {
    // Renderiza a página principal de busca
    render(SearchSchoolPage);

    // Verifica se a página carregou o cabeçalho básico
    expect(screen.getByText("🔍 Busca de Escolas")).toBeInTheDocument();

    // 3. Simular a busca disparada pelo SearchForm
    // Como o SearchForm está em outro arquivo e dispara o evento 'search',
    // vamos preencher o input de texto e clicar no botão de busca.
    const inputNome = screen.getByLabelText(/Nome da Escola/i);
    await fireEvent.input(inputNome, { target: { value: "Paulo Freire" } });

    const btnBuscar = screen.getByRole("button", { name: /buscar|search/i });
    await fireEvent.click(btnBuscar);

    // 4. Verificar se a API de busca foi chamada e a listagem atualizou
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/school/search/Paulo%20Freire"),
      );
    });

    // Confere se o componente SchList renderizou a escola retornada
    await waitFor(() => {
      expect(
        screen.getByText("Escola Municipal Paulo Freire"),
      ).toBeInTheDocument();
    });

    // 5. Configurar o mock do modal antes do clique
    fetchSchoolScores.mockResolvedValue(mockScoresData);

    // 6. Simular o clique no botão de visualizar scores dentro da lista
    // (Nota: Ajuste o query/texto se o seu botão no SchList usar outro texto ou ícone)
    const btnVerScores = screen.getByRole("button", { name: /pontuação/i });
    await fireEvent.click(btnVerScores);

    // 7. Verificar se o modal abriu exibindo o estado de carregamento e depois os dados
    //expect(screen.getByText("Carregando scores...")).toBeInTheDocument();

    await waitFor(() => {
      expect(fetchSchoolScores).toHaveBeenCalledWith("112233");
      expect(screen.getByText("Scores da Escola")).toBeInTheDocument();
    });

    // 8. Validar se os dados finais do SchoolScores estão visíveis dentro do modal integrado
    expect(screen.getByText("Código: 112233 | Ano: 2026")).toBeInTheDocument();
  });
});
```


---

## 📁 src

### `src/vitest-setup.js`

```javascript
import "@testing-library/jest-dom/vitest";
```


---

## 📂 Raiz

### `svelte.config.js`

```javascript
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

/** @type {import("@sveltejs/vite-plugin-svelte").SvelteConfig} */
export default {
  // Consult https://svelte.dev/docs#compile-time-svelte-preprocess
  // for more information about preprocessors
  preprocess: vitePreprocess(),
}
```

### `vite.config.js`

```javascript
// vite.config.js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";

export default defineConfig(({ mode }) => {
  const isDev = mode === "development";

  return {
    plugins: [svelte(), svelteTesting()],

    // Vite configuration options
    resolve: process.env.VITEST
      ? {
          conditions: ["browser"],
        }
      : undefined,

    // Vitest configuration
    test: {
      environment: "jsdom", // Use 'happy-dom' if you prefer
      setupFiles: ["./src/vitest-setup.js"],
    },

    // -------------------------------------------------------
    // DEV SERVER CONFIG (somente quando rodando `npm run dev`)
    // -------------------------------------------------------
    server: {
      port: 5173,
      strictPort: true,
      open: false,
      allowedHosts: ["ubatexu.lan","molehill-swirl-repair.ngrok-free.dev"],

      // Todo request do frontend para /api é enviado ao Mojolicious
      proxy: {
        "/api": {
          target: "http://localhost:3000",
          changeOrigin: true,
          secure: false,
        },
        "/analytic-api": {
          target: "http://analytic:8000",
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/analytic-api/, ""),
        },
      },
    },

    // -------------------------------------------------------
    // BUILD DE PRODUÇÃO (usado por npm run build)
    // -------------------------------------------------------
    build: {
      sourcemap: true, // necessário para debug após build
      outDir: "dist",

      rollupOptions: {
        output: {
          entryFileNames: "[name].js",
          chunkFileNames: "[name].js",
          assetFileNames: ({ name }) => {
            if (name && name.endsWith(".css")) {
              return "[name].css";
            }
            return "[name][extname]";
          },
        },
      },
    },
  };
});
```

