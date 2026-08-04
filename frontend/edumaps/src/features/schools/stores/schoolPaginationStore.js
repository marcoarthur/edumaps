// src/features/schools/stores/schoolPaginationStore.js
import { from, of } from "rxjs";
import { createPaginationStore } from "@/shared/stores/paginationStore";
import { searchPaginatedSchools } from "../api/schoolApi";

const fetchSchoolsAdapter = (params) => {
  // 1. Limpa parâmetros vazios
  const cleanParams = {};
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== "") {
      // Ignora objetos vazios
      if (
        typeof value === "object" &&
        !Array.isArray(value) &&
        Object.keys(value).length === 0
      )
        continue;
      cleanParams[key] = value;
    }
  }

  // 2. Verifica se há filtro válido (escola ou municipio com >=3 caracteres)
  const hasValidFilter =
    (cleanParams.escola && cleanParams.escola.length >= 3) ||
    (cleanParams.municipio && cleanParams.municipio.length >= 3);

  if (!hasValidFilter) {
    // Retorna dados vazios sem chamar a API
    return of({
      data: [],
      meta: { current_page: 1, per_page: 10, total_entries: 0, total_pages: 0 },
    });
  }

  console.log("📦 Adaptador enviando params:", cleanParams);
  return from(searchPaginatedSchools(cleanParams));
};

export function createSchoolStore(initialParams = {}) {
  return createPaginationStore(
    fetchSchoolsAdapter,
    {
      page: 1,
      per_page: 10,
      escola: "",
      municipio: "",
      ...initialParams,
    },
    300,
  );
}
