// src/features/cluster-geotag/mocks/handlers.js
import { http, HttpResponse } from "msw";
import {
  REGIONS_FIXTURE,
  UFS_FIXTURE,
  MUNICIPALITIES_FIXTURE,
  CLUSTER_POLYGONS_FIXTURE,
  CLUSTER_SUMMARY_FIXTURE,
  FIXTURE_GEOTAG,
  PRESETS_FIXTURE,
  COLUMNS_FIXTURE,
  YEARS_FIXTURE,
} from "./fixtures.js";

// Um único job de clusterização "mágico": qualquer POST aceito, qualquer
// progress chega a finished e o GET de escolas devolve os polígonos.
export const clusterGeotagHandlers = [
  http.get("/api/cluster/regions", () => HttpResponse.json(REGIONS_FIXTURE)),

  http.get("/api/cluster/ufs", () => HttpResponse.json(UFS_FIXTURE)),

  http.get("/api/cluster/municipalities", () =>
    HttpResponse.json(MUNICIPALITIES_FIXTURE),
  ),

  http.get("/api/cluster/presets", () => HttpResponse.json(PRESETS_FIXTURE)),

  http.get("/api/cluster/columns", () => HttpResponse.json(COLUMNS_FIXTURE)),

  http.get("/api/cluster/years", () => HttpResponse.json(YEARS_FIXTURE)),

  http.get("/api/cluster/summary", () =>
    HttpResponse.json(CLUSTER_SUMMARY_FIXTURE),
  ),

  http.post("/api/task/cluster", () =>
    HttpResponse.json({ task: "cluster", job_id: 42 }, { status: 202 }),
  ),

  http.get("/api/task/progress", ({ request }) => {
    const url = new URL(request.url);
    if (url.searchParams.get("job_id") !== "42") {
      return HttpResponse.json({ error: "job não encontrado" }, { status: 404 });
    }
    return HttpResponse.json({ state: "finished", job_id: 42 });
  }),

  http.get("/api/cluster/schools", ({ request }) => {
    const url = new URL(request.url);
    const codigoRegiao = url.searchParams.get("codigo_regiao");
    const codigoUf = url.searchParams.get("codigo_uf");
    if (
      String(codigoRegiao) === String(FIXTURE_GEOTAG.codigo_regiao) &&
      String(codigoUf) === String(FIXTURE_GEOTAG.codigo_uf)
    ) {
      return HttpResponse.json(CLUSTER_POLYGONS_FIXTURE);
    }
    return HttpResponse.json(
      { error: "Nenhuma escola com cluster gerado para o recorte informado." },
      { status: 404 },
    );
  }),
];