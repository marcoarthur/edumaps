<!-- src/features/gestor/components/canais/ExclusoesHistorico.svelte -->
<script>
  // Histórico de exclusões da escola (issue #214, onda 2): pedidos do titular,
  // remoções feitas pela gestão e execuções da retenção automática. Registros
  // sem dados pessoais: data, origem, regra ou motivo e contagens.
  /** @type {{exclusoes?: Array, carregando?: boolean, erro?: string|null}} */
  let { exclusoes = [], carregando = false, erro = null } = $props();

  const ORIGEM = {
    titular: { texto: "Titular", classe: "bg-blue-100 text-blue-700" },
    gestor: { texto: "Gestor", classe: "bg-purple-100 text-purple-700" },
    retencao: { texto: "Retenção", classe: "bg-gray-100 text-gray-700" },
  };

  const REGRA = {
    metadados: "Metadados técnicos vencidos",
    pendentes: "Inscrições nunca confirmadas",
    lista_inativa: "Lista desativada",
    listas_inativas: "Lista desativada",
  };

  function detalhe(e) {
    if (e.origem === "retencao") return REGRA[e.regra] ?? e.regra ?? "—";
    if (e.origem === "titular") return "Pedido pelo link pessoal";
    return e.motivo || "Sem motivo informado";
  }

  const data = (iso) => (iso ? new Date(iso).toLocaleString("pt-BR") : "—");
</script>

<section
  class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3"
  aria-labelledby="exclusoes-titulo"
  data-testid="exclusoes-historico"
>
  <div>
    <h2 id="exclusoes-titulo" class="text-sm font-semibold text-gray-900">Exclusões</h2>
    <p class="text-xs text-gray-500">
      Remoções de dados nesta escola. Ficam só datas e contagens, sem dados pessoais.
    </p>
  </div>

  {#if carregando}
    <p class="text-sm text-gray-500">Carregando histórico…</p>
  {:else if erro}
    <p class="text-sm text-red-600" role="alert">{erro}</p>
  {:else if exclusoes.length === 0}
    <p class="py-4 text-center text-sm text-gray-400">
      Nenhuma exclusão registrada até agora.
    </p>
  {:else}
    <table class="w-full text-sm">
      <thead class="hidden sm:table-header-group bg-gray-50 text-gray-500 text-xs uppercase">
        <tr>
          <th class="text-left font-medium px-3 py-2">Data</th>
          <th class="text-left font-medium px-3 py-2">Origem</th>
          <th class="text-left font-medium px-3 py-2">Regra ou motivo</th>
          <th class="text-right font-medium px-3 py-2">Contatos</th>
          <th class="text-right font-medium px-3 py-2">Inscrições</th>
          <th class="text-right font-medium px-3 py-2">Membros</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each exclusoes as e (e.id)}
          {@const o = ORIGEM[e.origem] ?? { texto: e.origem, classe: "bg-gray-100 text-gray-700" }}
          <tr class="block sm:table-row py-2 sm:py-0" data-testid="exclusao-row">
            <td class="block sm:table-cell px-3 sm:py-2 text-gray-600">{data(e.created_at)}</td>
            <td class="block sm:table-cell px-3 sm:py-2" data-testid="exclusao-origem">
              <span class={`inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold ${o.classe}`}>{o.texto}</span>
            </td>
            <td class="block sm:table-cell px-3 sm:py-2 text-gray-700" data-testid="exclusao-detalhe">{detalhe(e)}</td>
            <td class="inline-block sm:table-cell px-3 sm:py-2 sm:text-right text-gray-700" data-testid="exclusao-contatos">
              <span class="sm:hidden text-xs text-gray-400">Contatos </span>{e.contatos ?? 0}
            </td>
            <td class="inline-block sm:table-cell px-3 sm:py-2 sm:text-right text-gray-700" data-testid="exclusao-inscricoes">
              <span class="sm:hidden text-xs text-gray-400">Inscrições </span>{e.inscricoes ?? 0}
            </td>
            <td class="inline-block sm:table-cell px-3 sm:py-2 sm:text-right text-gray-700" data-testid="exclusao-membros">
              <span class="sm:hidden text-xs text-gray-400">Membros </span>{e.membros ?? 0}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</section>
