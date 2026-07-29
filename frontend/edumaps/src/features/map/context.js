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
        "Confira se o componente está dentro do slot correto.",
    );
  }
  return ctx;
}
