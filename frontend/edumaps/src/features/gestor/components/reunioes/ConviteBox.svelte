<!-- src/features/gestor/components/reunioes/ConviteBox.svelte -->
<script>
  // Caixa do convite copiável (decisão da fase 3: sem envio real). Recebe o
  // texto pronto (buildConvite) e oferece: copiar texto, copiar e-mail e
  // abrir no WhatsApp com número opcional pré-preenchido.
  import { addToast } from "@/shared/stores/toastStore.js";
  import { waLink } from "../../utils/convite.js";

  /** @type {{convite: {textoWhatsApp: string, textoEmail: string, linhaAssunto: string}, telefoneInicial?: string|null}} */
  let { convite, telefoneInicial = null } = $props();

  let telefone = $state("");
  let copiado = $state({ wa: false, email: false });

  $effect(() => {
    if (telefoneInicial && !telefone) telefone = telefoneInicial;
  });

  async function copiar(texto, campoTipo) {
    try {
      await navigator.clipboard.writeText(texto);
    } catch {
      // fallback p/ navegadores sem Clipboard API
      const ta = document.createElement("textarea");
      ta.value = texto;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      ta.remove();
    }
    copiado[campoTipo] = true;
    addToast(
      campoTipo === "wa" ? "Convite copiado! Cole no WhatsApp." : "E-mail copiado!",
      "success",
    );
    setTimeout(() => {
      copiado[campoTipo] = false;
    }, 2000);
  }
</script>

<div class="rounded-md border border-gray-200 bg-gray-50 p-4 space-y-3">
  <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">
    Convite (copie e envie)
  </p>

  <pre
    class="whitespace-pre-wrap rounded-md border border-gray-200 bg-white p-3 text-xs text-gray-700"
    role="region"
    aria-label="Texto do convite"
  >{convite.textoWhatsApp}</pre>

  <div class="flex flex-wrap items-center gap-2">
    <button
      type="button"
      onclick={() => copiar(convite.textoWhatsApp, "wa")}
      class="px-3 py-1.5 rounded-md bg-green-600 text-white text-xs font-medium hover:bg-green-700 transition-colors"
    >
      {copiado.wa ? "Copiado ✓" : "Copiar convite"}
    </button>

    <label class="flex items-center gap-2 text-xs text-gray-600">
      <span>WhatsApp:</span>
      <input
        type="tel"
        bind:value={telefone}
        placeholder="+5511 99999-0001"
        class="w-44 h-8 px-2 rounded-md border border-gray-300 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <a
        href={waLink(convite.textoWhatsApp, telefone)}
        target="_blank"
        rel="noopener noreferrer"
        class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
      >Abrir</a>
    </label>

    <button
      type="button"
      onclick={() => copiar(`${convite.linhaAssunto}\n\n${convite.textoEmail}`, "email")}
      class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
    >
      {copiado.email ? "Copiado ✓" : "Copiar e-mail"}
    </button>
  </div>
</div>