<!-- src/features/gestor/components/canais/QRModal.svelte -->
<script>
  // Modal do QR code de uma lista (issue #208).
  // Renderiza a imagem do QR no navegador (lib `qrcode`, SVG — sem canvas),
  // o link copiável, os usos, a expiração e a ação de revogar.
  // Issue #214: "Válido até" e "Limite de inscrições" opcionais ao gerar/
  // rotacionar (validados aqui; o 400 do backend chega por `erroGerar`) e o
  // estado do QR (ativo, expirado, esgotado, revogado).
  import QRCode from "qrcode";
  import { QR_ESTADOS, estadoQr, opcoesQr } from "../../utils/qrEstado.js";

  /** @type {{lista: object, qrcode?: object|null, gerando?: boolean, revogando?: boolean, erroGerar?: string|null, onFechar: Function, onGerar: (opcoes: {expira_em?: string, max_usos?: number}) => void, onRevogar: Function}} */
  let {
    lista,
    qrcode = null,
    gerando = false,
    revogando = false,
    erroGerar = null,
    onFechar = () => {},
    onGerar = () => {},
    onRevogar = () => {},
  } = $props();

  // opções de geração/rotação
  let validoAte = $state("");
  let limite = $state("");
  let erroOpcoes = $state(null);
  let rotacionarAberto = $state(false);

  const estado = $derived(estadoQr(qrcode));
  const selo = $derived(estado ? QR_ESTADOS[estado] : null);

  function gerar() {
    const { erro, opcoes } = opcoesQr({ validoAte, limite });
    erroOpcoes = erro;
    if (erro) return;
    onGerar(opcoes);
  }

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

{#snippet opcoesGeracao(rotulo)}
  <form
    class="space-y-3"
    data-testid="qr-opcoes"
    novalidate
    onsubmit={(e) => { e.preventDefault(); gerar(); }}
  >
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <label class="block">
        <span class="block text-xs font-medium text-gray-700">Válido até (opcional)</span>
        <input
          type="datetime-local"
          bind:value={validoAte}
          class="mt-1 w-full h-10 px-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </label>
      <label class="block">
        <span class="block text-xs font-medium text-gray-700">Limite de inscrições (opcional)</span>
        <input
          type="number"
          min="1"
          step="1"
          inputmode="numeric"
          bind:value={limite}
          placeholder="Sem limite"
          class="mt-1 w-full h-10 px-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </label>
    </div>
    {#if erroOpcoes || erroGerar}
      <p class="text-sm text-red-600" role="alert">{erroOpcoes ?? erroGerar}</p>
    {/if}
    <button
      type="submit"
      disabled={gerando}
      class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
    >
      {gerando ? "Gerando…" : rotulo}
    </button>
  </form>
{/snippet}

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
        {@render opcoesGeracao("Gerar QR code")}
      {:else}
        {#if selo}
          <div class="flex items-center justify-between gap-2">
            <span class="text-xs text-gray-500">Estado do QR</span>
            <span
              class={`inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold ${selo.classe}`}
              data-testid="qr-status"
            >{selo.rotulo}</span>
          </div>
          {#if estado === "expirado"}
            <p class="text-xs text-gray-600">O prazo de validade passou: o link não aceita mais inscrições. Gere um novo QR.</p>
          {:else if estado === "esgotado"}
            <p class="text-xs text-gray-600">O limite de inscrições foi atingido: o link não aceita mais inscrições. Gere um novo QR.</p>
          {:else if estado === "revogado"}
            <p class="text-xs text-gray-600">Este QR foi revogado e o link não funciona mais.</p>
          {/if}
        {/if}
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

        <section class="rounded-md border border-gray-200">
          <button
            type="button"
            aria-expanded={rotacionarAberto || estado !== "ativo"}
            onclick={() => (rotacionarAberto = !rotacionarAberto)}
            class="w-full px-3 py-2 text-left text-sm font-medium text-blue-700 hover:bg-blue-50"
          >Gerar novo QR (o atual deixa de funcionar)</button>
          {#if rotacionarAberto || estado !== "ativo"}
            <div class="px-3 pb-3">
              {@render opcoesGeracao("Gerar novo QR")}
            </div>
          {/if}
        </section>

        {#if estado !== "revogado"}
          <button
            type="button"
            onclick={onRevogar}
            disabled={revogando}
            class="w-full h-11 rounded-md border border-red-300 text-red-700 text-sm font-semibold hover:bg-red-50 disabled:opacity-50 transition-colors"
          >
            {revogando ? "Revogando…" : "Revogar QR"}
          </button>
        {/if}
      {/if}
    </div>
  </div>
</div>
