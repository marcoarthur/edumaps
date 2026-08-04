import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { of, throwError, delay } from "rxjs";
import { createPaginationStore } from "@/shared/stores/paginationStore";

describe("createPaginationStore", () => {
  let mockFetchFn;

  beforeEach(() => {
    vi.useFakeTimers();
    mockFetchFn = vi.fn().mockImplementation((params) =>
      of({
        data: [{ id: 1, name: "Item 1" }],
        meta: { total_pages: 5, current_page: params.page },
      }),
    );
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("deve carregar o estado inicial com loading e depois emitir os dados", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);
    const emissions = [];

    const sub = store.result$.subscribe((state) => emissions.push(state));

    // Antes do tempo do debounce expirar
    expect(emissions.length).toBe(0);

    // Avança o tempo do debounceTime(300)
    vi.advanceTimersByTime(300);

    // Primeira emissão vindo do startWith ({ loading: true })
    expect(emissions[0]).toEqual({
      data: [],
      meta: null,
      error: null,
      loading: true,
    });

    // Segunda emissão com os dados retornados pelo mockFetchFn
    expect(emissions[1]).toEqual({
      data: [{ id: 1, name: "Item 1" }],
      meta: { total_pages: 5, current_page: 1 },
      error: null,
      loading: false,
    });

    expect(mockFetchFn).toHaveBeenCalledWith({
      page: 1,
      per_page: 10,
      q: "",
    });

    sub.unsubscribe();
  });

  it("deve aplicar debounce e resetar para a página 1 ao alterar a busca (setSearch)", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);
    const sub = store.result$.subscribe();

    vi.advanceTimersByTime(300); // Carregamento inicial

    // Simula digitação rápida
    store.goToPage(3);
    store.setSearch("test");

    expect(store.getCurrentParams().page).toBe(1);
    expect(store.getCurrentParams().q).toBe("test");

    // Avança apenas 200ms (não deve ter disparado ainda)
    vi.advanceTimersByTime(200);
    expect(mockFetchFn).toHaveBeenCalledTimes(1); // Apenas a chamada inicial

    // Completa os 300ms
    vi.advanceTimersByTime(100);
    expect(mockFetchFn).toHaveBeenCalledTimes(2);
    expect(mockFetchFn).toHaveBeenLastCalledWith({
      page: 1,
      per_page: 10,
      q: "test",
    });

    sub.unsubscribe();
  });

  it("deve ir para uma página específica (goToPage)", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);
    const sub = store.result$.subscribe();

    vi.advanceTimersByTime(300);

    store.goToPage(4);
    vi.advanceTimersByTime(300);

    expect(mockFetchFn).toHaveBeenLastCalledWith({
      page: 4,
      per_page: 10,
      q: "",
    });

    sub.unsubscribe();
  });

  it("não deve permitir páginas menores que 1", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);

    store.goToPage(-5);

    expect(store.getCurrentParams().page).toBe(1);
  });

  it("deve alterar a quantidade de itens por página e resetar a página para 1 (setPerPage)", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);
    const sub = store.result$.subscribe();

    vi.advanceTimersByTime(300);

    store.goToPage(3);
    store.setPerPage(25);

    expect(store.getCurrentParams()).toEqual({
      page: 1,
      per_page: 25,
      q: "",
    });

    vi.advanceTimersByTime(300);

    expect(mockFetchFn).toHaveBeenLastCalledWith({
      page: 1,
      per_page: 25,
      q: "",
    });

    sub.unsubscribe();
  });

  it("deve re-executar a busca quando reload() for chamado", () => {
    const store = createPaginationStore(mockFetchFn, {}, 300);
    const sub = store.result$.subscribe();

    vi.advanceTimersByTime(300);
    expect(mockFetchFn).toHaveBeenCalledTimes(1);

    // Executa o reload sem alterar os parâmetros
    store.reload();
    vi.advanceTimersByTime(300);

    expect(mockFetchFn).toHaveBeenCalledTimes(2);

    sub.unsubscribe();
  });

  it("deve capturar exceções e retornar o estado de erro", () => {
    const errorFetchFn = vi
      .fn()
      .mockReturnValue(
        throwError(() => new Error("Falha na conexão com a API")),
      );

    const store = createPaginationStore(errorFetchFn, {}, 300);
    const emissions = [];

    const sub = store.result$.subscribe((state) => emissions.push(state));

    vi.advanceTimersByTime(300);

    const lastState = emissions[emissions.length - 1];

    expect(lastState).toEqual({
      data: [],
      meta: null,
      error: "Falha na conexão com a API",
      loading: false,
    });

    sub.unsubscribe();
  });
});
