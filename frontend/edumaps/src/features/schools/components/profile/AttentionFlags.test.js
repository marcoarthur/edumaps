// src/features/schools/components/profile/AttentionFlags.test.js
// #522 (QU-01): a regra dos sinais cita "sem formação continuada", o rótulo
// da coluna que vem de qt_doc_bas_espec_nenhum (não é especialização).
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import AttentionFlags from "./AttentionFlags.svelte";

describe("AttentionFlags (#522)", () => {
  it("a regra fala em formação continuada, não em especialização", async () => {
    render(AttentionFlags, { flags: [] });
    await fireEvent.click(screen.getByRole("button", { name: "Detalhes sobre este dado" }));
    const dialog = screen.getByRole("dialog", { name: "O que é um sinal de atenção" });
    expect(dialog.textContent).toMatch(/como em "sem formação continuada"/);
    expect(dialog.textContent).not.toMatch(/especialização/);
  });
});

// #542 (P1-PN-02): a frase do sinal com os números, sem "quartil".
describe("AttentionFlags com os números (#542)", () => {
  const indicadores = [
    { indicador: "prop_licenciatura", label: "Docentes com licenciatura", escola: 0.941, municipio: 0.852, rede: 0.806, brasil: 0.796, direcao: "maior" },
    { indicador: "ratio_aluno_docente", label: "Relação aluno/docente", escola: 25.3, municipio: 22.3, rede: 14.9, brasil: 15, direcao: "menor" },
  ];
  const clusterResumo = [
    { indicador: "prop_licenciatura", p50: 1, n: 30 },
    { indicador: "ratio_aluno_docente", p50: 20.6, n: 29 },
  ];
  const flags = [
    { indicador: "prop_licenciatura", codigo: "prop_licenciatura_baixo", severidade: "media",
      mensagem: "Proporção de docentes com licenciatura no quartil inferior do grupo de referência" },
    { indicador: "ratio_aluno_docente", codigo: "ratio_aluno_docente_alta", severidade: "media",
      mensagem: "Relação aluno/docente no quartil superior do grupo de referência" },
  ];

  it("diz a escola, a mediana das parecidas e o lado do município e do Brasil", () => {
    render(AttentionFlags, { flags, indicadores, clusterResumo, tamanhoGrupo: 30 });
    const lic = screen.getByTestId("sinal-prop_licenciatura");
    expect(lic).toHaveTextContent(
      "Docentes com licenciatura: 94% nesta escola. Nas 30 escolas parecidas do município, metade tem 100%. A escola está melhor que o município (85%) e o Brasil (80%).",
    );
    expect(lic.textContent).not.toMatch(/quartil|grupo de referência/);
    // menor é melhor: "ou menos", e pior que os dois
    expect(screen.getByTestId("sinal-ratio_aluno_docente")).toHaveTextContent(
      "Relação aluno/docente: 25,3 nesta escola. Nas 29 escolas parecidas do município, metade tem 20,6 ou menos. A escola está pior que o município (22,3) e o Brasil (15,0).",
    );
  });

  it("sem os números, a mensagem do motor", () => {
    render(AttentionFlags, { flags: [flags[0]] });
    expect(screen.getByTestId("sinal-prop_licenciatura")).toHaveTextContent("no quartil inferior do grupo de referência");
  });
});

