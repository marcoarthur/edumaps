// src/mocks/handlers.js
// Barrel: cada feature registra seus próprios handlers aqui.
import { schoolsHandlers } from "@/features/schools/mocks/handlers.js";
import { networkCompareHandlers } from "@/features/network-compare/mocks/handlers.js";
import { clusterGeotagHandlers } from "@/features/cluster-geotag/mocks/handlers.js";
import { gestorPesquisasHandlers } from "@/features/gestor/mocks/handlers.js";

export const handlers = [
  ...schoolsHandlers,
  ...networkCompareHandlers,
  ...clusterGeotagHandlers,
  ...gestorPesquisasHandlers,
];
