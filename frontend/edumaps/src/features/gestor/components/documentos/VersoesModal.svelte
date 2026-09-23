<!-- src/features/gestor/components/documentos/VersoesModal.svelte -->
<!--
  Modal com o histórico de versões (sobrescrita mantém as versões antigas).
  Cada linha tem download; onDownload(versao) dispara o download real.
-->
<script>
  import { MIME_ROTULO, formatarTamanho } from "../../constants/documentos.js";

  let { nome, versoes = [], baixando, onDownload, onFechar } = $props();

  function rotuloMime(mime) {
    return MIME_ROTULO[mime] ?? (mime ? mime.split("/").pop().toUpperCase() : "ARQ");
  }

  function quando(iso) {
    if (!iso) return "";
    return new Date(iso).toLocaleString("pt-BR");
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
        <h2 class="text-lg font-bold text-gray-900">Versões</h2>
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

    <ul class="overflow-y-auto divide-y divide-gray-100 flex-1">
      {#each versoes as v (v.versao)}
        <li class="flex items-center justify-between px-4 py-3 gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-medium text-gray-800">Versão {v.versao}</span>
              <span class="text-[10px] bg-gray-200 text-gray-600 rounded px-1 py-px uppercase">
                {rotuloMime(v.mime ?? v.mime)}
              </span>
              {#if versoes[0]?.versao === v.versao}
                <span class="text-[10px] bg-green-100 text-green-700 rounded px-1 py-px">atual</span>
              {/if}
            </div>
            <p class="text-xs text-gray-500 mt-0.5">
              {formatarTamanho(v.tamanho)} · {v.gestor ?? "Gestor"} · {quando(v.criado_em)}
            </p>
          </div>
          <button
            type="button"
            onclick={() => onDownload(v.versao)}
            disabled={baixando === v.versao}
            class="shrink-0 text-sm px-3 py-1.5 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            {baixando === v.versao ? "Baixando…" : "Baixar"}
          </button>
        </li>
      {/each}
      {#if !versoes.length}
        <li class="px-4 py-6 text-sm text-gray-400 text-center">Sem versões registradas.</li>
      {/if}
    </ul>
  </div>
</div>