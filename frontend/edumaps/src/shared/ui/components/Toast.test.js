// shared/ui/components/Toast.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import {
  describe,
  it,
  expect,
  vi,
  beforeEach,
  afterEach,
  beforeAll,
} from "vitest";
import { BehaviorSubject } from "rxjs";
import Toast from "./Toast.svelte";
import * as toastStore from "@/shared/stores/toastStore";

// Mock do animate para evitar erro em transições
beforeAll(() => {
  if (!Element.prototype.animate) {
    Element.prototype.animate = vi.fn(() => ({
      finished: Promise.resolve(),
      cancel: vi.fn(),
    }));
  }
});

// Mock do toastStore
vi.mock("@/shared/stores/toastStore", () => ({
  toast$: new BehaviorSubject([]),
  removeToast: vi.fn(),
}));

describe("Toast Component", () => {
  let toastSubject;

  beforeEach(() => {
    vi.clearAllMocks();
    toastSubject = new BehaviorSubject([]);
    // Substitui o mock do toast$ pelo nosso subject controlado
    toastStore.toast$ = toastSubject.asObservable();
    // Mantém o removeToast mockado
    toastStore.removeToast = vi.fn();
  });

  afterEach(() => {
    toastSubject.complete();
  });

  it("não deve renderizar nada quando não há toasts", () => {
    render(Toast);
    const container = document.querySelector(".fixed.top-4.right-4");
    expect(container).toBeNull();
  });

  it("deve renderizar um único toast com a mensagem correta", async () => {
    render(Toast);
    const toast = { id: "1", message: "Mensagem de teste", type: "info" };
    toastSubject.next([toast]);

    await waitFor(() => {
      expect(screen.getByText("Mensagem de teste")).toBeInTheDocument();
    });
    expect(screen.getByText("ℹ️")).toBeInTheDocument();
  });

  it("deve renderizar múltiplos toasts", async () => {
    render(Toast);
    const toasts = [
      { id: "1", message: "Primeiro", type: "info" },
      { id: "2", message: "Segundo", type: "success" },
    ];
    toastSubject.next(toasts);

    await waitFor(() => {
      expect(screen.getByText("Primeiro")).toBeInTheDocument();
      expect(screen.getByText("Segundo")).toBeInTheDocument();
    });
  });

  it("deve aplicar as classes corretas para cada tipo", async () => {
    render(Toast);
    const toasts = [
      { id: "1", message: "Info", type: "info" },
      { id: "2", message: "Success", type: "success" },
      { id: "3", message: "Error", type: "error" },
      { id: "4", message: "Warning", type: "warning" },
    ];
    toastSubject.next(toasts);

    await waitFor(() => {
      const infoToast = screen.getByText("Info").closest("div");
      expect(infoToast).toHaveClass(
        "bg-blue-50",
        "border-blue-500",
        "text-blue-800",
      );

      const successToast = screen.getByText("Success").closest("div");
      expect(successToast).toHaveClass(
        "bg-green-50",
        "border-green-500",
        "text-green-800",
      );

      const errorToast = screen.getByText("Error").closest("div");
      expect(errorToast).toHaveClass(
        "bg-red-50",
        "border-red-500",
        "text-red-800",
      );

      const warningToast = screen.getByText("Warning").closest("div");
      expect(warningToast).toHaveClass(
        "bg-yellow-50",
        "border-yellow-500",
        "text-yellow-800",
      );
    });
  });

  it("deve chamar removeToast ao clicar no botão de fechar", async () => {
    render(Toast);
    const toast = { id: "123", message: "Para fechar", type: "info" };
    toastSubject.next([toast]);

    await waitFor(() => {
      expect(screen.getByText("Para fechar")).toBeInTheDocument();
    });

    const closeButton = screen.getByRole("button", { name: /fechar/i });
    await fireEvent.click(closeButton);

    expect(toastStore.removeToast).toHaveBeenCalledWith("123");
  });

  // it("deve atualizar a lista quando o subject emite novos valores", async () => {
  //   render(Toast);
  //
  //   toastSubject.next([{ id: "1", message: "Toast 1", type: "info" }]);
  //   await waitFor(() => {
  //     expect(screen.getByText("Toast 1")).toBeInTheDocument();
  //   });
  //
  //   toastSubject.next([{ id: "2", message: "Toast 2", type: "success" }]);
  //
  //   await waitFor(() => {
  //     expect(screen.queryByText("Toast 1")).not.toBeInTheDocument();
  //     expect(screen.getByText("Toast 2")).toBeInTheDocument();
  //   });
  // });
});
