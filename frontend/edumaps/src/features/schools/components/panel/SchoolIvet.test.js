// src/features/schools/components/panel/SchoolIvet.test.js
import { render, screen } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import SchoolIvet from "./SchoolIvet.svelte";
import {
  IVET_FIXTURE,
  IVET_NAO_PUBLICAVEL_FIXTURE,
} from "../../mocks/fixtures.js";

describe("SchoolIvet", () => {
  it("exibe o índice e os blocos A–G quando publicável", () => {
    render(SchoolIvet, { props: { ivet: IVET_FIXTURE } });

    expect(screen.getByText("0.412")).toBeTruthy();
    // bloco C calculado aparece formatado
    expect(screen.getByText("0.390")).toBeTruthy();
    // proveniência visível
    expect(screen.getByText(/ivet-v1\.2/)).toBeTruthy();
  });

  it("bloco ausente vira n/d, nunca 0 (#154)", () => {
    render(SchoolIvet, {
      props: { ivet: { ...IVET_FIXTURE, blocos: { ...IVET_FIXTURE.blocos, F: null } } },
    });
    // o bloco F mostra "n/d" e não "0.000"
    expect(screen.queryByText("0.000")).toBeNull();
    expect(screen.getAllByText("n/d").length).toBeGreaterThan(0);
  });

  it("LGPD: não publicável esconde os valores e mostra o aviso", () => {
    render(SchoolIvet, { props: { ivet: IVET_NAO_PUBLICAVEL_FIXTURE } });

    expect(screen.getByText(/não é publicável/i)).toBeTruthy();
    // nenhum valor de bloco é exibido
    expect(screen.queryByText("0.412")).toBeNull();
    expect(screen.queryByText("0.390")).toBeNull();
  });

  it("sem medição: mensagem de ausência, sem número", () => {
    render(SchoolIvet, { props: { ivet: null, loading: false } });
    expect(screen.getByText(/ainda não teve o índice/i)).toBeTruthy();
  });
});
