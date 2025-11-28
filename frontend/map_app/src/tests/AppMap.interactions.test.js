// AppMap.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import userEvent from "@testing-library/user-event";
import AppMap from "../lib/AppMap.svelte";

// Mock do fetch para simular a API
global.fetch = vi.fn();

describe("AppMap - Interações Básicas", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  // Teste mais trivial possível: digitar e buscar
  it("deve permitir digitar um nome de cidade e clicar para buscar", async () => {
    const user = userEvent.setup();

    // Mock da resposta da API
    fetch.mockResolvedValueOnce({
      json: async () => ({ features: [] }), // Retorna array vazio para simplificar
    });

    render(AppMap);

    // 1. Encontra o campo de busca (assumindo que MapControls tem um input)
    const searchInput = screen.getByPlaceholderText(
      /enter city name|buscar cidade/i,
    );

    // 2. Digita o nome da cidade
    await user.type(searchInput, "São Paulo");

    // 3. Verifica se o input tem o valor digitado
    expect(searchInput.value).toBe("São Paulo");

    // 4. Encontra e clica no botão de busca
    const searchButton = screen.getByRole("button", { name: /search|buscar/i });
    await user.click(searchButton);

    // 5. Verifica se a função fetch foi chamada com os parâmetros corretos
    expect(fetch).toHaveBeenCalledWith("/api/geojson?city=S%C3%A3o%20Paulo");

    // 6. Verifica se o status mudou para "buscando"
    // (isso depende de como seu componente mostra o status)
    const statusElement =
      screen.getByTestId("status") || screen.getByText(/buscando|searching/i);
    expect(statusElement).toBeInTheDocument();
  });

  // Teste ainda mais simples: apenas verificar que os controles existem
  it("deve renderizar todos os controles básicos", () => {
    render(AppMap);

    // Verifica se os elementos principais estão presentes
    expect(
      screen.getByPlaceholderText(/enter city name|buscar cidade/i),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /search|buscar/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /clear|limpar/i }),
    ).toBeInTheDocument();
  });

  // Teste do botão "Clear Map"
  it("deve limpar o mapa quando clicar no botão Clear", async () => {
    const user = userEvent.setup();
    render(AppMap);

    // Encontra e clica no botão Clear
    const clearButton = screen.getByRole("button", { name: /clear|limpar/i });
    await user.click(clearButton);

    // Verifica se a mensagem de status mudou para "Map cleared"
    const statusMessage = screen.getByText(/map cleared|mapa limpo/i);
    expect(statusMessage).toBeInTheDocument();
  });
});
