// src/features/gestor/utils/qrEstado.test.js
import { describe, it, expect } from "vitest";
import { estadoQr, opcoesQr } from "./qrEstado.js";

const AGORA = Date.parse("2026-10-12T12:00:00Z");

describe("estadoQr", () => {
  it("deduz ativo, expirado, esgotado e revogado", () => {
    expect(estadoQr(null)).toBeNull();
    expect(estadoQr({ status: "ativo", usos: 0 }, AGORA)).toBe("ativo");
    expect(estadoQr({ status: "ativo", expira_em: "2026-10-12T11:00:00Z" }, AGORA)).toBe("expirado");
    expect(estadoQr({ status: "ativo", usos: 5, max_usos: 5 }, AGORA)).toBe("esgotado");
    expect(estadoQr({ status: "revogado", usos: 5, max_usos: 5 }, AGORA)).toBe("revogado");
    expect(estadoQr({ status: "esgotado" }, AGORA)).toBe("esgotado");
  });
});

describe("opcoesQr", () => {
  it("sem campos não envia nada", () => {
    expect(opcoesQr({}, AGORA)).toEqual({ erro: null, opcoes: {} });
  });

  it("converte validade para ISO e limite para inteiro", () => {
    const { erro, opcoes } = opcoesQr({ validoAte: "2026-12-01T10:30", limite: "50" }, AGORA);
    expect(erro).toBeNull();
    expect(opcoes.expira_em).toBe(new Date("2026-12-01T10:30").toISOString());
    expect(opcoes.max_usos).toBe(50);
  });

  it("recusa data passada e limite inválido", () => {
    expect(opcoesQr({ validoAte: "2026-01-01T00:00" }, AGORA).erro).toMatch(/futura/);
    expect(opcoesQr({ limite: "0" }, AGORA).erro).toMatch(/maior que zero/);
    expect(opcoesQr({ limite: "2.5" }, AGORA).erro).toMatch(/maior que zero/);
  });
});
