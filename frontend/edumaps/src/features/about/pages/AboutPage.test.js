// src/features/about/pages/AboutPage.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import AboutPage from "./AboutPage.svelte";

describe("AboutPage", () => {
  it("renderiza o título principal", () => {
    render(AboutPage);
    expect(
      screen.getByRole("heading", { level: 1, name: /sobre o refactor/i }),
    ).toBeInTheDocument();
  });

  it("lista os objetivos da reescrita", () => {
    render(AboutPage);
    expect(screen.getByText(/pwa com svelte 5/i)).toBeInTheDocument();
  });
});
