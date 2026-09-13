# Visão geral boa do GPT

Esse documento é grande (218 páginas) e o que você está pedindo equivale praticamente ao início de um projeto greenfield. Há bastante contexto no PDF (árvore do projeto, problemas da arquitetura atual, objetivos da refatoração), mas escrever toda a arquitetura, justificar cada decisão e implementar os componentes completos (com testes) excede bastante o que cabe em uma única resposta.

Pelo que li do documento, o principal problema é que o frontend cresceu de forma incremental: o `App.svelte` virou roteador, o `AppMap.svelte` concentra praticamente toda a lógica da aplicação (requisições, SSE, estado, Leaflet, clusters, seleção, carregamento de escolas, OSM, etc.), o CSS está distribuído entre componentes e as features não possuem fronteiras claras.  

Na minha opinião, eu iria um passo além do plano do documento.

---

# Arquitetura proposta (Svelte 5)

Eu abandonaria a organização por tipo (`City`, `School`, `service`, `ui`...) e passaria para uma arquitetura baseada em Features.

```
src/

app/
    App.svelte
    router.js
    providers.js

core/

    api/
        client.js
        http.js

    leaflet/
        map.js
        popup.js

    stores/
        notification.js
        loading.js

    ui/
        Button.svelte
        Card.svelte
        Modal.svelte
        Spinner.svelte
        Input.svelte
        Badge.svelte
        Tabs.svelte

features/

    map/

        components/

            MapView.svelte
            MapToolbar.svelte
            LayerControl.svelte
            ProgressOverlay.svelte

        services/

            city.service.js
            osm.service.js

        stores/

            map.svelte.js

        tests/

            MapView.test.js
            LayerControl.test.js

    schools/

        components/

            SchoolSearch.svelte
            SchoolList.svelte
            SchoolCard.svelte
            SchoolDetails.svelte

        services/

            school.service.js

        stores/

            schools.svelte.js

        tests/

            SchoolSearch.test.js
            SchoolList.test.js

shared/

    components/
    icons/
    utils/

styles/
```

Observe que não existe mais um `SchoolLayer.svelte` perdido em `src/lib`.

Tudo relativo à feature Escola vive em `features/schools`.

---

# Decisão 1 — Stores usando Svelte 5

Ao invés de writable(), utilizar `$state`.

```
schools.svelte.js

class SchoolStore {

    schools = $state([]);

    selected = $state(null);

    loading = $state(false);

    search = $state("");

}

export const schoolStore = new SchoolStore();
```

Vantagens

* menos boilerplate
* reatividade natural
* testes muito mais simples

---

# Decisão 2 — Services isolados

Nenhum componente faz fetch.

Hoje o AppMap faz dezenas de fetch.

```
fetch("/api/schools")
```

Isso desaparece.

Passa a existir

```
school.service.js

export async function searchSchools(query){

...
}
```

Os componentes apenas chamam

```
await searchSchools(...)
```

---

# Decisão 3 — Componentes "burros"

MapView

não conhece API.

não conhece SSE.

não conhece banco.

Recebe

```
<MapView

    schools={...}

    city={...}

    clusters={...}

/>
```

Ele apenas desenha.

Isso reduz absurdamente a complexidade.

---

# Decisão 4 — Presenter

A lógica vai para um Presenter.

```
SchoolPresenter

↓

SchoolStore

↓

SchoolService

↓

API
```

O componente nunca conhece HTTP.

---

# Feature 1 — Busca de Escolas

```
┌────────────────────────────────────────────┐
│ Buscar escola...                           │
├────────────────────────────────────────────┤
│ filtros                                   │
├────────────────────────────────────────────┤
│ Escola A                                  │
│ Escola B                                  │
│ Escola C                                  │
│ Escola D                                  │
│ Escola E                                  │
└────────────────────────────────────────────┘
```

Cada item

```
SchoolCard
```

é independente.

```
SchoolList

    ├── SchoolCard

    ├── SchoolCard

    ├── SchoolCard
```

---

# Feature 2 — Mapa

```
+---------------------------------------------------+

 Toolbar

-----------------------------------------------

            Leaflet

-----------------------------------------------

 Layers

 Scale

 Zoom

 Cluster

---------------------------------------------------

 Status Bar

```

Separado em

```
MapView

MapToolbar

LayerSelector

StatusBar

ProgressOverlay
```

Nenhum possui mais de 250 linhas.

---

# Testes

Eu adotaria Vitest + Testing Library.

```
tests/

MapView.test.js

SchoolSearch.test.js

SchoolCard.test.js

SchoolList.test.js

LayerControl.test.js

Toolbar.test.js
```

