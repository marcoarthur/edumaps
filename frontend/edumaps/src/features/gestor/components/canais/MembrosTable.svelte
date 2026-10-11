<!-- src/features/gestor/components/canais/MembrosTable.svelte -->
<script>
  // Tabela de membros (contatos inscritos) de uma lista. Mobile-first: vira
  // cartões empilhados em telas estreitas e tabela em telas largas.
  /** @type {{membros?: Array, carregando?: boolean}} */
  let { membros = [], carregando = false } = $props();

  function quando(iso) {
    return iso ? new Date(iso).toLocaleString("pt-BR") : "—";
  }
</script>

<div class="rounded-card bg-white border border-gray-200 shadow-card" data-testid="membros-table">
  {#if carregando}
    <p class="p-4 text-sm text-gray-500">Carregando inscrições…</p>
  {:else if membros.length === 0}
    <p class="p-4 text-sm text-gray-400">
      Ninguém se inscreveu ainda. Compartilhe o QR ou o link.
    </p>
  {:else}
    <table class="w-full text-sm">
      <thead class="hidden sm:table-header-group bg-gray-50 text-gray-500 text-xs uppercase">
        <tr>
          <th class="text-left font-medium px-4 py-2">Nome</th>
          <th class="text-left font-medium px-4 py-2">Telefone</th>
          <th class="text-left font-medium px-4 py-2">Quando</th>
          <th class="text-left font-medium px-4 py-2">Status</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each membros as m (m.id)}
          <tr class="block sm:table-row" data-testid="membro-row">
            <td class="block sm:table-cell px-4 pt-3 sm:py-2 font-medium text-gray-900">
              <span class="sm:hidden text-xs uppercase text-gray-400">Nome </span>{m.nome}
            </td>
            <td class="block sm:table-cell px-4 sm:py-2 text-gray-700">
              <span class="sm:hidden text-xs uppercase text-gray-400">Telefone </span>{m.telefone}
            </td>
            <td class="block sm:table-cell px-4 sm:py-2 text-gray-500">
              <span class="sm:hidden text-xs uppercase text-gray-400">Quando </span>{quando(m.quando)}
            </td>
            <td class="block sm:table-cell px-4 pb-3 sm:py-2">
              {#if m.validado}
                <span class="inline-block rounded-full bg-green-100 text-green-700 px-2 py-0.5 text-[10px] font-semibold uppercase">validado</span>
              {:else}
                <span class="inline-block rounded-full bg-gray-100 text-gray-600 px-2 py-0.5 text-[10px] font-semibold uppercase">não validado</span>
              {/if}
              {#if m.conflito}
                <span class="inline-block ml-1 rounded-full bg-amber-100 text-amber-700 px-2 py-0.5 text-[10px] font-semibold uppercase">conflito</span>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>
