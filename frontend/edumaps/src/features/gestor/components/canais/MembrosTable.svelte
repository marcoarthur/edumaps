<!-- src/features/gestor/components/canais/MembrosTable.svelte -->
<script>
  // Tabela de membros (contatos inscritos) de uma lista. Mobile-first: vira
  // cartões empilhados em telas estreitas e tabela em telas largas.
  // Issue #214: conforme a `coleta` da lista, mostra telefone e/ou e-mail, o
  // estado de cada contato e o estado geral (inclui `parcial`).
  // Onda 2: com `onRemover`, cada linha ganha a ação "Remover inscrito".
  /** @type {{membros?: Array, carregando?: boolean, mensagemVazia?: string, coleta?: string, onRemover?: ((membro: object) => void)|null}} */
  let {
    membros = [],
    carregando = false,
    mensagemVazia = "Ninguém se inscreveu ainda. Compartilhe o QR ou o link.",
    coleta = "telefone",
    onRemover = null,
  } = $props();

  const mostraTelefone = $derived(coleta !== "email");
  const mostraEmail = $derived(coleta !== "telefone");
  // estado por contato só faz sentido quando há mais de um tipo de contato
  const porContato = $derived(coleta !== "telefone");

  function quando(iso) {
    return iso ? new Date(iso).toLocaleString("pt-BR") : "—";
  }

  const VIA = { telegram: "Telegram", whatsapp: "WhatsApp", email: "E-mail" };

  // Selo do estado geral de confirmação (issues #212/#214).
  function selo(m) {
    if (m.estado === "confirmado") {
      const via = porContato ? null : (VIA[m.confirmado_via] ?? m.confirmado_via);
      return {
        texto: via ? `Confirmado (${via})` : "Confirmado",
        data: m.confirmado_em ? new Date(m.confirmado_em).toLocaleDateString("pt-BR") : null,
        classe: "bg-green-100 text-green-700",
      };
    }
    if (m.estado === "parcial") {
      return { texto: "Parcial", data: null, classe: "bg-orange-100 text-orange-700" };
    }
    if (m.estado === "pendente") {
      return { texto: "Pendente", data: null, classe: "bg-amber-100 text-amber-700" };
    }
    return { texto: "Não exigida", data: null, classe: "bg-gray-100 text-gray-600" };
  }

  // Selo pequeno do estado de um contato (telefone_estado / email_estado).
  const SELO_CONTATO = {
    confirmado: { texto: "confirmado", classe: "text-green-700" },
    pendente: { texto: "pendente", classe: "text-amber-700" },
    nao_exigida: { texto: "não exigida", classe: "text-gray-500" },
  };
</script>

{#snippet estadoContato(estado, testid)}
  {#if porContato && estado && SELO_CONTATO[estado]}
    <span class={`block text-[11px] font-medium ${SELO_CONTATO[estado].classe}`} data-testid={testid}>
      {SELO_CONTATO[estado].texto}
    </span>
  {/if}
{/snippet}

<div class="rounded-card bg-white border border-gray-200 shadow-card" data-testid="membros-table">
  {#if carregando}
    <p class="p-4 text-sm text-gray-500">Carregando inscrições…</p>
  {:else if membros.length === 0}
    <p class="p-4 text-sm text-gray-400">{mensagemVazia}</p>
  {:else}
    <table class="w-full text-sm">
      <thead class="hidden sm:table-header-group bg-gray-50 text-gray-500 text-xs uppercase">
        <tr>
          <th class="text-left font-medium px-4 py-2">Nome</th>
          {#if mostraTelefone}
            <th class="text-left font-medium px-4 py-2">Telefone</th>
          {/if}
          {#if mostraEmail}
            <th class="text-left font-medium px-4 py-2">E-mail</th>
          {/if}
          <th class="text-left font-medium px-4 py-2">Quando</th>
          <th class="text-left font-medium px-4 py-2">Estado</th>
          <th class="text-left font-medium px-4 py-2">Status</th>
          {#if onRemover}
            <th class="text-left font-medium px-4 py-2"><span class="sr-only">Ações</span></th>
          {/if}
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each membros as m (m.id)}
          {@const s = selo(m)}
          <tr class="block sm:table-row" data-testid="membro-row">
            <td class="block sm:table-cell px-4 pt-3 sm:py-2 font-medium text-gray-900">
              <span class="sm:hidden text-xs uppercase text-gray-400">Nome </span>{m.nome}
            </td>
            {#if mostraTelefone}
              <td class="block sm:table-cell px-4 sm:py-2 text-gray-700" data-testid="membro-telefone">
                <span class="sm:hidden text-xs uppercase text-gray-400">Telefone </span>{m.telefone || "—"}
                {#if m.telefone}{@render estadoContato(m.telefone_estado, "membro-telefone-estado")}{/if}
              </td>
            {/if}
            {#if mostraEmail}
              <td class="block sm:table-cell px-4 sm:py-2 text-gray-700 break-all" data-testid="membro-email">
                <span class="sm:hidden text-xs uppercase text-gray-400">E-mail </span>{m.email || "—"}
                {#if m.email}{@render estadoContato(m.email_estado, "membro-email-estado")}{/if}
              </td>
            {/if}
            <td class="block sm:table-cell px-4 sm:py-2 text-gray-500">
              <span class="sm:hidden text-xs uppercase text-gray-400">Quando </span>{quando(m.quando)}
            </td>
            <td class="block sm:table-cell px-4 sm:py-2" data-testid="membro-estado">
              <span class="sm:hidden text-xs uppercase text-gray-400">Estado </span>
              <span class={`inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold ${s.classe}`}>{s.texto}</span>
              {#if s.data}
                <span class="block text-[11px] text-gray-500 mt-0.5">em {s.data}</span>
              {/if}
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
            {#if onRemover}
              <td class="block sm:table-cell px-4 pb-3 sm:py-2 sm:text-right">
                <button
                  type="button"
                  aria-label={`Remover inscrito ${m.nome}`}
                  onclick={() => onRemover(m)}
                  class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50 transition-colors"
                >Remover</button>
              </td>
            {/if}
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>
