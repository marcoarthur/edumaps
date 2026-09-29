import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import OsmPoisPanel from "./OsmPoisPanel.svelte";
import { eventBus } from "@/shared/events";
import {
  OSM_POIS_STATUS_RECENT_FIXTURE,
  OSM_POIS_STATUS_PENDING_JOB_FIXTURE,
} from "../mocks/osmFixtures.js";

const mocks = vi.hoisted(() => ({
  watchJobProgress: vi.fn(() => () => {}),
  getJobProgress: vi.fn(),
}));

vi.mock("@/shared/api/taskProgress.js", () => ({
  watchJobProgress: mocks.watchJobProgress,
  getJobProgress: mocks.getJobProgress,
}));

vi.mock("@/features/map/components/LeafletMap.svelte", async () => {
  const { default: Stub } = await import("./__tests__/LeafletMapStub.svelte");
  return { default: Stub };
});

describe("OsmPoisPanel", () => {
  beforeEach(() => {
    mocks.watchJobProgress.mockReset();
    mocks.watchJobProgress.mockImplementation(() => () => {});
    // absorve os eventos emitidos (evita o aviso de evento "órfão" em DEV)
    eventBus.onAny(() => {});
  });

  it("renderiza catálogos, raio e estado vazio", async () => {
    render(OsmPoisPanel, { inep: "11000040" });

    expect(
      await screen.findByText("Equipamentos no entorno (OSM)"),
    ).toBeInTheDocument();
    // aguarda o status carregar (o botão só aparece depois)
    expect(
      await screen.findByRole("button", { name: /Buscar equipamentos/ }),
    ).toBeEnabled();
    expect(screen.getByText("Transporte")).toBeInTheDocument();
    expect(screen.getByText("Saúde")).toBeInTheDocument();
    expect(screen.getByText(/Raio do buffer/)).toBeInTheDocument();
    expect(
      screen.getByText(/Nenhum equipamento carregado ainda/),
    ).toBeInTheDocument();
    // sem escola/feições não há mapa
    expect(screen.queryByTestId("leaflet-map-stub")).not.toBeInTheDocument();
  });

  it("dispara a busca e acompanha o progresso até concluir", async () => {
    let handlers = null;
    mocks.watchJobProgress.mockImplementation((_id, h) => {
      handlers = h;
      return () => {};
    });
    render(OsmPoisPanel, { inep: "11000040" });
    await screen.findByText("Equipamentos no entorno (OSM)");

    await fireEvent.click(await screen.findByRole("button", { name: /Buscar equipamentos/ }));

    await waitFor(() => expect(mocks.watchJobProgress).toHaveBeenCalled());
    expect(mocks.watchJobProgress.mock.calls[0][0]).toBe(1); // job_id do MSW

    handlers.onProgress({ percent: 50, message: "Processando feições (1/2)" });
    expect(
      await screen.findByText(/50% — Processando feições/),
    ).toBeInTheDocument();

    handlers.onDone();
    await waitFor(() =>
      expect(screen.getByRole("button", { name: /Buscar equipamentos/ })).toBeEnabled(),
    );
  });

  it("pede confirmação quando os dados são recentes (< 7 dias)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/osm/pois", () =>
        HttpResponse.json(OSM_POIS_STATUS_RECENT_FIXTURE),
      ),
    );
    render(OsmPoisPanel, { inep: "11000040" });

    // carrega o status recente e mostra o resumo
    expect(await screen.findByText(/Atualizado em/)).toBeInTheDocument();
    expect(screen.getByText(/amenity: bus station/)).toBeInTheDocument();

    // mapa com a escola + POIs e legenda com toggle por categoria
    expect(screen.getByTestId("leaflet-map-stub")).toBeInTheDocument();
    const toggle = screen.getByRole("checkbox", { name: /amenity: bus station/ });
    expect(toggle).toBeChecked();
    await fireEvent.click(toggle);
    expect(toggle).not.toBeChecked();

    await fireEvent.click(await screen.findByRole("button", { name: /Buscar equipamentos/ }));

    const dialog = await screen.findByRole("dialog", { name: "Confirmar atualização" });
    expect(dialog).toBeInTheDocument();
    expect(screen.getByText(/Os dados são recentes/)).toBeInTheDocument();

    // cancelar fecha sem disparar
    await fireEvent.click(screen.getByRole("button", { name: "Cancelar" }));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(mocks.watchJobProgress).not.toHaveBeenCalled();
  });

  it("trava a interface quando já há um job enfileirado", async () => {
    server.use(
      http.get("/api/gestor/:codInep/osm/pois", () =>
        HttpResponse.json(OSM_POIS_STATUS_PENDING_JOB_FIXTURE),
      ),
    );
    render(OsmPoisPanel, { inep: "11000040" });

    await waitFor(() => expect(mocks.watchJobProgress).toHaveBeenCalledWith(42, expect.anything()));
    expect(screen.getByRole("button", { name: /Buscando/ })).toBeDisabled();
    expect(screen.getByText(/Acompanhando a busca em andamento/)).toBeInTheDocument();
  });

  it("mostra o erro assim que a tarefa falha", async () => {
    mocks.watchJobProgress.mockImplementation((_id, h) => {
      h.onError("Overpass indisponível no momento.");
      return () => {};
    });
    render(OsmPoisPanel, { inep: "11000040" });
    await screen.findByText("Equipamentos no entorno (OSM)");

    await fireEvent.click(await screen.findByRole("button", { name: /Buscar equipamentos/ }));

    expect(
      await screen.findByText(/Overpass indisponível no momento/),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /Buscar equipamentos/ })).toBeEnabled();
  });

  it("pede login quando não há sessão do gestor (401)", async () => {
    server.use(
      http.get("/api/gestor/:codInep/osm/pois", () =>
        HttpResponse.json({ error: "Faça login como gestor." }, { status: 401 }),
      ),
    );
    render(OsmPoisPanel, { inep: "11000040" });

    expect(
      await screen.findByText(/Entre como gestor desta escola/),
    ).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: /Buscar equipamentos/ }),
    ).not.toBeInTheDocument();
  });
});
