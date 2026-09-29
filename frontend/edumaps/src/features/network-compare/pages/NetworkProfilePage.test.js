// src/features/network-compare/pages/NetworkProfilePage.test.js
import { describe, it, expect, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import NetworkProfilePage from "./NetworkProfilePage.svelte";

function renderWithQuery(query) {
  window.history.replaceState({}, "", `/municipio/perfil${query}`);
  return render(NetworkProfilePage);
}

describe("NetworkProfilePage", () => {
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("carrega e renderiza o perfil da rede via MSW", async () => {
    renderWithQuery("?ibge=3551702");

    await screen.findByText(/Sertãozinho/);
    expect(screen.getByText("Rede vs. Brasil")).toBeInTheDocument();
    expect(screen.getByText("Distribuição por cluster")).toBeInTheDocument();
    expect(screen.getByText("Alta perfil escolar")).toBeInTheDocument();
    expect(screen.getByText("Baixa perfil escolar")).toBeInTheDocument();
    expect(
      screen.getAllByText("Docentes com licenciatura").length,
    ).toBeGreaterThan(0);
  });

  it("exibe erro quando o município não é encontrado (404)", async () => {
    renderWithQuery("?ibge=9999999");

    await screen.findByText(/Dados não encontrados/);
  });

  it("exibe erro quando nenhum IBGE é informado", async () => {
    renderWithQuery("");

    await screen.findByText(/Nenhum código IBGE informado/);
  });
});
