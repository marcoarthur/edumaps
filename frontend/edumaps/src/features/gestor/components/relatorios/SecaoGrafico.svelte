<!-- src/features/gestor/components/relatorios/SecaoGrafico.svelte -->
<script>
  // Seção de gráfico (#219): barras ou linhas pelos wrappers Carbon de
  // shared/ui/components/charts. Acessibilidade: descrição textual dos valores
  // (aria-describedby) e os mesmos dados numa tabela recolhível.
  import BarChartGrouped from "@/shared/ui/components/charts/BarChartGrouped.svelte";
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";
  import SecaoTabela from "./SecaoTabela.svelte";
  import { formatarValor } from "../../utils/relatorioFormatos.js";
  import { dadosGrafico, descricaoGrafico } from "../../utils/relatorioGrafico.js";

  /** @type {{secao: object}} */
  let { secao } = $props();

  const linhas = $derived(secao.grafico === "linhas");
  const rows = $derived(dadosGrafico(secao));
  const descricao = $derived(descricaoGrafico(secao, formatarValor));

  const options = $derived({
    title: secao.titulo ?? "",
    axes: {
      left: { mapsTo: "value", title: secao.y?.rotulo ?? "" },
      bottom: { mapsTo: "key", scaleType: "labels", title: secao.x?.rotulo ?? "" },
    },
    data: { groupMapsTo: "group" },
    legend: { position: "bottom" },
    ...(linhas ? { curve: "curveMonotoneX" } : {}),
  });

  const tabela = $derived({
    id: `${secao.id}-dados`,
    titulo: `Dados: ${secao.titulo ?? ""}`,
    colunas: [
      { id: secao.x?.id, rotulo: secao.x?.rotulo ?? secao.x?.id, formato: "texto" },
      ...(secao.series ?? []).map((s) => ({ id: s.id, rotulo: s.rotulo ?? s.id, formato: s.formato ?? secao.formato })),
    ],
    linhas: secao.dados ?? [],
  });
</script>

<section class="space-y-2" data-testid="secao-grafico" data-grafico={linhas ? "linhas" : "barras"}>
  <figure
    class="bg-white border border-gray-200 rounded-card shadow-card p-4 print:shadow-none print:break-inside-avoid"
    aria-describedby="grafico-desc-{secao.id}"
  >
    {#if rows.length > 0}
      {#if linhas}
        <LineChart data={rows} {options} height="320px" />
      {:else}
        <BarChartGrouped data={rows} {options} height="320px" />
      {/if}
    {:else}
      <p class="text-sm font-semibold text-gray-900">{secao.titulo}</p>
      <p class="text-sm text-gray-500 mt-2">Sem dados para este gráfico.</p>
    {/if}
    <figcaption id="grafico-desc-{secao.id}" class="sr-only" data-testid="grafico-descricao">
      {descricao}
    </figcaption>
  </figure>
  {#if rows.length > 0}
    <details class="text-sm">
      <summary class="cursor-pointer text-blue-700 hover:underline print:hidden">Ver os dados do gráfico em tabela</summary>
      <div class="mt-2"><SecaoTabela secao={tabela} /></div>
    </details>
  {/if}
</section>
