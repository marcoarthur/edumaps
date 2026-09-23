<!-- src/features/gestor/components/documentos/HistoricoModal.svelte -->
<!--
  Modal de auditoria de um documento: criado, sobrescrito, renomeado,
  movido, tags, excluido — sempre com autor e timestamp.
-->
<script>
  import { ACAO_ROTULO } from "../../constants/documentos.js";

  let { nome, historico = [], onFechar } = $props();

  function quando(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleString("pt-BR");
  }

  function resumoDetalhes(d) {
    if (!d) return "";
    const partes = [];
    if (d.para && d.de !== undefined) partes.push(`"${d.de}" → "${d.para}"`);
    if (Array.isArray(d.adicionadas) && d.adicionadas.length) partes.push(`+ ${d.adicionadas.join(", ")}`);
    if (Array.isArray(d.removidas) && d.removidas.length) partes.push(`− ${d.removidas.join(", ")}`);
    if (d.versao) partes.push(`v${d.versao}`);
    if (d.tamanho) partes.push(`${d.tamanho} bytes`);
    return partes.join(" · ");
  }
</script>

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
  onclick={(e) => {
    if (e.target === e.currentTarget) onFechar();
  }}
>
  <div class="w-full max-w-lg bg-white rounded-lg shadow-xl max-h-[80vh] flex flex-col">
    <header class="flex items-center justify-between px-4 py-3 border-b">
      <div>
        <h2 class="text-lg font-bold text-gray-900">Histórico</h2>
        <p class="text-xs text-gray-500 truncate max-w-sm">{nome}</p>
      </div>
      <button
        type="button"
        aria-label="Fechar"
        onclick={onFechar}
        class="text-gray-400 hover:text-gray-700 text-xl leading-none"
      >
        ×
      </button>
    </header>

    <ol class="overflow-y-auto divide-y divide-gray-100 flex-1">
      {#each historico as h (h.id)}
        <li class="px-4 py-3 flex items-start gap-3">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="text-xs font-semibold text-indigo-700 uppercase tracking-wide">
                {ACAO_ROTULO[h.acao] ?? h.acao}
              </span>
              {#if h.gestor}
                <span class="text-xs text-gray-500">por {h.gestor}</span>
              {/if}
            </div>
            {#if resumoDetalhes(h.detalhes)}
              <p class="text-sm text-gray-600 mt-0.5">{resumoDetalhes(h.detalhes)}</p>
            {/if}
          </div>
          <span class="text-xs text-gray-400 shrink-0">{quando(h.criado_em)}</span>
        </li>
      {/each}
      {#if !historico.length}
        <li class="px-4 py-6 text-sm text-gray-400 text-center">Sem eventos registrados.</li>
      {/if}
    </ol>
  </div>
</div>