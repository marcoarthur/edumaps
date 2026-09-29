<script>
  // src/features/gestor/components/OsmPoisPanel.svelte
  //
  // Equipamentos públicos no entorno da escola (OSM): o gestor escolhe os
  // catálogos (POIs) e o raio do buffer, dispara uma task Minion e acompanha
  // o progresso. Os dados são sobrescritos (upsert); se forem recentes
  // (< 7 dias) pede confirmação. Emite eventos no EventBus (o middleware
  // `logger` registra em DEV).
  import { onMount, onDestroy } from "svelte";
  import { requestOsmPois, getOsmPoisStatus } from "../api/gestorApi.js";
  import { watchJobProgress } from "@/shared/api/taskProgress.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { eventBus } from "@/shared/events";
  import InfoHint from "@/shared/ui/components/InfoHint.svelte";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import OsmPoisMap from "./OsmPoisMap.svelte";
  import {
    OSM_CATALOGS,
    OSM_DEFAULT_PROFILES,
    OSM_RAIO_MIN,
    OSM_RAIO_MAX,
    OSM_RAIO_STEP,
    OSM_RAIO_DEFAULT,
    OSM_RECENT_DAYS,
    OSM_EVENTS,
    daysSince,
    formatUpdatedAt,
    categoryColor,
    categoryLabel,
  } from "../constants/osm.js";

  /** @type {{ inep: string|number }} */
  let { inep } = $props();

  let loading = $state(true);
  let canManage = $state(true);
  let busy = $state(false);
  let error = $state(null);
  let status = $state(null);
  let progress = $state(null);
  let selectedProfiles = $state([...OSM_DEFAULT_PROFILES]);
  let raio = $state(OSM_RAIO_DEFAULT);
  let confirmOpen = $state(false);
  let hidden = $state({});
  let cancelWatch = null;

  const updatedLabel = $derived(formatUpdatedAt(status?.updated_at));
  const recentDays = $derived(daysSince(status?.updated_at));
  const isRecent = $derived(recentDays !== null && recentDays < OSM_RECENT_DAYS);
  const hasMap = $derived(
    !!status &&
      (status.escola?.latitude != null || (status.geojson?.features?.length ?? 0) > 0),
  );

  function toggleCategory(category) {
    hidden = { ...hidden, [category]: !hidden[category] };
  }

  function toggleCatalog(id) {
    if (id === "equipamentos_publicos") {
      selectedProfiles = ["equipamentos_publicos"];
      return;
    }
    let cur = selectedProfiles.filter((p) => p !== "equipamentos_publicos");
    cur = cur.includes(id) ? cur.filter((p) => p !== id) : [...cur, id];
    selectedProfiles = cur.length ? cur : ["equipamentos_publicos"];
  }

  async function loadStatus() {
    loading = true;
    error = null;
    try {
      status = await getOsmPoisStatus(inep);
      canManage = true;
      if (status?.profiles?.length) selectedProfiles = status.profiles;
      if (status?.raio) raio = status.raio;
      // Se já há job em andamento, trava a interface e anexa ao progresso.
      if (status?.job_id) attach(status.job_id);
    } catch (err) {
      status = null;
      // O painel é público, mas a busca exige sessão do gestor da escola.
      if (err instanceof ApiError && (err.status === 401 || err.status === 403)) {
        canManage = false;
      } else {
        error = err instanceof ApiError ? err.message : "Erro ao carregar o status dos equipamentos.";
      }
    } finally {
      loading = false;
    }
  }

  function attach(jobId) {
    busy = true;
    progress = { percent: 0, message: "Acompanhando a busca em andamento…" };
    cancelWatch?.();
    cancelWatch = watchJobProgress(jobId, {
      onProgress: (p) => {
        progress = p;
        eventBus.emit(OSM_EVENTS.PROGRESS, p, { source: "OsmPoisPanel" });
      },
      onDone: async () => {
        busy = false;
        progress = null;
        cancelWatch = null;
        eventBus.emit(OSM_EVENTS.DONE, { inep }, { source: "OsmPoisPanel" });
        addToast("Equipamentos do entorno atualizados.", "success");
        await loadStatus();
      },
      onError: (msg) => {
        busy = false;
        progress = null;
        cancelWatch = null;
        error = msg;
        eventBus.emit(OSM_EVENTS.ERROR, { inep, error: msg }, { source: "OsmPoisPanel" });
        addToast(msg, "error");
      },
    });
  }

  async function submit({ refresh = false } = {}) {
    if (busy) return;
    error = null;
    hidden = {};
    busy = true;
    progress = { percent: 0, message: "Enfileirando…" };
    eventBus.emit(
      OSM_EVENTS.START,
      { inep, raio: Number(raio), profiles: selectedProfiles },
      { source: "OsmPoisPanel" },
    );
    try {
      const { job_id } = await requestOsmPois(inep, {
        raio: Number(raio),
        profiles: selectedProfiles,
        refresh,
      });
      attach(job_id);
    } catch (err) {
      busy = false;
      progress = null;
      const msg = err instanceof ApiError ? err.message : "Não foi possível iniciar a busca.";
      error = msg;
      eventBus.emit(OSM_EVENTS.ERROR, { inep, error: msg }, { source: "OsmPoisPanel" });
    }
  }

  function onClickSearch() {
    if (busy) return;
    if (isRecent) {
      confirmOpen = true;
      return;
    }
    submit();
  }

  onMount(() => {
    // O painel do gestor é público; a busca exige sessão. Restaura o token
    // salvo (localStorage) para as chamadas autenticadas do OSM.
    restaurarSessao();
    loadStatus();
  });
  onDestroy(() => cancelWatch?.());
