Vou montar as configs e o componente unificado de mapa, organizados por feature. Uso Tailwind v4 (plugin nativo do Vite, sem `tailwind.config.js` — a config vira CSS via `@theme`, que é o padrão mais moderno hoje) e Svelte 5 com runes.

## 1. `package.json` (dependências relevantes)

```json
{
  "name": "edumaps",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite --host",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage"
  },
  "dependencies": {
    "@carbon/charts-svelte": "^1.22.18",
    "leaflet": "^1.9.4",
    "leaflet.markercluster": "^1.5.3",
    "svelte": "^5.0.0",
    "svelte-routing": "^2.13.0"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^4.0.0",
    "@tailwindcss/vite": "^4.0.0",
    "@testing-library/jest-dom": "^6.9.1",
    "@testing-library/svelte": "^5.2.9",
    "@testing-library/user-event": "^14.6.1",
    "@vitest/coverage-v8": "^2.1.0",
    "jsdom": "^27.2.0",
    "tailwindcss": "^4.0.0",
    "vite": "^6.0.0",
    "vite-plugin-pwa": "^0.21.0",
    "vitest": "^4.0.14"
  }
}
```

## 2. `vite.config.js`

```js
// vite.config.js
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { svelteTesting } from "@testing-library/svelte/vite";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import { fileURLToPath, URL } from "node:url";

export default defineConfig(({ mode }) => {
  const isDev = mode === "development";

  return {
    plugins: [
      tailwindcss(),
      svelte(),
      svelteTesting(),
      VitePWA({
        registerType: "autoUpdate",
        includeAssets: ["favicon.svg", "robots.txt"],
        manifest: {
          name: "EduMaps",
          short_name: "EduMaps",
          description: "Análise educacional, econômica e demográfica dos municípios brasileiros",
          theme_color: "#1e40af",
          background_color: "#f9fafb",
          display: "standalone",
          start_url: "/",
          icons: [
            { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
            { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
            { src: "/icons/icon-512-maskable.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
          ],
        },
        workbox: {
          // dados de API não devem ficar em cache "stale" por padrão
          runtimeCaching: [
            {
              urlPattern: /^\/api\//,
              handler: "NetworkFirst",
              options: { cacheName: "edumaps-api", expiration: { maxAgeSeconds: 300 } },
            },
          ],
        },
        devOptions: { enabled: false },
      }),
    ],

    resolve: {
      alias: {
        // aliases por feature, evita "../../../.." nos imports
        "@/features": fileURLToPath(new URL("./src/features", import.meta.url)),
        "@/shared": fileURLToPath(new URL("./src/shared", import.meta.url)),
        "@/app": fileURLToPath(new URL("./src/app", import.meta.url)),
      },
      conditions: process.env.VITEST ? ["browser"] : undefined,
    },

    test: {
      environment: "jsdom",
      setupFiles: ["./src/vitest-setup.js"],
      coverage: {
        provider: "v8",
        include: ["src/features/**/*.{js,svelte}"],
        exclude: ["**/*.test.js"],
      },
    },

    server: {
      port: 5173,
      strictPort: true,
      open: false,
      allowedHosts: ["ubatexu.lan", "molehill-swirl-repair.ngrok-free.dev"],
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

    build: {
      sourcemap: true,
      outDir: "dist",
      rollupOptions: {
        output: {
          // chunk por feature ajuda o nginx com cache de longo prazo por hash
          manualChunks(id) {
            if (id.includes("leaflet")) return "vendor-leaflet";
            if (id.includes("@carbon")) return "vendor-charts";
          },
        },
      },
    },
  };
});
```

## 3. `src/app.css` (Tailwind v4 — config via `@theme`)

