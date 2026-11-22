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
