// src/main.js
import { mount } from "svelte";
import { eventBus, logger } from "@/shared/events";
import { initSentry } from "@/shared/sentry";
import { registerToastEventBridge } from "@/shared/stores/toastEventBridge.js";
import { startTelemetry } from "@/app/telemetry.js";
import "./app.css";
import "@carbon/charts-svelte/styles.css";
import App from "./app/App.svelte";

async function enableMocking() {
  if (!import.meta.env.DEV) return;
  const { worker } = await import("./mocks/browser.js");
  // onUnhandledRequest: "bypass" deixa passar direto ao proxy real
  // qualquer rota que ainda não tenha handler mockado (ex: /api/school/search).
  return worker.start({ onUnhandledRequest: "bypass" });
}

//await enableMocking();

eventBus.use(logger);
registerToastEventBridge();
// Telemetria de sessão (etapa 2): liga o tracker no bus antes de montar o app,
// para capturar a navegação inicial e os primeiros eventos.
startTelemetry();

async function bootstrap() {
  // Sentry opcional: sem DSN retorna null e nada é inicializado.
  const Sentry = await initSentry();

  const options = { target: document.getElementById("app") };
  if (Sentry) {
    // Erros de componentes Svelte 5 (mount/update) também sobem ao Sentry.
    options.onerror = (details) => {
      const err =
        details && typeof details === "object" && "error" in details
          ? details.error
          : details;
      Sentry.captureException(err);
    };
  }

  const app = mount(App, options);
  if (import.meta.env.DEV) window.__edumapsApp = app;
}

bootstrap();