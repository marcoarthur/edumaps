// src/shared/stores/paginationStore.js
import { BehaviorSubject, combineLatest, of } from "rxjs";
import {
  debounceTime,
  distinctUntilChanged,
  switchMap,
  catchError,
  map,
  shareReplay,
  startWith,
} from "rxjs/operators";

/**
 * Comparação profunda simples entre objetos (ignora funções e datas)
 */
function deepEqual(a, b) {
  if (a === b) return true;
  if (
    typeof a !== "object" ||
    a === null ||
    typeof b !== "object" ||
    b === null
  )
    return false;
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) return false;
  for (const key of keysA) {
    if (!keysB.includes(key)) return false;
    if (!deepEqual(a[key], b[key])) return false;
  }
  return true;
}

/**
 * Cria um store de paginação para uma feature específica.
 *
 * @param {Function} fetchFn - (params) => Observable<{ data, meta }>
 * @param {Object} defaultParams - { page: 1, per_page: 10, ... } (qualquer filtro)
 * @param {number} debounceMs - 300
 * @returns {Object} { result$, setSearch, goToPage, setPerPage, reload, getCurrentParams }
 */
export function createPaginationStore(
  fetchFn,
  defaultParams = {},
  debounceMs = 300,
) {
  const initial = { page: 1, per_page: 10, ...defaultParams };

  const params$ = new BehaviorSubject({ ...initial });
  const reloadTrigger$ = new BehaviorSubject(null);

  const result$ = combineLatest([
    params$.pipe(
      debounceTime(debounceMs),
      distinctUntilChanged((a, b) => deepEqual(a, b)),
    ),
    reloadTrigger$,
  ]).pipe(
    map(([params]) => params),
    switchMap((params) =>
      fetchFn(params).pipe(
        map((response) => ({
          data: response.data || [],
          meta: response.meta || null,
          error: null,
          loading: false,
        })),
        catchError((err) =>
          of({
            data: [],
            meta: null,
            error: err.message || "Erro desconhecido",
            loading: false,
          }),
        ),
        startWith({ data: [], meta: null, error: null, loading: true }),
      ),
    ),
    shareReplay(1),
  );

  // Ações
  function setSearch(newParams) {
    const current = params$.value;
    let nextState;

    if (typeof newParams === "string") {
      // Compatibilidade com versão anterior: apenas `q`
      nextState = { ...current, q: newParams, page: 1 };
    } else {
      // Objeto: mescla tudo e sempre reseta para página 1
      nextState = { ...current, ...newParams, page: 1 };
    }
    params$.next(nextState);
  }

  function goToPage(page) {
    const current = params$.value;
    if (page < 1) page = 1;
    params$.next({ ...current, page });
  }

  function setPerPage(per_page) {
    const current = params$.value;
    params$.next({ ...current, per_page, page: 1 });
  }

  function reload() {
    reloadTrigger$.next(null);
  }

  function getCurrentParams() {
    return params$.value;
  }

  return {
    result$,
    setSearch,
    goToPage,
    setPerPage,
    reload,
    getCurrentParams,
  };
}
