<!-- src/shared/ui/components/ConfirmDialog.svelte -->
<script>
  // Diálogo de confirmação acessível (role="alertdialog", aria-modal, título e
  // descrição ligados por id). Escape ou clique fora cancelam (exceto durante
  // `ocupado`). O conteúdo extra (ex.: campo "motivo") vem pelo `children`.
  // Ao abrir, o foco vai para o primeiro campo do conteúdo ou para "Cancelar".
  import { onMount } from "svelte";

  /**
   * @type {{
   *   titulo: string,
   *   descricao?: string|null,
   *   confirmarRotulo?: string,
   *   cancelarRotulo?: string,
   *   perigo?: boolean,
   *   ocupado?: boolean,
   *   erro?: string|null,
   *   onConfirmar: () => void,
   *   onCancelar: () => void,
   *   children?: import("svelte").Snippet,
   *   testid?: string,
   * }}
   */
  let {
    titulo,
    descricao = null,
    confirmarRotulo = "Confirmar",
    cancelarRotulo = "Cancelar",
    perigo = false,
    ocupado = false,
    erro = null,
    onConfirmar,
    onCancelar,
    children,
    testid = "confirm-dialog",
  } = $props();

  const uid = Math.random().toString(36).slice(2, 9);
  let painel = $state(null);
  let anterior = null;

  function cancelar() {
    if (!ocupado) onCancelar();
  }

  onMount(() => {
    anterior = typeof document !== "undefined" ? document.activeElement : null;
    const alvo =
      painel?.querySelector("[data-dialog-conteudo] input, [data-dialog-conteudo] textarea, [data-dialog-conteudo] select") ??
      painel?.querySelector("[data-dialog-cancelar]");
    alvo?.focus?.();
    return () => anterior?.focus?.();
  });
</script>

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
  role="presentation"
  onclick={(e) => {
    if (e.target === e.currentTarget) cancelar();
  }}
  onkeydown={(e) => {
    if (e.key === "Escape") cancelar();
  }}
>
  <div
    bind:this={painel}
    role="alertdialog"
    aria-modal="true"
    aria-labelledby={`dlg-titulo-${uid}`}
    aria-describedby={descricao ? `dlg-desc-${uid}` : undefined}
    tabindex="-1"
    data-testid={testid}
    class="w-full max-w-md bg-white rounded-lg shadow-xl p-5 space-y-4"
  >
    <h2 id={`dlg-titulo-${uid}`} class="text-lg font-bold text-gray-900">{titulo}</h2>
    {#if descricao}
      <p id={`dlg-desc-${uid}`} class="text-sm text-gray-600">{descricao}</p>
    {/if}
    {#if children}
      <div data-dialog-conteudo>{@render children()}</div>
    {/if}
    {#if erro}
      <p class="text-sm text-red-600" role="alert">{erro}</p>
    {/if}
    <div class="flex justify-end gap-2">
      <button
        type="button"
        data-dialog-cancelar
        onclick={cancelar}
        disabled={ocupado}
        class="px-4 h-9 rounded-md border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
      >{cancelarRotulo}</button>
      <button
        type="button"
        onclick={onConfirmar}
        disabled={ocupado}
        class="px-4 h-9 rounded-md text-white text-sm font-semibold disabled:opacity-50 {perigo
          ? 'bg-red-600 hover:bg-red-700'
          : 'bg-indigo-600 hover:bg-indigo-700'}"
      >{confirmarRotulo}</button>
    </div>
  </div>
</div>