Cobertura

```
Services

95%

Stores

100%

UI

90%

```

---

# Exemplo de teste

```
describe("SchoolSearch", () => {

    it("calls search service", async () => {

        render(SchoolSearch);

        await user.type(

            screen.getByRole("textbox"),

            "ubatuba"

        );

        await user.click(

            screen.getByRole("button")

        );

        expect(searchSchools)

            .toHaveBeenCalled();

    });

});
```

---

# Design System

Também substituiria o CSS atual por tokens.

```
styles/

tokens.css

spacing.css

colors.css

typography.css

components.css
```

Exemplo

```
--color-primary

--color-surface

--radius-md

--space-4

--shadow-lg
```

Isso elimina centenas de regras duplicadas existentes hoje.

---

## O que eu implementaria primeiro

Eu dividiria a reescrita em etapas para manter o projeto sempre executável:

1. **Infraestrutura**: Vite + Svelte 5, roteamento, layout, design system, cliente HTTP e configuração de testes.
2. **Feature Busca de Escolas**: stores, serviços, componentes (`SchoolSearch`, `SchoolList`, `SchoolCard`, `SchoolDetails`) e testes.
3. **Feature Mapa**: `MapView`, `MapToolbar`, controle de camadas, integração Leaflet, clusters e testes.
4. **Integração**: SSE, OSM, detalhes do município e demais funcionalidades existentes.
5. **Migração incremental**: substituir gradualmente os componentes antigos pelos novos, reduzindo risco.

Eu faria essa reescrita como se fosse um framework interno do EduMaps, priorizando componentes pequenos, stores reativas do Svelte 5, separação rígida entre UI e lógica de negócio e cobertura de testes desde o primeiro componente. Isso produz uma base muito mais sustentável do que tentar evoluir a estrutura atual, onde um único componente (`AppMap.svelte`) concentra responsabilidades de roteamento, estado, comunicação com APIs, SSE, renderização e coordenação de diversas features. 
# Plano de Refatoração do Frontend - EduMaps

Com base na análise detalhada do código existente, apresento um plano completo para reescrever o frontend do zero, seguindo os requisitos estabelecidos.

---


## 📋 Sumário

