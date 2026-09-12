import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

import { EventBus } from "@/shared/events/EventBus.js";
import { EVENTS } from "@/shared/constants/events.js";
import { registerToastEventBridge } from "@/shared/stores/toastEventBridge.js";

const { addToast } = vi.hoisted(() => ({
  addToast: vi.fn(),
}));

vi.mock("@/shared/stores/toastStore.js", () => ({
  addToast,
}));

describe("toastEventBridge", () => {
  let bus;
  let unsubscribe;

  beforeEach(() => {
    vi.clearAllMocks();

    bus = new EventBus();
    unsubscribe = registerToastEventBridge(bus);
  });

  afterEach(() => {
    unsubscribe?.();
    bus.destroy();
  });

  it("deve encaminhar TOAST_ADD para addToast", () => {
    bus.emit(EVENTS.TOAST_ADD, {
      message: "Busca concluída",
      type: "info",
      duration: 3000,
    });

    expect(addToast).toHaveBeenCalledWith("Busca concluída", "info", 3000);
  });

  it("deve permitir cancelar o bridge", () => {
    unsubscribe();

    bus.emit(EVENTS.TOAST_ADD, {
      message: "Não deve aparecer",
      type: "error",
      duration: 5000,
    });

    expect(addToast).not.toHaveBeenCalled();
  });
});
