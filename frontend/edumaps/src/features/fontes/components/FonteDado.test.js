import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, beforeEach } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import FonteDado from "./FonteDado.svelte";
import { _resetFontes } from "../api/fontesApi.js";

describe("FonteDado (#428)", () => {
  beforeEach(() => _resetFontes());

  it("diz as bases da tela, o ano e a carga, com link para as fontes", async () => {
    render(FonteDado, { props: { tela: "comparacao_redes" } });
    const selo = await screen.findByTestId("fonte-dado");
    expect(selo).toHaveTextContent("Censo Escolar 2025 (INEP, carga em 14/10/2026)");
    expect(selo).toHaveTextContent("IDEB e SAEB 2005–2023 (INEP, carga não registrada)");
    expect(selo).not.toHaveTextContent("SIOPE");
    expect(selo.textContent).toMatch(/14\/10\/2026\)\s+·\s+IDEB/);
    expect(screen.getByRole("link", { name: "Fontes e metodologia" })).toHaveAttribute("href", "/fontes");
  });

  it("trocar a tela refiltra sem buscar de novo (#539)", async () => {
    let buscas = 0;
    const { FONTES_FIXTURE } = await import("../mocks/fixtures.js");
    server.use(http.get("*/api/fontes", () => { buscas += 1; return HttpResponse.json(FONTES_FIXTURE); }));
    const { rerender } = render(FonteDado, { props: { tela: "ranking" } });
    const selo = await screen.findByTestId("fonte-dado");
    expect(selo).toHaveTextContent("IDEB e SAEB");
    await rerender({ tela: "ranking_atendimento" });
    expect(screen.getByTestId("fonte-dado")).toHaveTextContent("População por idade (Censo Demográfico) 2022 (IBGE");
    expect(screen.getByTestId("fonte-dado")).not.toHaveTextContent("IDEB");
    expect(buscas).toBe(1);
  });

  it("falha na busca: o selo some, a tela segue", async () => {
    server.use(http.get("*/api/fontes", () => HttpResponse.json({ error: "x" }, { status: 500 })));
    render(FonteDado, { props: { tela: "folha" } });
    await new Promise((r) => setTimeout(r, 50));
    expect(screen.queryByTestId("fonte-dado")).toBeNull();
  });
});
