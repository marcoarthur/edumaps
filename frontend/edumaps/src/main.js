// src/main.js
import { mount } from "svelte";
import { eventBus, logger } from "@/shared/events";
import { initSentry } from "@/shared/sentry";
import { registerToastEventBridge } from "@/shared/stores/toastEventBridge.js";
import { startTelemetry } from "@/app/telemetry.js";
import { atualizador, instalarRecargaDeChunk } from "@/shared/pwa/atualizacao.js";
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

// Chunk antigo que não carrega (aba aberta antes de um deploy) → recarga
// única; se já recarregou há pouco, mostra o aviso em vez de entrar em laço.
instalarRecargaDeChunk({ aoFalhar: () => atualizador.mostrarErroChunk() });

// Service worker só no build de produção (o dev usa o Vite direto). O registro
// é manual (injectRegister: false) para o aviso de nova versão (#225).
if (import.meta.env.PROD && "serviceWorker" in navigator) {
  const registrar = () =>
    atualizador.registrar("/sw.js").catch((err) => {
      console.warn("[pwa] falha ao registrar o service worker", err);
    });
  if (document.readyState === "complete") registrar();
  else window.addEventListener("load", registrar, { once: true });
}

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