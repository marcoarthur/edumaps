// src/features/gestor/api/gestorFunilApi.test.js
// Onda 2 do #216 na camada de listas: n_optouts, optout por membro e o funil.
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { setApiToken } from "@/shared/api/client.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { INEP_CANAIS } from "../mocks/canaisFixtures.js";
import { resetCanaisMockState, setFunilHojeMock } from "../mocks/canaisHandlers.js";
import { listListas, getLista, listInscricoes, getFunil } from "./gestorCanaisApi.js";

describe("gestorCanaisApi — opt-out e funil (#216)", () => {
  beforeEach(() => {
    resetCanaisMockState();
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => setApiToken(null));

  it("listas trazem n_optouts e membros trazem optout", async () => {
    const listas = await listListas(INEP_CANAIS);
    expect(listas.find((l) => l.id === 4).n_optouts).toBe(1);
    expect(listas.find((l) => l.id === 1).n_optouts).toBe(0);
    expect((await getLista(INEP_CANAIS, 4)).n_optouts).toBe(1);
    const membros = await listInscricoes(INEP_CANAIS, 4);
    expect(membros.find((m) => m.nome === "Clara Pendente").optout).toBe(true);
    expect(membros.find((m) => m.nome === "Ana Parcial").optout).toBe(false);
  });

  it("funil com período: série com todos os dias, totais e taxas", async () => {
    const f = await getFunil(INEP_CANAIS, 4, { de: "2026-10-06", ate: "2026-10-12" });
    expect(f).toMatchObject({ de: "2026-10-06", ate: "2026-10-12", exige_confirmacao: true });
    expect(f.serie).toHaveLength(7);
    expect(f.serie[0]).toEqual({ dia: "2026-10-06", acessos: 0, inscricoes: 0, confirmados: 0, optouts: 0 });
    expect(f.totais).toEqual({ acessos: 20, inscricoes: 3, confirmados: 1, optouts: 1 });
    expect(f.taxas).toEqual({ acesso_inscricao: 0.15, inscricao_confirmacao: 0.3333 });
  });

  it("padrão: 30 dias até hoje; lista sem confirmação → confirmados null", async () => {
    setFunilHojeMock("2026-10-12");
    const f = await getFunil(INEP_CANAIS, 2);
    expect(f.de).toBe("2026-09-13");
    expect(f.serie).toHaveLength(30);
    expect(f.totais.confirmados).toBeNull();
    expect(f.serie.every((s) => s.confirmados === null)).toBe(true);
    expect(f.taxas).toEqual({ acesso_inscricao: 0, inscricao_confirmacao: null });
  });

  it("período inválido → 400", async () => {
    await expect(getFunil(INEP_CANAIS, 4, { de: "2026-10-12", ate: "2026-10-01" })).rejects.toMatchObject({
      status: 400,
    });
    await expect(getFunil(INEP_CANAIS, 4, { de: "2025-01-01", ate: "2026-10-12" })).rejects.toMatchObject({
      status: 400,
    });
  });
});
