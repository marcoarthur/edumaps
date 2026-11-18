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
    expect(screen.getByText(/ivet-v1\.8/)).toBeTruthy();
  });

  it("bloco ausente vira n/d, nunca 0 (#154)", () => {
    render(SchoolIvet, {
      props: { ivet: { ...IVET_FIXTURE, blocos: { ...IVET_FIXTURE.blocos, F: null } } },
    });
    // o bloco F mostra "n/d" e não "0.000"
    expect(screen.queryByText("0.000")).toBeNull();
    expect(screen.getAllByText("n/d").length).toBeGreaterThan(0);
  });

  it("sem número: diz os blocos que faltam e mostra os medidos (#489)", () => {
    render(SchoolIvet, { props: { ivet: IVET_NAO_PUBLICAVEL_FIXTURE } });

    const motivo = screen.getByTestId("ivet-motivo");
    expect(motivo.textContent).toMatch(/ainda não pode ser calculado/);
    expect(motivo.textContent).toMatch(/C \(acesso\), D \(saúde\) e E \(segurança\)/);
    // não fala em privacidade
    expect(screen.queryByText(/publicável|amostra insuficiente|sensível/i)).toBeNull();
    // o bloco A medido fica à mostra; sem selo
    expect(screen.getByText("0.437")).toBeTruthy();
    expect(screen.queryByTitle(/quanto maior, mais vulnerável/)).toBeNull();
  });

  it("sem número e sem a lista: motivo genérico, sem privacidade", () => {
    render(SchoolIvet, {
      props: { ivet: { ...IVET_NAO_PUBLICAVEL_FIXTURE, blocos_faltando: undefined } },
    });
    expect(screen.getByTestId("ivet-motivo").textContent).toMatch(/faltam blocos de território/);
  });

  it("rótulos dos blocos seguem o cálculo: D saúde, E segurança, F meio ambiente, G recursos", () => {
    render(SchoolIvet, { props: { ivet: IVET_FIXTURE } });
    for (const r of ["Saúde", "Segurança", "Meio ambiente", "Recursos"]) {
      expect(screen.getByTitle(r)).toBeTruthy();
    }
    expect(screen.queryByTitle("Mobilidade")).toBeNull();
  });

  it("sem medição: mensagem de ausência, sem número", () => {
    render(SchoolIvet, { props: { ivet: null, loading: false } });
    expect(screen.getByText(/ainda não teve o índice/i)).toBeTruthy();
  });
});
