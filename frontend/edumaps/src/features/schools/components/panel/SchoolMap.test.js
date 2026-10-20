// src/features/schools/components/panel/SchoolMap.test.js
//
// Foco na camada de isócrona (#296, PR3): a legenda é clicável e liga/desliga
// cada faixa, e as células H3 viram polígonos (via h3-js). O Leaflet real não
// é exercitado aqui — isolamos o componente de mapa com um stub que entrega
// um mapa falso para o onMapReady, como nos testes de cluster-geotag.
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolMap from "./SchoolMap.svelte";
import { ISOCRONA_FIXTURE } from "../../mocks/fixtures.js";

vi.mock("@/features/map/components/LeafletMap.svelte", async () => {
  const stub = (await import("./__stubs__/LeafletMapStub.svelte")).default;
  return { default: stub };
});

describe("SchoolMap — isócrona", () => {
  const baseProps = {
    latitude: -19.9,
    longitude: -43.9,
    schoolName: "Escola Teste",
    zoom: 13,
  };

  it("desenha a legenda das faixas quando há isócrona", async () => {
    render(SchoolMap, { props: { ...baseProps, isocrona: ISOCRONA_FIXTURE } });

    expect(await screen.findByRole("button", { name: /15 min a pé/ })).toBeTruthy();
    expect(screen.getByRole("button", { name: /45 min de carro/ })).toBeTruthy();
  });

  it("não mostra a legenda sem isócrona", () => {
    render(SchoolMap, { props: { ...baseProps, isocrona: null } });
    expect(screen.queryByLabelText(/área de influência/i)).toBeNull();
  });

  it("a legenda alterna a visibilidade da faixa (aria-pressed)", async () => {
    render(SchoolMap, { props: { ...baseProps, isocrona: ISOCRONA_FIXTURE } });

    const btn15 = await screen.findByRole("button", { name: /15 min a pé/ });
    expect(btn15.getAttribute("aria-pressed")).toBe("true");

    await fireEvent.click(btn15);
    expect(btn15.getAttribute("aria-pressed")).toBe("false");

    await fireEvent.click(btn15);
    expect(btn15.getAttribute("aria-pressed")).toBe("true");
  });
});
