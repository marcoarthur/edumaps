// src/features/map/components/LeafletMap.test.js
import { render } from "@testing-library/svelte";
import { describe, it, expect } from "vitest";
import LeafletMap from "./LeafletMap.svelte";

describe("LeafletMap", () => {
  it("renderiza o container do mapa", () => {
    const { container } = render(LeafletMap, { props: { center: [-23.56, -45.75], zoom: 12 } });
    expect(container.querySelector(".leaflet-container")).toBeInTheDocument();
  });

  it("expõe getMap() após montagem", async () => {
    const { component } = render(LeafletMap);
    await new Promise((r) => setTimeout(r, 0)); // aguarda onMount
    expect(component.getMap()).toBeTruthy();
  });
});
