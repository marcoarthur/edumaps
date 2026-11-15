// src/features/fontes/mocks/handlers.js
import { http, HttpResponse } from "msw";
import { FONTES_FIXTURE } from "./fixtures.js";

export const fontesHandlers = [
  http.get("*/api/fontes", () => HttpResponse.json(FONTES_FIXTURE)),
];
