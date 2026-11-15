// src/features/ranking-recorte/mocks/handlers.js
import { http, HttpResponse } from "msw";
import { REDES_FIXTURE, ESCOLAS_FIXTURE } from "./fixtures.js";

export const rankingRecorteHandlers = [
  http.get("*/api/ranking/redes", () => HttpResponse.json(REDES_FIXTURE)),
  http.get("*/api/ranking/escolas", () => HttpResponse.json(ESCOLAS_FIXTURE)),
];