1. [Análise do Estado Atual](#-análise-do-estado-atual)
2. [Arquitetura do Novo Frontend](#-arquitetura-do-novo-frontend)
3. [Estrutura de Diretórios](#-estrutura-de-diretórios)
4. [Configuração do Projeto](#-configuração-do-projeto)
5. [Migração por Componentes](#-migração-por-componentes)
6. [Exemplos de Implementação](#-exemplos-de-implementação)
7. [Plano de Migração](#-plano-de-migração)
8. [Checklist de Qualidade](#-checklist-de-qualidade)

---

## 🔍 Análise do Estado Atual

### Problemas Identificados no `map_app`

1. **Roteamento Ad-hoc**: Roteamento manual no `App.svelte` usando `window.location.pathname`
2. **Estilos Não Centralizados**: CSS espalhado por componentes, sem consistência
3. **Sem PWA/Service Worker**: Aplicação não é instalável nem funciona offline
4. **Stores Antigas**: Usa `writable` do Svelte 4, não aproveita runes
5. **Svelte 4**: Não utiliza as novas runes (`$state`, `$derived`, `$effect`)
6. **Componentes Monolíticos**: `AppMap.svelte` tem centenas de linhas com lógica misturada
7. **Sem Testes Robusto**: Testes existentes são limitados
8. **Integração Frágil**: Chamadas API espalhadas pelos componentes
9. **Sem Gerenciamento de Estado Global**: Múltiplas stores não coordenadas

---

## 🏗️ Arquitetura do Novo Frontend

### Stack Tecnológico

| Camada | Tecnologia | Motivação |
|--------|------------|-----------|
| Framework | **SvelteKit 5** | Roteamento nativo, SSR/CSR híbrido, runes |
| Build Tool | **Vite** | Performance, HMR rápido |
| Estilização | **Tailwind CSS** | Estilos utilitários, consistência, responsividade |
| PWA | **@vite-pwa/sveltekit** | Service worker, manifest, cache offline |
| API Client | **Fetch API + Services** | Centralização, testes, tipagem (JSDoc) |
| Testes | **Vitest + Testing Library** | Unitários, integração, E2E |
| Mapas | **Leaflet** | Mantido (funciona bem com Svelte) |

### Padrões de Design

1. **File-based Routing**: Cada página é um arquivo `.svelte` em `src/routes/`
2. **Store com Runes**: Estado global usando `$state` e `$derived`
3. **Composição de Componentes**: Componentes pequenos e reutilizáveis
4. **Services Layer**: Toda lógica de API em arquivos separados
5. **Tailwind Utility-first**: Estilos consistentes com classes utilitárias
6. **PWA Progressivo**: Funcionalidade offline, cache de tiles de mapa

---

## 📁 Estrutura de Diretórios

```
frontend/edumaps/
├── src/
│   ├── app.html
│   ├── app.css
│   ├── app.d.ts
│   ├── routes/
│   │   ├── +layout.svelte          # Layout principal com mapa
│   │   ├── +layout.server.js       # Dados iniciais
│   │   ├── +page.svelte            # Home (mapa principal)
│   │   ├── escola/
│   │   │   └── [id]/
│   │   │       └── +page.svelte    # Detalhe da escola
│   │   ├── cidade/
│   │   │   └── [id]/
│   │   │       └── +page.svelte    # Detalhe da cidade
│   │   └── analise/                # Análise municipal
│   │       └── +page.svelte
│   ├── lib/
│   │   ├── components/
│   │   │   ├── ui/
│   │   │   │   ├── Button.svelte
│   │   │   │   ├── Input.svelte
│   │   │   │   ├── Modal.svelte
│   │   │   │   ├── Spinner.svelte
│   │   │   │   └── Table.svelte
│   │   │   ├── map/
│   │   │   │   ├── Map.svelte
│   │   │   │   ├── MapControls.svelte
│   │   │   │   ├── CityLayer.svelte
│   │   │   │   ├── SchoolLayer.svelte
│   │   │   │   ├── ClusterLayer.svelte
│   │   │   │   └── Popup/
│   │   │   │       ├── CityPopup.svelte
│   │   │   │       └── SchoolPopup.svelte
│   │   │   ├── city/
│   │   │   │   ├── CitySelector.svelte
│   │   │   │   ├── CityDetail.svelte
│   │   │   │   └── CityAnalytics.svelte
│   │   │   ├── school/
│   │   │   │   ├── SchoolList.svelte
│   │   │   │   ├── SchoolCard.svelte
│   │   │   │   ├── SchoolSearch.svelte
│   │   │   │   ├── SchoolGrades.svelte
│   │   │   │   └── SchoolPayroll.svelte
│   │   │   └── shared/
│   │   │       ├── Navbar.svelte
│   │   │       ├── Footer.svelte
│   │   │       └── Container.svelte
│   │   ├── stores/
│   │   │   ├── mapStore.js      # Estado do mapa (runes)
│   │   │   ├── schoolStore.js   # Escolas selecionadas
│   │   │   ├── cityStore.js     # Cidade atual
│   │   │   └── uiStore.js       # UI state (loading, modals)
│   │   ├── services/
│   │   │   ├── api.js           # Cliente HTTP base
│   │   │   ├── schoolService.js
│   │   │   ├── cityService.js
│   │   │   ├── clusterService.js
│   │   │   └── siopeService.js
│   │   ├── types/               # JSDoc type definitions
│   │   │   ├── school.js
│   │   │   └── city.js
│   │   └── utils/
│   │       ├── formatters.js    # Formatação de números/datas
│   │       ├── geoUtils.js      # Utilitários Leaflet
│   │       └── validators.js
│   └── service-worker/
│       └── sw.js                # Service worker customizado
├── static/
│   ├── favicon.ico
│   ├── manifest.json
│   ├── pwa-192x192.png
│   └── pwa-512x512.png
├── tests/
│   ├── unit/
│   │   ├── services/
│   │   └── components/
│   └── integration/
│       └── pages/
├── package.json
├── svelte.config.js
├── vite.config.js
├── tailwind.config.js
├── postcss.config.js
├── jsconfig.json
└── .env
```

---

## ⚙️ Configuração do Projeto

### 1. Criar Projeto com `sv`

```bash
npx sv create edumaps
# Escolha: SvelteKit minimal
# TypeScript: No (usaremos JSDoc)
# ESLint: Yes
# Prettier: Yes
# Vitest: Yes
```

### 2. Instalar Dependências

```bash
cd edumaps
npm install

# Tailwind CSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# PWA
npm install -D @vite-pwa/sveltekit

# Leaflet
npm install leaflet
npm install -D @types/leaflet  # apenas para JSDoc

# Testes
npm install -D @testing-library/svelte @testing-library/jest-dom jsdom

# Utilidades
npm install -D @tailwindcss/forms @tailwindcss/typography
```

### 3. Configurar Tailwind (`tailwind.config.js`)

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
        }
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ]
}
```

### 4. Configurar PWA (`vite.config.js`)

```javascript
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';

export default defineConfig({
  plugins: [
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png', 'maskable-icon.png'],
      manifest: {
        name: 'EduMaps',
        short_name: 'EduMaps',
        description: 'Mapa educacional brasileiro',
        theme_color: '#3b82f6',
        background_color: '#ffffff',
        display: 'standalone',
        icons: [
          {
            src: 'pwa-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any maskable'
          },
          {
            src: 'pwa-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any maskable'
          }
        ]
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg,woff2}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/{s}\.tile\.openstreetmap\.org\/.*/,
            handler: 'CacheFirst',
            options: {
              cacheName: 'leaflet-tiles',
              expiration: { maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 * 7 }
            }
          },
          {
            urlPattern: /^\/api\/.*/,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              expiration: { maxEntries: 50, maxAgeSeconds: 60 * 60 }
            }
          }
        ]
      }
    })
  ],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      }
    }
  }
});
```

### 5. Configurar `svelte.config.js`

```javascript
import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/kit/vite';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: 'index.html'  // SPA mode
    }),
    alias: {
      '$lib': './src/lib',
      '$components': './src/lib/components',
      '$stores': './src/lib/stores',
      '$services': './src/lib/services',
      '$utils': './src/lib/utils'
    }
  }
};

