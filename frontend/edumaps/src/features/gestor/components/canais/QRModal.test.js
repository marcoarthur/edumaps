// src/features/gestor/components/canais/QRModal.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/svelte";
import QRModal from "./QRModal.svelte";

const LISTA = { id: 1, nome: "Responsáveis 6ºA" };
const QRCODE = {
  token: "12341234-5678-4abc-8def-123412341234",
  url: "http://localhost:5173/inscricao/12341234-5678-4abc-8def-123412341234",
  expira_em: "2026-12-01T00:00:00",
  usos: 3,
  max_usos: 10,
  status: "ativo",
};

function renderModal(props = {}) {
  return render(QRModal, {
    props: {
      lista: LISTA,
      qrcode: QRCODE,
      onFechar: vi.fn(),
      onGerar: vi.fn(),
      onRevogar: vi.fn(),
      ...props,
    },
  });
}

describe("QRModal", () => {
  const writeText = vi.fn().mockResolvedValue(undefined);

  beforeEach(() => {
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText },
      configurable: true,
    });
    writeText.mockClear();
  });
  afterEach(() => cleanup());

  it("desenha o QR, o link, os usos e a expiração", async () => {
    renderModal();
    await screen.findByTestId("qr-modal");
    await waitFor(() =>
      expect(document.querySelector('[data-testid="qr-imagem"] svg')).toBeTruthy(),
    );
    expect(screen.getByTestId("qr-link")).toHaveValue(QRCODE.url);
    expect(screen.getByTestId("qr-usos")).toHaveTextContent("3 / 10");
    expect(screen.getByTestId("qr-expira")).toHaveTextContent("01/12/2026");
  });

  it("mostra 'Sem expiração' quando expira_em é nulo", async () => {
    renderModal({ qrcode: { ...QRCODE, expira_em: null, usos: 0, max_usos: null } });
    expect(screen.getByTestId("qr-expira")).toHaveTextContent("Sem expiração");
    expect(screen.getByTestId("qr-usos")).toHaveTextContent("0");
  });

  it("copia o link para a área de transferência", async () => {
    renderModal();
    await fireEvent.click(screen.getByRole("button", { name: "Copiar link" }));
    await waitFor(() => expect(writeText).toHaveBeenCalledWith(QRCODE.url));
    expect(await screen.findByRole("button", { name: "Copiado!" })).toBeInTheDocument();
  });

  it("revoga o QR (chama onRevogar)", async () => {
    const onRevogar = vi.fn();
    renderModal({ onRevogar });
    await fireEvent.click(screen.getByRole("button", { name: "Revogar QR" }));
    expect(onRevogar).toHaveBeenCalledTimes(1);
  });

  it("oferece gerar quando não há QR ativo", async () => {
    const onGerar = vi.fn();
    renderModal({ qrcode: null, onGerar });
    expect(screen.queryByTestId("qr-imagem")).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
    expect(onGerar).toHaveBeenCalledTimes(1);
  });
});
