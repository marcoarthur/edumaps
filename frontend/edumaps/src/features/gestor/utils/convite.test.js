// src/features/gestor/utils/convite.test.js
import { describe, it, expect } from "vitest";
import { buildConvite, numeroParaWa, waLink } from "./convite.js";

describe("convite", () => {
  it("monta texto com quando, duração e onde", () => {
    const c = buildConvite({
      titulo: "Reunião de planejamento",
      quando: "2026-10-10 14:30:00",
      duracaoMin: 90,
      ondeLabel: "Google Meet",
      ondeLink: "https://meet.google.com/abc",
    });
    expect(c.linhaAssunto).toBe("Convite — Reunião de planejamento");
    expect(c.textoWhatsApp).toContain("Quando:");
    expect(c.textoWhatsApp).toContain("10 de outubro de 2026");
    expect(c.textoWhatsApp).toContain("às 14:30");
    expect(c.textoWhatsApp).toContain("(90 min)");
    expect(c.textoWhatsApp).toContain("Onde: Google Meet (https://meet.google.com/abc)");
    expect(c.textoWhatsApp).toContain("Você está convidado(a)");
  });

  it("omite onde quando não informado", () => {
    const c = buildConvite({ titulo: "R", quando: "2026-10-10 14:30:00", duracaoMin: null });
    expect(c.textoWhatsApp).not.toContain("Onde:");
    expect(c.textoWhatsApp).not.toContain("min)");
  });

  it("numeroParaWa normaliza para o formato brasileiro", () => {
    expect(numeroParaWa("+5511999990001")).toBe("5511999990001");
    expect(numeroParaWa("(11) 99999-0001")).toBe("5511999990001");
    expect(numeroParaWa("")).toBe("");
  });

  it("waLink gera link sem número por padrão", () => {
    expect(waLink("olá")).toBe("https://wa.me?text=ol%C3%A1");
  });
});