```css
/* src/app.css */
@import "tailwindcss";

@theme {
  /* Paleta central — antes duplicada em dezenas de <style> inline */
  --color-brand-50: #eff6ff;
  --color-brand-600: #2563eb;
  --color-brand-700: #1e40af;

  --color-cluster-1: #10b981; /* Excelência */
  --color-cluster-2: #3b82f6; /* Alto desempenho */
  --color-cluster-3: #f59e0b; /* Médio desempenho */
  --color-cluster-4: #ef4444; /* Baixo desempenho */
  --color-cluster-5: #8b5cf6; /* Em declínio */
  --color-cluster-6: #06b6d4; /* Em ascensão */

  --radius-card: 0.75rem;
  --shadow-card: 0 1px 3px rgba(0, 0, 0, 0.1);
}

@layer base {
  body {
    @apply bg-gray-50 text-gray-900 antialiased;
  }
}

/* Leaflet precisa dessas overrides globais — mantido fora do @layer
   para não ser purgado e para vencer a especificidade do Leaflet */
.leaflet-container {
  font-family: inherit;
}
.leaflet-popup-content-wrapper {
  border-radius: 0.5rem;
}
```

## 4. Estrutura de pastas (feature-oriented)

```
src/
├── app/                          # bootstrap, rotas, layout raiz
│   ├── App.svelte
│   └── routes.js
├── features/
│   └── map/
│       ├── components/
│       │   └── LeafletMap.svelte
│       ├── context.js
│       ├── icons.js
│       └── index.js              # barrel export público da feature
├── shared/
│   ├── ui/
│   └── utils/
├── app.css
├── main.js
└── vitest-setup.js
```

A regra: **outras features (`schools`, `cities`, `siope`) nunca importam de dentro de `features/map/components/`** — só do `index.js`. Isso é o que impede o acoplamento que existia entre `AppMap.svelte`, `CityLayer.svelte`, `SchoolLayer.svelte` etc, todos enfiados soltos em `lib/`.

## 5. `src/features/map/context.js`

```js
// src/features/map/context.js
import { getContext, setContext } from "svelte";

const MAP_CONTEXT_KEY = Symbol("leaflet-map");

/**
 * Chamado pelo LeafletMap para publicar a instância do mapa
 * para qualquer layer filha (City, School, OSM, Cluster...).
 */
export function provideMapContext(mapState) {
  setContext(MAP_CONTEXT_KEY, mapState);
}

/**
 * Usado por qualquer layer/feature filha para acessar o mapa.
 * mapState.map     -> instância Leaflet atual (ou null)
 * mapState.ready   -> boolean reativo
 */
export function useMapContext() {
  const ctx = getContext(MAP_CONTEXT_KEY);
  if (!ctx) {
    throw new Error(
      "useMapContext() precisa ser chamado dentro de um <LeafletMap>. " +
        "Confira se o componente está dentro do slot correto."
    );
  }
  return ctx;
}
```

## 6. `src/features/map/components/LeafletMap.svelte`

