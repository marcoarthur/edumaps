// src/shared/ui/components/charts/centroRosca.js
//
// Centro da rosca (DonutChart do Carbon) com o número e o formato separados.
//
// O Carbon espera `donut.center.number` NUMÉRICO e aplica a formatação pelo
// `numberFormatter`. Passar o texto já formatado quebrava o total (#421,
// AN-01): "77.662" (pt-BR) virava 77 e "R$ 8,9 mi" virava NaN.

/**
 * @param {string} label rótulo sob o número ("Total", "Docentes"...)
 * @param {number|string|null|undefined} valor total (número; null vira 0)
 * @param {(n: number) => string} [formatar] formatação do número no centro
 * @returns {{ label: string, number: number, numberFormatter?: (n: number) => string }}
 */
export function centroRosca(label, valor, formatar) {
  const n = Number(valor);
  const centro = { label, number: Number.isFinite(n) ? n : 0 };
  if (formatar) centro.numberFormatter = (v) => formatar(v);
  return centro;
}
