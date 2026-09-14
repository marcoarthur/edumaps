# Skill: frontend-svelte

## Purpose
Auxiliar no desenvolvimento frontend do EduMaps (Svelte 5 / Vite / Leaflet /
MSW / Vitest) — em especial os padrões de UI reutilizáveis de mapas e
componentes interativos.

## Stack do projeto
- Svelte 5 (runes: `$state`, `$derived`, `$props`, `$effect`), Vite
- Leaflet (`@/features/map/components/LeafletMap.svelte`)
- MSW (`mocks/handlers.js`) + Vitest (`@testing-library/svelte`)
- Frontend ativo: `frontend/edumaps` (não `frontend/map_app`)

## Testes
```bash
cd frontend/edumaps
npx vitest run src/features/<feature>   # feature isolada
npm run test:run                         # suíte completa
npm run build                            # build vite
```
- O polling de job usa `setTimeout(..., 1500)`; testes que dependem do fim do
  job devem usar `waitFor(..., { timeout: 3000 })` / `findByRole(..., { timeout: 3000 })`
  (o default de 1000 ms é menor que o primeiro tick do polling).

## Padrão: marcadores acionáveis quando representam grupos

Quando um mapa coloriza marcadores por **grupo** (ex.: cluster, categoria),
a legenda deve ser **clicável** para ligar/desligar o grupo — os markers do
grupo aparecem (on) ou somem (off) sem recarregar os dados.

Aplicado em `src/features/cluster-geotag/components/ClusterSchoolMap.svelte`.

### Estrutura
1. Estado de visibilidade por grupo — um `Set` reatribuído a cada toggle
   (reassinar dispara a reatividade do Svelte de forma simples e robusta):
   ```js
   let hiddenIds = $state(new Set());

   function toggleGroup(id) {
     const next = new Set(hiddenIds);
     if (next.has(id)) next.delete(id);
     else next.add(id);
     hiddenIds = next;
   }
   ```
2. Desenho dos markers filtra os grupos ocultos e re-ajusta o `fitBounds`
   só aos pontos visíveis:
   ```js
   function drawMarkers() {
     if (!mapRef) return;
     clearAll();
     const points = [];
     for (const feature of markers) {
       const groupId = groupKey(feature.properties?.group_id);
       if (hiddenIds.has(groupId)) continue;   // off
       // ... cria CircleMarker, adiciona, points.push(...)
     }
     if (points.length > 0) mapRef.fitBounds(L.latLngBounds(points), { padding: [40, 40] });
   }
   ```
3. A legenda usa `<button>` por grupo (acessível via `aria-pressed`), com
   indicação visual de oculto (opacidade + `line-through`):
   ```svelte
   {#each groupIds as id}
     {@const hidden = hiddenIds.has(id)}
     <button type="button" onclick={() => toggleGroup(id)} aria-pressed={!hidden}
             class="flex items-center gap-2 w-full text-left ...">
       <span class="w-3 h-3 rounded-full inline-block" class:opacity-30={hidden}
             style:background-color={groupColor(id)}></span>
       <span class="grow" class:line-through={hidden} class:opacity-50={hidden}>
         {labelsByGroup[id] ?? `Grupo ${id}`}
       </span>
       <span class="text-xs text-gray-400">({countsByGroup[id] ?? 0})</span>
     </button>
   {/each}
   ```
4. Re-render via `$effect` que depende de `markers` e de `hiddenIds`:
   ```js
   $effect(() => { if (mapRef && markers.length > 0) drawMarkers(); });
   ```

### Convenções
- `clusterColor(id)` / `clusterLabel(label, id)` vivem em
  `constants/cluster.js` (paleta + fallback `Grupo N`).
- Testar o toggle pelo `aria-pressed` do botão (não inspeciona o Leaflet):
  ```js
  const btn = await screen.findByRole("button", { name: /Baixa qualidade/ }, { timeout: 3000 });
  expect(btn.getAttribute("aria-pressed")).toBe("true");
  await fireEvent.click(btn);
  expect(btn.getAttribute("aria-pressed")).toBe("false");
  ```
