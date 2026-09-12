// toastEventBridge.js
//
// Ponte entre o eventBus e a toastStore existente. Registrar uma única
// vez na inicialização da app (ver main.js) — depois disso, qualquer
// feature pede um toast só emitindo EVENTS.TOAST_ADD, sem importar a
// store diretamente (ver SchoolSearchPageRx.svelte).
import { eventBus, EVENTS } from "@/shared/events";
import { addToast } from "./toastStore.js";

/**
 * @returns {() => void} função de cancelamento, útil em testes
 */
export function registerToastEventBridge(bus = eventBus) {
  return bus.on(
    EVENTS.TOAST_ADD,
    ({ message, type = "info", duration = 3000 } = {}) => {
      addToast(message, type, duration);
    },
  );
}