export default config;
```

---

## 🔄 Migração por Componentes

### Prioridade de Migração

1. **Fase 1: Infraestrutura** (Semana 1)
   - Configuração do projeto
   - Stores com runes
   - Services (API clients)
   - Utilitários

2. **Fase 2: Core UI** (Semana 2)
   - Componentes UI base (Button, Input, Modal, Spinner, Table)
   - Layout principal (Navbar, Footer, Container)
   - Roteamento básico

3. **Fase 3: Mapa** (Semana 3)
   - Componente Map com Leaflet
   - Camadas (CityLayer, SchoolLayer, ClusterLayer)
   - Popups
   - Controles do mapa

4. **Fase 4: Funcionalidades** (Semana 4)
   - Busca de escolas
   - Detalhe de escola
   - Detalhe de cidade
   - Análise municipal
   - SIOPE (payroll)

5. **Fase 5: Polimento** (Semana 5)
   - PWA completo
   - Testes
   - Performance
   - Acessibilidade
   - Responsividade

### Mapeamento Componentes Antigo → Novo

| Componente Antigo | Componente Novo | Observações |
|-------------------|-----------------|-------------|
| `App.svelte` | `routes/+layout.svelte` + `routes/+page.svelte` | Roteamento nativo |
| `AppMap.svelte` | `components/map/Map.svelte` | Lógica extraída para stores |
| `School/SearchForm.svelte` | `components/school/SchoolSearch.svelte` | Refatorar com runes |
| `School/SchList.svelte` | `components/school/SchoolList.svelte` | + Paginação melhorada |
| `School/SchoolScores.svelte` | `components/school/SchoolScores.svelte` | + tests |
| `City/CitySelector.svelte` | `components/city/CitySelector.svelte` | Extrair lógica de mapa |
| `School/SearchSchoolPage.svelte` | `routes/busca/+page.svelte` | Rota dedicada |
| `City/MunicipiosMapa.svelte` | `routes/analise/+page.svelte` | Rota dedicada |
| `School/GradesModal.svelte` | `components/school/SchoolGrades.svelte` | Simples refatoração |
| `School/PayrollModal.svelte` | `components/school/SchoolPayroll.svelte` | + cache |
| `School/ClusterLayer.svelte` | `components/map/ClusterLayer.svelte` | Manter, adaptar |
| `School/ClusterLegend.svelte` | `components/map/ClusterLegend.svelte` | Manter, adaptar |
| `Map/MarkerCluster.svelte` | `components/map/MarkerCluster.svelte` | Manter, adaptar |

---

## 💻 Exemplos de Implementação

### 1. Store com Runes (`src/lib/stores/mapStore.js`)

```javascript
/**
 * @typedef {import('leaflet').Map} LeafletMap
 */

// Store do mapa usando runes
export function createMapStore() {
  /** @type {LeafletMap | null} */
  let mapInstance = $state(null);
  let center = $state([-15.7939, -47.8828]);
  let zoom = $state(4);
  let bounds = $state(null);
  let loading = $state(false);
  let error = $state(null);

  return {
    get map() { return mapInstance; },
    set map(value) { mapInstance = value; },
    
    get center() { return center; },
    set center(value) { center = value; },
    
    get zoom() { return zoom; },
    set zoom(value) { zoom = value; },
    
    get bounds() { return bounds; },
    set bounds(value) { bounds = value; },
    
    get loading() { return loading; },
    set loading(value) { loading = value; },
    
    get error() { return error; },
    set error(value) { error = value; },

    // Ações
    flyTo(lat, lng, z) {
      if (mapInstance) {
        mapInstance.flyTo([lat, lng], z ?? zoom);
      }
    },

    fitBounds(bounds, options = {}) {
      if (mapInstance) {
        mapInstance.fitBounds(bounds, options);
      }
    },

    invalidateSize() {
      if (mapInstance) {
        setTimeout(() => mapInstance.invalidateSize(), 100);
      }
    }
  };
}

