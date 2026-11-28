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
    expect(screen.getByText("Distribuição por nível socioeconômico (INSE)")).toBeInTheDocument();
    expect(screen.getByText("INSE Nível IV")).toBeInTheDocument();
    expect(screen.getByText("Sem INSE")).toBeInTheDocument();
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

    // sem formação continuada abaixo do Brasil = melhor: verde, em p.p.
    const semEsp = screen.getByText("-43.6 p.p.");
    expect(semEsp.className).toMatch(/text-emerald-700/);
    expect(screen.getByText("menor é melhor")).toBeInTheDocument();
    // #522: o rótulo e a explicação dizem formação continuada, não especialização
    expect(screen.getAllByText(/sem formação continuada/).length).toBeGreaterThan(0);
    expect(screen.queryByText(/sem especialização/)).toBeNull();

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

  it("diz com qual Brasil compara e o critério dos grupos (#497)", async () => {
    renderWithQuery("?codigo_ibge=3551702");
    await screen.findByText(/Sertãozinho/);

    expect(screen.getByTestId("referencia-rotulo")).toHaveTextContent(
      "Comparada com: Brasil, todas as redes (180.540 escolas)",
    );
    expect(screen.getByRole("columnheader", { name: "Brasil, todas as redes" })).toBeInTheDocument();
    expect(screen.getByTestId("grupo-criterio")).toHaveTextContent(/classificação publicada pelo INEP/);
    expect(screen.queryByText(/Sem cluster/)).not.toBeInTheDocument();
  });

  it("exibe erro quando o município não é encontrado (404)", async () => {
    renderWithQuery("?ibge=9999999");

    await screen.findByText(/Dados não encontrados/);
  });

  it("exibe erro quando nenhum IBGE é informado", async () => {
    renderWithQuery("");

    await screen.findByText(/Nenhum código IBGE informado/);
  });

  it("o link da folha e do Fundeb da rede só com folha carregada (#614)", async () => {
    const { unmount } = renderWithQuery("?codigo_ibge=3551702");
    await screen.findByText(/Sertãozinho/);
    expect(screen.queryByTestId("link-folha-rede")).toBeNull();
    unmount();
    renderWithQuery("?codigo_ibge=5103403");
    const link = await screen.findByTestId("link-folha-rede");
    expect(link).toHaveAttribute("href", "/municipio/financeiro?codigo_ibge=5103403&ano=2026");
    expect(link).toHaveTextContent("Folha e Fundeb da rede municipal");
    expect(link).toHaveTextContent("folha do SIOPE de 2025 a 2026");
  });
});
