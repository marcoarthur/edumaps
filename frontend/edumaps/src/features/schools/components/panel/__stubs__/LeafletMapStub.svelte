<script>
  // Stub de LeafletMap para os testes do SchoolMap (#296, PR3).
  //
  // Diferente do stub de gestor/, este chama onMapReady com um mapa FALSO:
  // o SchoolMap precisa de um objeto de mapa para criar layerGroups e
  // polígonos. Como o componente desenha a isócrona, um stub sem mapa não
  // exercita o caminho da legenda + camada.
  import { onMount } from "svelte";

  let { onMapReady } = $props();

  // Mapa falso mínimo: o SchoolMap usa setView, fitBounds e L.layerGroup().
  // L.layerGroup é o Leaflet real (importado no componente), que aceita ser
  // adicionado a qualquer objeto — não precisamos reimplementá-lo aqui.
  const fakeMap = {
    setView() {},
    fitBounds() {},
    addLayer() {},
    remove() {},
  };

  onMount(() => {
    onMapReady?.(fakeMap);
  });
</script>

<div data-testid="leaflet-map-stub"></div>
