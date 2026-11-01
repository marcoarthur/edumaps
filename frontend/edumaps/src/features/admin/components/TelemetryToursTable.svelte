<!-- src/features/admin/components/TelemetryToursTable.svelte -->
<script>
  // Ajuda guiada na janela: por tour, aberturas (por gatilho), conclusões,
  // fechamentos, taxa de conclusão e o passo em que mais se fecha.
  // Taxa sem abertura na janela e passo sem fechamento = "—" (#154: ausência
  // nunca é zero).
  import { tourManager } from "@/shared/tour";

  let { tours = [] } = $props();

  // Nome legível do catálogo; id cru se o tour saiu do catálogo.
  function nome(id) {
    return tourManager.obter(id)?.titulo ?? id;
  }

  function pct(v) {
    return v === null || v === undefined ? "—" : `${v.toLocaleString("pt-BR")}%`;
  }

  // "3 de 7"; sem fechamento na janela = "—".
  function passoAbandono(t) {
    if (t.top_dismiss_step === null || t.top_dismiss_step === undefined) return "—";
    return t.total_steps ? `${t.top_dismiss_step} de ${t.total_steps}` : `${t.top_dismiss_step}`;
  }
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <h2 class="text-lg font-bold text-gray-900">Ajuda guiada</h2>
  <p class="text-sm text-gray-600 mt-1">
    Uso dos tours na janela: quantas vezes foram abertos (sozinhos na primeira visita, pelo botão “?”
    ou por link), concluídos ou fechados antes do fim, e onde as pessoas desistem.
  </p>

  {#if tours.length === 0}
    <p class="text-sm text-gray-500 mt-3">Nenhum tour aberto nesta janela.</p>
  {:else}
    <div class="overflow-x-auto">
      <table class="mt-3 w-full text-sm">
        <thead>
          <tr class="text-left text-xs uppercase tracking-wide text-gray-500">
            <th class="py-1">Tour</th>
            <th class="py-1 text-right">Aberturas</th>
            <th class="py-1 text-right">Concluídos</th>
            <th class="py-1 text-right">Fechados</th>
            <th class="py-1 text-right">Conclusão</th>
            <th class="py-1 text-right">Mais fecham no passo</th>
          </tr>
        </thead>
        <tbody>
          {#each tours as t (t.tour_id)}
            <tr class="border-t border-gray-100 align-top">
              <td class="py-1.5 text-gray-800">
                {nome(t.tour_id)}
                <span class="block font-mono text-xs text-gray-400">{t.tour_id}</span>
              </td>
              <td class="py-1.5 text-right tabular-nums">
                {t.started}
                <span class="block text-xs text-gray-500">
                  auto {t.started_auto} · botão {t.started_button} · link {t.started_link}
                </span>
              </td>
              <td class="py-1.5 text-right tabular-nums">{t.completed}</td>
              <td class="py-1.5 text-right tabular-nums">{t.dismissed}</td>
              <td class="py-1.5 text-right tabular-nums">{pct(t.completion_pct)}</td>
              <td class="py-1.5 text-right tabular-nums">{passoAbandono(t)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</section>
