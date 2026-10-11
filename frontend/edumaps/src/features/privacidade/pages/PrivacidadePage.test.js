// src/features/privacidade/pages/PrivacidadePage.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import PrivacidadePage from "./PrivacidadePage.svelte";

describe("PrivacidadePage", () => {
  it("renderiza o título principal", () => {
    render(PrivacidadePage);
    expect(
      screen.getByRole("heading", { level: 1, name: /política de privacidade/i }),
    ).toBeInTheDocument();
  });

  it("explica o uso de nome e telefone na autoinscrição", () => {
    render(PrivacidadePage);
    expect(screen.getByText(/nome e telefone/i)).toBeInTheDocument();
  });
});
