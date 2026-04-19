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
