// src/features/gestor/components/canais/QRModal.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor, cleanup } from "@testing-library/svelte";
import QRModal from "./QRModal.svelte";

const LISTA = { id: 1, nome: "Responsáveis 6ºA" };
const QRCODE = {
  token: "12341234-5678-4abc-8def-123412341234",
  url: "http://localhost:5173/inscricao/12341234-5678-4abc-8def-123412341234",
  expira_em: "2099-12-01T00:00:00",
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
    expect(screen.getByTestId("qr-expira")).toHaveTextContent("01/12/2099");
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
    expect(onGerar).toHaveBeenCalledWith({});
  });

  describe("validade e limite (#214)", () => {
    it("envia 'Válido até' em ISO e o limite como inteiro", async () => {
      const onGerar = vi.fn();
      renderModal({ qrcode: null, onGerar });
      await fireEvent.input(screen.getByLabelText(/Válido até/), {
        target: { value: "2099-06-30T18:00" },
      });
      await fireEvent.input(screen.getByLabelText(/Limite de inscrições/), {
        target: { value: "25" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
      expect(onGerar).toHaveBeenCalledWith({
        expira_em: new Date("2099-06-30T18:00").toISOString(),
        max_usos: 25,
      });
    });

    it("valida no cliente: data passada e limite ≤ 0 não chamam onGerar", async () => {
      const onGerar = vi.fn();
      renderModal({ qrcode: null, onGerar });
      await fireEvent.input(screen.getByLabelText(/Válido até/), {
        target: { value: "2020-01-01T00:00" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/data futura/);
      cleanup();

      renderModal({ qrcode: null, onGerar });
      await fireEvent.input(screen.getByLabelText(/Limite de inscrições/), {
        target: { value: "0" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar QR code" }));
      expect(await screen.findByRole("alert")).toHaveTextContent(/maior que zero/);
      expect(onGerar).not.toHaveBeenCalled();
    });

    it("mostra o erro do backend (400) recebido por erroGerar", () => {
      renderModal({ qrcode: null, erroGerar: "max_usos deve ser um inteiro maior que zero." });
      expect(screen.getByRole("alert")).toHaveTextContent("max_usos deve ser");
    });

    it("estado ativo; rotacionar com opções", async () => {
      const onGerar = vi.fn();
      renderModal({ onGerar });
      expect(screen.getByTestId("qr-status")).toHaveTextContent("Ativo");
      expect(screen.queryByTestId("qr-opcoes")).not.toBeInTheDocument();
      await fireEvent.click(screen.getByRole("button", { name: /Gerar novo QR \(/ }));
      await fireEvent.input(screen.getByLabelText(/Limite de inscrições/), {
        target: { value: "5" },
      });
      await fireEvent.click(screen.getByRole("button", { name: "Gerar novo QR" }));
      expect(onGerar).toHaveBeenCalledWith({ max_usos: 5 });
    });

    it("estado expirado (expira_em passado) abre a opção de gerar outro", () => {
      renderModal({ qrcode: { ...QRCODE, expira_em: "2020-01-01T00:00:00" } });
      expect(screen.getByTestId("qr-status")).toHaveTextContent("Expirado");
      expect(screen.getByText(/prazo de validade passou/)).toBeInTheDocument();
      expect(screen.getByTestId("qr-opcoes")).toBeInTheDocument();
    });

    it("estado esgotado (usos >= max_usos)", () => {
      renderModal({ qrcode: { ...QRCODE, usos: 10, max_usos: 10 } });
      expect(screen.getByTestId("qr-status")).toHaveTextContent("Esgotado");
      expect(screen.getByTestId("qr-usos")).toHaveTextContent("10 / 10");
      expect(screen.getByText(/limite de inscrições foi atingido/)).toBeInTheDocument();
    });

    it("estado revogado esconde o botão de revogar", () => {
      renderModal({ qrcode: { ...QRCODE, status: "revogado" } });
      expect(screen.getByTestId("qr-status")).toHaveTextContent("Revogado");
      expect(screen.queryByRole("button", { name: "Revogar QR" })).not.toBeInTheDocument();
    });
  });
});
