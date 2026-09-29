// src/features/gestor/mocks/osmHandlers.js
// MSW handlers dos POIs OSM no Painel do Gestor (/api/gestor/:inep/osm/pois).
import { http, HttpResponse } from "msw";
import { OSM_POIS_STATUS_FIXTURE } from "./osmFixtures.js";

export const gestorOsmHandlers = [
  http.get("/api/gestor/:codInep/osm/pois", () => {
    return HttpResponse.json(OSM_POIS_STATUS_FIXTURE);
  }),

  http.post("/api/gestor/:codInep/osm/pois", () => {
    return HttpResponse.json(
      { task: "query_osm_school", job_id: 1, reused: false },
      { status: 202 },
    );
  }),
];
