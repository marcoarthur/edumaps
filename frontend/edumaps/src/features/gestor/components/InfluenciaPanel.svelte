<script>
  // src/features/gestor/components/InfluenciaPanel.svelte
  //
  // Área de influência da escola (metodologia `influencia-v1`, #255/#137):
  // exibe a geometria já materializada em clean.escola_influencia — um buffer
  // por raio documentado — com legenda que liga/desliga cada raio. Somente
  // leitura: a materialização é feita pelo job `refresh_influencia`.
  //
  // Acesso restrito ao gestor da própria escola (a geometria por escola não é
  // dado público — guarda LGPD da metodologia). Ausência ≠ zero (#154): sem
  // linha na camada, mostramos "ainda não calculada", nunca um buffer vazio.
  import { onMount } from "svelte";
  import { getInfluencia } from "../api/gestorApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import InfoHint from "@/shared/ui/components/InfoHint.svelte";
  import InfluenciaMap from "./InfluenciaMap.svelte";
  import {
    radiusColor,
    radiusLabel,
    radiusPurpose,
    entornoLabel,
    formatAreaKm2,
    formatComputedAt,
  } from "../constants/influencia.js";

  /** @type {{ inep: string|number }} */
  let { inep } = $props();

  let loading = $state(true);
  let canView = $state(true);
  let missing = $state(false);
  let error = $state(null);
  let status = $state(null);
  // Raio -> oculto. Objeto (não Set) para casar com o toggle do mapa.
  let hidden = $state({});

  const features = $derived(status?.geojson?.features ?? []);
  const hasMap = $derived(
    !!status && (status.escola?.latitude != null || features.length > 0),
  );
  const computedLabel = $derived(formatComputedAt(status?.computado_em));

  function toggleRadius(raio) {
    hidden = { ...hidden, [raio]: !hidden[raio] };
  }

  async function load() {
    loading = true;
    error = null;
    missing = false;
    try {
      status = await getInfluencia(inep);
      canView = true;
    } catch (err) {
      status = null;
      if (err instanceof ApiError && (err.status === 401 || err.status === 403)) {
        canView = false;
      } else if (err instanceof ApiError && err.status === 404) {
        missing = true;
      } else {
        error =
          err instanceof ApiError
            ? err.message
            : "Erro ao carregar a área de influência.";
      }
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    restaurarSessao();
    load();
  });
</script>

<section id="influencia" class="space-y-4 scroll-mt-4">
  <div class="flex items-center gap-2">
    <h2 class="text-lg font-bold text-gray-900">Área de influência (IVET)</h2>
    <InfoHint
      title="O que é a área de influência"
      text="É o entorno da escola usado para ler o território no índice IVET. A base é um buffer de raio documentado ao redor da escola, calculado e materializado no servidor (metodologia influencia-v1)."
      items={[
        'A leitura exibida é a população e a densidade estimadas no entorno da escola, por raio (Censo 2022). Onde não há dado, aparece "—" (nunca zero).',
        'Cada raio serve a um grupo de indicadores na metodologia: 500 m (equipamentos e vias), 1 km (uso do solo), 2 km (queimada e chuva) — leituras ainda não materializadas.',
        'A geometria já vem calculada do banco — este painel apenas a exibe, sem recalcular.',
        'A geometria por escola só é mostrada ao gestor da própria escola; não é dado público.',
      ]}
    />
  </div>

  {#if loading}
    <p class="text-sm text-gray-500">Carregando a área de influência…</p>
  {:else if !canView}
    <p class="text-sm text-gray-600 bg-gray-50 border border-gray-200 rounded-md p-3">
      Entre como gestor desta escola para ver a área de influência.
    </p>
  {:else if missing}
    <p class="text-sm text-gray-600 bg-gray-50 border border-gray-200 rounded-md p-3">
      A área de influência desta escola ainda não foi calculada. Ela é gerada
      pela rotina de materialização do território.
    </p>
  {:else if error}
    <p class="text-sm text-red-700 bg-red-50 border border-red-200 rounded-md p-3">
      {error}
    </p>
  {:else}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="flex flex-col gap-3">
        <p class="text-sm text-gray-600">
          A plataforma considera o entorno da escola em três raios. A leitura é a
          população e a densidade estimadas no entorno (Censo 2022). Ligue ou
          desligue um raio na legenda.
        </p>

        <ul class="flex flex-col gap-2">
          {#each features as feature (feature.properties.raio_m)}
            {@const raio = feature.properties.raio_m}
            <li>
              <label class="flex items-start justify-between gap-2 text-sm cursor-pointer select-none">
                <span class="flex items-start gap-2 min-w-0">
                  <input
                    type="checkbox"
                    class="rounded border-gray-300 mt-0.5"
                    checked={!hidden[raio]}
                    onchange={() => toggleRadius(raio)}
                  />
                  <span
                    class="w-3 h-3 rounded-full inline-block shrink-0 mt-1"
                    style:background-color={radiusColor(raio)}
                  ></span>
                  <span class="min-w-0">
                    <span class="text-gray-900 font-medium">{radiusLabel(raio)}</span>
                    <span class="block text-xs text-gray-500">{radiusPurpose(raio)}</span>
                    <span class="block text-xs text-gray-700">
                      {entornoLabel(feature.properties.entorno)}
                    </span>
                  </span>
                </span>
                <span class="font-mono text-gray-700 whitespace-nowrap">
                  {formatAreaKm2(feature.properties.area_km2)}
                </span>
              </label>
            </li>
          {/each}
        </ul>

        <p class="text-xs text-gray-500">
          {status.versao} · tier {status.tier} · Censo {status.nu_ano_censo}{#if computedLabel},
            calculada em {computedLabel}{/if}
        </p>
      </div>

      <div>
        {#if hasMap}
          <InfluenciaMap escola={status.escola} {features} {hidden} height="340px" />
        {:else}
          <p class="text-sm text-gray-500">Sem geometria para desenhar.</p>
        {/if}
      </div>
    </div>
  {/if}
</section>
