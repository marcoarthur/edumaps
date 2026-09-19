<!-- src/features/gestor/components/survey/OpcaoBars.svelte -->
<script>
  // Gráfico de barras horizontais em SVG puro (sem biblioteca de charts —
  // decisão da fase 2). Renderiza a distribuição das respostas de uma
  // pergunta de escolha (unica/multipla/dropdown).
  /** @type {{opcoes: Array<{id:string,label:string,count:number,pct:number}>, total?:number}} */
  let { opcoes = [], total = 0 } = $props();

  const ROW_H = 30;
  const PAD_TOP = 18;
  const LABEL_W = 118;
  const GAP = 10;
  const BAR_W = 132;
  const VALUE_W = 52;

  const WIDTH = $derived(LABEL_W + GAP + BAR_W + GAP + VALUE_W);
  const HEIGHT = $derived(PAD_TOP + opcoes.length * ROW_H);
  const maxPct = $derived(Math.max(...opcoes.map((o) => o.pct || 0), 1));

  function barWidth(pct) {
    return Math.round(((pct || 0) / maxPct) * BAR_W);
  }
</script>

<svg
  width="100%"
  style="max-width:{WIDTH}px"
  viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
  role="img"
  aria-label="Distribuição das respostas"
  data-testid="opcao-bars"
>
  {#each opcoes as op, i (op.id)}
    {@const y = PAD_TOP + i * ROW_H}
    <text x="0" y={y + 12} font-size="11" fill="#374151" text-anchor="start">
      {op.label}
    </text>
    <rect
      x={LABEL_W + GAP}
      y={y}
      width={barWidth(op.pct)}
      height="14"
      rx="3"
      fill="#2563eb"
    />
    <text
      x={LABEL_W + GAP + BAR_W + GAP}
      y={y + 12}
      font-size="11"
      fill="#1f2937"
      text-anchor="start"
    >
      {op.count} ({op.pct}%)
    </text>
  {/each}
  <text x="0" y={HEIGHT - 5} font-size="10" fill="#9ca3af">
    {total} resposta{total === 1 ? "" : "s"}
  </text>
</svg>