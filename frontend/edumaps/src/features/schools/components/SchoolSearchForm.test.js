import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi, afterEach } from "vitest";
import SchoolSearchForm from "./SchoolSearchForm.svelte";
import { eventBus } from "@/shared/events";
import { SCHOOL_EVENTS } from "../constants/events.js";

describe("SchoolSearchForm", () => {
  // eventBus é uma instância compartilhada (singleton) — cada teste que
  // registra um handler guarda a função de cancelamento aqui e desfaz no
  // afterEach, pra não vazar handler de um teste pro próximo.
  const unsubscribers = [];

  function listen(type, handler) {
    unsubscribers.push(eventBus.on(type, handler));
  }

  afterEach(() => {
    unsubscribers.splice(0).forEach((unsubscribe) => unsubscribe());
  });

  it("mantém o botão de busca desabilitado com menos de 3 caracteres nos dois campos", async () => {
    render(SchoolSearchForm);
    expect(
      screen.getByRole("button", { name: /buscar escolas/i }),
    ).toBeDisabled();

    await fireEvent.input(screen.getByLabelText("Nome da Escola"), {
      target: { value: "ab" },
    });
    expect(
      screen.getByRole("button", { name: /buscar escolas/i }),
    ).toBeDisabled();
  });

  it("habilita o botão quando um dos campos atinge 3 caracteres", async () => {
    render(SchoolSearchForm);
    await fireEvent.input(screen.getByLabelText("Município"), {
      target: { value: "SP" },
    });
    expect(
      screen.getByRole("button", { name: /buscar escolas/i }),
    ).toBeDisabled();

    await fireEvent.input(screen.getByLabelText("Município"), {
      target: { value: "SPD" },
    });
    expect(
      screen.getByRole("button", { name: /buscar escolas/i }),
    ).not.toBeDisabled();
  });

  it("ao submeter, chama onSearch com os filtros e emite SCHOOL_EVENTS.SEARCH no bus", async () => {
    const onSearch = vi.fn();
    const busHandler = vi.fn();
    listen(SCHOOL_EVENTS.SEARCH, busHandler);

    render(SchoolSearchForm, { onSearch });

    await fireEvent.input(screen.getByLabelText("Nome da Escola"), {
      target: { value: "Paulo Freire" },
    });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    const expectedFilters = { escola: "Paulo Freire", municipio: "" };
    expect(onSearch).toHaveBeenCalledWith(expectedFilters);
    expect(busHandler).toHaveBeenCalledWith(
      expectedFilters,
      expect.objectContaining({ source: "SchoolSearchForm" }),
    );
  });

  it("não submete (nem chama onSearch, nem emite) quando canSubmit é falso", async () => {
    const onSearch = vi.fn();
    const busHandler = vi.fn();
    listen(SCHOOL_EVENTS.SEARCH, busHandler);

    render(SchoolSearchForm, { onSearch });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    expect(onSearch).not.toHaveBeenCalled();
    expect(busHandler).not.toHaveBeenCalled();
  });

  it("ao limpar, reseta os campos, chama onClear e emite SCHOOL_EVENTS.CLEAR no bus", async () => {
    const onClear = vi.fn();
    const busHandler = vi.fn();
    listen(SCHOOL_EVENTS.CLEAR, busHandler);

    render(SchoolSearchForm, { onClear });

    await fireEvent.input(screen.getByLabelText("Nome da Escola"), {
      target: { value: "Paulo Freire" },
    });
    await fireEvent.click(screen.getByRole("button", { name: /limpar/i }));

    expect(screen.getByLabelText("Nome da Escola")).toHaveValue("");
    expect(onClear).toHaveBeenCalledOnce();
    expect(busHandler).toHaveBeenCalledOnce();
  });

  it("desabilita os campos e o botão de busca durante loading", () => {
    render(SchoolSearchForm, { loading: true });
    expect(screen.getByLabelText("Nome da Escola")).toBeDisabled();
    expect(screen.getByLabelText("Município")).toBeDisabled();
    expect(screen.getByRole("button", { name: /buscando/i })).toBeDisabled();
  });
});
