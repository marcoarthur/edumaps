<!-- src/features/gestor/components/planos/MetaHistorico.svelte -->
<script>
  // Gráfico simples (SVG) do histórico de medições de uma meta, com as linhas
  // da linha de base e do alvo. Sem dependência de biblioteca de gráficos.
  let { medicoes = [], linhaBase = null, alvo = null, rotulo = "Histórico da meta" } = $props();

  const W = 240;
  const H = 56;
  const PAD = 6;

  let pontos = $derived(medicoes.filter((m) => m.valor !== null && m.valor !== undefined));
  let escala = $derived.by(() => {
    const vals = [...pontos.map((m) => m.valor), linhaBase, alvo].filter((v) => v !== null && v !== undefined);
    if (!vals.length) return null;
    let min = Math.min(...vals);
    let max = Math.max(...vals);
    if (min === max) { min -= 1; max += 1; }
    return { min, max };
  });
  const y = (v, e) => H - PAD - ((v - e.min) / (e.max - e.min)) * (H - 2 * PAD);
  const x = (i, n) => (n <= 1 ? W / 2 : PAD + (i / (n - 1)) * (W - 2 * PAD));
  let linha = $derived(
    escala ? pontos.map((m, i) => `${x(i, pontos.length)},${y(m.valor, escala)}`).join(" ") : "",
  );
</script>

{#if escala && pontos.length}
  <svg viewBox={`0 0 ${W} ${H}`} class="w-full max-w-xs h-14" role="img" aria-label={rotulo}>
    {#if linhaBase !== null && linhaBase !== undefined}
      <line x1="0" x2={W} y1={y(linhaBase, escala)} y2={y(linhaBase, escala)} stroke="#9ca3af" stroke-dasharray="3 3" stroke-width="1" />
    {/if}
    {#if alvo !== null && alvo !== undefined}
      <line x1="0" x2={W} y1={y(alvo, escala)} y2={y(alvo, escala)} stroke="#16a34a" stroke-dasharray="4 2" stroke-width="1" />
    {/if}
    <polyline points={linha} fill="none" stroke="#2563eb" stroke-width="2" />
    {#each pontos as m, i (m.id)}
      <circle cx={x(i, pontos.length)} cy={y(m.valor, escala)} r="2.5" fill="#2563eb">
        <title>{m.ano_ref ?? m.data_ref}: {m.valor}</title>
      </circle>
    {/each}
  </svg>
{/if}
