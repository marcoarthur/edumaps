// src/features/cluster-geotag/components/FeatureSelect.test.js
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import FeatureSelect from "./FeatureSelect.svelte";

const COLUMNS = [
  {
    column_name: "in_agua_potavel",
    data_type: "boolean",
    comment: "Possui água potável",
    table_name: "censo_escolas",
  },
  {
    column_name: "in_biblioteca",
    data_type: "boolean",
    comment: "Possui biblioteca",
    table_name: "censo_escolas",
  },
  {
    column_name: "qt_doc_bas",
    data_type: "integer",
    comment: "Docentes na educação básica (total)",
    table_name: "censo_docentes",
  },
];

function setup(props = {}) {
  render(FeatureSelect, { props: { columns: COLUMNS, value: [], ...props } });
  return screen.getByLabelText(/buscar indicador/i);
}

describe("FeatureSelect", () => {
  it("não busca com menos de 2 caracteres e mostra a dica", async () => {
    const input = setup();

    await fireEvent.input(input, { target: { value: "a" } });

    expect(screen.queryByRole("option")).toBeNull();
    expect(screen.getByText(/ao menos 2 caracteres/i)).toBeInTheDocument();
  });

  it("busca pelo metadado (comment) e mostra o nome da coluna", async () => {
    const input = setup();

    // "água" só aparece no comment de in_agua_potavel.
    await fireEvent.input(input, { target: { value: "água" } });

    const option = await screen.findByRole("option");
    expect(option).toBeInTheDocument();
    expect(screen.getByText("in_agua_potavel")).toBeInTheDocument();
    expect(screen.getByText(/possui água potável/i)).toBeInTheDocument();
  });

  it("expõe o comentário no tooltip (title)", async () => {
    const input = setup();

    await fireEvent.input(input, { target: { value: "biblioteca" } });
    const option = await screen.findByRole("option");

    expect(option).toHaveAttribute("title", "Possui biblioteca");
  });

  it("adiciona o indicador ao clicar na opção", async () => {
    const input = setup();

    await fireEvent.input(input, { target: { value: "biblioteca" } });
    const option = await screen.findByRole("option");

    // Sequência real do browser: mousedown (que antes roubava o foco e fechava
    // a lista) seguido de click.
    await fireEvent.mouseDown(option);
    await fireEvent.click(option);

    expect(screen.getByText(/1 selecionado/i)).toBeInTheDocument();
    expect(screen.getByText("Possui biblioteca")).toBeInTheDocument();
  });

  it("não lista colunas já selecionadas", async () => {
    const input = setup({ value: ["in_biblioteca"] });

    await fireEvent.input(input, { target: { value: "biblioteca" } });

    expect(screen.queryByRole("option")).toBeNull();
  });
});