export const mapStore = createMapStore();
```

### 2. Service com JSDoc (`src/lib/services/api.js`)

```javascript
/**
 * Cliente HTTP base para comunicação com a API
 * @module services/api
 */

const BASE_URL = import.meta.env.VITE_API_URL || '/api';

/**
 * @typedef {Object} ApiResponse
 * @property {boolean} ok
 * @property {number} status
 * @property {any} data
 * @property {string} [error]
 */

/**
 * Faz uma requisição GET para a API
 * @param {string} endpoint - Endpoint da API
 * @param {object} [params] - Parâmetros de query string
 * @returns {Promise<ApiResponse>}
 */
export async function get(endpoint, params = {}) {
  const url = new URL(`${BASE_URL}${endpoint}`);
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null) {
      url.searchParams.append(key, value);
    }
  });

  try {
    const response = await fetch(url);
    const data = await response.json();
    
    return {
      ok: response.ok,
      status: response.status,
      data,
      error: response.ok ? undefined : data.error || data.message
    };
  } catch (error) {
    return {
      ok: false,
      status: 500,
      data: null,
      error: error.message || 'Erro de conexão'
    };
  }
}

/**
 * Faz uma requisição POST para a API
 * @param {string} endpoint - Endpoint da API
 * @param {any} body - Corpo da requisição
 * @returns {Promise<ApiResponse>}
 */
