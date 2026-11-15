// src/shared/ui/components/charts/centroRosca.test.js
import { describe, it, expect } from "vitest";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { centroRosca } from "./centroRosca.js";

describe("centroRosca (#421, AN-01)", () => {
  it("mantém o número numérico e formata à parte", () => {
    const fmt = (n) => n.toLocaleString("pt-BR");
    const c = centroRosca("Total", 77662, fmt);
    expect(c.number).toBe(77662);
    expect(typeof c.number).toBe("number");
    expect(c.numberFormatter(c.number)).toBe("77.662");
    expect(c.label).toBe("Total");
  });

  it("valor em reais: número inteiro, formato de moeda no formatter", () => {
    const c = centroRosca("Total", 8895579.41, () => "R$ 8,9 mi");
    expect(c.number).toBe(8895579.41);
    expect(c.numberFormatter(c.number)).toBe("R$ 8,9 mi");
  });

  it("ausente vira 0, nunca NaN", () => {
    expect(centroRosca("Total", null).number).toBe(0);
    expect(centroRosca("Total", undefined).number).toBe(0);
    expect(centroRosca("Total", "abc").number).toBe(0);
    expect(centroRosca("Total", 5).numberFormatter).toBeUndefined();
  });

  it("nenhum componente passa texto formatado em donut.center.number", () => {
    const raiz = join(__dirname, "../../../..");
    const ofensores = [];
    const varrer = (dir) => {
      for (const nome of readdirSync(dir)) {
        const p = join(dir, nome);
        if (statSync(p).isDirectory()) varrer(p);
        else if (nome.endsWith(".svelte")) {
          const src = readFileSync(p, "utf8");
          if (/center:\s*\{[^}]*number:\s*format/.test(src)) ofensores.push(p);
        }
      }
    };
    varrer(raiz);
    expect(ofensores).toEqual([]);
  });
});
