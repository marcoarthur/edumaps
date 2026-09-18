<script>
  // src/features/gestor/components/SimilarSchoolsSearch.svelte
  //
  // Busca de escolas similares no painel do gestor: dropdown de escopo
  // (município/estado/região) + mapa de marcadores + tabela de resultados.
  // Cada escola listada leva ao painel da escola (/escola/panel?inep=).
  import { getSchoolSimilares } from "../api/gestorApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { SCOPE_OPTIONS } from "../constants/gestor.js";
  import LeafletMap from "@/features/map/components/LeafletMap.svelte";
  import SimilarMarkers from "./SimilarMarkers.svelte";

  /** @type {{ inep: string|number }} */
  let { inep } = $props();

  let scope = $state("municipio");
  let data = $state(null);
  let loading = $state(false);
  let error = $state(null);

  const PORTE_LABELS = {
    "Até 50 matrículas de escolarização": "Até 50",
    "Entre 51 e 200 matrículas de escolarização": "51–200",
    "Entre 201 e 500 matrículas de escolarização": "201–500",
    "Entre 501 e 1000 matrículas de escolarização": "501–1000",
    "Mais de 1000 matrículas de escolarização": "Mais de 1000",
    "Escola sem matrícula de escolarização": "Sem matrícula",
  };

  function porteLabel(value) {
    return PORTE_LABELS[value] ?? value ?? "—";
  }

  function formatInse(value) {
    return value != null ? value : "—";
  }

  function formatSimilarity(value) {
    return value != null ? `${Math.round(value * 100)}%` : "—";
  }

  async function search() {
    loading = true;
    error = null;
    data = null;
    try {
      data = await getSchoolSimilares(inep, { scope, limit: 10 });
    } catch (err) {
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao buscar escolas similares.";
    } finally {
      loading = false;
    }
  }
</script>

<section id="escolas-similares" class="space-y-4 scroll-mt-4">
  <div class="flex flex-wrap items-end justify-between gap-3">
    <div>
      <h2 class="text-lg font-bold text-gray-900">Escolas similares</h2>
      <p class="text-sm text-gray-600">
        Busca escolas com porte, localização, condições socioeconômicas (INSE)
        e etapas de ensino parecidas.
      </p>
    </div>
    <div class="flex items-center gap-2">
      <label class="text-sm font-medium text-gray-700" for="similar-scope">
        Escopo
      </label>
      <select
        id="similar-scope"
        class="h-9 px-2 text-sm rounded-md border border-gray-300 bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
        bind:value={scope}
        onchange={search}
      >
        {#each SCOPE_OPTIONS as opt (opt.value)}
          <option value={opt.value}>{opt.label}</option>
        {/each}
      </select>
      <button
        type="button"
        onclick={search}
        disabled={loading}
        class="h-9 px-3 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-60 transition-colors"
      >
        {loading ? "Buscando…" : "Buscar escolas similares"}
      </button>
    </div>
  </div>

  {#if loading}
    <p class="text-gray-500">Buscando escolas similares…</p>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if data}
    {#if data.similares.length === 0}
      <p class="text-gray-500">
        Nenhuma escola semelhante encontrada no escopo {scope} para {inep}.
      </p>
    {:else}
      <p class="text-xs text-gray-500">
        {data.similares.length} escolas mais semelhantes · escopo:
        {scope} · INSE ausente é ignorado na comparação.
      </p>

      <LeafletMap height="340px" zoom={5}>
        <SimilarMarkers target={data.escola_alvo} schools={data.similares} />
      </LeafletMap>

      <div class="overflow-x-auto bg-white border border-gray-200 rounded-card shadow-card">
        <table class="w-full text-sm border-collapse">
          <thead>
            <tr>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Escola</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Município</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">UF</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Porte</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Localização</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">INSE</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Etapas</th>
              <th class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100">Similaridade</th>
            </tr>
          </thead>
          <tbody>
            {#each data.similares as s (s.id_escola)}
              <tr class="border-b border-gray-200 hover:bg-gray-50">
                <td class="px-4 py-2">
                  <a
                    href={`/escola/panel?inep=${s.id_escola}`}
                    class="text-blue-600 hover:underline"
                  >
                    {s.nome}
                  </a>
                </td>
                <td class="px-4 py-2">{s.municipio}</td>
                <td class="px-4 py-2">{s.uf}</td>
                <td class="px-4 py-2">{porteLabel(s.porte_escola)}</td>
                <td class="px-4 py-2">{s.localizacao}</td>
                <td class="px-4 py-2">{formatInse(s.media_inse)}</td>
                <td class="px-4 py-2">{s.etapas}</td>
                <td class="px-4 py-2 font-mono">{formatSimilarity(s.similarity)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
  {/if}
</section>