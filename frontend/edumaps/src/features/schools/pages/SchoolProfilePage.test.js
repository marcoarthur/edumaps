// src/features/schools/pages/SchoolProfilePage.test.js
import { describe, it, expect, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import { server } from "../../../mocks/server.js";
import { http, HttpResponse } from "msw";
import SchoolProfilePage from "./SchoolProfilePage.svelte";

function renderWithQuery(query) {
  window.history.replaceState({}, "", `/escola/perfil${query}`);
  return render(SchoolProfilePage);
}

describe("SchoolProfilePage", () => {
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("carrega e renderiza o perfil via MSW", async () => {
    renderWithQuery("?inep=35123456");

    await screen.findByText("EMEF Exemplo");
    expect(screen.getByText("Posição relativa")).toBeInTheDocument();
    expect(screen.getByText("Sinais de atenção")).toBeInTheDocument();
  });

  it("exibe erro quando a escola não é encontrada (400)", async () => {
    server.use(
      http.get("/api/school/:codInep/profile", () =>
        HttpResponse.json({ error: "Escola não encontrada." }, { status: 400 }),
      ),
    );
    renderWithQuery("?inep=99999999");

    await screen.findByText("Escola não encontrada.");
  });

  it("exibe erro quando nenhum INEP é informado", async () => {
    renderWithQuery("");

    await screen.findByText(/Nenhum código INEP informado/);
  });
});
