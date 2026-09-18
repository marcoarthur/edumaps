<script>
  // Stub de LeafletMap usado nos testes (evita Leaflet/jsdom).
  import { provideMapContext } from "@/features/map/context.js";

  provideMapContext({ map: null, ready: false });

  let { children } = $props();
</script>

<div data-testid="leaflet-map-stub">
  {@render children?.()}
</div>