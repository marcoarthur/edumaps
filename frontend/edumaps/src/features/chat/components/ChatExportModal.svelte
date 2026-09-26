<!-- src/features/chat/components/ChatExportModal.svelte -->
<script>
  /**
   * @param {boolean} open
   * @param {Function} onClose
   * @param {Function} onExport - callback (format) onde format é 'md'
   */
  let { open = false, onClose = () => {}, onExport = () => {} } = $props();

  let format = $state("md");
</script>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" role="dialog" aria-modal="true" aria-labelledby="export-modal-title">
    <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
      <div class="flex items-center justify-between p-4 border-b">
        <h2 id="export-modal-title" class="text-lg font-semibold text-gray-900">Exportar conversas</h2>
        <button onclick={onClose} class="text-gray-400 hover:text-gray-600 text-2xl leading-none" aria-label="Fechar">×</button>
      </div>
      <div class="p-4 space-y-4">
        <p class="text-sm text-gray-600">Escolha o formato de exportação.</p>
        <div class="space-y-2">
          <label class="flex items-center gap-2 cursor-pointer">
            <input type="radio" name="format" bind:group={format} value="md" class="h-4 w-4 text-blue-600 focus:ring-blue-500" />
            <span class="text-sm text-gray-700">Markdown (.md) — Pergunta: xxx / Resposta: yyyy data-hora</span>
          </label>
        </div>
      </div>
      <div class="flex justify-end gap-2 p-4 border-t">
        <button onclick={onClose} class="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 text-sm font-medium">Cancelar</button>
        <button onclick={() => { onExport(format); onClose(); }} class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium">Exportar</button>
      </div>
    </div>
  </div>
{/if}