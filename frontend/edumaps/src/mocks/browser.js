// src/mocks/browser.js — usado apenas em desenvolvimento (npm run dev)
import { setupWorker } from "msw/browser";
import { handlers } from "./handlers.js";

export const worker = setupWorker(...handlers);
