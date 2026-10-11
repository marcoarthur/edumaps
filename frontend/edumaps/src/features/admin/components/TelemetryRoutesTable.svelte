<!-- src/features/admin/components/TelemetryRoutesTable.svelte -->
<script>
  // Top N rotas de frontend (páginas da SPA) com participação percentual.
  let { routes = [] } = $props();
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <h2 class="text-lg font-bold text-gray-900">Rotas mais acessadas</h2>
  <p class="text-sm text-gray-600 mt-1">Páginas da SPA, por número de acessos na janela.</p>

  {#if routes.length === 0}
    <p class="text-sm text-gray-500 mt-3">Sem acessos registrados nesta janela.</p>
  {:else}
    <table class="mt-3 w-full text-sm">
      <thead>
        <tr class="text-left text-xs uppercase tracking-wide text-gray-500">
          <th class="py-1">Rota</th>
          <th class="py-1 text-right">Acessos</th>
          <th class="py-1 text-right">%</th>
        </tr>
      </thead>
      <tbody>
        {#each routes as r (r.route)}
          <tr class="border-t border-gray-100">
            <td class="py-1.5 font-mono text-gray-800">{r.route}</td>
            <td class="py-1.5 text-right tabular-nums">{r.count}</td>
            <td class="py-1.5 text-right tabular-nums text-gray-500">{r.share_pct}%</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</section>
