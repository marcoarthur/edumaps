// src/mocks/server.js — usado nos testes (Vitest / Node)
import { setupServer } from "msw/node";
import { handlers } from "./handlers.js";

export const server = setupServer(...handlers);
