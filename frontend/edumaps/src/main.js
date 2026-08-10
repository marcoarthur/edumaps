// src/main.js
import { mount } from "svelte";
import { eventBus, logger } from "@/shared/events";
import { registerToastEventBridge } from "@/shared/stores/toastEventBridge.js";
import "./app.css";
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

const app = mount(App, {
  target: document.getElementById("app"),
});

export default app;
