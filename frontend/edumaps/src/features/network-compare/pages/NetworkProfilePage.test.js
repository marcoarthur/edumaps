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
    renderWithQuery("?codigo_ibge=3551702");

    await screen.findByText(/Sertãozinho/);
    expect(screen.getByText("Rede vs. Brasil")).toBeInTheDocument();
    expect(screen.getByText("Distribuição por grupo")).toBeInTheDocument();
    expect(screen.getByText("Alta perfil escolar")).toBeInTheDocument();
    expect(screen.getByText("Baixa perfil escolar")).toBeInTheDocument();
    expect(
      screen.getAllByText("Docentes com licenciatura").length,
    ).toBeGreaterThan(0);
  });

  it("aceita o parâmetro antigo ?ibge= dos links já compartilhados (#431)", async () => {
    renderWithQuery("?ibge=3551702");
    await screen.findByText(/Sertãozinho/);
    expect(screen.getByText("Rede vs. Brasil")).toBeInTheDocument();
  });

  it("variação segue o sentido do indicador e usa p.p. nas proporções (#421)", async () => {
    renderWithQuery("?codigo_ibge=3551702");
    await screen.findByText(/Sertãozinho/);

    // sem especialização abaixo do Brasil = melhor: verde, em p.p.
    const semEsp = screen.getByText("-43.6 p.p.");
    expect(semEsp.className).toMatch(/text-emerald-700/);
    expect(screen.getByText("menor é melhor")).toBeInTheDocument();

    // IDEB abaixo do Brasil = pior: vermelho
    expect(screen.getByText("-0.1").className).toMatch(/text-red-700/);
    // licenciatura acima do Brasil = melhor: verde
    expect(screen.getByText("+1.0 p.p.").className).toMatch(/text-emerald-700/);
  });

  it("explica cada seção com legenda e caixa (?)", async () => {
    renderWithQuery("?codigo_ibge=3551702");

    await screen.findByText(/Sertãozinho/);
    expect(
      screen.getAllByRole("button", { name: "Detalhes sobre este dado" }).length,
    ).toBeGreaterThanOrEqual(2);
    expect(screen.getByText(/Cada grupo mostra/)).toBeInTheDocument();
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
