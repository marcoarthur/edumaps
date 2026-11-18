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

  it("índices do EduMaps: versão, histórico e sem licença de órgão (#462)", async () => {
    render(FontesPage);
    const ind = await screen.findByTestId("fonte-indices_edumaps");
    expect(screen.getByTestId("versao-indices_edumaps")).toHaveTextContent("indices-v2");
    expect(ind).toHaveTextContent("Versão da fórmula: indices-v2, de 16/11/2026");
    expect(ind).toHaveTextContent("Último cálculo: 16/11/2026");
    expect(ind).not.toHaveTextContent("Licença");
    const hist = screen.getByTestId("historico-indices_edumaps");
    expect(hist).toHaveTextContent("indices-v1 (04/06/2026): Fórmula original");
    expect(ind).toHaveTextContent("O que cada índice mede");
    expect(screen.getByTestId("fonte-censo")).not.toHaveTextContent("Versão da fórmula");
  });

  it("IVET do EduMaps: versão citável e histórico (#489)", async () => {
    render(FontesPage);
    const ivet = await screen.findByTestId("fonte-ivet_edumaps");
    expect(ivet).toHaveTextContent("Versão da fórmula: ivet-v1.8, de 17/11/2026");
    expect(ivet).toHaveTextContent("Usada em: painel da escola");
    expect(screen.getByTestId("historico-ivet_edumaps")).toHaveTextContent("ivet-v1.3 (10/11/2026): Bloco C");
  });
});
