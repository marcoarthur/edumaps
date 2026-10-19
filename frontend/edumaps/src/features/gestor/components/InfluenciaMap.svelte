<script>
  // src/features/gestor/components/InfluenciaMap.svelte
  //
  // Mapa da área de influência materializada (clean.escola_influencia): o
  // marcador da escola e um polígono por raio, vindos do backend como GeoJSON
  // (a geometria real, não um círculo recalculado no cliente). A visibilidade
  // por raio é controlada pelo pai via `hidden` (a legenda é o resumo).
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import {
    radiusColor,
    radiusLabel,
    radiusPurpose,
    formatAreaKm2,
    ringCartela,
  } from "../constants/influencia.js";
  import L from "leaflet";

  let {
    escola = null,
    features = [],
    hidden = {},
    height = "340px",
    class: className = "",
  } = $props();

  let mapRef = $state(null);
  // Camadas por raio. É $state para o efeito de visibilidade reagir a cada novo
  // desenho; o efeito de desenho ESCREVE (nunca lê) esta variável.
  let layersByRadius = $state({});
  // Cartela (rótulo do anel sobre a própria geometria) por raio. Mesmo ciclo de
  // vida das camadas: criada no desenho, ligada/desligada pelo toggle `hidden`.
  let cartelasByRadius = $state({});

  const SCHOOL_SVG =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="30" height="30">' +
    '<path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7z" ' +
    'fill="#1d4ed8" stroke="#ffffff" stroke-width="1.5"/>' +
    '<circle cx="12" cy="9" r="2.6" fill="#ffffff"/></svg>';

  function schoolIcon() {
    return L.divIcon({
      className: "influencia-school-marker",
      html: SCHOOL_SVG,
      iconSize: [30, 30],
      iconAnchor: [15, 30],
      popupAnchor: [0, -30],
    });
  }

  function popupHtml(feature) {
    const p = feature.properties ?? {};
    return (
      `<b>${radiusLabel(p.raio_m)}</b><br>` +
      `${radiusPurpose(p.raio_m)}<br>` +
      `Área: ${formatAreaKm2(p.area_km2)}<br>` +
      `<span style="color:#6b7280">${p.versao ?? "influencia-v1"} · ${p.tier ?? "buffer"}</span>`
    );
  }

  // Cartela do anel: identifica o entorno sobre a própria geometria (raio, a
  // leitura do entorno pelo Censo 2022 e a área). HTML inline (não CSS
  // scoped): o Leaflet injeta este conteúdo fora do alcance do Svelte.
  function cartelaHtml(cartela) {
    return (
      `<span style="display:inline-flex;flex-direction:column;gap:1px;` +
      `background:rgba(255,255,255,0.94);border:1px solid #e5e7eb;` +
      `border-left:4px solid ${cartela.color};border-radius:6px;` +
      `padding:4px 8px;box-shadow:0 1px 5px rgba(15,23,42,0.18);` +
      `font:11px/1.3 system-ui,-apple-system,sans-serif;white-space:nowrap;` +
      `color:#374151">` +
      `<b style="font-size:12px;color:#111827">${cartela.label}</b>` +
      `<span style="color:#374151">${cartela.entorno}</span>` +
      `<span style="font-family:ui-monospace,SFMono-Regular,monospace">${cartela.area}</span>` +
      `</span>`
    );
  }

  function cartelaIcon(cartela) {
    return L.divIcon({
      className: "influencia-cartela",
      html:
        `<div style="position:absolute;left:0;top:0;` +
        `transform:translate(-50%,-50%);pointer-events:none">` +
        cartelaHtml(cartela) +
        `</div>`,
      iconSize: [0, 0],
      iconAnchor: [0, 0],
    });
  }

  // Coordenadas [lng, lat] das posições da geometria (Polygon ou MultiPolygon).
  function ringPoints(feature) {
    const g = feature?.geometry;
    if (!g) return [];
    if (g.type === "MultiPolygon") return g.coordinates.flat(2);
    if (g.type === "Polygon") return g.coordinates.flat(1);
    return [];
  }

  // Vértice da geometria mais próximo de uma direção (0° = norte). Ancora a
  // cartela na borda do anel, mantendo-a dentro do recorte quando possível.
  function pointAtBearing(feature, bearingDeg) {
    const points = ringPoints(feature);
    if (!points.length) return null;
    let cx = 0;
    let cy = 0;
    for (const [lng, lat] of points) {
      cx += lng;
      cy += lat;
    }
    cx /= points.length;
    cy /= points.length;
    const target = ((bearingDeg % 360) + 360) % 360;
    let best = null;
    let bestDiff = Infinity;
    for (const [lng, lat] of points) {
      const norm = ((Math.atan2(lng - cx, lat - cy) * 180) / Math.PI + 360) % 360;
      const diff = Math.min(Math.abs(norm - target), 360 - Math.abs(norm - target));
      if (diff < bestDiff) {
        bestDiff = diff;
        best = [lat, lng];
      }
    }
    return best;
  }

  // Direções candidatas (0° = norte) para ancorar a cartela de um anel. A
  // direção final é escolhida por anel para não sobrepor cartelas largas de
  // anéis concêntricos nem deixá-las fora do mapa.
  const CARTELA_BEARINGS = [0, 45, 90, 135, 180, 225, 270, 315];
  const CARTELA_W = 240; // largura típica estimada (px)
  const CARTELA_H = 56; // altura típica estimada (px)

  // Para cada anel (do menor para o maior), escolhe a direção cuja cartela caiba
  // no mapa e não colida com as já posicionadas. Devolve { raio: [lat, lng] }.
  function chooseAnchors(entries) {
    const size = mapRef?.getSize?.() ?? { x: 0, y: 0 };
    const placed = [];
    const anchors = {};
    for (const { raio, feature } of entries) {
      let best = null;
      let fallback = null;
      for (const bearing of CARTELA_BEARINGS) {
        const ll = pointAtBearing(feature, bearing);
        if (!ll) continue;
        const p = mapRef.latLngToContainerPoint(ll);
        const inside =
          p.x - CARTELA_W / 2 > 4 &&
          p.x + CARTELA_W / 2 < size.x - 4 &&
          p.y - CARTELA_H / 2 > 4 &&
          p.y + CARTELA_H / 2 < size.y - 4;
        const collides = placed.some(
          (q) => Math.abs(p.x - q.x) < CARTELA_W && Math.abs(p.y - q.y) < CARTELA_H,
        );
        if (inside && !collides) {
          best = { ll, p };
          break;
        }
        if (inside && !fallback) fallback = { ll, p };
      }
      const pick = best ?? fallback;
      if (pick) {
        anchors[raio] = pick.ll;
        placed.push(pick.p);
      }
    }
    return anchors;
  }

  function draw() {
    if (!mapRef) return;

    // Limpa o que este componente desenhou (marcador + camadas GeoJSON).
    mapRef.eachLayer((layer) => {
      if (layer instanceof L.GeoJSON || layer instanceof L.Marker) mapRef.removeLayer(layer);
    });

    let bounds = null;
    const extend = (b) => {
      if (!b) return;
      try {
        bounds = bounds ? bounds.extend(b) : b;
      } catch (e) {
        /* bounds vazio — ignora */
      }
    };

    if (escola?.latitude != null && escola?.longitude != null) {
      L.marker([escola.latitude, escola.longitude], { icon: schoolIcon() })
        .bindPopup(`<b>${escola.nome ?? "Escola"}</b>`)
        .addTo(mapRef);
      extend(L.latLngBounds([escola.latitude, escola.longitude], [escola.latitude, escola.longitude]));
    }

    const next = {};
    const entries = [];
    for (const feature of features ?? []) {
      const raio = Number(feature.properties?.raio_m ?? 0);
      const layer = L.geoJSON(feature, {
        style: {
          color: radiusColor(raio),
          weight: 2,
          fillColor: radiusColor(raio),
          fillOpacity: 0.08,
        },
      });
      layer.bindPopup(popupHtml(feature));
      layer.addTo(mapRef);
      next[raio] = layer;
      entries.push({ raio, feature });
      extend(layer.getBounds());
    }

    layersByRadius = next;

    // Enquadra antes de posicionar as cartelas: a escolha da direção depende da
    // projeção final (tamanho/centro do mapa).
    if (bounds?.isValid?.()) {
      // Folga extra para as cartelas, que ficam centradas na borda do anel.
      // Sem animação: a projeção usada para posicionar as cartelas logo abaixo
      // precisa já estar na vista final.
      mapRef.fitBounds(bounds, { padding: [50, 50], maxZoom: 16, animate: false });
    }

    const nextCartelas = {};
    const anchors = chooseAnchors(
      [...entries].sort((a, b) => a.raio - b.raio),
    );
    for (const { raio, feature } of entries) {
      const anchor = anchors[raio];
      if (!anchor) continue;
      const cartela = L.marker(anchor, {
        icon: cartelaIcon(ringCartela(feature.properties)),
        interactive: false,
        keyboard: false,
      });
      cartela.addTo(mapRef);
      nextCartelas[raio] = cartela;
    }

    cartelasByRadius = nextCartelas;
  }

  // Redesenha quando chegam dados (mapa pronto, escola ou feições).
  // NÃO lê `hidden` — deve apenas escrever `layersByRadius`.
  $effect(() => {
    if (mapRef && ((features?.length ?? 0) > 0 || escola?.latitude != null)) {
      draw();
    }
  });

  // Aplica o toggle de raios sempre que as camadas ou `hidden` mudam.
  $effect(() => {
    for (const [raio, layer] of Object.entries(layersByRadius)) {
      const visible = !hidden?.[raio];
      if (visible) mapRef?.addLayer(layer);
      else mapRef?.removeLayer(layer);
    }
    for (const [raio, cartela] of Object.entries(cartelasByRadius)) {
      const visible = !hidden?.[raio];
      if (visible) mapRef?.addLayer(cartela);
      else mapRef?.removeLayer(cartela);
    }
  });
</script>

<div class="relative rounded-card overflow-hidden border border-gray-200" style:height>
  <LeafletMap
    center={[escola?.latitude ?? -15.5, escola?.longitude ?? -55.0]}
    zoom={14}
    {height}
    {className}
    onMapReady={(map) => {
      mapRef = map;
    }}
  />
</div>
