// src/mocks/handlers.js
// Barrel: cada feature registra seus próprios handlers aqui.
import { schoolsHandlers } from "@/features/schools/mocks/handlers.js";
import { networkCompareHandlers } from "@/features/network-compare/mocks/handlers.js";
import { clusterGeotagHandlers } from "@/features/cluster-geotag/mocks/handlers.js";
import { gestorPesquisasHandlers } from "@/features/gestor/mocks/handlers.js";
import { gestorReunioesHandlers } from "@/features/gestor/mocks/reunioesHandlers.js";
import { gestorInventarioHandlers } from "@/features/gestor/mocks/inventarioHandlers.js";
import { gestorRelacoesHandlers } from "@/features/gestor/mocks/relacoesHandlers.js";
import { gestorDocumentosHandlers } from "@/features/gestor/mocks/documentosHandlers.js";
import { gestorCanaisHandlers } from "@/features/gestor/mocks/canaisHandlers.js";
import { gestorEnviosHandlers } from "@/features/gestor/mocks/enviosHandlers.js";
import { gestorOsmHandlers } from "@/features/gestor/mocks/osmHandlers.js";
import { gestorInfluenciaHandlers } from "@/features/gestor/mocks/influenciaHandlers.js";
import { gestorRelatoriosHandlers } from "@/features/gestor/mocks/relatoriosHandlers.js";
import { configHandlers } from "@/features/config/mocks/configHandlers.js";
import { telemetryHandlers } from "@/features/admin/mocks/telemetryHandlers.js";
import { chatHandlers } from "@/features/chat/mocks/chatHandlers.js";

export const handlers = [
  ...schoolsHandlers,
  ...networkCompareHandlers,
  ...clusterGeotagHandlers,
  ...gestorPesquisasHandlers,
  ...gestorReunioesHandlers,
  ...gestorInventarioHandlers,
  ...gestorRelacoesHandlers,
  ...gestorDocumentosHandlers,
  ...gestorCanaisHandlers,
  ...gestorEnviosHandlers,
  ...gestorOsmHandlers,
  ...gestorInfluenciaHandlers,
  ...gestorRelatoriosHandlers,
  ...configHandlers,
  ...telemetryHandlers,
  ...chatHandlers,
];
