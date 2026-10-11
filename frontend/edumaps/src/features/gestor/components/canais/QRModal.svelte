<!-- src/features/gestor/components/canais/QRModal.svelte -->
<script>
  // Modal do QR code de uma lista (issue #208).
  // Renderiza a imagem do QR no navegador (lib `qrcode`, SVG — sem canvas),
  // o link copiável, os usos, a expiração e a ação de revogar.
  import QRCode from "qrcode";

  /** @type {{lista: object, qrcode?: object|null, gerando?: boolean, revogando?: boolean, onFechar: Function, onGerar: Function, onRevogar: Function}} */
  let {
    lista,
    qrcode = null,
    gerando = false,
    revogando = false,
    onFechar = () => {},
    onGerar = () => {},
    onRevogar = () => {},
  } = $props();

  let svg = $state("");
  let qrErro = $state(null);
  let copiado = $state(false);
  let linkInput = $state(null);

  const url = $derived(qrcode?.url ?? "");

  $effect(() => {
    const alvo = url;
    if (!alvo) {
      svg = "";
      qrErro = null;
      return;
    }
    let cancelado = false;
    QRCode.toString(alvo, { type: "svg", margin: 1, width: 220, errorCorrectionLevel: "M" })
      .then((gerado) => {
        if (!cancelado) {
          svg = gerado;
          qrErro = null;
        }
      })
      .catch(() => {
        if (!cancelado) {
          svg = "";
          qrErro = "Não foi possível desenhar o QR. Use o link abaixo.";
        }
      });
    return () => {
      cancelado = true;
    };
  });

  async function copiar() {
    if (!url) return;
    try {
      if (navigator?.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
      } else {
        linkInput?.select();
      }
      copiado = true;
      setTimeout(() => (copiado = false), 2000);
    } catch {
      linkInput?.select();
    }
  }

  function quando(iso) {
    return iso ? new Date(iso).toLocaleString("pt-BR") : "";
  }
</script>

<div
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
  role="dialog"
  aria-modal="true"
  aria-label="QR code da lista"
  tabindex="-1"
  data-testid="qr-modal"
  onclick={(e) => {
    if (e.target === e.currentTarget) onFechar();
  }}
  onkeydown={(e) => {
    if (e.key === "Escape") onFechar();
  }}
>
  <div class="w-full max-w-md bg-white rounded-lg shadow-xl max-h-[90vh] flex flex-col">
    <header class="flex items-start justify-between px-4 py-3 border-b">
      <div class="min-w-0">
        <h2 class="text-lg font-bold text-gray-900">QR code</h2>
        <p class="text-xs text-gray-500 truncate">{lista?.nome ?? "Lista"}</p>
      </div>
      <button
        type="button"
        aria-label="Fechar"
        onclick={onFechar}
        class="text-gray-400 hover:text-gray-700 text-xl leading-none"
      >×</button>
    </header>

    <div class="overflow-y-auto p-4 space-y-4">
      {#if !qrcode}
        <p class="text-sm text-gray-600">
          Nenhum QR ativo para esta lista. Gere um link para o público se inscrever.
        </p>
        <button
          type="button"
          onclick={onGerar}
          disabled={gerando}
          class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >
          {gerando ? "Gerando…" : "Gerar QR code"}
        </button>
      {:else}
        <div class="flex justify-center">
          <div
            class="rounded-md border border-gray-200 bg-white p-2 w-[236px] h-[236px] flex items-center justify-center"
            data-testid="qr-imagem"
            aria-label={`QR code de ${lista?.nome ?? "lista"}`}
          >
            {#if svg}
              {@html svg}
            {:else if qrErro}
              <span class="text-xs text-red-600 text-center px-3">{qrErro}</span>
            {:else}
              <span class="text-xs text-gray-400">Desenhando QR…</span>
            {/if}
          </div>
        </div>

        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Link de inscrição</span>
          <div class="mt-1 flex gap-2">
            <input
              bind:this={linkInput}
              readonly
              value={url}
              data-testid="qr-link"
              aria-label="Link de inscrição"
              class="flex-1 h-10 px-3 rounded-md border border-gray-300 text-xs text-gray-700 bg-gray-50 focus:outline-none"
              onfocus={(e) => e.currentTarget.select()}
            />
            <button
              type="button"
              onclick={copiar}
              class="px-3 h-10 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
            >{copiado ? "Copiado!" : "Copiar link"}</button>
          </div>
        </label>

        <dl class="grid grid-cols-2 gap-3 text-sm">
          <div class="rounded-md border border-gray-200 p-3">
            <dt class="text-xs text-gray-500">Usos</dt>
            <dd class="font-semibold text-gray-900" data-testid="qr-usos">
              {qrcode.usos ?? 0}{qrcode.max_usos ? ` / ${qrcode.max_usos}` : ""}
            </dd>
          </div>
          <div class="rounded-md border border-gray-200 p-3">
            <dt class="text-xs text-gray-500">Expira em</dt>
            <dd class="font-semibold text-gray-900" data-testid="qr-expira">
              {qrcode.expira_em ? quando(qrcode.expira_em) : "Sem expiração"}
            </dd>
          </div>
        </dl>

        <button
          type="button"
          onclick={onRevogar}
          disabled={revogando}
          class="w-full h-11 rounded-md border border-red-300 text-red-700 text-sm font-semibold hover:bg-red-50 disabled:opacity-50 transition-colors"
        >
          {revogando ? "Revogando…" : "Revogar QR"}
        </button>
      {/if}
    </div>
  </div>
</div>
