<!-- src/features/chat/components/ChatGrafico.svelte -->
<script>
  // Gráfico da resposta do Assistente do Censo (#224): barras, linhas ou
  // pizza (Donut) pelos wrappers Carbon de shared/ui/components/charts.
  // Acessibilidade: descrição textual dos valores (aria-describedby) e os
  // mesmos dados numa tabela recolhível. A spec já vem normalizada
  // (utils/chatGrafico.js → graficoDoChat).
  import BarChartGrouped from "@/shared/ui/components/charts/BarChartGrouped.svelte";
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import { linhasGrafico, descricaoGraficoChat } from "../utils/chatGrafico.js";

  /** @type {{spec: {tipo: string, titulo: string, xRotulo: string, yRotulo: string, pontos: Array<{key: string, value: number}>}}} */
  let { spec } = $props();

  const uid = $props.id();
  const rows = $derived(linhasGrafico(spec));
  const descricao = $derived(descricaoGraficoChat(spec));

  const options = $derived(
    spec.tipo === "pizza"
      ? {
          title: spec.titulo,
          data: { groupMapsTo: "group" },
          legend: { position: "bottom" },
        }
      : {
          title: spec.titulo,
          axes: {
            left: { mapsTo: "value", title: spec.yRotulo },
            bottom: { mapsTo: "key", scaleType: "labels", title: spec.xRotulo },
          },
          data: { groupMapsTo: "group" },
          legend: { enabled: false },
          ...(spec.tipo === "linha" ? { curve: "curveMonotoneX" } : {}),
        },
  );

  const fmt = (v) => v.toLocaleString("pt-BR");
</script>

<div class="mt-3 space-y-2" data-testid="chat-grafico" data-grafico={spec.tipo}>
  <figure class="bg-white border border-gray-200 rounded-lg p-3" aria-describedby="chat-grafico-desc-{uid}">
    {#if spec.tipo === "pizza"}
      <DonutChart data={rows} {options} height="280px" />
    {:else if spec.tipo === "linha"}
      <LineChart data={rows} {options} height="280px" />
    {:else}
      <BarChartGrouped data={rows} {options} height="280px" />
    {/if}
    <figcaption id="chat-grafico-desc-{uid}" class="sr-only" data-testid="chat-grafico-descricao">
      {descricao}
    </figcaption>
  </figure>
  <details class="text-xs">
    <summary class="cursor-pointer opacity-70 hover:opacity-100">Ver os dados do gráfico em tabela</summary>
    <table class="mt-2 min-w-full text-xs bg-white border border-gray-200 rounded">
      <caption class="sr-only">Dados: {spec.titulo || "gráfico da resposta"}</caption>
      <thead class="bg-gray-50 text-gray-600">
        <tr>
          <th scope="col" class="text-left font-medium px-2 py-1">{spec.xRotulo || "Categoria"}</th>
          <th scope="col" class="text-right font-medium px-2 py-1">{spec.yRotulo || "Valor"}</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each spec.pontos as p, i (i)}
          <tr>
            <th scope="row" class="text-left font-normal px-2 py-1">{p.key}</th>
            <td class="text-right px-2 py-1 tabular-nums">{fmt(p.value)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </details>
</div>
