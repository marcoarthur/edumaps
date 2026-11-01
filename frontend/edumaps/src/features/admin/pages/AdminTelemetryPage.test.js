// src/features/admin/pages/AdminTelemetryPage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import AdminTelemetryPage from "./AdminTelemetryPage.svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN, SESSION_GESTOR } from "@/features/gestor/mocks/fixtures.js";

// Carbon é pesado e não acrescenta na verificação dos KPIs.
vi.mock("@carbon/charts-svelte", () => {
  const stub = () => null;
  return { LineChart: stub, DonutChart: stub, BarChartGrouped: stub, RadarChart: stub };
});

describe("AdminTelemetryPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("mostra logins (6/12/24h), atividade e rotas", async () => {
    render(AdminTelemetryPage);

    expect(await screen.findByText("Painel de Administração")).toBeInTheDocument();
    expect(await screen.findByText("Últimas 6 h")).toBeInTheDocument();
    expect(screen.getByText("Últimas 12 h")).toBeInTheDocument();
    expect(screen.getByText("Últimas 24 h")).toBeInTheDocument();
    expect(screen.getByText("7")).toBeInTheDocument(); // logins 24h

    expect(screen.getByText("Sessões ativas")).toBeInTheDocument();
    expect(screen.getByText("120")).toBeInTheDocument();
    expect(screen.getByText("Buscas")).toBeInTheDocument();
    expect(screen.getByText("34")).toBeInTheDocument();

    expect(await screen.findByText("/escola/search")).toBeInTheDocument();
    expect(screen.getByText("40.5%")).toBeInTheDocument();
  });

  it("mostra a ajuda guiada por tour, com taxa ausente como “—”", async () => {
    render(AdminTelemetryPage);

    expect(await screen.findByText("Ajuda guiada")).toBeInTheDocument();
    // nome do catálogo + id
    expect(screen.getByText("Como buscar uma escola")).toBeInTheDocument();
    expect(screen.getByText("busca-escola")).toBeInTheDocument();
    expect(screen.getByText("auto 14 · botão 5 · link 1")).toBeInTheDocument();
    expect(screen.getByText("45%")).toBeInTheDocument();
    expect(screen.getByText("3 de 7")).toBeInTheDocument();
    // painel-gestor sem abertura na janela: taxa “—”, nunca 0%
    expect(screen.getByText("Conhecer o painel do gestor")).toBeInTheDocument();
    expect(screen.queryByText("0%")).toBeNull();
    expect(screen.getAllByText("—").length).toBeGreaterThan(0);
  });

  it("trocar a janela refaz a consulta (números da janela de 6h)", async () => {
    render(AdminTelemetryPage);
    await screen.findByText("Painel de Administração");
    expect(await screen.findByText("812")).toBeInTheDocument(); // eventos 24h

    await fireEvent.click(screen.getByRole("button", { name: "6 h" }));

    expect(await screen.findByText("203")).toBeInTheDocument(); // eventos 6h
    expect(screen.getByText("30")).toBeInTheDocument(); // sessões ativas 6h
    expect(screen.getByText("60%")).toBeInTheDocument();
  });

  it("é restrita a administradores da instalação", async () => {
    server.use(
      http.get("/api/gestor/me", () =>
        HttpResponse.json({ ...SESSION_GESTOR, access_role: "gestor" }),
      ),
    );
    render(AdminTelemetryPage);

    expect(await screen.findByText(/restrita a administradores/)).toBeInTheDocument();
  });

  it("sem sessão, mostra o cartão de login", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(AdminTelemetryPage);

    expect(await screen.findByText("Entrar como administrador")).toBeInTheDocument();
  });
});
