// AppMap.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import AppMap from "../lib/AppMap.svelte";

describe("AppMap", () => {
  it('deve renderizar o componente Header com o nome "EduMaps"', () => {
    render(AppMap);
    const title = screen.queryByText(/EduMaps/iu);
    expect(title).toBeInTheDocument();
  });
});
