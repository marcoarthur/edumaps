import { describe, it, expect, beforeEach, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import InfluenciaPanel from "./InfluenciaPanel.svelte";

vi.mock("@/features/map/components/LeafletMap.svelte", async () => {
  const { default: Stub } = await import("./__tests__/LeafletMapStub.svelte");
  return { default: Stub };
});

describe("InfluenciaPanel", () => {
  beforeEach(() => {
    // limpa a sessão para cada caso (o painel restaura do localStorage)
    localStorage.clear();
  });

  it("mostra a legenda dos três raios, áreas e proveniência", async () => {
    render(InfluenciaPanel, { inep: "11000040" });

    expect(
      await screen.findByText("Área de influência (IVET)"),
    ).toBeInTheDocument();

    // legenda com os três raios canônicos e suas áreas
    expect(await screen.findByText("500 m")).toBeInTheDocument();
    expect(screen.getByText("1 km")).toBeInTheDocument();
    expect(screen.getByText("2 km")).toBeInTheDocument();
    expect(screen.getByText(/0,7854 km²/)).toBeInTheDocument();

    // leitura do entorno socioeconômico (Censo 2022) por raio
    expect(screen.getByText(/5\.362 hab · 6\.867 hab\/km²/)).toBeInTheDocument();

    // proveniência da camada
    expect(screen.getByText(/influencia-v1/)).toBeInTheDocument();
    expect(screen.getByText(/tier buffer/)).toBeInTheDocument();
    expect(screen.getByText(/Censo 2025/)).toBeInTheDocument();

    // mapa presente (escola + feições)
    expect(screen.getByTestId("leaflet-map-stub")).toBeInTheDocument();
  });

  it("liga e desliga um raio pela legenda", async () => {
    render(InfluenciaPanel, { inep: "11000040" });
    await screen.findByText("500 m");

    const cb = screen.getByRole("checkbox", { name: /1 km/ });
    expect(cb).toBeChecked();

    await fireEvent.click(cb);
    expect(cb).not.toBeChecked();

    await fireEvent.click(cb);
    expect(cb).toBeChecked();
  });

  it("mostra 'ainda não calculada' quando a camada não existe (404)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/influencia", () =>
        HttpResponse.json(
          { error: "Área de influência ainda não calculada para esta escola" },
          { status: 404 },
        ),
      ),
    );
    render(InfluenciaPanel, { inep: "11000040" });

    expect(
      await screen.findByText(/ainda não foi calculada/),
    ).toBeInTheDocument();
    // sem geometria não há mapa nem legenda
    expect(screen.queryByTestId("leaflet-map-stub")).not.toBeInTheDocument();
    expect(screen.queryByText("500 m")).not.toBeInTheDocument();
  });

  it("pede login quando não há sessão do gestor (401)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/influencia", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    render(InfluenciaPanel, { inep: "11000040" });

    expect(
      await screen.findByText(/Entre como gestor desta escola/),
    ).toBeInTheDocument();
  });

  it("nega acesso ao gestor de outra escola (403)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/influencia", () =>
        HttpResponse.json(
          { error: "Você só administra a sua própria escola." },
          { status: 403 },
        ),
      ),
    );
    render(InfluenciaPanel, { inep: "11000040" });

    await waitFor(() =>
      expect(
        screen.getByText(/Entre como gestor desta escola/),
      ).toBeInTheDocument(),
    );
  });

  it("mostra a mensagem do servidor em falha inesperada (500)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/influencia", () =>
        HttpResponse.json(
          { error: "Falha ao consultar a camada de influência." },
          { status: 500 },
        ),
      ),
    );
    render(InfluenciaPanel, { inep: "11000040" });

    expect(
      await screen.findByText(/Falha ao consultar a camada de influência/),
    ).toBeInTheDocument();
  });
});
