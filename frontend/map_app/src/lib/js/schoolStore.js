import { writable, derived } from "svelte/store";

export const schools = writable([]);
export const selectedSchool = writable(null);
export const hoveredSchool = writable(null);

// Lista ordenada: escola selecionada sempre no topo
export const sortedSchools = derived(
  [schools, selectedSchool],
  ([$schools, $selected]) => {
    if (!$selected) return $schools;
    return [
      $selected,
      ...$schools.filter(
        (s) => s.properties.codigo_inep !== $selected.properties.codigo_inep,
      ),
    ];
  },
);