</script>

<section id="osm-pois" class="space-y-4 scroll-mt-4" aria-label="Equipamentos no entorno (OSM)">
  <div class="flex items-center gap-2">
    <h2 class="text-lg font-bold text-gray-900">Equipamentos no entorno (OSM)</h2>
    <InfoHint
      title="Como buscamos os equipamentos"
      text="Consultamos o OpenStreetMap (Overpass) num raio ao redor da escola e guardamos os equipamentos públicos no banco do EduMaps."
      items={[
        'Escolha os catálogos (ex.: transporte, saúde) e o raio do buffer (100 m a 10 km).',
        'A busca sobrescreve a anterior (upsert) por escola.',
        'Se os dados tiverem menos de 7 dias, pedimos confirmação antes de refazer.',
        'O progresso é acompanhado em tempo real; falhas aparecem na hora.',
      ]}
    />
  </div>

  {#if loading}
    <p class="text-sm text-gray-500">Carregando status…</p>
  {:else if !canManage}
    <p class="text-sm text-gray-600 bg-gray-50 border border-gray-200 rounded-md p-3">
      Entre como gestor desta escola para buscar e atualizar os equipamentos do entorno.
    </p>
  {:else}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="flex flex-col gap-3">
        <fieldset class="flex flex-col gap-2">
          <legend class="text-sm font-medium text-gray-700 mb-1">Catálogos</legend>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
            {#each OSM_CATALOGS as cat (cat.id)}
              <label class="flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="checkbox"
                  class="rounded border-gray-300"
                  checked={selectedProfiles.includes(cat.id)}
                  disabled={busy}
                  onchange={() => toggleCatalog(cat.id)}
                />
                {cat.label}
              </label>
            {/each}
          </div>
        </fieldset>

        <div class="flex flex-col gap-1">
          <label for="osm-raio" class="text-sm font-medium text-gray-700">
            Raio do buffer: <span class="font-mono">{raio} m</span>
          </label>
          <input
            id="osm-raio"
            type="range"
            min={OSM_RAIO_MIN}
            max={OSM_RAIO_MAX}
            step={OSM_RAIO_STEP}
            value={raio}
            disabled={busy}
            oninput={(e) => (raio = Number(e.currentTarget.value))}
            class="w-full"
          />
          <div class="flex justify-between text-xs text-gray-500">
            <span>{OSM_RAIO_MIN} m</span>
            <span>{OSM_RAIO_MAX} m</span>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <button
            type="button"
            onclick={onClickSearch}
            disabled={busy}
            class="px-4 py-2 bg-blue-700 text-white text-sm font-semibold rounded-md hover:bg-blue-800 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {busy ? "Buscando…" : "Buscar equipamentos no entorno"}
          </button>
          {#if updatedLabel}
            <span class="text-xs text-gray-500">Atualizado em {updatedLabel}</span>
          {/if}
        </div>

        {#if busy}
          <div class="flex flex-col gap-1" aria-label="Progresso da busca">
            <div class="h-2 bg-gray-100 rounded overflow-hidden">
              <div
                class="h-full bg-blue-600 transition-all"
                style="width: {Math.min(100, progress?.percent ?? 0)}%"
              ></div>
            </div>
            <p class="text-xs text-gray-600">
              {Math.min(100, Math.round(progress?.percent ?? 0))}% — {progress?.message ?? "Iniciando…"}
            </p>
          </div>
        {/if}

        {#if error}
          <p class="text-sm text-red-700 bg-red-50 border border-red-200 rounded-md p-2">{error}</p>
        {/if}
      </div>

      <div class="flex flex-col gap-3">
        {#if hasMap}
          <OsmPoisMap
            escola={status?.escola}
            features={status?.geojson?.features}
            raio={status?.raio}
            {hidden}
            height="340px"
          />
        {/if}

        <div class="flex flex-col gap-2">
          <h3 class="text-sm font-semibold text-gray-800">
            Equipamentos encontrados {status ? `(${status.total ?? 0})` : ""}
          </h3>
          {#if !status || (status.total ?? 0) === 0}
            <p class="text-sm text-gray-500">Nenhum equipamento carregado ainda.</p>
          {:else}
            <ul class="flex flex-col gap-1">
              {#each status.resumo as row (row.category)}
                <li>
                  <label class="flex items-center justify-between gap-2 text-sm cursor-pointer select-none">
                    <span class="flex items-center gap-2 min-w-0">
                      <input
                        type="checkbox"
                        checked={!hidden[row.category]}
                        disabled={busy}
                        onchange={() => toggleCategory(row.category)}
                      />
                      <span
                        class="w-3 h-3 rounded-full inline-block shrink-0"
                        style:background-color={categoryColor(row.category)}
                      ></span>
                      <span class="text-gray-700 truncate">{categoryLabel(row.category)}</span>
                    </span>
                    <span class="font-mono text-gray-900">{row.count}</span>
                  </label>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</section>

{#if confirmOpen}
  <div class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 p-4">
    <div role="dialog" aria-label="Confirmar atualização" class="bg-white rounded-lg shadow-xl max-w-md w-full p-5">
      <h3 class="text-base font-bold text-gray-900 mb-2">Os dados são recentes</h3>
      <p class="text-sm text-gray-600 mb-4">
        Os equipamentos do entorno foram atualizados há menos de {OSM_RECENT_DAYS} dias.
        Deseja refazer a busca (os dados atuais serão sobrescritos)?
      </p>
      <div class="flex justify-end gap-2">
        <button
          type="button"
          class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100"
          onclick={() => (confirmOpen = false)}
        >
          Cancelar
        </button>
        <button
          type="button"
          class="px-3 py-2 text-sm font-semibold rounded-md bg-blue-700 text-white hover:bg-blue-800"
          onclick={() => {
            confirmOpen = false;
            submit({ refresh: true });
          }}
        >
          Atualizar mesmo assim
        </button>
      </div>
    </div>
  </div>
{/if}
