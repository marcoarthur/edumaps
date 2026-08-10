// src/features/schools/pages/SchoolSearchPageRx.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { of, throwError } from "rxjs";

import SchoolSearchPage from "@/features/schools/pages/SchoolSearchPageRx.svelte";
import * as schoolApi from "@/features/schools/api/schoolApi.js";
import { eventBus, EVENTS } from "@/shared/events";

vi.mock("@/features/schools/api/schoolApi.js", () => ({
  searchPaginatedSchools: vi.fn(),
}));

describe("SchoolSearchPageRx", () => {
  const mockSchoolsData = [
    {
      escola: "Escola E.E. Brasil",
      codigo_inep: 123,
      endereco: "Rua das Flores, 123",
      telefone: "12981234567",
      municipio: "Ubatuba",
      uf: "SP",
      osm: "https://www.openstreetmap.org/?mlat=1&mlon=2",
      whatsapp: "https://wa.me/5512981234567",
      modalidades: ["Ensino Fundamental", "EJA"],
      tipo: "Municipal",
    },
    {
      escola: "Colégio Anchieta",
      codigo_inep: 456,
      municipio: "Campinas",
      telefone: "12981234567",
      uf: "SP",
      osm: "https://www.openstreetmap.org/?mlat=1&mlon=2",
      whatsapp: "https://wa.me/5512981234567",
      modalidades: ["Ensino Fundamental", "EJA"],
      tipo: "Municipal",
    },
  ];

  const mockMeta = {
    current_page: 1,
    total_pages: 3,
    per_page: 10,
    total_entries: 25,
  };

  let events = [];
  let unsubscribe;

  beforeEach(() => {
    vi.clearAllMocks();

    events = [];

    unsubscribe = eventBus.onAny((payload, event) => {
      events.push({ payload, event });
    });
  });

  afterEach(() => {
    unsubscribe?.();
  });

  function getToastEvents() {
    return events.filter(({ event }) => event.type === EVENTS.TOAST_ADD);
  }

  it("deve exibir a mensagem inicial orientando a busca", () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({ data: [], meta: null }),
    );

    render(SchoolSearchPage);

    expect(
      screen.getByRole("heading", { name: /busca de escolas/i }),
    ).toBeInTheDocument();

    expect(
      screen.getByText(/informe um nome de escola ou município para começar/i),
    ).toBeInTheDocument();
  });

  it("deve realizar uma busca com sucesso e renderizar os cards e paginação", async () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({
        data: mockSchoolsData,
        meta: mockMeta,
      }),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, {
      target: { value: "Brasil" },
    });

    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText("Escola E.E. Brasil")).toBeInTheDocument();

      expect(screen.getByText("Colégio Anchieta")).toBeInTheDocument();
    });

    expect(screen.getByText(/página 1 de 3/i)).toBeInTheDocument();

    const toastEvents = getToastEvents();

    expect(toastEvents).toHaveLength(1);

    expect(toastEvents[0].payload).toEqual({
      message: "Busca concluída: 25 escolas encontradas",
      type: "info",
      duration: 3000,
    });
  });

  it("deve emitir toast quando não há resultados", async () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({
        data: [],
        meta: {
          ...mockMeta,
          total_entries: 0,
          total_pages: 0,
        },
      }),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, {
      target: { value: "XYZ" },
    });

    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(
        screen.getByText(/nenhuma escola encontrada/i),
      ).toBeInTheDocument();
    });

    await waitFor(() => {
      expect(getToastEvents()).toContainEqual(
        expect.objectContaining({
          payload: {
            message: "Nenhuma escola encontrada.",
            type: "info",
            duration: 3000,
          },
        }),
      );
    });
  });

  it("deve emitir toast de erro quando a API falha", async () => {
    const errorMessage = "Servidor fora do ar";

    schoolApi.searchPaginatedSchools.mockReturnValue(
      throwError(() => new Error(errorMessage)),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, {
      target: { value: "Brasil" },
    });

    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText(errorMessage)).toBeInTheDocument();
    });

    expect(getToastEvents()).toContainEqual(
      expect.objectContaining({
        payload: {
          message: errorMessage,
          type: "error",
          duration: 5000,
        },
      }),
    );
  });
});
