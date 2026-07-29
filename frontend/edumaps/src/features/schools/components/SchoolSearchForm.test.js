// src/features/schools/components/SchoolSearchForm.test.js
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolSearchForm from "./SchoolSearchForm.svelte";

describe("SchoolSearchForm", () => {
  it("chama onSearch com os valores preenchidos", async () => {
    const onSearch = vi.fn();
    render(SchoolSearchForm, { props: { onSearch } });

    await fireEvent.input(screen.getByLabelText(/nome da escola/i), {
      target: { value: "Paulo Freire" },
    });
    await fireEvent.click(screen.getByRole("button", { name: /buscar/i }));

    expect(onSearch).toHaveBeenCalledWith({
      escola: "Paulo Freire",
      municipio: "",
    });
  });

  it("chama onClear ao clicar em limpar", async () => {
    const onClear = vi.fn();
    render(SchoolSearchForm, { props: { onClear } });

    await fireEvent.click(screen.getByRole("button", { name: /limpar/i }));
    expect(onClear).toHaveBeenCalled();
  });

  it("não permite submeter com os campos vazios", () => {
    render(SchoolSearchForm, { props: { onSearch: vi.fn() } });
    expect(screen.getByRole("button", { name: /buscar/i })).toBeDisabled();
  });
});
