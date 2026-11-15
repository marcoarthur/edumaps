import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, beforeEach } from "vitest";
import FontesPage from "./FontesPage.svelte";
import { _resetFontes } from "../api/fontesApi.js";

describe("FontesPage (#428)", () => {
  beforeEach(() => _resetFontes());

  it("um cartão por base, com ano, carga, licença e arquivos", async () => {
    render(FontesPage);
    const censo = await screen.findByTestId("fonte-censo");
    expect(censo).toHaveTextContent("Dado de 2025");
    expect(censo).toHaveTextContent("Última carga: 14/10/2026");
    expect(censo).toHaveTextContent("Licença: consulte os termos do órgão");
    expect(censo).toHaveTextContent(/Usada em: comparação de redes, perfil da escola/);

    const ideb = screen.getByTestId("fonte-ideb");
    expect(ideb).toHaveTextContent("Última carga: não registrada");

    const siope = screen.getByTestId("fonte-siope");
    expect(siope).toHaveTextContent("Licença: Domínio público");
    expect(siope).toHaveTextContent("ab12cd34ef56");
    expect(screen.getByText("Como ler os números")).toBeInTheDocument();
  });
});
