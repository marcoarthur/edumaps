// src/features/home/pages/HomePage.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import HomePage from "./HomePage.svelte";

describe("HomePage", () => {
  it("renderiza o título principal", () => {
    render(HomePage);
    expect(
      screen.getByRole("heading", { level: 1, name: /edumaps/i }),
    ).toBeInTheDocument();
  });

  it("apresenta os quatro pilares do projeto", () => {
    render(HomePage);
    for (const title of [
      /^mapas$/i,
      /^educação$/i,
      /^censo escolar$/i,
      /ferramentas analíticas/i,
    ]) {
      expect(
        screen.getByRole("heading", { level: 2, name: title }),
      ).toBeInTheDocument();
    }
  });

  it("oferece os atalhos para busca de escolas e para análises", () => {
    render(HomePage);
    expect(screen.getByRole("link", { name: /buscar escola/i })).toHaveAttribute(
      "href",
      "/escola/search",
    );
    expect(screen.getByRole("link", { name: /ver análises/i })).toHaveAttribute(
      "href",
      "/cluster/geotag",
    );
  });
});
