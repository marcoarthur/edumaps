<!-- src/features/gestor/components/planos/MetaHistorico.svelte -->
<script>
  // Gráfico simples (SVG) do histórico de medições de uma meta, com as linhas
  // da linha de base e do alvo. Sem dependência de biblioteca de gráficos.
  // Cada ponto leva o ano (ou a data) embaixo, e a legenda explica as linhas
  // (#383, achado P1-PG-03 da avaliação das personas).
  import { fmtData, fmtNum } from "../../constants/planos.js";

  let { medicoes = [], linhaBase = null, alvo = null, rotulo = "Histórico da meta" } = $props();

  const W = 240;
  const H = 70;
  const PAD = 6;
  const EIXO = 12; // faixa de baixo para os rótulos de tempo

  const temValor = (v) => v !== null && v !== undefined;
  let pontos = $derived(medicoes.filter((m) => temValor(m.valor)));
  let escala = $derived.by(() => {
    const vals = [...pontos.map((m) => m.valor), linhaBase, alvo].filter(temValor);
    if (!vals.length) return null;
    let min = Math.min(...vals);
    let max = Math.max(...vals);
    if (min === max) { min -= 1; max += 1; }
    return { min, max };
  });
  const ALTURA = H - EIXO;
  const y = (v, e) => ALTURA - PAD - ((v - e.min) / (e.max - e.min)) * (ALTURA - 2 * PAD);
  const x = (i, n) => (n <= 1 ? W / 2 : PAD + 10 + (i / (n - 1)) * (W - 2 * PAD - 20));
  let linha = $derived(
    escala ? pontos.map((m, i) => `${x(i, pontos.length)},${y(m.valor, escala)}`).join(" ") : "",
  );
  const quando = (m) => (m.ano_ref ? String(m.ano_ref) : fmtData(m.data_ref).slice(0, 5));
  // até 6 pontos, todos os rótulos; acima disso, o primeiro e o último
  const mostraRotulo = (i, n) => n <= 6 || i === 0 || i === n - 1;
</script>

{#if escala && pontos.length}
  <figure class="space-y-0.5">
    <svg viewBox={`0 0 ${W} ${H}`} class="w-full max-w-xs h-[4.5rem]" role="img" aria-label={rotulo}>
      {#if temValor(linhaBase)}
        <line x1="0" x2={W} y1={y(linhaBase, escala)} y2={y(linhaBase, escala)} stroke="#9ca3af" stroke-dasharray="3 3" stroke-width="1" />
      {/if}
      {#if temValor(alvo)}
        <line x1="0" x2={W} y1={y(alvo, escala)} y2={y(alvo, escala)} stroke="#16a34a" stroke-dasharray="4 2" stroke-width="1" />
      {/if}
      <polyline points={linha} fill="none" stroke="#2563eb" stroke-width="2" />
      {#each pontos as m, i (m.id)}
        <circle cx={x(i, pontos.length)} cy={y(m.valor, escala)} r="2.5" fill="#2563eb">
          <title>{quando(m)}: {fmtNum(m.valor)}</title>
        </circle>
        {#if mostraRotulo(i, pontos.length)}
          <text x={x(i, pontos.length)} y={H - 2} text-anchor="middle" font-size="8" fill="#6b7280">{quando(m)}</text>
        {/if}
      {/each}
    </svg>
    <figcaption class="flex flex-wrap gap-x-3 text-xs text-gray-600">
      <span><span aria-hidden="true" class="text-blue-600">●</span> medições</span>
      {#if temValor(linhaBase)}<span><span aria-hidden="true" class="text-gray-400">┅</span> linha de base ({fmtNum(linhaBase)})</span>{/if}
      {#if temValor(alvo)}<span><span aria-hidden="true" class="text-green-600">┅</span> alvo ({fmtNum(alvo)})</span>{/if}
    </figcaption>
  </figure>
{/if}