export async function post(endpoint, body) {
  try {
    const response = await fetch(`${BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    const data = await response.json();
    
    return {
      ok: response.ok,
      status: response.status,
      data,
      error: response.ok ? undefined : data.error || data.message
    };
  } catch (error) {
    return {
      ok: false,
      status: 500,
      data: null,
      error: error.message || 'Erro de conexão'
    };
  }
}
```

### 3. Service de Escolas (`src/lib/services/schoolService.js`)

```javascript
/**
 * @module services/schoolService
 */

import { get, post } from './api.js';

/**
 * Busca escolas por nome ou cidade
 * @param {Object} params
 * @param {string} [params.nome] - Nome da escola
 * @param {string} [params.cidade] - Nome da cidade
 * @param {number} [params.limit=50] - Limite de resultados
 * @returns {Promise<Array>} Lista de escolas
 */
export async function searchSchools({ nome, cidade, limit = 50 }) {
  const params = {};
  if (nome) params.nome = nome;
  if (cidade) params.cidade = cidade;
  params.limit = limit;

  const response = await get('/school/search', params);
  
  if (!response.ok) {
    throw new Error(response.error || 'Erro ao buscar escolas');
  }

  return response.data;
}

/**
 * Busca detalhes de uma escola por ID
 * @param {string|number} id - Código INEP da escola
 * @returns {Promise<Object>} Dados da escola
 */
export async function getSchoolById(id) {
  const response = await get(`/school/${id}`);
  
  if (!response.ok) {
    throw new Error(response.error || 'Escola não encontrada');
  }

  return response.data;
}

/**
 * Busca scores de uma escola
 * @param {string|number} id - Código INEP da escola
 * @returns {Promise<Object>} Scores da escola
 */
export async function getSchoolScores(id) {
  const response = await get('/school/scores', { id });
  
  if (!response.ok) {
    throw new Error(response.error || 'Scores não disponíveis');
  }

  return response.data;
}

/**
 * Busca escolas clusterizadas por cidade
 * @param {string} city - Nome da cidade
 * @param {number[]} [clusterIds] - IDs dos clusters
 * @returns {Promise<Array>} Dados clusterizados
 */
export async function getClusteredSchools(city, clusterIds = null) {
  const params = { city };
  if (clusterIds?.length) {
    params.clusters = clusterIds.join(',');
  }

  const response = await get('/schools/clustered', params);
  
  if (!response.ok) {
    throw new Error(response.error || 'Erro ao carregar clusters');
  }

  return response.data;
}
```

### 4. Componente de Mapa com Runes (`src/lib/components/map/Map.svelte`)

```svelte
<script>
  import { onMount, onDestroy } from 'svelte';
  import { mapStore } from '$stores/mapStore';
  import L from 'leaflet';
  import 'leaflet/dist/leaflet.css';

  // Estados reativos
  let container = $state(null);
  let isReady = $state(false);
  let tileLayer = $state(null);

  // Valores derivados
  $derived({
    center: mapStore.center,
    zoom: mapStore.zoom
  });

  onMount(() => {
    if (!container) return;

    // Inicializa o mapa
    const map = L.map(container, {
      center: mapStore.center,
      zoom: mapStore.zoom,
      zoomControl: false,
      attributionControl: true
    });

    // Tile layer OSM
    tileLayer = L.tileLayer(
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19
      }
    ).addTo(map);

    // Guarda a instância na store
    mapStore.map = map;

    // Eventos
    map.on('moveend', () => {
      const center = map.getCenter();
      mapStore.center = [center.lat, center.lng];
      mapStore.zoom = map.getZoom();
      mapStore.bounds = map.getBounds();
    });

    isReady = true;

    // Cleanup
    return () => {
      tileLayer?.remove();
      map.remove();
      mapStore.map = null;
      isReady = false;
    };
  });

  // Atualiza view quando center/zoom mudarem externamente
  $effect(() => {
    const map = mapStore.map;
    if (!map || !isReady) return;
    
    const currentCenter = map.getCenter();
    const currentZoom = map.getZoom();
    
    const centerChanged = currentCenter.lat !== mapStore.center[0] ||
                         currentCenter.lng !== mapStore.center[1];
    const zoomChanged = currentZoom !== mapStore.zoom;

    if (centerChanged || zoomChanged) {
      map.setView(mapStore.center, mapStore.zoom);
    }
  });
</script>

<div
  bind:this={container}
  class="w-full h-full min-h-[500px] rounded-lg overflow-hidden relative z-0"
>
  {#if isReady}
    <slot />
  {/if}
</div>

<!-- Estilos globais para Leaflet -->
<style>
  :global(.leaflet-container) {
    height: 100%;
    width: 100%;
    font-family: system-ui, sans-serif;
  }
  
  :global(.leaflet-popup-content-wrapper) {
    border-radius: 0.75rem;
    box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1);
  }
  
  :global(.leaflet-control-zoom) {
    border: none !important;
    box-shadow: 0 2px 8px rgb(0 0 0 / 0.15);
  }
  
  :global(.leaflet-control-zoom a) {
    width: 36px !important;
    height: 36px !important;
    line-height: 36px !important;
    background: white !important;
  }
  
  :global(.leaflet-control-zoom a:hover) {
    background: #f3f4f6 !important;
  }
</style>
```

### 5. Componente de Busca com Runes (`src/lib/components/school/SchoolSearch.svelte`)

```svelte
<script>
  import { debounce } from '$utils/debounce.js';
  import { schoolStore } from '$stores/schoolStore.js';
  import { getSchoolScores } from '$services/schoolService.js';

  // Estados com runes
  let nome = $state('');
  let cidade = $state('');
  let loading = $state(false);
  let error = $state(null);
  let results = $state([]);

  // Reação a mudanças na busca
  const performSearch = $effect(() => {
    const query = { nome: nome.trim(), cidade: cidade.trim() };
    
    // Não busca se ambos estiverem vazios
    if (!query.nome && !query.cidade) {
      results = [];
      return;
    }

    // Busca com debounce
    const searchFn = debounce(async () => {
      loading = true;
      error = null;
      
      try {
        const data = await searchSchools(query);
        results = data;
        schoolStore.setResults(data);
      } catch (err) {
        error = err.message;
        results = [];
      } finally {
        loading = false;
      }
    }, 300);

    searchFn();
  });

  // Limpa a busca
  function clearSearch() {
    nome = '';
    cidade = '';
    results = [];
    error = null;
    schoolStore.clearResults();
  }

  // Seleciona uma escola
  function selectSchool(school) {
    schoolStore.setSelected(school);
    // Navega para detalhe
    goto(`/escola/${school.codigo_inep}`);
  }
</script>

<div class="space-y-4">
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div>
      <label for="nome-escola" class="block text-sm font-medium text-gray-700">
        Nome da Escola
      </label>
      <input
        id="nome-escola"
        type="text"
        bind:value={nome}
        placeholder="Ex: Maria, São José"
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        disabled={loading}
      />
    </div>
    <div>
      <label for="cidade" class="block text-sm font-medium text-gray-700">
        Cidade
      </label>
      <input
        id="cidade"
        type="text"
        bind:value={cidade}
        placeholder="Ex: Ubatuba, São Paulo"
        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
        disabled={loading}
      />
    </div>
  </div>

  {#if loading}
    <div class="flex items-center justify-center py-8">
      <Spinner size="md" />
      <span class="ml-3 text-gray-500">Buscando escolas...</span>
    </div>
  {/if}

  {#if error}
    <div class="rounded-md bg-red-50 p-4">
      <p class="text-sm text-red-700">{error}</p>
    </div>
  {/if}

  {#if results.length > 0}
    <div class="bg-white rounded-lg shadow overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Escola
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Cidade/UF
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Tipo
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
              Ações
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each results as school (school.codigo_inep)}
            <tr class="hover:bg-gray-50 cursor-pointer" on:click={() => selectSchool(school)}>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-gray-900">{school.escola}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-500">{school.municipio} - {school.uf}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                  {school.tipo || 'N/A'}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button
                  on:click|stopPropagation={() => selectSchool(school)}
                  class="text-primary-600 hover:text-primary-900"
                >
                  Ver detalhes
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {:else if nome || cidade}
    <div class="text-center py-8 text-gray-500">
      <p>Nenhuma escola encontrada</p>
      <p class="text-sm">Tente ajustar os termos da busca</p>
    </div>
  {/if}
</div>
```

### 6. Teste Unitário com Vitest (`tests/unit/services/schoolService.test.js`)

```javascript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { searchSchools, getSchoolById, getSchoolScores } from '$services/schoolService';
import * as api from '$services/api';

// Mock do módulo api
vi.mock('$services/api', () => ({
  get: vi.fn(),
  post: vi.fn()
}));

describe('School Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('searchSchools', () => {
    it('deve buscar escolas com parâmetros', async () => {
      const mockData = [
        { codigo_inep: '123', escola: 'Escola Teste', municipio: 'Ubatuba', uf: 'SP' }
      ];
      
      api.get.mockResolvedValue({ ok: true, data: mockData });

      const result = await searchSchools({ nome: 'Teste', cidade: 'Ubatuba', limit: 10 });

      expect(api.get).toHaveBeenCalledWith('/school/search', {
        nome: 'Teste',
        cidade: 'Ubatuba',
        limit: 10
      });
      expect(result).toEqual(mockData);
    });

    it('deve lançar erro quando a API falha', async () => {
      api.get.mockResolvedValue({ 
        ok: false, 
        error: 'Erro na busca',
        data: null 
      });

      await expect(searchSchools({ nome: 'Teste' }))
        .rejects
        .toThrow('Erro na busca');
    });
  });

  describe('getSchoolById', () => {
    it('deve buscar escola por ID', async () => {
      const mockData = { codigo_inep: '123', escola: 'Escola Teste' };
      api.get.mockResolvedValue({ ok: true, data: mockData });

      const result = await getSchoolById('123');

      expect(api.get).toHaveBeenCalledWith('/school/123');
      expect(result).toEqual(mockData);
    });
  });

  describe('getSchoolScores', () => {
    it('deve buscar scores da escola', async () => {
      const mockData = { 
        co_entidade: '123',
        score_infraestrutura: '8.5',
        score_capacidade_atendimento: '7.2'
      };
      api.get.mockResolvedValue({ ok: true, data: mockData });

      const result = await getSchoolScores('123');

      expect(api.get).toHaveBeenCalledWith('/school/scores', { id: '123' });
      expect(result).toEqual(mockData);
    });
  });
});
```

### 7. Teste de Componente (`tests/unit/components/SchoolSearch.test.js`)

```javascript
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import SchoolSearch from '$components/school/SchoolSearch.svelte';
import * as schoolService from '$services/schoolService';

vi.mock('$services/schoolService');

describe('SchoolSearch', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('deve renderizar os campos de busca', () => {
    render(SchoolSearch);
    
    expect(screen.getByLabelText(/Nome da Escola/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Cidade/i)).toBeInTheDocument();
  });

  it('deve buscar escolas ao digitar', async () => {
    const mockResults = [
      { codigo_inep: '123', escola: 'Escola Teste', municipio: 'Ubatuba', uf: 'SP' }
    ];
    
    schoolService.searchSchools.mockResolvedValue(mockResults);

    render(SchoolSearch);

    const input = screen.getByLabelText(/Nome da Escola/i);
    await fireEvent.input(input, { target: { value: 'Teste' } });

    await waitFor(() => {
      expect(schoolService.searchSchools).toHaveBeenCalledWith({
        nome: 'Teste',
        cidade: ''
      });
    });

    await waitFor(() => {
      expect(screen.getByText('Escola Teste')).toBeInTheDocument();
    });
  });

  it('deve mostrar mensagem de erro quando a busca falha', async () => {
    schoolService.searchSchools.mockRejectedValue(new Error('Erro de rede'));

    render(SchoolSearch);

    const input = screen.getByLabelText(/Nome da Escola/i);
    await fireEvent.input(input, { target: { value: 'Teste' } });

    await waitFor(() => {
      expect(screen.getByText('Erro de rede')).toBeInTheDocument();
    });
  });
});
```

---

## 📋 Plano de Migração

### Semana 1: Infraestrutura

```bash
# Configuração do projeto
mkdir frontend/edumaps
cd frontend/edumaps
npx sv create . --template minimal --no-typescript
npm install

# Dependências
npm install -D tailwindcss postcss autoprefixer @tailwindcss/forms
npm install -D @vite-pwa/sveltekit
npm install leaflet
npm install -D @testing-library/svelte @testing-library/jest-dom jsdom

# Configuração
npx tailwindcss init -p
```

### Semana 2: Core

- [ ] Configurar Tailwind
- [ ] Configurar PWA
- [ ] Criar stores com runes
- [ ] Criar services (API, school, city)
- [ ] Criar utils (formatters, geo)
- [ ] Configurar testes

### Semana 3: Mapa

- [ ] Componente Map
- [ ] CityLayer
- [ ] SchoolLayer
- [ ] ClusterLayer
- [ ] Popups (City, School)
- [ ] MapControls
- [ ] Testes do mapa

### Semana 4: Funcionalidades

- [ ] Página de busca (`/busca`)
- [ ] Página de análise municipal (`/analise`)
- [ ] Detalhe de escola (`/escola/[id]`)
- [ ] Detalhe de cidade (`/cidade/[id]`)
- [ ] Modais (grades, payroll, scores)
- [ ] SIOPE integration
- [ ] Testes de integração

### Semana 5: Polimento

- [ ] PWA completo (manifest, service worker)
- [ ] Cache de tiles
- [ ] Acessibilidade (ARIA, keyboard navigation)
- [ ] Responsividade (mobile-first)
- [ ] Performance (lazy loading, code splitting)
- [ ] Testes E2E (Playwright)
- [ ] Documentação

---

## ✅ Checklist de Qualidade

### Código
- [ ] Componentes < 300 linhas
- [ ] 80%+ cobertura de testes
- [ ] JSDoc em todas as funções públicas
- [ ] Nomes descritivos (não abreviados)
- [ ] Sem console.log em produção

### UX/UI
- [ ] 100% responsivo (mobile, tablet, desktop)
- [ ] Loading states em todas as ações
- [ ] Feedback visual para erros
- [ ] Acessibilidade (WCAG 2.1 AA)
- [ ] Temas claro/escuro (se aplicável)

### Performance
- [ ] Lighthouse score > 90 (mobile e desktop)
- [ ] Bundle size < 200KB (gzip)
- [ ] Lazy loading de componentes pesados
- [ ] Cache de tiles de mapa
- [ ] PWA instalável

### Manutenção
- [ ] Git hooks (pre-commit, pre-push)
- [ ] CI/CD (GitHub Actions)
- [ ] Documentação no README
- [ ] Scripts de build otimizados
- [ ] Logging de erros (Sentry)

---

## 🔗 Referências

- [SvelteKit Docs](https://svelte.dev/docs/kit)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Leaflet with Svelte](https://github.com/leaflet/leaflet)
- [PWA with SvelteKit](https://kit.svelte.dev/docs/service-workers)
- [Vitest Testing](https://vitest.dev/)
- [Testing Library Svelte](https://testing-library.com/docs/svelte-testing-library/intro)

---

## 📊 Comparativo: Antes vs Depois

| Aspecto | Antes (map_app) | Depois (edumaps) |
|---------|-----------------|------------------|
| Roteamento | Manual (window.location) | File-based (SvelteKit) |
| Estilos | CSS espalhado | Tailwind centralizado |
| PWA | Não | Sim (instalável, offline) |
| State | Svelte 4 stores | Runes ($state, $derived) |
| Testes | Limitado | Unitários + Integração + E2E |
| API | Espalhada | Services centralizados |
| Componentes | Monolíticos | Pequenos e reutilizáveis |
| Responsividade | Limitada | Mobile-first (Tailwind) |
| Build | Vite básico | Vite + PWA + otimizações |

---

**Próximo passo**: Começar pela Semana 1 (Infraestrutura). O código antigo (`map_app`) será mantido como referência até que o novo frontend esteja completo e testado.

Posso ajudar com qualquer parte específica deste plano, seja na configuração inicial, na implementação de um componente específico, ou na criação de testes.


