// src/app/routes.test.js
import { describe, it, expect } from "vitest";
import { matchRoute } from "./routes.js";

describe("matchRoute", () => {
  it("encontra a rota /about", () => {
    const match = matchRoute("/about");
    expect(match?.path).toBe("/about");
  });

  it("retorna null para rota inexistente", () => {
    expect(matchRoute("/nao-existe")).toBeNull();
  });
});