```svelte
<script>
  // src/features/map/components/LeafletMap.svelte
  //
  // Substitui AppMap.svelte / BaseMap.svelte / AnalBaseMap.svelte / Map.svelte
  // do frontend antigo — todos faziam a mesma inicialização de Leaflet
  // com pequenas variações de estilo e tile layer.
  import { onMount, onDestroy } from "svelte";
  import L from "leaflet";
  import "leaflet/dist/leaflet.css";
  import { provideMapContext } from "../context.js";

  let {
    center = [-15.5, -55.0], // centro do Brasil por padrão
    zoom = 4,
    minZoom = 3,
    maxZoom = 19,
    tileUrl = "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
    attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/">CartoDB</a>',
    class: className = "",
    height = "100%",
    children,
    onMapReady,
  } = $props();

  let mapContainer;
  let map = $state(null);
  let ready = $state(false);

  // Objeto reativo único, publicado no contexto — todas as layers
  // filhas leem `mapState.map` e `mapState.ready`, sem precisar
  // de polling (`setInterval(checkMap, 50)`) como no código antigo.
  const mapState = $state({ map: null, ready: false });
  provideMapContext(mapState);

  onMount(() => {
    map = L.map(mapContainer, { minZoom, maxZoom }).setView(center, zoom);

    L.tileLayer(tileUrl, { attribution, minZoom, maxZoom }).addTo(map);

    ready = true;
    mapState.map = map;
    mapState.ready = true;

    onMapReady?.(map);
  });

  onDestroy(() => {
    map?.remove();
    mapState.map = null;
    mapState.ready = false;
  });

  // API pública exposta via bind:this — mantém compatibilidade
  // com o padrão usado no código antigo (baseMap.getMap(), fitBounds etc.)
  export function getMap() {
    return map;
  }

  export function fitBounds(bounds, options) {
    map?.fitBounds(bounds, options);
  }

  export function setView(lat, lng, newZoom = zoom) {
    map?.setView([lat, lng], newZoom);
  }

  export function invalidateSize() {
    // necessário quando o container muda de tamanho (ex: painel lateral abre/fecha)
    map?.invalidateSize();
  }
</script>

<div
  bind:this={mapContainer}
  class="relative z-0 w-full overflow-hidden rounded-card {className}"
  style:height
>
  {#if ready}
    {@render children?.()}
  {/if}
</div>
```

## 7. `src/features/map/index.js` (barrel — única porta de entrada da feature)

```js
// src/features/map/index.js
export { default as LeafletMap } from "./components/LeafletMap.svelte";
export { useMapContext } from "./context.js";
```

## 8. Exemplo de uso por outra feature (`schools`)

Isso mostra por que o context centralizado importa — a layer de escolas não sabe nada sobre como o mapa foi criado, só consome `useMapContext()`:

```svelte
<script>
  // src/features/schools/components/SchoolLayer.svelte
  import { useMapContext } from "@/features/map";
  import L from "leaflet";

  let { schoolData = null } = $props();
  const mapState = useMapContext();

  let layerGroup;

  $effect(() => {
    if (!mapState.ready || !schoolData) return;

    layerGroup?.remove();
    layerGroup = L.geoJSON(schoolData, {
      pointToLayer: (_, latlng) =>
        L.circleMarker(latlng, { radius: 6, fillColor: "#ff7800", fillOpacity: 0.8 }),
    }).addTo(mapState.map);

    return () => layerGroup?.remove();
  });
</script>
```

## 9. Teste do `LeafletMap` (padrão obrigatório por feature)

```js
// src/features/map/components/LeafletMap.test.js
import { render } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import LeafletMap from "./LeafletMap.svelte";

describe("LeafletMap", () => {
  it("renderiza o container do mapa", () => {
    const { container } = render(LeafletMap, { props: { center: [-23.56, -45.75], zoom: 12 } });
    expect(container.querySelector(".leaflet-container")).toBeInTheDocument();
  });

  it("expõe getMap() após montagem", async () => {
    const { component } = render(LeafletMap);
    await new Promise((r) => setTimeout(r, 0)); // aguarda onMount
    expect(component.getMap()).toBeTruthy();
  });
});
```

### Por que essa divisão

- **`features/map`** só sabe inicializar/expor o Leaflet — zero conhecimento sobre escolas, cidades ou SIOPE.
- Camadas de domínio (`features/schools/components/SchoolLayer.svelte`, `features/cities/components/CityLayer.svelte`) consomem `useMapContext()` e vivem cada uma na sua própria pasta de feature, com seus próprios `stores/`, `api/` e testes.
- Isso elimina os 4 componentes de mapa quase-duplicados do código antigo e o polling manual (`setInterval(checkMap, 50)`) que cada layer reimplementava para "esperar o mapa ficar pronto".

Quer que eu continue com a feature `schools` completa (layer + card + api client) ou prefere ver primeiro a feature `cities` (que tem o fluxo de autocomplete + modal, mais complexo)?
